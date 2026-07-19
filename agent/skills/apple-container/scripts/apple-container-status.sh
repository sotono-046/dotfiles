#!/usr/bin/env bash

set -u

budget_gib=2

usage() {
  cat <<'EOF'
Usage: apple-container-status.sh [--budget-gib N]

Read-only Apple Container status and disk-budget check.
Exits 0 when healthy and within budget, 1 on inspection failure,
and 2 when physical app-root usage exceeds the soft budget.
EOF
}

while (($# > 0)); do
  case "$1" in
    --budget-gib)
      if (($# < 2)); then
        echo "error: --budget-gib requires a value" >&2
        exit 1
      fi
      budget_gib=$2
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$budget_gib" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "error: budget must be a positive number of GiB" >&2
  exit 1
fi

if ! command -v container >/dev/null 2>&1; then
  echo "error: Apple Container CLI is not installed" >&2
  exit 1
fi

echo "== Version =="
container --version

echo
echo "== System status =="
status_output=$(container system status 2>&1)
status_rc=$?
printf '%s\n' "$status_output"

app_root=$(printf '%s\n' "$status_output" | awk '
  $1 == "appRoot" {
    sub(/^[^[:space:]]+[[:space:]]+/, "")
    print
    exit
  }
')
if [[ -z "$app_root" ]]; then
  app_root="$HOME/Library/Application Support/com.apple.container"
fi

inspection_failed=0

echo
echo "== Disk accounting =="
if ! container system df; then
  inspection_failed=1
fi

echo
echo "== Containers =="
if ! container list --all; then
  inspection_failed=1
fi

echo
echo "== Volumes =="
if ! container volume list; then
  inspection_failed=1
fi

echo
echo "== Builder =="
if ! container builder status; then
  inspection_failed=1
fi

echo
echo "== Physical app-root usage =="
if [[ -d "$app_root" ]]; then
  du -sh "$app_root"
  used_kib=$(du -sk "$app_root" | awk '{print $1}')
  used_gib=$(awk -v kib="$used_kib" 'BEGIN { printf "%.3f", kib / 1048576 }')
  if awk -v used="$used_gib" -v budget="$budget_gib" 'BEGIN { exit !(used > budget) }'; then
    echo "budget: EXCEEDED (${used_gib} GiB > ${budget_gib} GiB)"
    budget_rc=2
  else
    echo "budget: OK (${used_gib} GiB <= ${budget_gib} GiB)"
    budget_rc=0
  fi
else
  echo "app root not found: $app_root"
  inspection_failed=1
  budget_rc=0
fi

echo
echo "== Startup jobs =="
uid=$(id -u)
if launchctl print "gui/$uid/homebrew.mxcl.container" >/dev/null 2>&1; then
  echo "warning: homebrew.mxcl.container is loaded; inspect it for a KeepAlive restart loop"
else
  echo "homebrew.mxcl.container: not loaded"
fi
if launchctl print "gui/$uid/dev.sotono.apple-container-start" >/dev/null 2>&1; then
  echo "dev.sotono.apple-container-start: loaded"
else
  echo "dev.sotono.apple-container-start: not loaded"
fi

if ((status_rc != 0 || inspection_failed != 0)); then
  exit 1
fi
exit "$budget_rc"
