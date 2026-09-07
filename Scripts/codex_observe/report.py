#!/usr/bin/env python3
"""Build an evidence-linked report from interactive Codex hook records."""

from __future__ import annotations

import argparse
import datetime
import json
from pathlib import Path
import sys

from store import Store, atomic, contained, identity, now, read, save, sha


def short(value, limit=120):
    return str(value).replace("\n", " ").replace("|", "\\|")[:limit]


def native_commands(hooks, actors):
    """Optional enrichment only: saved transcript formats can change with Codex."""
    paths = set()
    for hook in hooks:
        payload = hook["payload"]
        for key in ("transcript_path", "agent_transcript_path"):
            if isinstance(payload.get(key), str) and payload[key]:
                paths.add(payload[key])
    commands = {}
    for name in paths:
        path = Path(name)
        try:
            if path.stat().st_size > 32 * 1024 * 1024:
                continue
            with path.open() as stream:
                first = json.loads(next(stream))
                meta = first.get("payload", {})
                actor = meta.get("id")
                if first.get("type") != "session_meta" or actor not in actors:
                    continue
                inherited = meta.get("subagent_history_start_ordinal") or 0
                for number, line in enumerate(stream, 2):
                    if number <= inherited:
                        continue
                    event = json.loads(line)
                    item = event.get("payload", {}).get("item", {})
                    if event.get("type") == "event_msg" and item.get("type") == "CommandExecution":
                        commands[(actor, item["id"])] = {
                            "exit_code": item.get("exit_code"), "duration": item.get("duration"),
                            "source_file": str(path), "source_line": number}
        except (OSError, ValueError, KeyError, TypeError, AttributeError, StopIteration):
            continue
    return commands


def validate_event(event):
    identity(event["event_id"])
    identity(event["task_id"])
    identity(event["session_id"])
    datetime.datetime.fromisoformat(event["recorded_at"])
    if event["actor_id"] is not None:
        identity(event["actor_id"])
    if type(event["revision"]) is not int or event["revision"] < 1:
        raise ValueError("Invalid assignment revision")
    if not isinstance(event["kind"], str) or not isinstance(event["data"], dict):
        raise ValueError("Invalid event kind or data")
    required = {
        "assignment_saved": ("title", "assignment_sha256"),
        "artifact_submitted": ("summary", "artifact_id", "artifact_sha256"),
        "verification": ("passed", "command", "exit_code", "log_path", "log_sha256"),
        "review_decision": ("status", "reason"),
    }
    if any(k not in event["data"] for k in required.get(event["kind"], ())):
        raise ValueError("Missing fields for " + event["kind"])
    for name in ("title", "summary", "command", "status", "reason"):
        if name in event["data"] and not isinstance(event["data"][name], str):
            raise ValueError("Invalid text field: " + name)
    if event["kind"] == "verification" and type(event["data"]["passed"]) is not bool:
        raise ValueError("Invalid verification result")


def check_evidence_files(store, task_folder, event):
    """Check preserved evidence, never compare old acceptance to today's files."""
    data, kind = event["data"], event["kind"]
    if kind == "assignment_saved":
        path = contained(task_folder, "assignments/" + str(event["revision"]) + ".json")
        if sha(path.read_bytes()) != data["assignment_sha256"]:
            raise ValueError("Saved assignment changed")
    elif kind == "artifact_submitted":
        folder = contained(task_folder, "artifacts/" + identity(data["artifact_id"]))
        raw = (folder / "artifact.json").read_bytes()
        if sha(raw) != data["artifact_sha256"]:
            raise ValueError("Saved artifact metadata changed")
        for name, metadata in json.loads(raw)["files"].items():
            if metadata["sha256"] is not None:
                if sha(contained(folder / "files", name).read_bytes()) != metadata["sha256"]:
                    raise ValueError("Saved artifact content changed: " + name)
    elif kind == "verification":
        path = contained(store.root, data["log_path"])
        path.relative_to(task_folder / "checks")
        if sha(path.read_bytes()) != data["log_sha256"]:
            raise ValueError("Saved verification log changed")


def analyze(store, session_id):
    folder = store.session(session_id)
    hooks, gaps = [], []
    for path in (folder / "hooks").glob("*.json"):
        try:
            hook = read(path)
            if hook["payload"]["session_id"] != session_id:
                raise ValueError("Session ID differs from recording directory")
            datetime.datetime.fromisoformat(hook["received_at"])
            identity(hook["record_id"])
            identity(hook["payload"].get("agent_id") or session_id)
            if not isinstance(hook["payload"]["hook_event_name"], str):
                raise ValueError("Invalid hook event name")
            for field in ("tool_use_id", "tool_name", "turn_id"):
                value = hook["payload"].get(field)
                if value is not None and not isinstance(value, str):
                    raise ValueError("Invalid hook field: " + field)
            hook["record_path"] = str(path.relative_to(folder))
            hooks.append(hook)
        except (OSError, ValueError, KeyError, TypeError) as error:
            gaps.append("Unreadable hook " + path.name + ": " + str(error))
    hooks.sort(key=lambda h: (h["received_at"], h["record_id"]))
    actors = {h["payload"].get("agent_id") or session_id for h in hooks}
    commands = native_commands(hooks, actors)
    receipts, tool_calls = {}, {}
    for hook in hooks:
        payload = hook["payload"]
        actor = payload.get("agent_id") or session_id
        tool_id = payload.get("tool_use_id")
        kind = payload["hook_event_name"]
        if tool_id and kind in ("PreToolUse", "PostToolUse"):
            call = tool_calls.setdefault((actor, tool_id), {"actor_id": actor, "tool_id": tool_id})
            call[kind] = hook
            call["native"] = commands.get((actor, tool_id))
        if kind != "PostToolUse" or not isinstance(payload.get("tool_response"), str):
            continue
        for line in payload["tool_response"].splitlines():
            if not line.startswith("WORKFLOW_EVENT "):
                continue
            try:
                receipt = json.loads(line[len("WORKFLOW_EVENT "):])
                receipts.setdefault(receipt["event_id"], []).append((receipt, hook))
            except (ValueError, KeyError):
                gaps.append("Malformed task receipt in " + hook["record_path"])
    tasks, timeline, seen_events = [], [], set()
    for task_folder in sorted((folder / "tasks").glob("*")):
        if not task_folder.is_dir():
            continue
        records = []
        for path in (task_folder / "events").glob("*.json"):
            try:
                event = read(path)
                validate_event(event)
                seen_events.add(event["event_id"])
                candidates = receipts.get(event["event_id"], [])
                matched = []
                for receipt, hook in candidates:
                    actor = hook["payload"].get("agent_id") or session_id
                    if (receipt.get("sha256") == sha(path.read_bytes())
                            and contained(store.root, receipt["path"]) == path
                            and receipt.get("session_id") == event["session_id"] == session_id
                            and receipt.get("task_id") == event["task_id"] == task_folder.name
                            and receipt.get("revision") == event["revision"]
                            and actor == event["actor_id"]):
                        matched.append(hook)
                event["record_path"] = str(path.relative_to(folder))
                event["receipt_verified"] = bool(matched)
                event["hook_path"] = matched[0]["record_path"] if matched else None
                if not matched:
                    gaps.append("Task record lacks a matching hook receipt and actor: " + event["event_id"])
                try:
                    check_evidence_files(store, task_folder, event)
                except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
                    gaps.append(event["kind"] + " evidence unavailable or changed: " + str(error))
                records.append(event)
            except (OSError, ValueError, KeyError, TypeError) as error:
                gaps.append("Unreadable task event " + path.name + ": " + str(error))
        records.sort(key=lambda e: (e["recorded_at"], e["event_id"]))
        title, status, failed_check = task_folder.name, "assignment not recorded", False
        for event in records:
            data = event["data"]
            kind = event["kind"]
            if kind == "assignment_saved":
                title, status, failed_check = data["title"], "assigned", False
            elif kind == "assignment_acknowledged":
                status = "acknowledged"
            elif kind == "artifact_submitted":
                status = "submitted"
            elif kind == "verification":
                failed_check = failed_check or not data["passed"]
                status = "check failed" if failed_check else "checks passed"
            elif kind == "review_decision":
                status = data["status"]
            description = data.get("summary") or data.get("reason") or data.get("title") or kind.replace("_", " ")
            if kind == "verification":
                description = ("PASS" if data["passed"] else "FAIL") + " exit=" + str(data["exit_code"]) + " " + data["command"]
            elif kind == "review_decision":
                description = data["status"].replace("_", " ") + ": " + description
            elif kind in ("assignment_saved", "artifact_submitted"):
                description = kind.replace("_", " ") + ": " + description
            timeline.append({"time": event["recorded_at"], "actor": event["actor_id"],
                             "task": task_folder.name, "revision": event["revision"],
                             "event": kind, "description": description,
                             "evidence": event["record_path"], "receipt_verified": event["receipt_verified"]})
        revision = max((e["revision"] for e in records if e["kind"] == "assignment_saved"), default=1)
        tasks.append({"task_id": task_folder.name, "title": title, "revision": revision, "status": status, "records": records})
    for event_id in receipts.keys() - seen_events:
        gaps.append("Observed task receipt has a missing or unreadable event file: " + event_id)
    for hook in hooks:
        payload = hook["payload"]
        kind = payload["hook_event_name"]
        if kind in ("SessionStart", "SessionEnd", "UserPromptSubmit", "SubagentStart", "SubagentStop", "Stop", "Interrupt"):
            timeline.append({"time": hook["received_at"], "actor": payload.get("agent_id") or session_id,
                             "task": None, "event": kind, "description": kind,
                             "evidence": hook["record_path"]})
    for call in tool_calls.values():
        hook = call.get("PostToolUse") or call["PreToolUse"]
        payload = hook["payload"]
        tool = payload.get("tool_name", "unknown tool")
        tool_input = payload.get("tool_input", {})
        command = tool_input.get("command") if isinstance(tool_input, dict) else None
        detail = command if command else tool
        native = call["native"]
        code = native.get("exit_code") if native else None
        status = "finished" if "PostToolUse" in call else "completion not observed"
        if tool == "Bash":
            status += "; exit=" + str(code) if code is not None else "; exit unknown"
        timeline.append({"time": hook["received_at"], "actor": call["actor_id"], "task": None,
                         "event": "tool", "description": str(detail)[:300] + " (" + status + ")",
                         "evidence": hook["record_path"], "native": native})
    timeline.sort(key=lambda e: (e["time"], e["evidence"]))
    if not hooks:
        gaps.append("No hook events recorded for this session")
    elif not any(h["payload"]["hook_event_name"] == "SessionStart" for h in hooks):
        gaps.append("SessionStart was not observed; recording may cover only part of this session")
    return {"schema_version": 1, "session_id": session_id, "generated_at": now(),
            "hook_count": len(hooks), "worker_ids": sorted(actors - {session_id}),
            "task_count": len(tasks), "tasks": tasks, "timeline": timeline, "evidence_gaps": gaps,
            "native_command_count": len(commands), "tool_call_count": len(tool_calls),
            "limitations": ["Hook coverage is partial; hosted tools and some specialized tool paths are not observed.",
                            "Task attribution is explicit for workflow records. Other tool calls are attributed to agents only.",
                            "Receipt times are approximate wall times; unobserved intervals are not classified as idle work.",
                            "Native command enrichment is optional and depends on the installed Codex transcript format.",
                            "Main-agent acceptance is a recorded decision, not human approval or proof that all requirements were tested."]}


def build_report(store, session_id):
    folder = store.session(session_id)
    with store.lock(folder / ".report.lock"):
        result = analyze(store, session_id)
        labels = {actor: "worker " + str(index + 1) for index, actor in enumerate(result["worker_ids"])}
        labels[session_id] = "main"
        lines = ["# Codex session report", "", "Session: `" + session_id + "`", "",
                 "Updated: " + result["generated_at"], "",
                 "%d hook events · %d workers · %d tasks · %d tool calls · %d evidence gaps" % (
                     result["hook_count"], len(result["worker_ids"]), result["task_count"], result["tool_call_count"], len(result["evidence_gaps"])), "",
                 "## Tasks", "", "| Task | Status | Records |", "| --- | --- | --- |"]
        for task in result["tasks"]:
            records = task["records"]
            path = "tasks/" + task["task_id"] + "/assignments/" + str(task["revision"]) + ".json"
            lines.append("| [%s](%s) | %s | %d/%d receipts linked |" % (
                short(task["title"]), path, short(task["status"]),
                sum(r["receipt_verified"] for r in records), len(records)))
        if not result["tasks"]:
            lines.append("| No explicit task records | Activity recording only | — |")
        if result["worker_ids"]:
            lines.extend(["", "## Workers", "", "| Agent | Thread ID |", "| --- | --- |"])
            for actor in result["worker_ids"]:
                lines.append("| " + labels[actor] + " | `" + actor + "` |")
        lines.extend(["", "## Timeline", "", "Times are UTC. Tool rows have agent attribution; task rows also have explicit task attribution.", "",
                      "| Time | Agent | Task | Activity | Evidence |", "| --- | --- | --- | --- | --- |"])
        for event in result["timeline"]:
            actor = labels.get(event["actor"], "unknown")
            task = event["task"][:8] if event["task"] else "—"
            if event.get("revision"):
                task += " r" + str(event["revision"])
            label = "record" if event.get("receipt_verified", True) else "unverified record"
            lines.append("| %s | %s | %s | %s | [%s](%s) |" % (
                short(event["time"][11:23]), actor, task, short(event["description"], 160), label, event["evidence"]))
        lines.extend(["", "## Evidence gaps", ""])
        lines.extend("- " + short(g, 1000) for g in result["evidence_gaps"])
        if not result["evidence_gaps"]:
            lines.append("No missing task receipts detected in the recorded data.")
        lines.extend(["", "## Interpretation", ""])
        lines.extend("- " + value for value in result["limitations"])
        save(folder / "report.json", result, replace=True)
        atomic(folder / "report.md", ("\n".join(lines) + "\n").encode(), replace=True)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    choose = parser.add_mutually_exclusive_group()
    choose.add_argument("--session")
    choose.add_argument("--latest", action="store_true")
    choose.add_argument("--list", action="store_true")
    args = parser.parse_args()
    store = Store()
    try:
        sessions = []
        for folder in store.base.glob("*"):
            try:
                session_id = identity(folder.name)
            except ValueError:
                continue
            paths = list((folder / "hooks").glob("*.json"))
            if paths:
                sessions.append((max(p.stat().st_mtime_ns for p in paths), session_id))
        sessions.sort(reverse=True)
        if args.list:
            for _, session_id in sessions:
                print(session_id)
            return 0
        if not args.session and not sessions:
            raise ValueError("No sessions recorded. Start Codex in this project with the reviewed hooks enabled.")
        session_id = identity(args.session) if args.session else sessions[0][1]
        result = build_report(store, session_id)
        print(store.session(session_id) / "report.md")
        print(json.dumps({"hook_events": result["hook_count"], "tasks": result["task_count"],
                          "evidence_gaps": len(result["evidence_gaps"])}))
        return 0
    except (OSError, ValueError, KeyError) as error:
        print("Cannot build Codex report: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
