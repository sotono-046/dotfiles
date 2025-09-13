#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title reapp
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Mouse,Sleepwatcher

brew services restart sleepwatcher
pkill -x "BetterMouse" || true; pkill -x "BetterMouse Helper" || true; open -a "BetterMouse"
killall Dock
killall Finder 