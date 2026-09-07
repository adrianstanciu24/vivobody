"""Project-scoped storage shared by the Codex recorder, task helper, and reports."""

from __future__ import annotations

import contextlib
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
FORMAT = 1


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def identity(value):
    return str(uuid.UUID(str(value)))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def encode(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def atomic(path, data, replace=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(prefix=".writing-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        if replace:
            os.replace(temporary, path)
        else:
            os.link(temporary, path)  # Atomic create; never replace a saved revision.
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def save(path, value, replace=False):
    atomic(path, encode(value), replace=replace)


def contained(root, value):
    root = Path(root).resolve()
    path = (root / value).resolve()
    path.relative_to(root)
    return path


class Store:
    def __init__(self, root=ROOT):
        self.root = Path(root).resolve()
        # .codex is protected read-only inside Codex's workspace-write sandbox.
        self.base = contained(self.root, ".verify/codex-observe")

    def session(self, session_id):
        return contained(self.base, identity(session_id))

    def task(self, session_id, task_id):
        return contained(self.session(session_id), "tasks/" + identity(task_id))

    @contextlib.contextmanager
    def lock(self, path):
        path = contained(self.base, str(path))
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with path.open("a") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def context(self, session_id=None):
        actor = os.environ.get("CODEX_THREAD_ID")
        actor = identity(actor) if actor else None
        binding = self.base / "actors" / (actor + ".json") if actor else None
        observed = read(binding) if binding and binding.is_file() else None
        if session_id:
            session_id = identity(session_id)
            if observed and observed["session_id"] != session_id:
                raise ValueError("The requested session differs from this agent's hook binding")
        elif observed:
            session_id = observed["session_id"]
        else:
            raise ValueError("No recorded session for this agent. Enable project hooks and start a new Codex session, or pass --session explicitly.")
        return {"session_id": session_id, "actor_id": actor,
                "hook_binding_observed": observed is not None}

    def events(self, session_id, task_id):
        folder = self.task(session_id, task_id) / "events"
        return sorted((read(p) for p in folder.glob("*.json")),
                      key=lambda e: (e["recorded_at"], e["event_id"]))

    def event(self, context, task_id, revision, kind, **data):
        event = dict(schema_version=FORMAT, event_id=str(uuid.uuid4()),
                     recorded_at=now(), task_id=task_id, revision=revision,
                     kind=kind, **context, data=data)
        path = self.task(context["session_id"], task_id) / "events" / (event["event_id"] + ".json")
        save(path, event)
        receipt = {key: event[key] for key in ("event_id", "task_id", "session_id", "revision", "kind")}
        receipt.update(path=str(path.relative_to(self.root)), sha256=sha(path.read_bytes()))
        print("WORKFLOW_EVENT " + json.dumps(receipt), flush=True)
        return event

    def snapshot(self, paths):
        files = {}
        for value in sorted(set(paths)):
            requested = Path(os.path.abspath(self.root / value))
            requested.relative_to(self.root)
            components = [requested] + list(requested.parents)
            if any(p.is_symlink() for p in components if p != self.root and self.root in p.parents):
                raise ValueError("Symlink artifacts are unsupported; name the actual regular file: " + str(value))
            path = contained(self.root, value)
            relative = path.relative_to(self.root).as_posix()
            if relative == ".git" or relative.startswith((".git/", ".verify/codex-observe/")):
                raise ValueError("Task artifacts must be project files outside Git metadata and the recorder's own storage")
            if path.exists() and not path.is_file():
                raise ValueError("Name individual artifact files, not directories: " + relative)
            data = path.read_bytes() if path.exists() else None
            if data is not None and len(data) > 16 * 1024 * 1024:
                raise ValueError("Artifact exceeds the 16 MiB snapshot limit: " + relative)
            files[relative] = {"sha256": sha(data) if data is not None else None,
                               "size": len(data) if data is not None else None}
        return files
