#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title HDDを安全に取り外す
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 💾
# @raycast.packageName Disk Utilities
# @raycast.description Eagleを終了してから指定した外付けHDDを安全に取り外します

# Finder に表示される外付けHDDのボリューム名。
VOLUME_NAME="home"
VOLUME_PATH="/Volumes/$VOLUME_NAME"
KEEPALIVE_PLIST="$HOME/Library/LaunchAgents/dev.sotono.hdd-keepalive.plist"
EJECT_LOCK="/tmp/dev.sotono.hdd-ejecting"
EAGLE_PROCESS_NAME="Eagle"
EAGLE_QUIT_TIMEOUT_SECONDS=10

if [ ! -d "$VOLUME_PATH" ]; then
  echo "$VOLUME_NAME は接続されていません"
  exit 1
fi

VOLUME_INFO=$(diskutil info -plist "$VOLUME_PATH") || {
  echo "ディスク情報を取得できませんでした"
  exit 1
}

# APFS ではボリュームの ParentWholeDisk が仮想コンテナを指すため、
# 物理ストアを経由して、実際に取り外せるディスクを特定する。
PHYSICAL_STORE=$(printf '%s' "$VOLUME_INFO" |
  plutil -extract 'APFSPhysicalStores.0.APFSPhysicalStore' raw - 2>/dev/null || true)

if [ -n "$PHYSICAL_STORE" ]; then
  SOURCE_INFO=$(diskutil info -plist "$PHYSICAL_STORE") || {
    echo "物理ディスクの情報を取得できませんでした"
    exit 1
  }
else
  SOURCE_INFO="$VOLUME_INFO"
fi

DISK_ID=$(printf '%s' "$SOURCE_INFO" |
  plutil -extract ParentWholeDisk raw - 2>/dev/null || true)

if [ -z "$DISK_ID" ]; then
  DISK_ID=$(printf '%s' "$SOURCE_INFO" |
    plutil -extract DeviceIdentifier raw - 2>/dev/null || true)
fi

if [ -z "$DISK_ID" ]; then
  echo "ディスクを特定できませんでした"
  exit 1
fi

DISK_INFO=$(diskutil info -plist "$DISK_ID") || {
  echo "取り外し対象の情報を取得できませんでした"
  exit 1
}

INTERNAL=$(printf '%s' "$DISK_INFO" |
  plutil -extract Internal raw - 2>/dev/null || true)
EJECTABLE=$(printf '%s' "$DISK_INFO" |
  plutil -extract Ejectable raw - 2>/dev/null || true)

if [ "$INTERNAL" = "true" ] || [ "$EJECTABLE" != "true" ]; then
  echo "$VOLUME_NAME は安全に取り外せる外付けディスクではありません"
  exit 1
fi

# Eagle が home 内のファイルを保持するため、通常終了を待ってから取り外す。
if pgrep -x "$EAGLE_PROCESS_NAME" >/dev/null 2>&1; then
  echo "Eagleを終了しています..."
  if ! osascript -e 'tell application "Eagle" to quit'; then
    echo "Eagleを終了できませんでした"
    exit 1
  fi

  for ((attempt = 1; attempt <= EAGLE_QUIT_TIMEOUT_SECONDS; attempt++)); do
    if ! pgrep -x "$EAGLE_PROCESS_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if pgrep -x "$EAGLE_PROCESS_NAME" >/dev/null 2>&1; then
    echo "Eagleが終了しなかったため、取り外しを中止しました"
    exit 1
  fi
fi

# KeepAlive が対象ボリュームを読んでいるため、取り外す間だけ停止する。
# 未登録の場合も安全な取り外しを試みるため、bootout の失敗は無視する。
if ! touch "$EJECT_LOCK"; then
  echo "取り外しロックを作成できませんでした"
  exit 1
fi
trap 'rm -f "$EJECT_LOCK"' EXIT
launchctl bootout "gui/$(id -u)" "$KEEPALIVE_PLIST" >/dev/null 2>&1 || true
if diskutil eject "/dev/$DISK_ID" >/dev/null; then
  echo "$VOLUME_NAME を安全に取り外しました"
else
  # 取り外しに失敗してまだマウントされている場合だけ KeepAlive を再開する。
  if [ -d "$VOLUME_PATH" ]; then
    launchctl bootstrap "gui/$(id -u)" "$KEEPALIVE_PLIST" >/dev/null 2>&1 ||
      echo "$VOLUME_NAME のKeepAliveを再開できませんでした" >&2
  fi
  echo "取り外しに失敗しました。使用中のアプリを閉じてください"
  exit 1
fi
