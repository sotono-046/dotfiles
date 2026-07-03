#!/bin/zsh
# Claude Code SessionStart hook → Discord にスレッドを切る
# 発火条件: source=startup かつ git リポジトリ内のみ

set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin

# 7日以上前の残留スレッドファイルを掃除する（SessionEnd が発火しなかった分の蓄積対策）
find "$HOME/.claude/session-threads" -type f -mtime +7 -delete 2>/dev/null

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[[ -z "$CWD" ]] && CWD="$PWD"

# startup 以外（resume / compact / clear）は黙る
if [[ "$SOURCE" != "startup" ]]; then
  exit 0
fi

# git リポジトリ外なら黙る
if ! git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
REPO_NAME=$(basename "$REPO_ROOT")
BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
HOST=$(hostname -s)

# worktree 判定 (main worktree でなければ true)
GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null)
COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
WORKTREE_FLAG=""
if [[ "$(cd "$GIT_DIR" && pwd)" != "$(cd "$COMMON_DIR" && pwd)" ]]; then
  WORKTREE_FLAG=" 🌳wt"
fi

SHORT_ID="${SESSION_ID:0:8}"
TS=$(date +%H:%M)

THREAD_NAME="[$HOST] $REPO_NAME @ $BRANCH ($TS)"
# Discord thread name 上限 100 文字
THREAD_NAME="${THREAD_NAME:0:100}"

INITIAL_MSG="🆕 **セッション開始**${WORKTREE_FLAG}
📁 repo: \`$REPO_NAME\`
🌿 branch: \`$BRANCH\`
📂 cwd: \`$CWD\`
🖥 host: \`$HOST\`
🆔 \`$SHORT_ID\`"

# discord-ops で bus にメッセージ投稿してスレッド作成
# create_thread は message_id 必須なので、先に send_message してそのIDから thread を作る
set -a; . "$HOME/.discord-ops-env"; set +a

POST=$(discord-ops run send_message --args "$(jq -n \
  --arg project "my-project" \
  --arg channel "bus" \
  --arg content "$INITIAL_MSG" \
  '{project:$project, channel:$channel, content:$content, raw:true}')" 2>/dev/null)

MSG_ID=$(printf '%s' "$POST" | jq -r '.id // empty' 2>/dev/null)

if [[ -n "$MSG_ID" ]]; then
  THREAD=$(discord-ops run create_thread --args "$(jq -n \
    --arg project "my-project" \
    --arg channel "bus" \
    --arg name "$THREAD_NAME" \
    --arg msg "$MSG_ID" \
    '{project:$project, channel:$channel, name:$name, message_id:$msg}')" 2>/dev/null)
  THREAD_ID=$(printf '%s' "$THREAD" | jq -r '.id // empty' 2>/dev/null)
  if [[ -n "$THREAD_ID" && -n "$SESSION_ID" ]]; then
    mkdir -p "$HOME/.claude/session-threads"
    printf '%s' "$THREAD_ID" > "$HOME/.claude/session-threads/$SESSION_ID"
  fi
fi

exit 0
