"""Behavior and failure-path tests for project-local Codex workflow recording."""

import contextlib
from concurrent.futures import ThreadPoolExecutor
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "codex_observe"))
from store import Store, encode, now, read, save, sha
from workflow import Workflow
from record_hook import record
from report import analyze, build_report


class RecordingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.store = Store(self.root)
        self.session = str(uuid.uuid4())
        self.worker = str(uuid.uuid4())
        self.main_context = dict(session_id=self.session, actor_id=self.session, hook_binding_observed=True)
        self.worker_context = dict(self.main_context, actor_id=self.worker)
        self.main = Workflow(self.store, self.main_context)
        self.child = Workflow(self.store, self.worker_context)
        self.output = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.output)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__, None, None, None)
        (self.root / "result.txt").write_text("before\n")

    def hook(self, kind, actor=None, **extra):
        payload = dict(session_id=self.session, cwd=str(self.root), hook_event_name=kind, **extra)
        if actor:
            payload["agent_id"] = actor
        return record(payload, encode(payload), self.root)

    def create(self):
        return self.main.create("Fix result", "Produce the required result.", ["The project check passes"], ["result.txt"])["task_id"]

    def acknowledge(self, task, revision=1):
        assignment = self.child.read_assignment(task, revision)
        self.child.ack(task, revision, assignment["assignment_sha256"])
        return assignment

    def submit(self, task, revision=1):
        self.acknowledge(task, revision)
        return self.child.submit(task, revision, "Updated result", ["result.txt"])

    def test_worker_binding_keeps_concurrent_sessions_separate(self):
        self.hook("PreToolUse", self.worker, tool_name="Bash", tool_use_id="one")
        with patch.dict(os.environ, {"CODEX_THREAD_ID": self.worker}):
            self.assertEqual(self.store.context()["session_id"], self.session)
            with self.assertRaises(ValueError):
                self.store.context(str(uuid.uuid4()))
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ValueError):
                self.store.context()

    def test_parallel_hook_files_are_complete_and_unique(self):
        self.hook("SessionStart")
        with ThreadPoolExecutor(max_workers=6) as executor:
            list(executor.map(lambda n: self.hook("PreToolUse", self.worker, tool_use_id=str(n)), range(30)))
        paths = list((self.store.session(self.session) / "hooks").glob("*.json"))
        self.assertEqual(len(paths), 31)
        self.assertEqual(len({read(p)["record_id"] for p in paths}), 31)

    def test_assignment_read_returns_exact_text_and_wrong_digest_is_rejected(self):
        task = self.create()
        value = self.child.read_assignment(task, 1)
        self.assertEqual(value["assignment"]["instructions"], "Produce the required result.")
        with self.assertRaises(ValueError):
            self.child.ack(task, 1, "wrong")
        self.child.ack(task, 1, value["assignment_sha256"])
        stranger = Workflow(self.store, dict(self.worker_context, actor_id=str(uuid.uuid4())))
        stranger.read_assignment(task, 1)
        with self.assertRaises(ValueError):
            stranger.ack(task, 1, value["assignment_sha256"])

    def test_worker_cannot_accept_own_result(self):
        task = self.create()
        self.submit(task)
        with self.assertRaises(ValueError):
            self.child.check(task, 1, "true", 3)
        with self.assertRaises(ValueError):
            self.child.decide(task, 1, "accepted", "Self approval")

    def test_unverified_and_failed_results_cannot_be_accepted(self):
        task = self.create()
        self.submit(task)
        with self.assertRaises(ValueError):
            self.main.decide(task, 1, "accepted", "No check")
        check = self.main.check(task, 1, "printf failure; exit 23", 3)
        self.assertEqual(check["data"]["exit_code"], 23)
        self.assertFalse(check["data"]["passed"])
        self.main.check(task, 1, "true", 3)
        with self.assertRaises(ValueError):
            self.main.decide(task, 1, "accepted", "Ignore the failure")

    def test_correction_preserves_first_artifact_and_accepts_second(self):
        task = self.create()
        first = self.submit(task)
        self.main.check(task, 1, "exit 1", 3)
        self.main.decide(task, 1, "correction_requested", "Wrong result", "Write the corrected result")
        with self.assertRaises(ValueError):
            self.child.submit(task, 1, "Late result", [])
        (self.root / "result.txt").write_text("corrected\n")
        self.submit(task, 2)
        self.main.check(task, 2, "test \"$(cat result.txt)\" = corrected", 3)
        result = self.main.decide(task, 2, "accepted", "The required result passed the check")
        self.assertEqual(result["data"]["status"], "accepted")
        old = self.main.folder(task) / "artifacts" / first["data"]["artifact_id"] / "files/result.txt"
        self.assertEqual(old.read_text(), "before\n")

    def test_changes_before_or_after_check_reject_stale_evidence(self):
        task = self.create()
        self.submit(task)
        (self.root / "result.txt").write_text("changed")
        with self.assertRaises(ValueError):
            self.main.check(task, 1, "true", 3)
        (self.root / "result.txt").write_text("before\n")
        self.main.check(task, 1, "true", 3)
        (self.root / "result.txt").write_text("changed again")
        with self.assertRaises(ValueError):
            self.main.decide(task, 1, "accepted", "Old tests")

    def test_check_that_changes_artifact_does_not_pass(self):
        task = self.create()
        self.submit(task)
        check = self.main.check(task, 1, "printf mutation > result.txt", 3)
        self.assertEqual(check["data"]["exit_code"], 0)
        self.assertFalse(check["data"]["passed"])

    def test_changed_verification_log_is_rejected(self):
        task = self.create()
        self.submit(task)
        check = self.main.check(task, 1, "printf success", 3)
        (self.root / check["data"]["log_path"]).write_text("forged")
        with self.assertRaises(ValueError):
            self.main.decide(task, 1, "accepted", "Changed log")

    def test_timeout_is_recorded_as_failure(self):
        task = self.create()
        self.submit(task)
        result = self.main.check(task, 1, "sleep 5", 0.03)
        self.assertTrue(result["data"]["timed_out"])
        self.assertFalse(result["data"]["passed"])

    def test_paths_cannot_escape_checkout_or_snapshot_recorder_storage(self):
        for name in ("../outside", ".git/config", ".verify/codex-observe/a.json"):
            with self.assertRaises(ValueError):
                self.store.snapshot([name])
        (self.root / "outside-link").symlink_to(self.root.parent)
        with self.assertRaises(ValueError):
            self.store.snapshot(["outside-link/a.txt"])

    def test_deleted_file_is_a_verifiable_artifact(self):
        task = self.create()
        (self.root / "result.txt").unlink()
        self.submit(task)
        self.main.check(task, 1, "test ! -e result.txt", 3)
        self.main.decide(task, 1, "accepted", "Removal verified")

    def test_report_links_receipts_and_flags_missing_or_changed_records(self):
        self.hook("SessionStart")
        task = self.create()
        receipt_line = self.output.getvalue().splitlines()[-1]
        self.hook("PostToolUse", tool_name="Bash", tool_use_id="call-1", tool_response=receipt_line)
        report = analyze(self.store, self.session)
        self.assertEqual(report["evidence_gaps"], [])
        self.assertTrue(report["tasks"][0]["records"][0]["receipt_verified"])
        self.acknowledge(task)
        self.assertEqual(len(analyze(self.store, self.session)["evidence_gaps"]), 2)
        first = self.main.events(task)[0]
        path = self.main.folder(task) / "events" / (first["event_id"] + ".json")
        path.write_text(path.read_text() + " ")
        self.assertEqual(len(analyze(self.store, self.session)["evidence_gaps"]), 3)

    def test_multiple_turns_refresh_same_session_and_unknown_exits_stay_unknown(self):
        self.hook("SessionStart")
        for n in (1, 2):
            self.hook("UserPromptSubmit", turn_id=str(n), prompt="A new turn")
            self.hook("PostToolUse", tool_name="Bash", tool_use_id=str(n), tool_response="Finished")
            self.hook("Stop", turn_id=str(n))
        report = read(self.store.session(self.session) / "report.json")
        self.assertEqual(report["hook_count"], 7)
        self.assertEqual(report["tool_call_count"], 2)
        tools = [r for r in report["timeline"] if r["event"] == "tool"]
        self.assertTrue(all("exit unknown" in r["description"] for r in tools))

    def test_coordinator_inspection_does_not_invalidate_worker_read(self):
        task = self.create()
        assignment = self.child.read_assignment(task, 1)
        self.main.read_assignment(task, 1)
        acknowledgment = self.child.ack(task, 1, assignment["assignment_sha256"])
        self.assertEqual(acknowledgment["actor_id"], self.worker)

    def test_symlink_artifacts_are_explicitly_rejected(self):
        (self.root / "current.txt").symlink_to("result.txt")
        with self.assertRaisesRegex(ValueError, "[Ss]ymlink"):
            self.store.snapshot(["current.txt"])

    def test_post_check_snapshot_error_is_a_recorded_failure(self):
        task = self.create()
        self.submit(task)
        self.main.check(task, 1, "true", 3)
        failed = self.main.check(task, 1, "rm result.txt; mkdir result.txt; exit 1", 3)
        self.assertFalse(failed["data"]["passed"])
        self.assertTrue(failed["data"]["snapshot_error"])
        (self.root / "result.txt").rmdir()
        (self.root / "result.txt").write_text("before\n")
        with self.assertRaises(ValueError):
            self.main.decide(task, 1, "accepted", "Restore the file and ignore the failed check")

    def test_simultaneous_workers_have_distinct_readable_labels(self):
        self.hook("SessionStart")
        for actor in ("01a07803-aa3f-75a3-b46d-61efe953f916", "01a07803-c2a3-7af3-84c5-62775a7b74e7"):
            self.hook("SubagentStart", actor)
        build_report(self.store, self.session)
        text = (self.store.session(self.session) / "report.md").read_text()
        self.assertIn("worker 1", text)
        self.assertIn("worker 2", text)

    def test_malformed_records_are_reported_without_hiding_good_data(self):
        self.hook("SessionStart")
        folder = self.store.session(self.session)
        save(folder / "hooks/bad.json", {"payload": {"session_id": self.session}})
        save(folder / "hooks/bad-tool.json", {"record_id": str(uuid.uuid4()), "received_at": now(),
             "payload": {"session_id": self.session, "hook_event_name": "PreToolUse", "tool_use_id": []}})
        task = self.create()
        save(self.main.folder(task) / "events/bad.json", {"task_id": task})
        report = build_report(self.store, self.session)
        self.assertEqual(report["hook_count"], 1)
        self.assertGreaterEqual(len(report["evidence_gaps"]), 2)

    def test_deleted_event_with_observed_receipt_is_an_evidence_gap(self):
        self.hook("SessionStart")
        task = self.create()
        receipt = self.output.getvalue().splitlines()[-1]
        self.hook("PostToolUse", tool_name="Bash", tool_use_id="deleted", tool_response=receipt)
        for path in (self.main.folder(task) / "events").glob("*.json"):
            path.unlink()
        report = analyze(self.store, self.session)
        self.assertTrue(any("missing" in g.lower() for g in report["evidence_gaps"]))

    def test_report_flags_changed_assignment_and_saved_artifact(self):
        self.hook("SessionStart")
        task = self.create()
        self.submit(task)
        self.hook("PostToolUse", self.worker, tool_name="Bash", tool_use_id="worker", tool_response=self.output.getvalue())
        self.hook("PostToolUse", tool_name="Bash", tool_use_id="main", tool_response=self.output.getvalue())
        assignment = self.main.folder(task) / "assignments/1.json"
        assignment.write_text(assignment.read_text() + " ")
        submitted = self.main.require(task, 1, "artifact_submitted")
        snapshot = self.main.folder(task) / "artifacts" / submitted["data"]["artifact_id"] / "files/result.txt"
        snapshot.write_text("corrupted snapshot")
        report = analyze(self.store, self.session)
        self.assertTrue(any("assignment" in g.lower() for g in report["evidence_gaps"]))
        self.assertTrue(any("artifact" in g.lower() for g in report["evidence_gaps"]))


if __name__ == "__main__":
    unittest.main()
