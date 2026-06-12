#!/usr/bin/env zsh
# tmux-agents-list.zsh — list tmux panes that look like running agent CLIs
# (Claude Code, Codex, cursor-agent, aider). Useful for picking a send target.
#
# Output columns:
#   SESSION:WINDOW.PANE  PANE_ID  COMMAND  TITLE
#
# Usage:
#   tmux-agents-list.zsh           # only agent-looking panes
#   tmux-agents-list.zsh --all     # every pane

set -euo pipefail

show_all=0
if [[ "${1:-}" == "--all" ]]; then show_all=1; fi

if ! tmux info >/dev/null 2>&1; then
  echo "tmux is not running" >&2
  exit 1
fi

fmt='#{session_name}:#{window_index}.#{pane_index}\t#{pane_id}\t#{pane_current_command}\t#{pane_title}'

panes="$(tmux list-panes -a -F "$fmt")"

if (( show_all )); then
  printf '%s\n' "$panes" | awk -F'\t' 'BEGIN{printf "%-24s %-8s %-14s %s\n","SESSION:W.P","PANE_ID","COMMAND","TITLE"} {printf "%-24s %-8s %-14s %s\n",$1,$2,$3,$4}'
  exit 0
fi

# Heuristic match on command or title.
pattern='claude|codex|cursor-agent|aider|gemini|opencode'

filtered="$(printf '%s\n' "$panes" | awk -F'\t' -v p="$pattern" 'tolower($3) ~ p || tolower($4) ~ p')"

if [[ -z "$filtered" ]]; then
  echo "No agent-looking panes found. Use --all to list every pane." >&2
  exit 2
fi

printf '%s\n' "$filtered" | awk -F'\t' 'BEGIN{printf "%-24s %-8s %-14s %s\n","SESSION:W.P","PANE_ID","COMMAND","TITLE"} {printf "%-24s %-8s %-14s %s\n",$1,$2,$3,$4}'
