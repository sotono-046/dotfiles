#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title HDDを安全に取り外す
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 💾
# @raycast.packageName Disk Utilities
# @raycast.description 指定した外付けHDDを安全に取り外します

# Finder に表示される外付けHDDのボリューム名。
VOLUME_NAME="home"
VOLUME_PATH="/Volumes/$VOLUME_NAME"

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

if diskutil eject "/dev/$DISK_ID" >/dev/null; then
  echo "$VOLUME_NAME を安全に取り外しました"
else
  echo "取り外しに失敗しました。使用中のアプリを閉じてください"
  exit 1
fi
