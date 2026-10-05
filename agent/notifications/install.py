#!/usr/bin/env python3
"""Install question-only Pop hooks for Codex and Pi."""
import argparse
import json
import os
import shutil
import tempfile
from datetime import datetime
from pathlib import Path

SOURCE = Path(__file__).resolve().parent
HOOK = SOURCE / "question-pop.py"
PI_EXTENSION = SOURCE / "pi-question-pop.ts"


def backup(path, backup_dir):
    if path.exists() or path.is_symlink():
        backup_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        shutil.copy2(path, backup_dir / f"{path.name}.{stamp}.bak", follow_symlinks=False)


def install(home):
    backup_dir = home / ".local/state/dotfiles/backups"
    pi_dir = home / ".pi/agent/extensions"
    pi_target = pi_dir / PI_EXTENSION.name
    pi_dir.mkdir(parents=True, exist_ok=True)
    if not (pi_target.is_symlink() and pi_target.resolve() == PI_EXTENSION):
        backup(pi_target, backup_dir)
        if pi_target.exists() or pi_target.is_symlink():
            pi_target.unlink()
        pi_target.symlink_to(PI_EXTENSION)

    codex_dir = home / ".codex"
    codex_dir.mkdir(parents=True, exist_ok=True)
    hooks_path = codex_dir / "hooks.json"
    if hooks_path.exists():
        with hooks_path.open() as stream:
            config = json.load(stream)
        mode = hooks_path.stat().st_mode & 0o777
    else:
        config, mode = {}, 0o600
    hooks = config.setdefault("hooks", {})
    desired = {
        "PreToolUse": {"matcher": "^(request_user_input|request_user_input_async)$", "event": "pretool"},
        "PermissionRequest": {"matcher": "", "event": "permission"},
    }
    changed = False
    for event_name, spec in desired.items():
        entry = {
            "matcher": spec["matcher"],
            "hooks": [{"type": "command", "command": f'python3 "{HOOK}" {spec["event"]}', "timeout": 5}],
        }
        groups = hooks.setdefault(event_name, [])
        command = entry["hooks"][0]["command"]
        managed = next((index for index, group in enumerate(groups) if any(hook.get("command") == command for hook in group.get("hooks", []))), None)
        if managed is None:
            groups.append(entry)
            changed = True
        elif groups[managed] != entry:
            groups[managed] = entry
            changed = True
    if changed or not hooks_path.exists():
        backup(hooks_path, backup_dir)
        fd, temporary = tempfile.mkstemp(dir=codex_dir, prefix=".hooks.")
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(config, stream, indent=2)
                stream.write("\n")
            os.chmod(temporary, mode)
            os.replace(temporary, hooks_path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--home", type=Path, default=Path.home(), help="target home (defaults to current user)")
    args = parser.parse_args()
    install(args.home.expanduser().resolve())


if __name__ == "__main__":
    main()
