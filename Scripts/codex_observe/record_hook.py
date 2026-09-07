#!/usr/bin/env python3
"""Record this checkout's hook events without changing Codex tool decisions."""

import json
from pathlib import Path
import sys
import uuid

from store import ROOT, Store, identity, now, save, sha


def record(payload, raw, root=ROOT):
    store = Store(root)
    Path(payload["cwd"]).resolve().relative_to(store.root)
    session_id = identity(payload["session_id"])
    actor_id = identity(payload.get("agent_id") or session_id)
    kind = payload["hook_event_name"]
    entry = {"schema_version": 1, "received_at": now(), "record_id": str(uuid.uuid4()),
             "raw_stdin_sha256": sha(raw), "payload": payload}
    folder = store.session(session_id)
    save(folder / "hooks" / (entry["record_id"] + ".json"), entry)
    # Tool hooks run before workflow.py and bind worker thread IDs to their root.
    # Repeated hook invocations are independent processes; use UTC receipt times,
    # not comparisons between their monotonic clocks.
    binding = {"session_id": session_id, "actor_id": actor_id,
               "root": str(store.root), "updated_at": entry["received_at"]}
    save(store.base / "actors" / (actor_id + ".json"), binding, replace=True)
    if kind in ("Stop", "SessionEnd", "Interrupt"):
        from report import build_report
        build_report(store, session_id)
    return entry


def main():
    try:
        raw = sys.stdin.buffer.read()
        record(json.loads(raw), raw)
    except Exception as error:
        # Observability failure must never veto a tool or force another turn.
        # Keep an actionable diagnostic; missing evidence remains unknown.
        print("Codex recording failed: " + str(error), file=sys.stderr)
    print("{}")


if __name__ == "__main__":
    main()
