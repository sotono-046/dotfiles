#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title reapp
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Dock,Finder,DisplayLink


# Mac周り
# Dockのフリーズ時は通常終了では再起動できないことがある
killall -KILL Dock
killall Finder

# DisplayLink（未インストール・未起動時はエラーを握りつぶす）
killall DisplayLinkUserAgent 2>/dev/null
open -a "DisplayLink Manager" 2>/dev/null
