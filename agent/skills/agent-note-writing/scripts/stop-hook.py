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
            f'agent-note-writing の各ターン自動保存です。{skill} を読み、'
            '直前の会話ターンの依頼・応答・判断・現在の状態を短く要約して、既存vaultへ保存してください。'
            '作業の完了や再利用価値を保存条件にせず、短い返答・質問や承認の回答待ち・進行中の作業も記録してください。'
            'このhook設定は各ターンのローカル保存を認可しています。'
            'ユーザーが記録不要・read-only・編集対象限定を指定した場合はその制約を優先してください。'
            '同じ会話の自動メモがあればターンごとに時刻付きで追記し、なければ新規作成してください。'
            '別会話のメモは更新せず、今回のターンが既に記録済みなら重複して追記しないでください。'
            'vaultが使えない場合は自動保存をスキップし、保存先確認のためだけに会話を止めないでください。'
            '会話ログを転載せず、secret・個人情報・内部URLを除外してください。'
            '外部送信やIssue作成はこのhookの対象外です。保存した場合だけpathと要約を短く報告し、'
            'スキップした場合は説明を増やさず元の依頼への回答を保って終了してください。'
        ),
    }


if __name__ == '__main__':
    print(json.dumps(main(), ensure_ascii=False))
