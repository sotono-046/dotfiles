#!/usr/bin/env bash
set -euo pipefail

APPLY=false
ALL_VOLUMES=false
RECLAIM_SPACE=false
TIMEOUT_SECONDS=15

usage() {
  cat <<'EOF'
Usage: docker-cleanup.sh [--apply] [--all-volumes] [--reclaim-space]

Without --apply, report Docker disk usage without deleting anything.

  --apply          Remove stopped containers, unused images and networks,
                   anonymous volumes, and all unused build cache.
  --all-volumes    Also remove unused named volumes. Requires --apply.
  --reclaim-space  Compact Docker Desktop's sparse disk on macOS. Requires
                   --apply and runs Docker's privileged reclaim helper.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true ;;
    --all-volumes) ALL_VOLUMES=true ;;
    --reclaim-space) RECLAIM_SPACE=true ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$APPLY" != "true" && ( "$ALL_VOLUMES" == "true" || "$RECLAIM_SPACE" == "true" ) ]]; then
  echo "--all-volumes and --reclaim-space require --apply." >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || {
  echo "docker CLI was not found." >&2
  exit 127
}

run_timed() {
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$TIMEOUT_SECONDS" "$@"
  elif command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SECONDS" "$@"
  else
    "$@"
  fi
}

docker_desktop_data_dir() {
  local candidate
  for candidate in \
    "$HOME/Library/Containers/com.docker.docker" \
    "$HOME/.docker/desktop"; do
    [[ -d "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

report_state() {
  local data_dir=""

  echo "Docker version"
  docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
  echo
  echo "Running containers"
  docker ps --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}'
  echo
  echo "All containers"
  docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}'
  echo
  echo "Docker disk usage"
  docker system df
  echo
  echo "Unused volumes"
  docker volume ls --filter dangling=true --format '{{.Name}}'
  echo
  echo "Buildx disk usage"
  if docker buildx version >/dev/null 2>&1; then
    docker buildx du 2>/dev/null | tail -n 12 || true
  else
    echo "Buildx is unavailable."
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    data_dir=$(docker_desktop_data_dir 2>/dev/null || true)
    if [[ -n "$data_dir" ]]; then
      echo
      echo "Docker Desktop physical storage"
      du -sh "$data_dir" 2>/dev/null || true
    fi
  fi
}

if ! run_timed docker info >/dev/null 2>&1; then
  echo "Docker daemon is unavailable or did not respond within ${TIMEOUT_SECONDS}s." >&2
  echo "Try: docker desktop status" >&2
  echo "Then: docker desktop restart --timeout 120" >&2
  exit 3
fi

echo "=== Before ==="
report_state

if [[ "$APPLY" != "true" ]]; then
  echo
  echo "Report only. Re-run with --apply to remove unused Docker data."
  exit 0
fi

running_containers=$(docker ps -q)
if [[ -n "$running_containers" ]]; then
  echo >&2
  echo "Refusing cleanup because containers are running:" >&2
  docker ps --format '{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}' >&2
  exit 4
fi

echo
echo "=== Cleanup ==="
docker system prune --all --volumes --force

if docker buildx version >/dev/null 2>&1; then
  docker buildx prune --all --force
fi

if [[ "$ALL_VOLUMES" == "true" ]]; then
  docker volume prune --all --force
fi

if [[ "$RECLAIM_SPACE" == "true" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]] || ! docker_desktop_data_dir >/dev/null 2>&1; then
    echo "Skipping Docker Desktop sparse-disk reclaim: macOS Docker Desktop data was not found." >&2
  else
    docker run --privileged --pid=host docker/desktop-reclaim-space
    docker image rm docker/desktop-reclaim-space >/dev/null 2>&1 || true
    docker system prune --all --volumes --force >/dev/null
  fi
fi

echo
echo "=== After ==="
report_state
