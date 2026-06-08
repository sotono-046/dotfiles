#!/usr/bin/env zsh
set -euo pipefail

app_name="Cursor"
shortcut="cmd-i"
submit="false"
prompt_file=""

usage() {
  cat <<'USAGE'
Usage:
  send-to-cursor-composer.zsh [--app Cursor] [--shortcut cmd-i|cmd-l|cmd-shift-i|none] [--submit] <prompt-file>
  send-to-cursor-composer.zsh [options] < prompt.md

Copies the prompt to the clipboard, activates Cursor, focuses Composer/chat with
the selected shortcut, pastes the prompt, and optionally presses Return.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      app_name="${2:?--app requires a value}"
      shift 2
      ;;
    --shortcut)
      shortcut="${2:?--shortcut requires a value}"
      shift 2
      ;;
    --submit)
      submit="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      print -u2 "Unknown option: $1"
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$prompt_file" ]]; then
        print -u2 "Only one prompt file is supported."
        exit 2
      fi
      prompt_file="$1"
      shift
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  print -u2 "Unexpected arguments: $*"
  exit 2
fi

case "$shortcut" in
  cmd-i|cmd-l|cmd-shift-i|none) ;;
  *)
    print -u2 "Unsupported shortcut: $shortcut"
    print -u2 "Use one of: cmd-i, cmd-l, cmd-shift-i, none"
    exit 2
    ;;
esac

if [[ -n "$prompt_file" ]]; then
  if [[ ! -f "$prompt_file" ]]; then
    print -u2 "Prompt file not found: $prompt_file"
    exit 1
  fi
  prompt_content="$(<"$prompt_file")"
else
  if [[ -t 0 ]]; then
    usage >&2
    exit 2
  fi
  prompt_content="$(cat)"
fi

if [[ -z "${prompt_content//[$' \t\r\n']/}" ]]; then
  print -u2 "Prompt is empty."
  exit 1
fi

printf "%s" "$prompt_content" | pbcopy

osascript - "$app_name" "$shortcut" "$submit" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  set shortcutName to item 2 of argv
  set shouldSubmit to item 3 of argv

  tell application appName to activate
  delay 0.25

  tell application "System Events"
    if not (exists process appName) then error "Process is not available: " & appName
    tell process appName
      set frontmost to true
      delay 0.15

      if shortcutName is "cmd-i" then
        keystroke "i" using {command down}
        delay 0.3
      else if shortcutName is "cmd-l" then
        keystroke "l" using {command down}
        delay 0.3
      else if shortcutName is "cmd-shift-i" then
        keystroke "i" using {command down, shift down}
        delay 0.3
      else if shortcutName is "none" then
        delay 0.1
      else
        error "Unsupported shortcut: " & shortcutName
      end if

      keystroke "v" using {command down}

      if shouldSubmit is "true" then
        delay 0.15
        key code 36
      end if
    end tell
  end tell
end run
APPLESCRIPT

print "Sent prompt to ${app_name} using shortcut ${shortcut}."
