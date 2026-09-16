#!/usr/bin/env python3
"""Merge this skill's Stop hook into both runtimes; preserve other hooks."""
import argparse
import json
from pathlib import Path
import shlex
import shutil
from datetime import datetime


def install(path, script, remove=False):
    path = path.resolve()
    data = json.loads(path.read_text()) if path.exists() else {}
    hooks = data.setdefault('hooks', {})
    groups = hooks.get('Stop', [])
    command = f'python3 {shlex.quote(str(script))}'
    updated = []
    for group in groups:
        kept = [h for h in group.get('hooks', [])
                if h.get('command') != command]
        if kept:
            updated.append({**group, 'hooks': kept})
    if not remove:
        updated.append({'hooks': [{'type': 'command', 'command': command, 'timeout': 5}]})
    if updated == groups:
        print(f'unchanged: {path}')
        return
    hooks['Stop'] = updated
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + '.agent-note-' + datetime.now().strftime('%Y%m%d%H%M%S%f') + '.bak')
        shutil.copy2(path, backup)
        backup.chmod(0o600)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    path.chmod(0o600)
    print(f'{"removed" if remove else "installed"}: {path}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path, default=Path.home(), help='Target home (temporary directory for validation)')
    parser.add_argument('--remove', action='store_true')
    args = parser.parse_args()
    script = Path(__file__).resolve().with_name('stop-hook.py')
    for name in ('.claude/settings.json', '.codex/hooks.json'):
        install(args.home / name, script, args.remove)


if __name__ == '__main__':
    main()
