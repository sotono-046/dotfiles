#!/usr/bin/env python3
"""Ask the current agent to save each turn once; never copy transcripts."""
import json
import os
from pathlib import Path
import sys


def main():
    try:
        event = json.load(sys.stdin)
    except (ValueError, OSError):
        return {}
    if not isinstance(event, dict):
        return {}
    if (event.get('hook_event_name') != 'Stop'
            or event.get('stop_hook_active') is not False
            or event.get('agent_id')
            or os.environ.get('AGENT_NOTE_WRITING_DISABLED') == '1'):
        return {}
    skill = Path(__file__).resolve().parents[1] / 'SKILL.md'
    return {
        'decision': 'block',
        'reason': (
            '各ターンの自動メモ保存をサブエージェント1体へ委譲してください。'
            'CodexではLuna（gpt-5.6-luna）、Claude CodeではSonnet（sonnet）を指定してください。'
            f'{skill} の「自動保存の委譲」に従い、親は直前ターンの要点と既知の保存先を渡し、'
            '子が要約・保存を担当します。保存結果を確認してpathと一行要約だけ報告してください。'
            'この設定はローカル保存とその委譲を認可しています。'
        ),
    }


if __name__ == '__main__':
    print(json.dumps(main(), ensure_ascii=False))
