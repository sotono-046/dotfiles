#!/usr/bin/env python3
"""Inspect and optionally merge non-draft PRs assigned to the current gh user."""

from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import Any


SUCCESS_CONCLUSIONS = {"SUCCESS"}
FAILURE_CONCLUSIONS = {
    "ACTION_REQUIRED",
    "CANCELLED",
    "FAILURE",
    "STARTUP_FAILURE",
    "STALE",
    "TIMED_OUT",
}
SUCCESS_STATES = {"SUCCESS"}
FAILURE_STATES = {"ERROR", "FAILURE"}
PENDING_STATES = {"EXPECTED", "IN_PROGRESS", "PENDING", "QUEUED", "REQUESTED", "WAITING"}
MERGE_BLOCKING_STATES = {"BLOCKED", "DIRTY", "DRAFT", "UNKNOWN", "UNSTABLE"}
UPDATEABLE_STATES = {"BEHIND"}
TOKEN_RE = re.compile(r"(github_pat_|gh[pousr]_)[A-Za-z0-9_]+")


@dataclass
class CommandResult:
    args: list[str]
    returncode: int
    stdout: str
    stderr: str


@dataclass
class CheckSummary:
    total: int = 0
    success: int = 0
    pending: int = 0
    failure: int = 0
    unknown: int = 0
    names: list[str] = field(default_factory=list)

    @property
    def green(self) -> bool:
        return self.total > 0 and self.failure == 0 and self.pending == 0 and self.unknown == 0


def run(args: list[str], *, check: bool = False) -> CommandResult:
    proc = subprocess.run(args, text=True, capture_output=True)
    result = CommandResult(args=args, returncode=proc.returncode, stdout=proc.stdout, stderr=proc.stderr)
    if check and proc.returncode != 0:
        quoted = " ".join(shlex.quote(part) for part in args)
        raise RuntimeError(f"command failed ({proc.returncode}): {quoted}\n{proc.stderr.strip()}")
    return result


def gh_json(args: list[str]) -> Any:
    result = run(["gh", *args], check=True)
    if not result.stdout.strip():
        return None
    return json.loads(result.stdout)


def current_login() -> str:
    return str(gh_json(["api", "user"]).get("login") or "")


def repo_full_name(repo: Any) -> str:
    if isinstance(repo, str):
        return repo
    if not isinstance(repo, dict):
        raise ValueError(f"unexpected repository shape: {repo!r}")
    for key in ("nameWithOwner", "fullName", "full_name"):
        value = repo.get(key)
        if value:
            return value
    owner = repo.get("owner")
    name = repo.get("name")
    if isinstance(owner, dict):
        owner = owner.get("login")
    if owner and name:
        return f"{owner}/{name}"
    raise ValueError(f"cannot derive repository full name from: {repo!r}")


def split_repo(repo: str) -> tuple[str, str]:
    if "/" not in repo:
        raise ValueError(f"repo must be OWNER/REPO: {repo}")
    owner, name = repo.split("/", 1)
    return owner, name


def assignee_logins(assignees: list[Any] | None) -> set[str]:
    logins: set[str] = set()
    for assignee in assignees or []:
        if isinstance(assignee, dict) and assignee.get("login"):
            logins.add(str(assignee["login"]))
        elif isinstance(assignee, str):
            logins.add(assignee)
    return logins


def redact(text: str, *, limit: int = 240) -> str:
    collapsed = " ".join(text.split())
    collapsed = TOKEN_RE.sub(lambda match: f"{match.group(1)}<redacted>", collapsed)
    if len(collapsed) > limit:
        return collapsed[: limit - 3] + "..."
    return collapsed


def update_succeeded(result: dict[str, Any]) -> bool:
    if result["returncode"] == 0:
        return True
    text = f"{result.get('stdout', '')}\n{result.get('stderr', '')}".lower()
    return any(marker in text for marker in ("already up to date", "already up-to-date", "not behind"))


def list_assigned_prs(limit: int, repo: str | None) -> list[dict[str, Any]]:
    search_fields = "number,title,url,isDraft,repository,updatedAt,state"
    if repo:
        list_fields = "number,title,url,isDraft,updatedAt,state"
        prs = gh_json(
            [
                "pr",
                "list",
                "--repo",
                repo,
                "--assignee",
                "@me",
                "--state",
                "open",
                "--limit",
                str(limit),
                "--json",
                list_fields,
            ]
        )
        for pr in prs:
            pr["repository"] = repo
        return prs

    return gh_json(
        [
            "search",
            "prs",
            "--assignee",
            "@me",
            "--state",
            "open",
            "--limit",
            str(limit),
            "--json",
            search_fields,
        ]
    )


def pr_view(repo: str, number: int) -> dict[str, Any]:
    fields = ",".join(
        [
            "number",
            "title",
            "url",
            "state",
            "isDraft",
            "assignees",
            "baseRefName",
            "baseRefOid",
            "headRefName",
            "headRefOid",
            "headRepository",
            "headRepositoryOwner",
            "isCrossRepository",
            "maintainerCanModify",
            "mergeStateStatus",
            "mergeable",
            "reviewDecision",
            "statusCheckRollup",
        ]
    )
    return gh_json(["pr", "view", str(number), "--repo", repo, "--json", fields])


def graphql_review_threads(repo: str, number: int) -> list[dict[str, Any]]:
    owner, name = split_repo(repo)
    query = """
query($owner:String!, $name:String!, $number:Int!, $after:String) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviewThreads(first:100, after:$after) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first:10) {
            nodes {
              id
              databaseId
              body
              url
              author { login }
              createdAt
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
"""
    after: str | None = None
    threads: list[dict[str, Any]] = []
    while True:
        args = [
            "api",
            "graphql",
            "-f",
            f"owner={owner}",
            "-f",
            f"name={name}",
            "-F",
            f"number={number}",
            "-f",
            f"query={query}",
        ]
        if after:
            args.extend(["-f", f"after={after}"])
        data = gh_json(args)
        page = data["data"]["repository"]["pullRequest"]["reviewThreads"]
        threads.extend(page["nodes"])
        if not page["pageInfo"]["hasNextPage"]:
            return threads
        after = page["pageInfo"]["endCursor"]


def summarize_checks(status_rollup: list[dict[str, Any]] | None) -> CheckSummary:
    summary = CheckSummary()
    if not status_rollup:
        return summary

    for item in status_rollup:
        summary.total += 1
        name = item.get("name") or item.get("context") or item.get("workflowName") or "<unnamed>"
        conclusion = str(item.get("conclusion") or "").upper()
        status = str(item.get("status") or item.get("state") or "").upper()
        if conclusion in SUCCESS_CONCLUSIONS or status in SUCCESS_STATES:
            summary.success += 1
        elif conclusion in FAILURE_CONCLUSIONS or status in FAILURE_STATES:
            summary.failure += 1
            summary.names.append(name)
        elif status in PENDING_STATES or (status and not conclusion):
            summary.pending += 1
            summary.names.append(name)
        else:
            summary.unknown += 1
            summary.names.append(name)
    return summary


def evaluate_pr(repo: str, number: int, *, allow_no_checks: bool, login: str) -> dict[str, Any]:
    view = pr_view(repo, number)
    if view.get("isDraft"):
        return {
            "repo": repo,
            "number": number,
            "title": view.get("title"),
            "url": view.get("url"),
            "status": "draft",
            "ready": False,
            "blockers": ["draft"],
            "headRefOid": view.get("headRefOid"),
            "headRefName": view.get("headRefName"),
            "baseRefName": view.get("baseRefName"),
            "mergeStateStatus": view.get("mergeStateStatus"),
            "mergeable": view.get("mergeable"),
            "reviewDecision": view.get("reviewDecision"),
            "checks": {"total": 0, "success": 0, "pending": 0, "failure": 0, "unknown": 0, "names": []},
            "unresolvedReviewThreads": [],
        }

    threads = graphql_review_threads(repo, number)
    unresolved = [thread for thread in threads if not thread.get("isResolved")]
    checks = summarize_checks(view.get("statusCheckRollup"))
    merge_state = str(view.get("mergeStateStatus") or "").upper()
    mergeable = view.get("mergeable")
    mergeable_state = str(mergeable or "").upper()

    blockers: list[str] = []
    if view.get("state") != "OPEN":
        blockers.append(f"state:{view.get('state')}")
    if view.get("isDraft"):
        blockers.append("draft")
    if login and login not in assignee_logins(view.get("assignees")):
        blockers.append("assignee:mismatch")
    if unresolved:
        blockers.append(f"unresolved_review_threads:{len(unresolved)}")
    if view.get("reviewDecision") in {"CHANGES_REQUESTED", "REVIEW_REQUIRED"}:
        blockers.append(f"review_decision:{view.get('reviewDecision')}")
    if merge_state in MERGE_BLOCKING_STATES or merge_state in UPDATEABLE_STATES:
        blockers.append(f"merge_state:{merge_state}")
    if mergeable is False or mergeable_state in {"CONFLICTING", "UNKNOWN"}:
        blockers.append(f"mergeable:{mergeable_state or mergeable}")
    if view.get("isCrossRepository") and not view.get("maintainerCanModify"):
        blockers.append("fork_permission:update_branch_unavailable")
    if checks.total == 0 and not allow_no_checks:
        blockers.append("checks:none")
    elif not checks.green:
        if checks.failure:
            blockers.append(f"checks:failure:{checks.failure}")
        if checks.pending:
            blockers.append(f"checks:pending:{checks.pending}")
        if checks.unknown:
            blockers.append(f"checks:unknown:{checks.unknown}")

    ready = not blockers
    status = "ready" if ready else "blocked"
    if view.get("isDraft"):
        status = "draft"
    else:
        non_wait_blockers = [
            blocker for blocker in blockers if not blocker.startswith("checks:pending:")
        ]
        if checks.total > 0 and checks.pending and not non_wait_blockers:
            status = "waiting"

    return {
        "repo": repo,
        "number": number,
        "title": view.get("title"),
        "url": view.get("url"),
        "status": status,
        "ready": ready,
        "blockers": blockers,
        "headRefOid": view.get("headRefOid"),
        "headRefName": view.get("headRefName"),
        "baseRefName": view.get("baseRefName"),
        "mergeStateStatus": view.get("mergeStateStatus"),
        "mergeable": mergeable,
        "reviewDecision": view.get("reviewDecision"),
        "checks": {
            "total": checks.total,
            "success": checks.success,
            "pending": checks.pending,
            "failure": checks.failure,
            "unknown": checks.unknown,
            "names": checks.names[:10],
        },
        "unresolvedReviewThreads": [
            {
                "id": thread.get("id"),
                "path": thread.get("path"),
                "line": thread.get("line"),
                "url": (thread.get("comments", {}).get("nodes") or [{}])[-1].get("url"),
            }
            for thread in unresolved
        ],
    }


def update_branch(repo: str, number: int, *, rebase: bool) -> dict[str, Any]:
    args = ["pr", "update-branch", str(number), "--repo", repo]
    if rebase:
        args.append("--rebase")
    result = run(["gh", *args])
    return {
        "command": " ".join(shlex.quote(part) for part in ["gh", *args]),
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def watch_checks(repo: str, number: int) -> dict[str, Any]:
    args = ["pr", "checks", str(number), "--repo", repo, "--watch"]
    result = run(["gh", *args])
    return {
        "command": " ".join(shlex.quote(part) for part in ["gh", *args]),
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def merge_pr(repo: str, number: int, *, method: str, head_sha: str, delete_branch: bool) -> dict[str, Any]:
    method_flag = {"merge": "--merge", "squash": "--squash", "rebase": "--rebase"}[method]
    args = [
        "pr",
        "merge",
        str(number),
        "--repo",
        repo,
        method_flag,
        "--match-head-commit",
        head_sha,
    ]
    if delete_branch:
        args.append("--delete-branch")
    result = run(["gh", *args])
    return {
        "command": " ".join(shlex.quote(part) for part in ["gh", *args]),
        "method": method,
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def print_human(items: list[dict[str, Any]], *, cycle_number: int | None = None) -> None:
    if cycle_number is not None:
        print(f"cycle: {cycle_number}")
    for item in items:
        label = f"{item['repo']}#{item['number']}"
        print(f"{label}: {item['status']} - {item.get('title')}")
        if item.get("url"):
            print(f"  url: {item['url']}")
        print(f"  head: {str(item.get('headRefOid') or '')[:12] or '-'}")
        if item.get("headBeforeUpdate"):
            print(f"  update head: {str(item['headBeforeUpdate'])[:12]} -> {str(item.get('headRefOid') or '')[:12]}")
        print(f"  review: {item.get('reviewDecision') or '-'}")
        print(f"  merge state: {item.get('mergeStateStatus') or '-'} / mergeable: {item.get('mergeable')}")
        for blocker in item.get("blockers", []):
            print(f"  blocker: {blocker}")
        checks = item.get("checks", {})
        print(
            "  checks: "
            f"success={checks.get('success', 0)} "
            f"pending={checks.get('pending', 0)} "
            f"failure={checks.get('failure', 0)} "
            f"unknown={checks.get('unknown', 0)}"
        )
        if checks.get("names"):
            print(f"  check attention: {', '.join(checks['names'])}")
        unresolved = item.get("unresolvedReviewThreads", [])
        if unresolved:
            print(f"  unresolved review threads: {len(unresolved)}")
            for thread in unresolved[:5]:
                print(f"    - {thread.get('url') or thread.get('id')}")
        if item.get("updateBranch"):
            result = item["updateBranch"]
            print(f"  update branch: rc={result['returncode']}")
            if result.get("stderr"):
                print(f"    stderr: {redact(result['stderr'])}")
        if item.get("watchChecks"):
            result = item["watchChecks"]
            print(f"  watch checks: rc={result['returncode']}")
            if result.get("stderr"):
                print(f"    stderr: {redact(result['stderr'])}")
        if item.get("merge"):
            result = item["merge"]
            print(f"  merge: method={result.get('method')} rc={result['returncode']}")
            if result.get("stderr"):
                print(f"    stderr: {redact(result['stderr'])}")
        if item["status"] == "waiting":
            print("  next: wait for checks")
        elif item["status"] == "blocked":
            print("  next: resolve blockers")
        elif item["status"] == "draft":
            print("  next: skipped because draft")
        print()


def cycle(args: argparse.Namespace) -> list[dict[str, Any]]:
    candidates = list_assigned_prs(args.limit, args.repo)
    results: list[dict[str, Any]] = []
    login = current_login()

    for candidate in candidates:
        repo = repo_full_name(candidate["repository"])
        number = int(candidate["number"])
        if candidate.get("isDraft"):
            results.append(
                {
                    "repo": repo,
                    "number": number,
                    "title": candidate.get("title"),
                    "url": candidate.get("url"),
                    "status": "draft",
                    "ready": False,
                    "blockers": ["draft"],
                    "checks": {"total": 0, "success": 0, "pending": 0, "failure": 0, "unknown": 0, "names": []},
                    "unresolvedReviewThreads": [],
                }
            )
            continue

        item = evaluate_pr(repo, number, allow_no_checks=args.allow_no_checks, login=login)
        results.append(item)

        if item["status"] == "draft" or not args.merge:
            continue

        pre_update_blockers = [
            blocker for blocker in item["blockers"] if blocker != "merge_state:BEHIND"
        ]
        if pre_update_blockers:
            continue

        item["headBeforeUpdate"] = item.get("headRefOid")
        update_result = update_branch(repo, number, rebase=args.rebase_update)
        item["updateBranch"] = update_result
        if not update_succeeded(update_result):
            item["status"] = "blocked"
            item.setdefault("blockers", []).append("update_branch_failed")
            continue

        post_update_view = pr_view(repo, number)
        post_update_head = post_update_view.get("headRefOid")
        if post_update_view.get("isDraft"):
            item.update(
                {
                    "status": "draft",
                    "ready": False,
                    "blockers": ["draft"],
                    "headRefOid": post_update_head,
                    "mergeStateStatus": post_update_view.get("mergeStateStatus"),
                    "mergeable": post_update_view.get("mergeable"),
                    "reviewDecision": post_update_view.get("reviewDecision"),
                }
            )
            continue

        if post_update_head and post_update_head != item.get("headBeforeUpdate"):
            item["watchChecks"] = watch_checks(repo, number)

        item_after_update = evaluate_pr(repo, number, allow_no_checks=args.allow_no_checks, login=login)
        item_after_update["headBeforeUpdate"] = item.get("headBeforeUpdate")
        if item.get("watchChecks"):
            item_after_update["watchChecks"] = item["watchChecks"]
        item.update(item_after_update)
        item["updateBranch"] = update_result
        if item.get("watchChecks", {}).get("returncode", 0) != 0:
            item["ready"] = False
            item["status"] = "waiting" if any(blocker.startswith("checks:pending:") for blocker in item["blockers"]) else "blocked"
            item.setdefault("blockers", []).append("watch_checks_failed")

        if not item["ready"]:
            continue

        merge_result = merge_pr(
            repo,
            number,
            method=args.merge_method,
            head_sha=item["headRefOid"],
            delete_branch=args.delete_branch,
        )
        item["merge"] = merge_result
        item["status"] = "merged" if merge_result["returncode"] == 0 else "blocked"
        if merge_result["returncode"] != 0:
            item.setdefault("blockers", []).append("merge_failed")

    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", help="Limit to a single OWNER/REPO repository.")
    parser.add_argument("--limit", type=int, default=50, help="Maximum PRs to fetch.")
    parser.add_argument("--once", action="store_true", help="Run one scan and exit.")
    parser.add_argument("--watch", action="store_true", help="Repeat until no open non-draft PRs remain ready/waiting.")
    parser.add_argument("--interval", type=int, default=60, help="Seconds between watch cycles.")
    parser.add_argument("--max-cycles", type=int, default=0, help="0 means unlimited.")
    parser.add_argument("--merge", action="store_true", help="Allow update-branch and merge for eligible non-draft PRs.")
    parser.add_argument("--merge-method", choices=["merge", "squash", "rebase"], default="squash")
    parser.add_argument("--delete-branch", action="store_true", help="Delete the local and remote branch after merge.")
    parser.add_argument("--rebase-update", action="store_true", help="Use gh pr update-branch --rebase.")
    parser.add_argument("--allow-no-checks", action="store_true", help="Allow PRs with no reported checks.")
    parser.add_argument("--json", action="store_true", help="Print JSON instead of a human summary.")
    args = parser.parse_args()
    if not args.once and not args.watch:
        args.once = True
    return args


def main() -> int:
    args = parse_args()
    cycles = 0
    while True:
        cycles += 1
        try:
            results = cycle(args)
        except Exception as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1

        if args.json:
            print(json.dumps({"cycle": cycles, "results": results}, ensure_ascii=False, indent=2))
        else:
            print_human(results, cycle_number=cycles)

        if args.once:
            return 0
        if args.max_cycles and cycles >= args.max_cycles:
            return 0

        active = [item for item in results if item["status"] in {"ready", "waiting"}]
        if not active:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
