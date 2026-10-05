#!/usr/bin/env python3
"""Play Pop only for structured Codex questions and approval requests."""
import fcntl
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SOUND = "/System/Library/Sounds/Pop.aiff"
DEDUP_TTL = 300
COOLDOWN = 1.0


def qualifies(event, payload):
    if not isinstance(payload, dict) or payload.get("hook_event_name") != ("PreToolUse" if event == "pretool" else "PermissionRequest" if event == "permission" else None):
        return False
    if payload.get("agent_id") or payload.get("agent_type"):
        return False
    if event == "pretool":
        if payload.get("tool_name") not in {"request_user_input", "request_user_input_async"}:
            return False
        tool_input = payload.get("tool_input")
        questions = tool_input.get("questions") if isinstance(tool_input, dict) else None
        field = "title" if payload["tool_name"].endswith("request_user_input_async") else "question"
        return isinstance(questions, list) and any(
            isinstance(q, dict) and isinstance(q.get(field), str) and q[field].strip()
            for q in questions
        )
    if event == "permission":
        # PermissionRequest is emitted only when Codex actually requests approval.
        return isinstance(payload.get("tool_name"), str) and bool(payload["tool_name"].strip()) and "tool_input" in payload
    return False


def allowed_by_cooldown(path, now, event_key):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+") as state:
        fcntl.flock(state, fcntl.LOCK_EX)
        state.seek(0)
        try:
            entries = json.loads(state.read() or "[]")
        except ValueError:
            entries = []
        entries = [item for item in entries if isinstance(item, list) and len(item) == 3 and isinstance(item[0], str) and isinstance(item[1], (int, float)) and isinstance(item[2], (int, float)) and 0 <= now - item[1] < item[2]]
        if event_key and any(item[0] == event_key for item in entries):
            return False
        if entries and now - max(item[1] for item in entries) < COOLDOWN:
            return False
        entries.append([event_key, now, DEDUP_TTL if event_key.startswith("tool:") else 2])
        entries = entries[-128:]
        state.seek(0)
        state.truncate()
        json.dump(entries, state)
        state.flush()
        return True


def main():
    if os.environ.get("AGENT_QUESTION_SOUND", "on").lower() in {"0", "false", "off", "no"}:
        return
    for marker in ("ORCA_PI_STATUS_OWNED", "ORCA_PI_TITLE_MARKER_OWNED"):
        try:
            owner = int(os.environ.get(marker, ""))
            if owner > 0 and owner != os.getpid():
                os.kill(owner, 0)
                return
        except (ValueError, ProcessLookupError):
            pass
        except PermissionError:
            return
    event = sys.argv[1] if len(sys.argv) == 2 else ""
    try:
        raw = sys.stdin.buffer.read(1024 * 1024 + 1)
        if len(raw) > 1024 * 1024:
            return
        payload = json.loads(raw)
    except (ValueError, OSError):
        return
    if not qualifies(event, payload):
        return
    state = os.environ.get("QUESTION_POP_STATE", os.path.join(tempfile.gettempdir(), f"question-pop-{os.getuid()}.state"))
    identity = payload.get("tool_use_id") or ""
    if identity:
        event_key = f'tool:{payload.get("session_id", "")}:{event}:{identity}'
    elif event == "permission":
        signature = json.dumps([payload.get("session_id"), payload.get("turn_id"), payload.get("tool_name"), payload.get("tool_input")], sort_keys=True, separators=(",", ":"))
        event_key = f'permission:{hashlib.sha256(signature.encode()).hexdigest()}'
    else:
        event_key = ""
    if not allowed_by_cooldown(state, time.time(), event_key):
        return
    try:
        subprocess.run(["/usr/bin/afplay", SOUND], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3, check=False)
    except (OSError, subprocess.TimeoutExpired):
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
