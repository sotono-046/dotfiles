#!/usr/bin/env python3
"""Read-only safety audit for linked Git worktrees."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import selectors
import shutil
import stat
import subprocess
import sys
import time
from typing import Any


REGENERABLE_DIRS = (
    "node_modules",
    ".pnpm-store",
    ".yarn/cache",
    ".next",
    ".nuxt",
    ".svelte-kit",
    ".turbo",
    ".cache",
    "dist",
    "build",
    "coverage",
    ".venv",
    "venv",
    "target",
)
MAX_STATUS_OUTPUT_BYTES = 64 * 1024
MAX_STATUS_PATHS = 512
MAX_MTIME_SCAN_ENTRIES = 2048
STATUS_TIMEOUT_SECONDS = 20.0


class GitError(RuntimeError):
    pass


def run(
    command: list[str], cwd: Path, *, check: bool = True
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["GIT_OPTIONAL_LOCKS"] = "0"
    result = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise GitError(f"{' '.join(command)}: {detail}")
    return result


def git(cwd: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], cwd, check=check)


def parse_porcelain(raw: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for line in raw.splitlines():
        if not line:
            if current is not None:
                records.append(current)
                current = None
            continue
        key, separator, value = line.partition(" ")
        if key == "worktree":
            if current is not None:
                records.append(current)
            current = {"path": value if separator else "", "unknown_fields": []}
            continue
        if current is None:
            continue
        if key in {"HEAD", "branch"}:
            current[key.lower()] = value
        elif key in {"bare", "detached"}:
            current[key] = True
        elif key in {"locked", "prunable"}:
            current[key] = value if separator else True
        else:
            current["unknown_fields"].append(line)
    if current is not None:
        records.append(current)
    return records


def iso_timestamp(timestamp: float | None) -> str | None:
    if timestamp is None:
        return None
    return dt.datetime.fromtimestamp(timestamp, tz=dt.timezone.utc).isoformat()


def path_contains(root: Path, child: Path) -> bool:
    try:
        child.relative_to(root)
        return True
    except ValueError:
        return False


def collect_active_cwds() -> tuple[set[Path], dict[str, Any]]:
    paths = {Path.cwd().resolve(strict=False)}
    lsof = shutil.which("lsof")
    if lsof is None:
        return paths, {"complete": False, "source": "current-process-only", "error": "lsof-not-found"}

    result = subprocess.run(
        [lsof, "-nP", "-a", "-d", "cwd", "-Fn"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    for line in result.stdout.splitlines():
        if line.startswith("n") and len(line) > 1:
            paths.add(Path(line[1:]).resolve(strict=False))
    complete = result.returncode == 0
    return paths, {
        "complete": complete,
        "source": "lsof-and-current-process",
        "error": None if complete else (result.stderr.strip() or f"lsof-exit-{result.returncode}"),
    }


def matching_active_cwds(worktree: Path, active_cwds: set[Path]) -> list[str]:
    root = worktree.resolve(strict=False)
    return sorted(str(cwd) for cwd in active_cwds if cwd == root or path_contains(root, cwd))


def mtime_evidence(worktree: Path) -> dict[str, Any]:
    gitdir_result = git(worktree, "rev-parse", "--path-format=absolute", "--git-dir", check=False)
    if gitdir_result.returncode != 0:
        return {
            "git_dir": None,
            "mtime_sources": {},
            "latest_mtime": None,
            "age_days": None,
            "evidence_complete": False,
            "_latest_epoch": None,
            "error": "worktree-git-dir-unavailable",
        }

    git_dir = Path(gitdir_result.stdout.strip()).resolve(strict=False)
    sources: dict[str, str | None] = {}
    timestamps: list[float] = []
    for relative in ("HEAD", "index", "logs/HEAD"):
        candidate = git_dir / relative
        try:
            timestamp = candidate.stat().st_mtime
        except OSError:
            sources[relative] = None
        else:
            sources[relative] = iso_timestamp(timestamp)
            timestamps.append(timestamp)
    latest = max(timestamps) if timestamps else None
    return {
        "git_dir": str(git_dir),
        "mtime_sources": sources,
        "latest_mtime": iso_timestamp(latest),
        "age_days": None,
        "evidence_complete": latest is not None,
        "_latest_epoch": latest,
        "error": None,
    }


def count_commits(worktree: Path, revision_range: str) -> int | None:
    result = git(worktree, "rev-list", "--count", revision_range, check=False)
    if result.returncode != 0:
        return None
    try:
        return int(result.stdout.strip())
    except ValueError:
        return None


def git_safety(worktree: Path) -> dict[str, Any]:
    origin = git(
        worktree,
        "symbolic-ref",
        "--quiet",
        "--short",
        "refs/remotes/origin/HEAD",
        check=False,
    )
    origin_head = origin.stdout.strip() if origin.returncode == 0 else None
    if origin_head:
        verify = git(worktree, "rev-parse", "--verify", f"{origin_head}^{{commit}}", check=False)
        if verify.returncode != 0:
            origin_head = None

    upstream_result = git(
        worktree,
        "rev-parse",
        "--abbrev-ref",
        "--symbolic-full-name",
        "@{upstream}",
        check=False,
    )
    upstream = upstream_result.stdout.strip() if upstream_result.returncode == 0 else None
    ahead_origin = count_commits(worktree, f"{origin_head}..HEAD") if origin_head else None
    ahead_upstream = count_commits(worktree, f"{upstream}..HEAD") if upstream else None
    return {
        "origin_head": origin_head,
        "ahead_of_origin_head": ahead_origin,
        "upstream": upstream,
        "ahead_of_upstream": ahead_upstream,
        "unpushed": None if upstream is None or ahead_upstream is None else ahead_upstream > 0,
        "unmerged_from_origin_head": None if ahead_origin is None else ahead_origin > 0,
    }


def stop_process(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def bounded_status(worktree: Path) -> dict[str, Any]:
    env = os.environ.copy()
    env["GIT_OPTIONAL_LOCKS"] = "0"
    command = [
        "git",
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=normal",
        "--ignored=matching",
        "--no-renames",
    ]
    process = subprocess.Popen(
        command,
        cwd=worktree,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if process.stdout is None:
        stop_process(process)
        return {"raw": b"", "returncode": process.returncode, "byte_truncated": False, "timed_out": False}

    output = bytearray()
    byte_truncated = False
    timed_out = False
    deadline = time.monotonic() + STATUS_TIMEOUT_SECONDS
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    try:
        while True:
            remaining_time = deadline - time.monotonic()
            if remaining_time <= 0:
                timed_out = True
                break
            events = selector.select(remaining_time)
            if not events:
                timed_out = True
                break
            chunk = os.read(process.stdout.fileno(), min(65536, MAX_STATUS_OUTPUT_BYTES - len(output) + 1))
            if not chunk:
                break
            output.extend(chunk)
            if len(output) > MAX_STATUS_OUTPUT_BYTES:
                del output[MAX_STATUS_OUTPUT_BYTES:]
                byte_truncated = True
                break
    finally:
        selector.close()

    if byte_truncated or timed_out:
        stop_process(process)
    else:
        try:
            process.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            timed_out = True
            stop_process(process)
    return {
        "raw": bytes(output),
        "returncode": process.returncode,
        "byte_truncated": byte_truncated,
        "timed_out": timed_out,
    }


def parse_status_paths(result: dict[str, Any]) -> tuple[dict[str, Any], list[Path]]:
    counts = {"tracked_changes": 0, "untracked": 0, "ignored": 0, "conflicts": 0}
    raw: bytes = result["raw"]
    complete_record_stream = not raw or raw.endswith(b"\0")
    records = raw.split(b"\0")[:-1] if complete_record_stream else raw.split(b"\0")[:-1]
    paths: list[Path] = []
    invalid_path_count = 0
    malformed_record_count = 0
    path_cap_reached = False
    conflict_codes = {"DD", "AU", "UD", "UA", "DU", "AA", "UU"}
    for record in records:
        if not record:
            continue
        if len(paths) >= MAX_STATUS_PATHS:
            path_cap_reached = True
            break
        if len(record) < 4 or record[2:3] != b" ":
            malformed_record_count += 1
            continue
        code = record[:2].decode("ascii", errors="replace")
        relative = Path(os.fsdecode(record[3:]))
        if relative.is_absolute() or ".." in relative.parts:
            invalid_path_count += 1
            continue
        paths.append(relative)
        if code == "??":
            counts["untracked"] += 1
        elif code == "!!":
            counts["ignored"] += 1
        elif code in conflict_codes:
            counts["conflicts"] += 1
        else:
            counts["tracked_changes"] += 1

    command_completed = result["returncode"] == 0 and not result["timed_out"]
    scan_complete = all(
        (
            command_completed,
            not result["byte_truncated"],
            complete_record_stream,
            not path_cap_reached,
            malformed_record_count == 0,
            invalid_path_count == 0,
        )
    )
    status_scan = {
        "command_completed": command_completed,
        "mode": "porcelain-v1-z/untracked-normal/ignored-matching/no-renames",
        "output_bytes": len(raw),
        "output_byte_cap": MAX_STATUS_OUTPUT_BYTES,
        "path_entries": len(paths),
        "path_entry_cap": MAX_STATUS_PATHS,
        "byte_truncated": result["byte_truncated"],
        "path_cap_reached": path_cap_reached,
        "timed_out": result["timed_out"],
        "partial_record": not complete_record_stream,
        "malformed_record_count": malformed_record_count,
        "invalid_path_count": invalid_path_count,
        "complete": scan_complete,
    }
    return {"status_scan": status_scan, **counts}, paths


def collect_filesystem_mtimes(worktree: Path, relative_paths: list[Path]) -> dict[str, Any]:
    root = worktree.resolve(strict=False)
    timestamps: list[float] = []
    scan_entries = 0
    scan_truncated = False
    seen: set[Path] = set()

    def observe(candidate: Path, *, recurse: bool) -> None:
        nonlocal scan_entries, scan_truncated
        stack = [candidate]
        while stack and not scan_truncated:
            current = stack.pop()
            if current in seen:
                continue
            seen.add(current)
            try:
                current_stat = current.lstat()
            except OSError:
                continue
            scan_entries += 1
            timestamps.append(current_stat.st_mtime)
            if scan_entries >= MAX_MTIME_SCAN_ENTRIES:
                scan_truncated = bool(stack) or recurse
                break
            if not recurse or stat.S_ISLNK(current_stat.st_mode) or not stat.S_ISDIR(current_stat.st_mode):
                continue
            try:
                with os.scandir(current) as iterator:
                    children = [Path(item.path) for item in iterator]
            except OSError:
                continue
            stack.extend(children)

    observe(root, recurse=False)
    for relative in relative_paths:
        if scan_entries >= MAX_MTIME_SCAN_ENTRIES:
            scan_truncated = True
            break
        candidate = root.joinpath(*relative.parts)
        if candidate.exists() or candidate.is_symlink():
            observe(candidate, recurse=candidate.is_dir() and not candidate.is_symlink())
            continue
        parent = candidate.parent
        while parent != root and not parent.exists():
            parent = parent.parent
        observe(parent, recurse=False)
        if scan_truncated:
            break

    latest = max(timestamps) if timestamps else None
    return {
        "root_mtime": iso_timestamp(root.lstat().st_mtime),
        "status_path_count": len(relative_paths),
        "observed_entry_count": scan_entries,
        "entry_cap": MAX_MTIME_SCAN_ENTRIES,
        "scan_truncated": scan_truncated,
        "latest_mtime": iso_timestamp(latest),
        "_latest_epoch": latest,
    }


def content_state(worktree: Path, git_dir: str | None) -> dict[str, Any]:
    bounded_result = bounded_status(worktree)
    state, status_paths = parse_status_paths(bounded_result)
    filesystem_evidence = collect_filesystem_mtimes(worktree, status_paths)

    in_progress: list[str] = []
    if git_dir:
        root = Path(git_dir)
        markers = {
            "merge": "MERGE_HEAD",
            "cherry-pick": "CHERRY_PICK_HEAD",
            "revert": "REVERT_HEAD",
            "bisect": "BISECT_LOG",
            "rebase-merge": "rebase-merge",
            "rebase-apply": "rebase-apply",
        }
        in_progress = [name for name, relative in markers.items() if (root / relative).exists()]
    state["in_progress"] = in_progress
    state["_filesystem_evidence"] = filesystem_evidence
    return state


def merge_activity(activity: dict[str, Any], content: dict[str, Any]) -> dict[str, Any]:
    git_latest = activity.pop("_latest_epoch")
    filesystem = content.pop("_filesystem_evidence")
    filesystem_latest = filesystem.pop("_latest_epoch")
    timestamps = [value for value in (git_latest, filesystem_latest) if value is not None]
    latest = max(timestamps) if timestamps else None
    now = dt.datetime.now(tz=dt.timezone.utc).timestamp()
    age_days = None if latest is None else max(0.0, (now - latest) / 86400)
    activity["filesystem_evidence"] = filesystem
    activity["latest_mtime"] = iso_timestamp(latest)
    activity["age_days"] = None if age_days is None else round(age_days, 3)
    activity["evidence_complete"] = bool(
        activity["evidence_complete"]
        and content["status_scan"]["complete"]
        and not filesystem["scan_truncated"]
    )
    return activity


def regenerable_directories(worktree: Path) -> list[str]:
    root = worktree.resolve(strict=False)
    found: list[str] = []
    for relative in REGENERABLE_DIRS:
        candidate = root
        contains_symlink = False
        for part in Path(relative).parts:
            candidate /= part
            if candidate.is_symlink():
                contains_symlink = True
                break
        if contains_symlink or not candidate.is_dir():
            continue
        resolved = candidate.resolve(strict=False)
        if path_contains(root, resolved):
            found.append(relative)
    return found


def decide(entry: dict[str, Any], active_scan_complete: bool) -> dict[str, Any]:
    blockers: list[str] = []
    if entry["is_main"]:
        blockers.append("main-worktree")
    if entry["bare"]:
        blockers.append("bare-worktree")
    if entry["locked"]:
        blockers.append("locked-worktree")
    if entry["active_cwd"]:
        blockers.append("active-cwd")
    if not active_scan_complete:
        blockers.append("active-cwd-scan-incomplete")
    if not entry["path_exists"]:
        if entry["prunable"] and not blockers:
            return {"action": "metadata-prune-candidate", "reasons": ["missing-path", "porcelain-prunable"]}
        blockers.append("missing-path")

    safety = entry["git_safety"]
    if entry["path_exists"]:
        if not entry["activity"]["evidence_complete"]:
            blockers.append("activity-evidence-incomplete")
        if safety["origin_head"] is None:
            blockers.append("origin-head-unavailable")
        if safety["unpushed"] is True:
            blockers.append("unpushed-commits")
        if safety["unmerged_from_origin_head"] is True:
            blockers.append("unmerged-from-origin-head")

    if blockers:
        return {"action": f"protected-{blockers[0]}", "reasons": blockers}

    age_days = entry["activity"]["age_days"]
    if age_days is None:
        return {"action": "protected-age-unknown", "reasons": ["activity-mtime-unavailable"]}
    if age_days < 3:
        return {"action": "no-op-recent", "reasons": ["younger-than-3-days"]}
    if age_days < 7:
        if not entry["regenerable_directories"]:
            return {
                "action": "no-op-no-regenerable-directories",
                "reasons": ["age-between-3-and-7-days", "no-regenerable-directories"],
            }
        return {"action": "regenerable-cleanup-candidate", "reasons": ["age-between-3-and-7-days"]}
    return {"action": "worktree-removal-candidate", "reasons": ["age-at-least-7-days", "ordinary-guards-clear"]}


def audit(repository: Path) -> dict[str, Any]:
    common = git(repository, "rev-parse", "--path-format=absolute", "--git-common-dir")
    common_dir = Path(common.stdout.strip()).resolve(strict=False)
    porcelain = git(repository, "worktree", "list", "--porcelain")
    raw_entries = parse_porcelain(porcelain.stdout)
    active_cwds, active_scan = collect_active_cwds()
    entries: list[dict[str, Any]] = []

    for index, raw in enumerate(raw_entries):
        path = Path(raw["path"]).resolve(strict=False)
        exists = path.is_dir()
        activity = mtime_evidence(path) if exists else {
            "git_dir": None,
            "mtime_sources": {},
            "latest_mtime": None,
            "age_days": None,
            "error": "worktree-path-missing",
        }
        matches = matching_active_cwds(path, active_cwds) if exists else []
        safety = git_safety(path) if exists else {
            "origin_head": None,
            "ahead_of_origin_head": None,
            "upstream": None,
            "ahead_of_upstream": None,
            "unpushed": None,
            "unmerged_from_origin_head": None,
        }
        content = content_state(path, activity["git_dir"]) if exists else None
        if content is not None:
            activity = merge_activity(activity, content)
        else:
            activity.pop("_latest_epoch", None)
        entry: dict[str, Any] = {
            "path": str(path),
            "is_main": index == 0,
            "path_exists": exists,
            "bare": bool(raw.get("bare", False)),
            "locked": raw.get("locked", False),
            "prunable": raw.get("prunable", False),
            "detached": bool(raw.get("detached", False)),
            "branch": raw.get("branch"),
            "head": raw.get("head"),
            "active_cwd": bool(matches),
            "active_cwd_matches": matches,
            "activity": activity,
            "git_safety": safety,
            "content_state": content,
            "regenerable_directories": regenerable_directories(path) if exists else [],
        }
        entry["decision"] = decide(entry, active_scan["complete"])
        entries.append(entry)

    candidate_actions = {
        "regenerable-cleanup-candidate",
        "worktree-removal-candidate",
        "metadata-prune-candidate",
    }
    linked = [entry for entry in entries if not entry["is_main"]]
    return {
        "schema_version": 1,
        "audit_only": True,
        "mutations_attempted": False,
        "generated_at": dt.datetime.now(tz=dt.timezone.utc).isoformat(),
        "repository": {
            "requested_path": str(repository),
            "common_git_dir": str(common_dir),
        },
        "active_cwd_scan": active_scan,
        "summary": {
            "worktree_total": len(entries),
            "linked_worktree_total": len(linked),
            "cleanup_candidate_total": sum(
                entry["decision"]["action"] in candidate_actions for entry in linked
            ),
        },
        "worktrees": entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repository",
        default=".",
        help="Any existing worktree path in the repository (default: current directory)",
    )
    parser.add_argument("--compact", action="store_true", help="Emit compact JSON")
    args = parser.parse_args()
    repository = Path(args.repository).expanduser().resolve(strict=False)
    try:
        report = audit(repository)
    except (GitError, OSError) as exc:
        report = {
            "schema_version": 1,
            "audit_only": True,
            "mutations_attempted": False,
            "error": str(exc),
        }
        json.dump(report, sys.stdout, ensure_ascii=False, indent=None if args.compact else 2)
        sys.stdout.write("\n")
        return 2

    json.dump(report, sys.stdout, ensure_ascii=False, indent=None if args.compact else 2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
