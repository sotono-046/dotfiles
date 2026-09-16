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

obsidian create \
  vault=${VAULT} \
  path="inbox/${note_name}.md" \
  template=${TEMPLATE} \
  open newtab
