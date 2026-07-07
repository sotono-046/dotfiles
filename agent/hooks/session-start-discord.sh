#!/bin/zsh
# Claude Code SessionStart hook → Discord にスレッドを切る
# 発火条件: source=startup かつ git リポジトリ内のみ

set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin

HOOK_DIR="${0:A:h}"
source "$HOOK_DIR/discord-session-lib.zsh"

mkdir -p "$DISCORD_LOG_DIR"

# 7日以上前の残留スレッドファイルを掃除する（SessionEnd が発火しなかった分の蓄積対策）
find "$SESSION_THREADS_DIR" -type f -mtime +7 -delete 2>/dev/null

# 孤児掃除: claude_pid が死んでいるのに daemon が残っているセッションを片付ける
if [[ -d "$SESSION_THREADS_DIR" ]]; then
  for f in "$SESSION_THREADS_DIR"/*.json(N); do
    local_claude_pid=$(jq -r '.claude_pid // empty' "$f" 2>/dev/null)
    local_daemon_pid=$(jq -r '.daemon_pid // empty' "$f" 2>/dev/null)
    if [[ -n "$local_claude_pid" ]] && ! kill -0 "$local_claude_pid" 2>/dev/null; then
      [[ -n "$local_daemon_pid" ]] && kill "$local_daemon_pid" 2>/dev/null
      rm -f "$f"
    fi
  done
fi

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

# tmux 内かどうかで注入可否の注記を出す
INJECT_NOTE=""
PANE_ID=""
PANE_PID=""
if [[ -n "${TMUX_PANE:-}" ]]; then
  PANE_ID="$TMUX_PANE"
  PANE_PID=$(tmux display -pt "$TMUX_PANE" -p '#{pane_pid}' 2>/dev/null)
else
  INJECT_NOTE="
⚠ tmux外のため Discord からの注入は無効（通知のみ）"
fi

INITIAL_MSG="🆕 **セッション開始**${WORKTREE_FLAG}
📁 repo: \`$REPO_NAME\`
🌿 branch: \`$BRANCH\`
📂 cwd: \`$CWD\`
🖥 host: \`$HOST\`
🆔 \`$SHORT_ID\`${INJECT_NOTE}"

# discord-ops で bus にメッセージ投稿してスレッド作成
# create_thread は message_id 必須なので、先に send_message してそのIDから thread を作る
discord_load_env || exit 0

POST=$(discord-ops run send_message --args "$(jq -n \
  --arg project "$CC_DISCORD_PROJECT" \
  --arg channel "$CC_DISCORD_CHANNEL" \
  --arg content "$INITIAL_MSG" \
  '{project:$project, channel:$channel, content:$content, raw:true}')" 2>/dev/null)

MSG_ID=$(printf '%s' "$POST" | jq -r '.id // empty' 2>/dev/null)

if [[ -n "$MSG_ID" && -n "$SESSION_ID" ]]; then
  THREAD=$(discord-ops run create_thread --args "$(jq -n \
    --arg project "$CC_DISCORD_PROJECT" \
    --arg channel "$CC_DISCORD_CHANNEL" \
    --arg name "$THREAD_NAME" \
    --arg msg "$MSG_ID" \
    '{project:$project, channel:$channel, name:$name, message_id:$msg}')" 2>/dev/null)
  THREAD_ID=$(printf '%s' "$THREAD" | jq -r '.id // empty' 2>/dev/null)

  if [[ -n "$THREAD_ID" ]]; then
    SESSION_JSON=$(jq -n \
      --arg thread_id "$THREAD_ID" \
      --arg tmux_pane "$PANE_ID" \
      --arg tmux_pane_pid "$PANE_PID" \
      --arg claude_pid "$PPID" \
      --arg cwd "$CWD" \
      '{thread_id:$thread_id, tmux_pane:$tmux_pane, tmux_pane_pid:$tmux_pane_pid,
        claude_pid:($claude_pid|tonumber), daemon_pid:null,
        last_seen_id:null, last_posted_hash:null, cwd:$cwd}')
    session_write "$SESSION_ID" "$SESSION_JSON"

    # tmux 内なら注入デーモンを起動する
    if [[ -n "$PANE_ID" ]]; then
      nohup "$HOOK_DIR/discord-inject-daemon.zsh" "$SESSION_ID" \
        >>"$DISCORD_LOG_DIR/discord-inject-$SESSION_ID.log" 2>&1 &!
      DAEMON_PID=$!
      session_update_field_num "$SESSION_ID" "daemon_pid" "$DAEMON_PID"
    fi
  fi
fi

exit 0
