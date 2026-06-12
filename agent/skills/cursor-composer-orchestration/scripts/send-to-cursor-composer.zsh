#!/usr/bin/env zsh
set -euo pipefail

# Cursor Agent CLI へ task packet を流し込み、headless 実行する helper。
# 以前は AppleScript で Cursor IDE の Composer に貼り付けていたが、IDE 連携が
# 不安定だったため `cursor-agent --print` を使う形に切り替えている。

workspace=""
model=""
plan="false"
force="false"
output_format=""
sandbox=""
extra_args=()
prompt_file=""

usage() {
  cat <<'USAGE'
Usage:
  send-to-cursor-composer.zsh [options] <prompt-file>
  send-to-cursor-composer.zsh [options] < prompt.md

Feeds the prompt to `cursor-agent --print` and streams the transcript to stdout.

Options:
  --workspace <path>            Working directory (default: cwd)
  --model <name>                Model id (e.g. sonnet-4-thinking, gpt-5)
  --plan                        Read-only plan mode (no edits)
  --force                       Auto-approve tool prompts (use with tight scope)
  --output-format <fmt>         text | json | stream-json
  --sandbox <enabled|disabled>  Override sandbox mode
  --                            Pass remaining args verbatim to cursor-agent
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      workspace="${2:?--workspace requires a value}"
      shift 2
      ;;
    --model)
      model="${2:?--model requires a value}"
      shift 2
      ;;
    --plan)
      plan="true"
      shift
      ;;
    --force)
      force="true"
      shift
      ;;
    --output-format)
      output_format="${2:?--output-format requires a value}"
      shift 2
      ;;
    --sandbox)
      sandbox="${2:?--sandbox requires a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args+=("$@")
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

if ! command -v cursor-agent >/dev/null 2>&1; then
  print -u2 "cursor-agent CLI is not on PATH. Install it or run 'cursor-agent login' first."
  exit 127
fi

cmd=(cursor-agent --print)
[[ -n "$workspace" ]] && cmd+=(--workspace "$workspace")
[[ -n "$model" ]] && cmd+=(--model "$model")
[[ "$plan" == "true" ]] && cmd+=(--plan)
[[ "$force" == "true" ]] && cmd+=(--force)
[[ -n "$output_format" ]] && cmd+=(--output-format "$output_format")
[[ -n "$sandbox" ]] && cmd+=(--sandbox "$sandbox")
(( ${#extra_args[@]} > 0 )) && cmd+=("${extra_args[@]}")

print -u2 "Running: ${cmd[*]}"
print "$prompt_content" | "${cmd[@]}"
