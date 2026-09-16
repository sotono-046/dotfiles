#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quick Note
# @raycast.mode silent
# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Mitumine
# @raycast.description Mitumineに自動保存するクイックメモ



set -euo pipefail

# brew install obsidian 前提
export PATH="/opt/homebrew/bin:$PATH"

if pgrep -xq Obsidian; then
  osascript -e 'tell application "Obsidian" to activate'
else
  open -a Obsidian
fi

note_name=$(date +%Y%m%d%H%M%S)
VAULT="Mitumine"
TEMPLATE="unique"

create_status=0
output=$(obsidian create \
  vault=${VAULT} \
  path="inbox/${note_name}.md" \
  template=${TEMPLATE} \
  open newtab 2>&1) || create_status=$?

case "$output" in
  *"Vault not found"*)
    open "obsidian://open?vault=${VAULT}"
    exit 0
    ;;
esac

if [ "$create_status" -ne 0 ]; then
  printf '%s\n' "$output" >&2
  exit 1
fi

# create の template 指定だけでは Templater の <% ... %> は展開されない。
obsidian command vault="${VAULT}" \
  id=templater-obsidian:replace-in-file-templater
