#!/bin/zsh
# Discord ⇄ Claude Code 連携の共通関数
# 各 hook / デーモンスクリプトから `source` して使う。
#
# 環境変数（他マシンでの上書き用。未設定時は既定値）:
#   CC_DISCORD_PROJECT  - discord-ops のプロジェクト名 (既定: my-project)
#   CC_DISCORD_CHANNEL  - スレッドを作る親チャンネルの alias (既定: bus)
#   CC_DISCORD_PROGRESS - "off" で Stop/Notification の進捗投稿を無効化
#   CC_DISCORD_POLL_INTERVAL - 注入デーモンのポーリング間隔秒 (既定: 10)

: "${CC_DISCORD_PROJECT:=my-project}"
: "${CC_DISCORD_CHANNEL:=bus}"
: "${CC_DISCORD_POLL_INTERVAL:=10}"

SESSION_THREADS_DIR="$HOME/.claude/session-threads"
DISCORD_LOG_DIR="$HOME/.claude/logs"

# discord-ops の認証情報を読み込む。無ければ 1 を返す。
discord_load_env() {
  if [[ -f "$HOME/.discord-ops-env" ]]; then
    set -a
    . "$HOME/.discord-ops-env"
    set +a
    return 0
  fi
  return 1
}

# セッション JSON のパス
session_file() {
  local session_id="$1"
  print -r -- "$SESSION_THREADS_DIR/${session_id}.json"
}

# 旧形式 (plain text の thread id のみ) のパス
session_file_legacy() {
  local session_id="$1"
  print -r -- "$SESSION_THREADS_DIR/${session_id}"
}

# セッション情報を読む。JSON があれば jq で、無ければ旧形式にフォールバック。
# 戻り値は jq 互換の JSON 文字列（旧形式は {"thread_id": "..."} に正規化）。
session_read() {
  local session_id="$1"
  local f
  f=$(session_file "$session_id")
  if [[ -f "$f" ]]; then
    if jq -e . "$f" >/dev/null 2>&1; then
      cat "$f"
      return 0
    fi
  fi
  f=$(session_file_legacy "$session_id")
  if [[ -f "$f" ]]; then
    local tid
    tid=$(cat "$f")
    jq -n --arg tid "$tid" '{thread_id: $tid}'
    return 0
  fi
  return 1
}

# セッション情報を atomic に書き込む (tmp -> mv)。
session_write() {
  local session_id="$1"
  local json="$2"
  mkdir -p "$SESSION_THREADS_DIR"
  local f tmp
  f=$(session_file "$session_id")
  tmp="${f}.tmp.$$"
  print -r -- "$json" > "$tmp" && mv "$tmp" "$f"
}

# セッション情報の 1 フィールドだけ更新する（値は文字列として格納）。
session_update_field() {
  local session_id="$1"
  local key="$2"
  local value="$3"
  local current
  current=$(session_read "$session_id") || current='{}'
  local updated
  updated=$(print -r -- "$current" | jq --arg k "$key" --arg v "$value" '.[$k] = $v')
  session_write "$session_id" "$updated"
}

# セッション情報の 1 フィールドを数値として更新する。
session_update_field_num() {
  local session_id="$1"
  local key="$2"
  local value="$3"
  local current
  current=$(session_read "$session_id") || current='{}'
  local updated
  updated=$(print -r -- "$current" | jq --arg k "$key" --argjson v "$value" '.[$k] = $v')
  session_write "$session_id" "$updated"
}

session_remove() {
  local session_id="$1"
  rm -f "$(session_file "$session_id")" "$(session_file_legacy "$session_id")"
}

# Discord にメッセージを投稿する（2000文字上限に切り詰め）。
# 使い方: discord_post <channel_id> <content>
discord_post() {
  local channel_id="$1"
  local content="$2"
  [[ -z "$channel_id" ]] && return 1
  if (( ${#content} > 1900 )); then
    content="${content[1,1900]}
…(切り詰め)"
  fi
  discord-ops run send_message --args "$(jq -n \
    --arg project "$CC_DISCORD_PROJECT" \
    --arg ch "$channel_id" \
    --arg content "$content" \
    '{project:$project, channel_id:$ch, content:$content, raw:true}')" >/dev/null 2>&1
}
