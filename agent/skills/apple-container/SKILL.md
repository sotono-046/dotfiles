---
name: apple-container
description: Operate Apple's `container` CLI with strict disk-usage and data-safety guardrails. Use whenever the task involves Apple Container, the apple/container project, `container system`, `container run`, `container build`, Apple Container images/volumes/machines, Docker-to-Apple-Container migration, installation, startup, upgrades, troubleshooting, or storage cleanup. Do not trigger for generic container concepts or Docker-only work unless Apple's CLI is actually in scope.
---

# Apple Container

Keep Apple Container small, observable, and reversible. Treat its images, stopped containers, builders, machines, and volumes as persistent disk consumers.

## Required workflow

1. Disambiguate Apple's `container` CLI from Docker, OCI containers in general, and similarly named commands.
2. Check the installed version before relying on flags:

   ```bash
   container --version
   ```

3. Confirm version-sensitive behavior against the matching tag in the official `apple/container` repository. Prefer the local `--help` output when the installed version differs from current documentation.
4. Run the bundled read-only inspection before changing state:

   ```bash
   bash scripts/apple-container-status.sh --budget-gib 2
   ```

5. List the exact resources in scope before stopping, deleting, pruning, or replacing anything.
6. Perform only the requested operation.
7. Re-run the inspection and report the disk delta, remaining resources, and service state.

## Disk budget

- Use **2 GiB as the default soft budget** on this workstation. This is an alert threshold, not a filesystem quota.
- Do not claim that Apple Container has a Docker Desktop-style global disk cap. Re-check the installed version and official documentation because this may change.
- If a pull, build, machine, or database workload is likely to exceed the soft budget, explain the expected growth before proceeding.
- Use `--rm` for disposable runs:

  ```bash
  container run --rm IMAGE COMMAND
  ```

- Delete validation-only images created by the current task after validation. Preserve project images unless cleanup was requested.
- Stop and delete a builder after the task only when the current task created it and reuse was not requested.
- Prefer host bind mounts for source code. Create named volumes only for persistent runtime data.
- Give every newly created named volume the smallest justified explicit size. Propose 1 GiB when no better estimate exists, but ask before choosing a size that could truncate or block expected database growth:

  ```bash
  container volume create -s 1g NAME
  ```

- Never run `container volume prune` automatically. Treat every volume as potentially valuable data.
- Do not delete the hidden runtime/init image merely because `container system df` marks it reclaimable; doing so usually causes a later re-download.

## Service startup

- Treat `container system start` as a one-shot setup command, not a daemon process.
- Never wrap it in an unconditional `KeepAlive` loop.
- On this workstation, use the existing login-once LaunchAgent `dev.sotono.apple-container-start`.
- Do not run `brew services start container` without first verifying the current formula's generated plist. Homebrew 6.0.11 with `container` 1.1.0 generated an unconditional `KeepAlive` loop that repeatedly executed the one-shot command.
- Do not replace or remove the existing startup mechanism unless the user explicitly requests startup changes.

## Safety rules

- Before stopping the system, list running containers and explain that they will stop.
- Before pruning stopped containers, list them. Stopped containers are state, not cache.
- Before deleting images, distinguish task-created validation images from project images.
- Require explicit authorization immediately before deleting any named volume or container machine.
- Never delete `~/Library/Application Support/com.apple.container` directly to repair or clean the runtime.
- Do not migrate or delete Docker Desktop data merely because Apple Container is installed. Treat migration as a separate, explicitly authorized workflow.
- Do not assume Docker Compose, Docker socket, or Docker-specific tooling is compatible. Inventory each project's dependencies before migration.

## Completion checks

Confirm and report:

- `container system status`
- `container system df`
- `container list --all`
- `container volume list`
- `container builder status`
- Physical app-root usage from `du -sh`
- What was created, downloaded, stopped, deleted, or preserved
- Whether the 2 GiB soft budget is satisfied
- Whether the login-once startup job remains loaded without a restart loop

Use `scripts/apple-container-status.sh` for the repeatable read-only checks.
