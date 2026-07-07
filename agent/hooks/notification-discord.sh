#!/bin/zsh
# Claude Code Notification hook → 権限待ち・入力待ちを Discord スレッドに投稿する
set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin

[[ "${CC_DISCORD_PROGRESS:-}" == "off" ]] && exit 0

HOOK_DIR="${0:A:h}"
source "$HOOK_DIR/discord-session-lib.zsh"

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty')
[[ -z "$SESSION_ID" || -z "$MESSAGE" ]] && exit 0

SESSION_JSON=$(session_read "$SESSION_ID") || exit 0
THREAD_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.thread_id // empty')
[[ -z "$THREAD_ID" ]] && exit 0

discord_load_env || exit 0
discord_post "$THREAD_ID" "⏸ **入力待ち**: $MESSAGE"
exit 0
