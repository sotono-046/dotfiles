#!/usr/bin/env python3
"""Submit a task-scoped result notification only when explicitly requested."""

import argparse
import fcntl
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_STATE_DIR = Path.home() / ".local/state/agent-result-notify"
APPLESCRIPT = 'on run argv\ndisplay notification (item 2 of argv) with title (item 1 of argv) sound name "Hero"\nend run'


def nonempty(value):
    if not value.strip():
        raise argparse.ArgumentTypeError("must be nonempty")
    return value


def backend():
    if platform.system() == "Darwin":
        executable = shutil.which("osascript")
        if executable:
            return [executable, "-e", APPLESCRIPT]
    elif platform.system() == "Linux":
        executable = shutil.which("notify-send")
        if executable:
            return [executable]
    raise RuntimeError("no supported notification backend available")


def notify(command, title, message):
    subprocess.run(command + ["--", title, message], check=True, timeout=10)


def save_state(path, state):
    fd, temporary = tempfile.mkstemp(prefix=path.stem + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(state, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def emit(status, **extra):
    print(json.dumps({"status": status, **extra}, ensure_ascii=False))


def run(args):
    if args.dry_run:
        emit("dry_run")
        return 0
    if args.role == "worker":
        emit("suppressed", reason="worker")
        return 0
    if args.request is None:
        emit("suppressed", reason="no_explicit_request")
        return 0

    command = backend()
    digest = hashlib.sha256(args.task_id.encode("utf-8")).hexdigest()
    state_dir = args.state_dir
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    state_path = state_dir / (digest + ".json")
    lock_path = state_dir / (digest + ".lock")
    lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(lock_fd, "r+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if state_path.exists():
            with state_path.open(encoding="utf-8") as stream:
                previous = json.load(stream)
            if previous.get("task_id") != args.task_id or previous.get("task_hash") != digest:
                raise RuntimeError("state identity mismatch")
            emit("suppressed", reason="duplicate", previous_status=previous["status"])
            return 0

        state = {
            "task_id": args.task_id,
            "task_hash": digest,
            "status": "submitting",
            "time": datetime.now(timezone.utc).isoformat(),
        }
        save_state(state_path, state)
        try:
            notify(command, args.title, args.message)
        except (OSError, subprocess.SubprocessError):
            state.update(status="error", time=datetime.now(timezone.utc).isoformat())
            save_state(state_path, state)
            emit("error", reason="notification_backend_failed")
            return 1

        state.update(status="submitted", time=datetime.now(timezone.utc).isoformat())
        save_state(state_path, state)
        emit("submitted")
        return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-id", required=True, type=nonempty)
    parser.add_argument("--request", choices=("result", "leader"))
    parser.add_argument("--role", choices=("owner", "leader", "worker"), default="owner")
    parser.add_argument("--title", required=True)
    parser.add_argument("--message", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--state-dir", type=Path, default=DEFAULT_STATE_DIR)
    args = parser.parse_args(argv)
    try:
        return run(args)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        emit("error", reason="notification_setup_failed", detail=str(error))
        return 1


if __name__ == "__main__":
    sys.exit(main())
