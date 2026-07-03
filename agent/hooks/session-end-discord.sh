#!/bin/zsh
# Claude Code SessionEnd hook → 対応スレッドに終了メッセージ
set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
REASON=$(printf '%s' "$INPUT" | jq -r '.reason // "exit"')

[[ -z "$SESSION_ID" ]] && exit 0
THREAD_FILE="$HOME/.claude/session-threads/$SESSION_ID"
[[ ! -f "$THREAD_FILE" ]] && exit 0

THREAD_ID=$(cat "$THREAD_FILE")
TS=$(date +%H:%M)

set -a; . "$HOME/.discord-ops-env"; set +a

discord-ops run send_message --args "$(jq -n \
  --arg project "my-project" \
  --arg ch "$THREAD_ID" \
  --arg content "🏁 セッション終了 ($REASON) at $TS" \
  '{project:$project, channel_id:$ch, content:$content, raw:true}')" >/dev/null 2>&1

rm -f "$THREAD_FILE"
exit 0
