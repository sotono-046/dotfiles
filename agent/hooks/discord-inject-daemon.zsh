#!/bin/zsh
# Discord スレッドに書かれた人間のメッセージを、動作中の Claude Code の
# tmux ペインへプロンプトとして注入するポーリングデーモン。
# session-start-discord.sh から nohup + disown で起動される。
#
# 終了条件:
#   - セッション JSON が消える（SessionEnd がキルスイッチ）
#   - claude_pid が死んでいる
#   - tmux pane が消える、または pane_pid が変わる（pane 再利用ガード）
#   - 24 時間経過（保険）

set -u
PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
zmodload zsh/datetime

HOOK_DIR="${0:A:h}"
source "$HOOK_DIR/discord-session-lib.zsh"
discord_load_env || exit 0

SESSION_ID="${1:?session_id required}"
TMUX_SEND="$HOOK_DIR/../skills/tmux-agent-bridge/scripts/tmux-send.zsh"

SESSION_JSON=$(session_read "$SESSION_ID") || exit 0
THREAD_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.thread_id // empty')
PANE_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.tmux_pane // empty')
PANE_PID=$(printf '%s' "$SESSION_JSON" | jq -r '.tmux_pane_pid // empty')
CLAUDE_PID=$(printf '%s' "$SESSION_JSON" | jq -r '.claude_pid // empty')

[[ -z "$THREAD_ID" || -z "$PANE_ID" ]] && exit 0

# スレッド先頭の投稿（＝bot 自身）の author タグを動的取得し、以後の bot 除外に使う。
# get_messages は order 指定に関わらず新着順で返ってくるため、id (snowflake) の
# 昇順で並べ替えてから先頭を取る。
BOT_AUTHOR=$(discord-ops run get_messages --args "$(jq -n \
  --arg project "$CC_DISCORD_PROJECT" \
  --arg ch "$THREAD_ID" \
  '{project:$project, channel_id:$ch, limit:50}')" 2>/dev/null \
  | jq -r '(.messages // .) | sort_by(.id | tonumber) | .[0].author // empty' 2>/dev/null)

START_TS=$EPOCHSECONDS
MAX_RUNTIME=$((24 * 60 * 60))

while true; do
  sleep "$CC_DISCORD_POLL_INTERVAL"

  # 終了条件チェック
  SESSION_JSON=$(session_read "$SESSION_ID") || exit 0
  [[ -n "$CLAUDE_PID" ]] && ! kill -0 "$CLAUDE_PID" 2>/dev/null && exit 0

  CUR_PANE_PID=$(tmux display -pt "$PANE_ID" -p '#{pane_pid}' 2>/dev/null)
  if [[ -z "$CUR_PANE_PID" || "$CUR_PANE_PID" != "$PANE_PID" ]]; then
    discord_post "$THREAD_ID" "⏹ tmux ペインが変わったため注入を停止しました"
    exit 0
  fi

  if (( EPOCHSECONDS - START_TS > MAX_RUNTIME )); then
    discord_post "$THREAD_ID" "⏹ 24時間経過のため注入デーモンを終了しました"
    exit 0
  fi

  LAST_SEEN_ID=$(printf '%s' "$SESSION_JSON" | jq -r '.last_seen_id // empty')

  MESSAGES=$(discord-ops run get_messages --args "$(jq -n \
    --arg project "$CC_DISCORD_PROJECT" \
    --arg ch "$THREAD_ID" \
    '{project:$project, channel_id:$ch, limit:20}')" 2>/dev/null)
  [[ -z "$MESSAGES" ]] && continue

  # get_messages は新着順で返るため id (snowflake) の昇順に並べ替えてから処理する。
  # last_seen より新しく、bot 以外が書いたメッセージだけを古い順に抽出
  NEW_MESSAGES=$(printf '%s' "$MESSAGES" | jq -c \
    --arg last "$LAST_SEEN_ID" \
    --arg bot "$BOT_AUTHOR" '
    (.messages // .) as $msgs
    | ($msgs | sort_by(.id | tonumber) | map(select(.author != $bot)))
    | if $last == "" or $last == "null" then .
      else map(select((.id | tonumber) > ($last | tonumber)))
      end
  ')
  [[ -z "$NEW_MESSAGES" || "$NEW_MESSAGES" == "[]" ]] && continue

  echo "$NEW_MESSAGES" | jq -c '.[]' | while IFS= read -r msg; do
    MSG_ID=$(printf '%s' "$msg" | jq -r '.id')
    CONTENT=$(printf '%s' "$msg" | jq -r '.content')
    [[ -z "$CONTENT" ]] && continue

    # 注入前に last_seen_id を書く（at-most-once。取りこぼしより二重注入を避ける）
    session_update_field "$SESSION_ID" "last_seen_id" "$MSG_ID"

    if [[ "$CONTENT" == "!esc" ]]; then
      tmux send-keys -t "$PANE_ID" Escape 2>/dev/null
      discord_post "$THREAD_ID" "⎋ 中断コマンドを送信しました"
      continue
    fi

    if printf '%s' "$CONTENT" | "$TMUX_SEND" "$PANE_ID" --paste --stdin >/dev/null 2>&1; then
      PREVIEW="${CONTENT[1,40]}"
      discord_post "$THREAD_ID" "📥 注入: \`$PREVIEW\`"
    else
      discord_post "$THREAD_ID" "⚠ 注入に失敗しました: \`${CONTENT[1,40]}\`"
    fi
  done
done
