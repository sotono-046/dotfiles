#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title reapp
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Mouse,Sleepwatcher


# BetterMouse
pkill -x "BetterMouse" 
pkill -x "BetterMouse Helper"
open -a "BetterMouse"

# Mac周り
killall Dock
killall Finder 