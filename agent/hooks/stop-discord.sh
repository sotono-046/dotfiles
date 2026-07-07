#!/bin/zsh
# Claude Code Stop hook → 最後の応答の抜粋を Discord スレッドに投稿する
set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin

[[ "${CC_DISCORD_PROGRESS:-}" == "off" ]] && exit 0

HOOK_DIR="${0:A:h}"
source "$HOOK_DIR/discord-session-lib.zsh"

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')
# Stop hook 自身の再帰発火はスキップ（無限ループ防止）
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
[[ -z "$SESSION_ID" || -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]] && exit 0

SESSION_JSON=$(session_read "$SESSION_ID") || exit 0
THREAD_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.thread_id // empty')
[[ -z "$THREAD_ID" ]] && exit 0

SUMMARY=$(tail -c 2000000 "$TRANSCRIPT_PATH" | jq -rs '
  [ .[] | select(.type=="assistant")
       | select((.message.content // []) | map(select(.type=="text" and .text != "")) | length > 0) ]
  | last
  | (.message.content | map(select(.type=="text") | .text) | join("\n"))
  | if length > 1800 then .[0:1800] + "\n…(切り詰め)" else . end
' 2>/dev/null)

[[ -z "$SUMMARY" || "$SUMMARY" == "null" ]] && exit 0

# 直前と同じ内容なら投稿しない（重複抑止）
HASH=$(printf '%s' "$SUMMARY" | shasum -a 256 | awk '{print $1}')
LAST_HASH=$(printf '%s' "$SESSION_JSON" | jq -r '.last_posted_hash // empty')
[[ "$HASH" == "$LAST_HASH" ]] && exit 0

discord_load_env || exit 0
TS=$(date +%H:%M)
discord_post "$THREAD_ID" "🤖 **応答** ($TS)
$SUMMARY"

session_update_field "$SESSION_ID" "last_posted_hash" "$HASH"
exit 0
