---
name: docker-cleanup
description: Safely inspect and reclaim unused Docker and Docker Desktop data on macOS. Use when the user says Docker is using too much disk, asks to clean Docker garbage, prune containers/images/build cache/volumes, shrink Docker.raw, or verify that no Docker data remains.
---

# Docker Cleanup

Inspect first, refuse destructive cleanup while containers are running, then prune only the scope the user authorized. Use `scripts/docker-cleanup.sh` for the repeatable checks and cleanup.

## Workflow

1. Verify the installed client and actual daemon state. Check the local Docker version before relying on flags, and confirm current prune behavior in the official Docker documentation when it may have changed.
2. Run the script without flags to report containers, images, volumes, build cache, and physical Docker Desktop storage:

   ```bash
   bash scripts/docker-cleanup.sh
   ```

3. If the daemon is unavailable, diagnose with `docker desktop status`. Restart Docker Desktop with `docker desktop restart --timeout 120` when available. Do not delete `Docker.raw` or runtime directories to repair a stuck daemon.
4. Review both `docker ps` and `docker ps -a`. The script must refuse `--apply` when any container is running.
5. Match cleanup scope to the request:
   - General Docker garbage cleanup: `bash scripts/docker-cleanup.sh --apply`
   - Also delete unused named volumes: add `--all-volumes` only when the user explicitly authorizes named-volume deletion.
   - Also compact Docker Desktop's sparse disk image: add `--reclaim-space` on macOS when physical usage remains materially above `docker system df` after pruning.
6. Report before/after `docker system df`, object counts, and physical Docker Desktop usage. Explain that the apparent size from `ls -lh Docker.raw` is its capacity; `du -sh` is the host space actually consumed.

## Safety Rules

- Treat volumes as potentially valuable database state even when no container is running. Never pass `--all-volumes` based only on “nothing is running.” Require explicit authorization to delete unused named volumes.
- Never stop a running container implicitly. If the running-container gate fails, list the containers and ask whether they should be stopped or preserved.
- Treat stopped containers as deletable runtime state, not harmless cache. List them before `--apply`; if the request is only a vague request to “free some space,” explain that `--apply` removes them before proceeding.
- Never use Docker Desktop's Clean/Purge data, factory reset, direct runtime-directory removal, or direct `Docker.raw` deletion unless the user explicitly requests a complete reset and accepts total data loss.
- Preserve Docker settings, contexts, credentials, and CLI configuration under `~/.docker`.
- The reclaim helper runs a privileged container. Use it only with `--reclaim-space`, after all running-container checks pass, and prune its image afterward.
- If Docker Desktop remains unresponsive after a normal restart, stop and report the blocker before escalating to forced process termination or a full reset.

## Expected Completion

Confirm these values after cleanup:

- `docker ps -q` is empty.
- `docker system df` shows the expected remaining objects and `0B` reclaimable where a complete cleanup was requested.
- `docker buildx du` shows no reclaimable cache after Buildx cleanup.
- `du -sh` for the Docker Desktop data directory reflects reclaimed host disk space when `--reclaim-space` was used.

State exactly what was deleted, what was preserved, how much host disk was recovered, and whether Docker Desktop was restarted.
