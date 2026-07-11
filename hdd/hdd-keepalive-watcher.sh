#!/bin/zsh

set -u

VOLUME="/Volumes/home"
KEEPALIVE_FILE="$VOLUME/.disk-keepalive"
KEEPALIVE_LABEL="dev.sotono.hdd-keepalive"
KEEPALIVE_PLIST="$HOME/Library/LaunchAgents/$KEEPALIVE_LABEL.plist"
EJECT_LOCK="/tmp/dev.sotono.hdd-ejecting"
LOCK_TTL_SECONDS=300
DOMAIN="gui/$(id -u)"

# Raycast が安全な取り外しを試みている間は、KeepAlive を再開しない。
# 異常終了で残ったロックは、次回の再接続を妨げないよう 5 分後に破棄する。
if [[ -e "$EJECT_LOCK" ]]; then
  lock_mtime=$(stat -f %m "$EJECT_LOCK" 2>/dev/null || echo 0)
  now=$(date +%s)

  if (( now - lock_mtime < LOCK_TTL_SECONDS )); then
    exit 0
  fi

  rm -f "$EJECT_LOCK"
fi

# 接続済みで、実際に読む対象ファイルがある場合だけ KeepAlive を再開する。
if [[ ! -d "$VOLUME" || ! -r "$KEEPALIVE_FILE" ]]; then
  exit 0
fi

if launchctl print "$DOMAIN/$KEEPALIVE_LABEL" >/dev/null 2>&1; then
  exit 0
fi

launchctl bootstrap "$DOMAIN" "$KEEPALIVE_PLIST"
