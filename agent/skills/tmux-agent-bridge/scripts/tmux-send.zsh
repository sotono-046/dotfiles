#!/usr/bin/env zsh
# tmux-send.zsh — send a message to another tmux pane and ALWAYS press Enter
# as a separate send-keys call, so that newline-containing payloads do not
# fire prematurely and bracketed-paste sequences do not get mangled.
#
# Usage:
#   tmux-send.zsh <target-pane> [options] [message...]
#
# Options:
#   --paste          use load-buffer + paste-buffer (recommended for multi-line)
#   --no-enter       do not send the trailing Enter
#   --pre-enter      press Enter once before sending (clears stray prompt input)
#   --wait <secs>    delay between body and Enter (default 0.2)
#   --stdin          read message body from stdin instead of argv
#   -h, --help       show this help
#
# Notes:
#   * target-pane accepts "session:window.pane" or "%paneid".
#   * In --paste mode, an extra Enter is sent after a short delay to clear
#     any "Paste detected, press Enter to send" confirmation prompts that
#     Claude Code / Codex may show.

set -euo pipefail

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

if (( $# < 1 )); then usage; exit 1; fi
case "$1" in -h|--help) usage; exit 0;; esac

target="$1"; shift

paste=0
send_enter=1
pre_enter=0
from_stdin=0
wait_secs="0.2"

while (( $# )); do
  case "$1" in
    --paste)     paste=1; shift ;;
    --no-enter)  send_enter=0; shift ;;
    --pre-enter) pre_enter=1; shift ;;
    --stdin)     from_stdin=1; shift ;;
    --wait)      wait_secs="$2"; shift 2 ;;
    --)          shift; break ;;
    -*)          echo "unknown option: $1" >&2; exit 2 ;;
    *)           break ;;
  esac
done

if (( from_stdin )); then
  body="$(cat)"
else
  body="$*"
fi

if [[ -z "$body" ]]; then
  echo "tmux-send: empty message" >&2
  exit 2
fi

# Validate target exists.
if ! tmux display-message -t "$target" -p '#{pane_id}' >/dev/null 2>&1; then
  echo "tmux-send: target pane not found: $target" >&2
  exit 3
fi

# Refuse to send into copy-mode / non-input modes.
in_mode="$(tmux display-message -t "$target" -p '#{pane_in_mode}')"
if [[ "$in_mode" == "1" ]]; then
  echo "tmux-send: target pane is in copy/view mode; cancelling it first" >&2
  tmux send-keys -t "$target" -X cancel || true
  sleep 0.1
fi

if (( pre_enter )); then
  tmux send-keys -t "$target" Enter
  sleep 0.1
fi

if (( paste )); then
  # Use the paste buffer for clean multi-line input.
  buf="tmux-send-$$-$RANDOM"
  printf '%s' "$body" | tmux load-buffer -b "$buf" -
  tmux paste-buffer -p -b "$buf" -t "$target"
  tmux delete-buffer -b "$buf" >/dev/null 2>&1 || true
else
  # Literal send so '$', ';', etc. aren't interpreted as tmux key names.
  tmux send-keys -t "$target" -l -- "$body"
fi

if (( send_enter )); then
  sleep "$wait_secs"
  tmux send-keys -t "$target" Enter

  if (( paste )); then
    # Some agents (Claude Code) show a "Paste detected, press Enter to send"
    # confirmation when content arrives via paste-buffer. Send one more Enter
    # after a short delay to dismiss it. Harmless if no prompt is shown.
    sleep "$wait_secs"
    tmux send-keys -t "$target" Enter
  fi
fi
