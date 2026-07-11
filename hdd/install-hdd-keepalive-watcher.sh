#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="dev.sotono.hdd-keepalive-watcher"
DOMAIN="gui/$(id -u)"
TARGET_SCRIPT="$HOME/bin/hdd-keepalive-watcher.sh"
TARGET_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/bin" "$HOME/Library/LaunchAgents"
install -m 755 "$SCRIPT_DIR/hdd-keepalive-watcher.sh" "$TARGET_SCRIPT"
install -m 644 "$SCRIPT_DIR/$LABEL.plist" "$TARGET_PLIST"

launchctl bootout "$DOMAIN" "$TARGET_PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$TARGET_PLIST"

echo "HDD KeepAlive watcher を有効化しました"
