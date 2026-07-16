#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title homeをマウントしてEagleを起動
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🦅
# @raycast.packageName Disk Utilities
# @raycast.description 再接続したhomeをマウントし、KeepAliveとEagleを起動します

VOLUME_NAME="home"
VOLUME_PATH="/Volumes/$VOLUME_NAME"
# home の APFS Volume UUID。ディスク番号が変わってもこのUUIDで識別する。
VOLUME_UUID="0451CEC4-B55E-41B7-9559-8D3BE03EBDFB"
KEEPALIVE_LABEL="dev.sotono.hdd-keepalive"
KEEPALIVE_PLIST="$HOME/Library/LaunchAgents/$KEEPALIVE_LABEL.plist"
MOUNT_WAIT_SECONDS=10

if [ ! -d "$VOLUME_PATH" ]; then
  VOLUME_DISK_ID=$(diskutil list -plist |
    plutil -p - |
    awk -v target_uuid="$VOLUME_UUID" '
      /"DeviceIdentifier" =>/ {
        if (match($0, /"disk[0-9]+s[0-9]+"/)) {
          device_id = substr($0, RSTART + 1, RLENGTH - 2)
        }
      }
      index($0, "\"VolumeUUID\" => \"" target_uuid "\"") {
        print device_id
        exit
      }
    ')

  if [ -z "$VOLUME_DISK_ID" ]; then
    echo "$VOLUME_NAME が接続されていません"
    exit 1
  fi

  if ! diskutil mount "$VOLUME_DISK_ID" >/dev/null; then
    echo "$VOLUME_NAME をマウントできませんでした"
    exit 1
  fi

  for ((attempt = 1; attempt <= MOUNT_WAIT_SECONDS; attempt++)); do
    if [ -d "$VOLUME_PATH" ]; then
      break
    fi
    sleep 1
  done

  if [ ! -d "$VOLUME_PATH" ]; then
    echo "$VOLUME_NAME のマウントを確認できませんでした"
    exit 1
  fi
fi

if ! launchctl print "gui/$(id -u)/$KEEPALIVE_LABEL" >/dev/null 2>&1; then
  if ! launchctl bootstrap "gui/$(id -u)" "$KEEPALIVE_PLIST" >/dev/null 2>&1; then
    echo "$VOLUME_NAME のKeepAliveを再開できませんでした" >&2
  fi
fi

if ! open -a "Eagle"; then
  echo "Eagleを起動できませんでした"
  exit 1
fi

echo "$VOLUME_NAME をマウントし、Eagleを起動しました"
