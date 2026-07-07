#!/bin/zsh
# Claude Code SessionEnd hook → 対応スレッドに終了メッセージ + 注入デーモン停止
set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin

HOOK_DIR="${0:A:h}"
source "$HOOK_DIR/discord-session-lib.zsh"

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
REASON=$(printf '%s' "$INPUT" | jq -r '.reason // "exit"')

[[ -z "$SESSION_ID" ]] && exit 0

SESSION_JSON=$(session_read "$SESSION_ID") || exit 0

THREAD_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.thread_id // empty')
DAEMON_PID=$(printf '%s' "$SESSION_JSON" | jq -r '.daemon_pid // empty')

# 注入デーモンを止める（セッションファイル削除自体もデーモン側の exit 条件だが、明示的にも kill する）
if [[ -n "$DAEMON_PID" && "$DAEMON_PID" != "null" ]] && kill -0 "$DAEMON_PID" 2>/dev/null; then
  kill "$DAEMON_PID" 2>/dev/null
fi

if [[ -n "$THREAD_ID" ]]; then
  discord_load_env
  TS=$(date +%H:%M)
  discord_post "$THREAD_ID" "🏁 セッション終了 ($REASON) at $TS"
fi

session_remove "$SESSION_ID"
exit 0
