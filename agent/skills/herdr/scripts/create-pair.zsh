#!/usr/bin/env zsh

setopt errexit nounset pipefail

usage() {
  print -u2 -- 'usage: create-pair.zsh --workspace ID --cwd ABS_EXISTING_DIR --label TEXT --left TEXT --right TEXT --record-dir NEW_ABS_DIR [--dry-run]'
}

fail() {
  print -u2 -- "$1"
  return 1
}

render_command() {
  local argument rendered line=''
  for argument in "$@"; do
    printf -v rendered '%q' "$argument"
    if [[ -n "$line" ]]; then
      line+=" "
    fi
    line+="$rendered"
  done
  print -r -- "$line"
}

save_layout() {
  local stage="$1"
  jq -n \
    --arg workspace_id "$workspace_id" \
    --arg cwd "$cwd" \
    --arg tab_id "$tab_id" \
    --arg left_pane_id "$left_pane_id" \
    --arg right_pane_id "$right_pane_id" \
    --arg label "$label" \
    --arg left_label "$left_label" \
    --arg right_label "$right_label" \
    --arg stage "$stage" \
    '{workspace_id:$workspace_id,cwd:$cwd,tab_id:$tab_id,left_pane_id:$left_pane_id,right_pane_id:(if $right_pane_id == "" then null else $right_pane_id end),label:$label,left_label:$left_label,right_label:$right_label,stage:$stage}' \
    > "$record_dir/layout.json.tmp"
  mv -- "$record_dir/layout.json.tmp" "$record_dir/layout.json"
}

workspace_id=''
cwd=''
label=''
left_label=''
right_label=''
record_dir=''
dry_run=0

while (( $# > 0 )); do
  case "$1" in
    --workspace)
      (( $# >= 2 )) || { usage; exit 2; }
      workspace_id="$2"
      shift 2
      ;;
    --cwd)
      (( $# >= 2 )) || { usage; exit 2; }
      cwd="$2"
      shift 2
      ;;
    --label)
      (( $# >= 2 )) || { usage; exit 2; }
      label="$2"
      shift 2
      ;;
    --left)
      (( $# >= 2 )) || { usage; exit 2; }
      left_label="$2"
      shift 2
      ;;
    --right)
      (( $# >= 2 )) || { usage; exit 2; }
      right_label="$2"
      shift 2
      ;;
    --record-dir)
      (( $# >= 2 )) || { usage; exit 2; }
      record_dir="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$workspace_id" || -z "$cwd" || -z "$label" || -z "$left_label" || -z "$right_label" || -z "$record_dir" ]]; then
  usage
  exit 2
fi

if [[ "$cwd" != /* || "$record_dir" != /* ]]; then
  fail '--cwd and --record-dir must be absolute paths.' || exit 2
fi

if (( dry_run == 0 )); then
  if [[ "${HERDR_ENV:-}" != '1' || "${HERDR_WORKSPACE_ID:-}" != "$workspace_id" ]]; then
    fail 'Refusing Herdr mutation: run from an active Herdr pane in the specified workspace.' || exit 2
  fi
fi

if [[ ! -d "$cwd" ]]; then
  fail "--cwd is not an existing directory: $cwd" || exit 2
fi

if [[ -e "$record_dir" ]]; then
  fail "--record-dir already exists; refusing to overwrite: $record_dir" || exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  fail 'jq is required but was not found in PATH.' || exit 2
fi

if (( dry_run )); then
  render_command mkdir -m 700 -- "$record_dir"
  render_command herdr tab create --workspace "$workspace_id" --cwd "$cwd" --label "$label" --no-focus
  render_command herdr pane split '<left_pane_id>' --direction right --cwd "$cwd" --no-focus
  render_command herdr pane rename '<left_pane_id>' "$left_label"
  render_command herdr pane rename '<right_pane_id>' "$right_label"
  exit 0
fi

if ! command -v herdr >/dev/null 2>&1; then
  fail 'herdr is required but was not found in PATH.' || exit 2
fi

umask 077
if ! mkdir -m 700 -- "$record_dir"; then
  fail "Could not create record directory: $record_dir" || exit 2
fi

if ! herdr tab create --workspace "$workspace_id" --cwd "$cwd" --label "$label" --no-focus > "$record_dir/tab.json"; then
  fail "Herdr tab creation failed; partial receipt kept in $record_dir" || exit 1
fi

tab_id="$(jq -er '.result.tab.tab_id | strings | select(length > 0)' "$record_dir/tab.json" 2>/dev/null)" || {
  fail "Could not read result.tab.tab_id; partial receipt kept in $record_dir" || exit 1
}
left_pane_id="$(jq -er '.result.root_pane.pane_id | strings | select(length > 0)' "$record_dir/tab.json" 2>/dev/null)" || {
  fail "Could not read result.root_pane.pane_id; partial receipt kept in $record_dir" || exit 1
}
right_pane_id=''
save_layout tab_created

if ! herdr pane split "$left_pane_id" --direction right --cwd "$cwd" --no-focus > "$record_dir/split.json"; then
  fail "Herdr pane split failed; partial receipts kept in $record_dir" || exit 1
fi

right_pane_id="$(jq -er '.result.pane.pane_id | strings | select(length > 0)' "$record_dir/split.json" 2>/dev/null)" || {
  fail "Could not read result.pane.pane_id; partial receipts kept in $record_dir" || exit 1
}
save_layout split_created

if ! herdr pane rename "$left_pane_id" "$left_label" > "$record_dir/rename-left.json"; then
  fail "Herdr left pane rename failed; partial receipts kept in $record_dir" || exit 1
fi

if ! herdr pane rename "$right_pane_id" "$right_label" > "$record_dir/rename-right.json"; then
  fail "Herdr right pane rename failed; partial receipts kept in $record_dir" || exit 1
fi

save_layout ready
cat "$record_dir/layout.json"
