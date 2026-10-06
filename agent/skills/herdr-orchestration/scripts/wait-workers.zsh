#!/usr/bin/env zsh
# Wait for Herdr worker agents to settle.
# Usage: wait-workers.zsh [--interval SEC] <agent-name-or-pane-id>...
# Prints "<target> <status>" on each status change.
# Exit 0 with "ALL_SETTLED" when no target is working.
# Exit 3 with "NEEDS_ATTENTION <target> <status>" when a target is blocked, unknown, or missing.

interval=15
if [[ "${1:-}" == "--interval" ]]; then
  interval="$2"
  shift 2
fi

if (( $# == 0 )); then
  print -u2 "usage: wait-workers.zsh [--interval SEC] <target>..."
  exit 2
fi

typeset -A last
while true; do
  working=0
  for target in "$@"; do
    agent_status="$(herdr agent get "$target" 2>/dev/null | jq -r '.result.agent.agent_status // "missing"' 2>/dev/null)"
    [[ -z "$agent_status" ]] && agent_status=missing

    if [[ "${last[$target]:-}" != "$agent_status" ]]; then
      print -r -- "$target $agent_status"
      last[$target]="$agent_status"
    fi

    case "$agent_status" in
      working) working=1 ;;
      idle|done) ;;
      *)
        print -r -- "NEEDS_ATTENTION $target $agent_status"
        exit 3
        ;;
    esac
  done

  if (( ! working )); then
    print -r -- "ALL_SETTLED"
    exit 0
  fi
  sleep "$interval"
done
