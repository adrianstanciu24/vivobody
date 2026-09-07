#!/usr/bin/env python3
"""Readable assignments and evidence-bound review for Codex delegated tasks."""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
import uuid

from store import Store, atomic, encode, now, save, sha


class Workflow:
    def __init__(self, store, context):
        self.store = store
        self.context = context

    def folder(self, task):
        return self.store.task(self.context["session_id"], task)

    def events(self, task, revision=None):
        events = self.store.events(self.context["session_id"], task)
        return [e for e in events if revision is None or e["revision"] == revision]

    def emit(self, task, revision, kind, **data):
        return self.store.event(self.context, task, revision, kind, **data)

    def require(self, task, revision, kind):
        events = [e for e in self.events(task, revision) if e["kind"] == kind]
        if not events:
            raise ValueError("Missing " + kind + " for this revision")
        return events[-1]

    def assignment(self, task, revision):
        event = self.require(task, revision, "assignment_saved")
        path = self.folder(task) / "assignments" / (str(revision) + ".json")
        data = path.read_bytes()
        if sha(data) != event["data"]["assignment_sha256"]:
            raise ValueError("Assignment changed after being recorded")
        return json.loads(data), sha(data)

    def active(self, task, revision):
        latest = max(e["revision"] for e in self.events(task))
        if revision != latest or any(e["kind"] == "review_decision" for e in self.events(task, revision)):
            raise ValueError("This revision is closed; use the latest open assignment or create a new task")

    def coordinator(self, task):
        first = self.require(task, 1, "assignment_saved")
        if first["actor_id"] != self.context["actor_id"]:
            raise ValueError("Only the task's assigning agent can verify or decide acceptance")

    def save_assignment(self, task, revision, value):
        path = self.folder(task) / "assignments" / (str(revision) + ".json")
        save(path, value)
        self.emit(task, revision, "assignment_saved", assignment_sha256=sha(path.read_bytes()),
                  assignment_path=str(path.relative_to(self.store.root)), title=value["title"])
        return {"task_id": task, "session_id": self.context["session_id"], "revision": revision,
                "assignment_path": str(path.relative_to(self.store.root)), "assignment_sha256": sha(path.read_bytes())}

    def create(self, title, instructions, criteria, files):
        if not title.strip() or not instructions.strip() or not criteria or any(not c.strip() for c in criteria):
            raise ValueError("Provide a title, readable instructions, and at least one success criterion")
        task = str(uuid.uuid4())
        value = {"schema_version": 1, "task_id": task, "session_id": self.context["session_id"],
                 "revision": 1, "title": title, "instructions": instructions, "success_criteria": criteria,
                 "initial_files": self.store.snapshot(files), "created_at": now()}
        return self.save_assignment(task, 1, value)

    def read_assignment(self, task, revision):
        self.active(task, revision)
        value, digest = self.assignment(task, revision)
        self.emit(task, revision, "assignment_read", assignment_sha256=digest)
        return {"assignment": value, "assignment_sha256": digest}

    def ack(self, task, revision, digest):
        self.active(task, revision)
        _, expected = self.assignment(task, revision)
        reads = [e for e in self.events(task, revision) if e["kind"] == "assignment_read"
                 and e["actor_id"] == self.context["actor_id"]
                 and e["data"]["assignment_sha256"] == expected]
        if digest != expected or not reads:
            raise ValueError("Acknowledge the exact assignment read by this worker")
        prior = reads[-1]
        existing = [e for e in self.events(task, revision) if e["kind"] == "assignment_acknowledged"]
        if existing:
            if existing[-1]["actor_id"] != self.context["actor_id"]:
                raise ValueError("This task revision already belongs to another worker")
            return existing[-1]
        return self.emit(task, revision, "assignment_acknowledged", assignment_sha256=digest,
                         read_event_id=prior["event_id"])

    def submit(self, task, revision, summary, files):
        self.active(task, revision)
        if not summary.strip():
            raise ValueError("A result summary is required")
        assignment, digest = self.assignment(task, revision)
        ack = self.require(task, revision, "assignment_acknowledged")
        if ack["actor_id"] != self.context["actor_id"]:
            raise ValueError("Only the acknowledging worker can submit this revision")
        if any(e["kind"] == "artifact_submitted" for e in self.events(task, revision)):
            raise ValueError("This revision already has a submission; record a correction to start another")
        manifest = self.store.snapshot(list(assignment["initial_files"]) + files)
        artifact = {"summary": summary, "files": manifest, "assignment_sha256": digest}
        artifact_id = str(uuid.uuid4())
        folder = self.folder(task) / "artifacts" / artifact_id
        for name, metadata in manifest.items():
            if metadata["sha256"] is not None:
                content = (self.store.root / name).read_bytes()
                if sha(content) != metadata["sha256"]:
                    raise ValueError("File changed during submission: " + name)
                atomic(folder / "files" / name, content)
        save(folder / "artifact.json", artifact)
        return self.emit(task, revision, "artifact_submitted", artifact_id=artifact_id,
                         artifact_sha256=sha(encode(artifact)), summary=summary,
                         acknowledgment_event_id=ack["event_id"])

    def artifact(self, task, revision):
        submitted = self.require(task, revision, "artifact_submitted")
        folder = self.folder(task) / "artifacts" / submitted["data"]["artifact_id"]
        data = (folder / "artifact.json").read_bytes()
        if sha(data) != submitted["data"]["artifact_sha256"]:
            raise ValueError("Submitted artifact metadata changed")
        value = json.loads(data)
        for name, metadata in value["files"].items():
            if metadata["sha256"] is not None and sha((folder / "files" / name).read_bytes()) != metadata["sha256"]:
                raise ValueError("Saved artifact content changed: " + name)
        return value, submitted

    def check(self, task, revision, command, timeout):
        self.active(task, revision)
        self.coordinator(task)
        artifact, submitted = self.artifact(task, revision)
        if self.store.snapshot(artifact["files"]) != artifact["files"]:
            raise ValueError("Project files changed since submission; request a new revision before checking")
        log_id = str(uuid.uuid4())
        log = self.folder(task) / "checks" / (log_id + ".log")
        log.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        started = time.monotonic()
        timed_out = False
        with log.open("xb") as output:
            process = subprocess.Popen(command, shell=True, cwd=self.store.root, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGKILL)
                code = process.wait()
        snapshot_error = None
        try:
            unchanged = self.store.snapshot(artifact["files"]) == artifact["files"]
        except (OSError, ValueError) as error:
            unchanged = False
            snapshot_error = str(error)
        return self.emit(task, revision, "verification", passed=code == 0 and unchanged and not timed_out,
                         exit_code=code, timed_out=timed_out, artifact_unchanged=unchanged, snapshot_error=snapshot_error,
                         duration_seconds=round(time.monotonic() - started, 3), command=command,
                         log_path=str(log.relative_to(self.store.root)), log_sha256=sha(log.read_bytes()),
                         artifact_sha256=submitted["data"]["artifact_sha256"], submission_event_id=submitted["event_id"])

    def decide(self, task, revision, status, reason, instructions=None):
        self.active(task, revision)
        self.coordinator(task)
        assignment, digest = self.assignment(task, revision)
        if not reason.strip():
            raise ValueError("A review reason is required")
        checks = [e for e in self.events(task, revision) if e["kind"] == "verification"]
        artifact, submitted = self.artifact(task, revision)
        if status == "accepted":
            if not checks or any(not e["data"]["passed"] for e in checks):
                raise ValueError("Acceptance requires passing recorded checks for this revision")
            for check in checks:
                log = self.store.root / check["data"]["log_path"]
                if sha(log.read_bytes()) != check["data"]["log_sha256"]:
                    raise ValueError("Verification log changed after capture")
                if check["data"]["artifact_sha256"] != submitted["data"]["artifact_sha256"]:
                    raise ValueError("Verification refers to another artifact")
            if self.store.snapshot(artifact["files"]) != artifact["files"]:
                raise ValueError("Files changed after verification; this result cannot be accepted")
        elif status != "correction_requested" or not instructions or not instructions.strip():
            raise ValueError("A correction needs readable revised instructions")
        event = self.emit(task, revision, "review_decision", status=status, reason=reason,
                          verification_event_ids=[c["event_id"] for c in checks],
                          artifact_sha256=submitted["data"]["artifact_sha256"])
        if status == "correction_requested":
            revised = dict(assignment, revision=revision + 1, instructions=instructions,
                           previous_assignment_sha256=digest, review_decision_event_id=event["event_id"])
            return self.save_assignment(task, revision + 1, revised)
        return event


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", help="Root session ID; normally resolved from this agent's hook binding")
    commands = parser.add_subparsers(dest="action", required=True)
    commands.add_parser("context")
    create = commands.add_parser("create")
    create.add_argument("--title", required=True)
    create.add_argument("--instructions", required=True)
    create.add_argument("--criterion", action="append", dest="criteria", required=True)
    create.add_argument("--file", action="append", dest="files", default=[])
    for name in ("read", "ack", "submit", "check", "decide"):
        command = commands.add_parser(name)
        command.add_argument("--task", required=True)
        command.add_argument("--revision", type=int, required=True)
        if name == "ack":
            command.add_argument("--sha256", dest="digest", required=True)
        if name == "submit":
            command.add_argument("--summary", required=True)
            command.add_argument("--file", action="append", dest="files", default=[])
        if name == "check":
            command.add_argument("--command", required=True)
            command.add_argument("--timeout", type=int, default=600)
        if name == "decide":
            command.add_argument("--status", choices=("accepted", "correction_requested"), required=True)
            command.add_argument("--reason", required=True)
            command.add_argument("--instructions")
    args = vars(parser.parse_args())
    action, session = args.pop("action"), args.pop("session")
    try:
        store = Store()
        context = store.context(session)
        flow = Workflow(store, context)
        if action == "context":
            result = context
        elif action == "create":
            result = flow.create(**args)
        else:
            with store.lock(flow.folder(args["task"]) / ".lock"):
                result = getattr(flow, "read_assignment" if action == "read" else action)(**args)
        print("WORKFLOW_RESULT " + json.dumps(result), flush=True)
        return 1 if action == "check" and not result["data"]["passed"] else 0
    except (OSError, ValueError, KeyError) as error:
        print(json.dumps({"workflow_error": str(error)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
