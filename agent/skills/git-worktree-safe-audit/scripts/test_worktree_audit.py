#!/usr/bin/env python3
"""Temp-repository tests for worktree_audit.py."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).with_name("worktree_audit.py")
STATUS_PATH_CAP = 512
STATUS_BYTE_CAP = 64 * 1024


def command(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )


class WorktreeAuditTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory(prefix="worktree-audit-test-")
        self.root = Path(self.temporary_directory.name)
        self.origin = self.root / "origin.git"
        self.main = self.root / "main"
        command("git", "init", "--bare", "-q", str(self.origin))
        command("git", "symbolic-ref", "HEAD", "refs/heads/main", cwd=self.origin)
        command("git", "clone", "-q", str(self.origin), str(self.main))
        command("git", "config", "user.name", "Audit-Test", cwd=self.main)
        command("git", "config", "user.email", "audit@example.invalid", cwd=self.main)
        (self.main / "tracked.txt").write_text("initial\n")
        command("git", "add", "tracked.txt", cwd=self.main)
        command("git", "commit", "-q", "-m", "initial", cwd=self.main)
        command("git", "push", "-q", "-u", "origin", "main", cwd=self.main)
        command("git", "remote", "set-head", "origin", "-a", cwd=self.main)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def add_worktree(self, branch: str) -> Path:
        path = self.root / branch
        command("git", "worktree", "add", "-q", "-b", branch, str(path), "main", cwd=self.main)
        return path

    def make_old(self, worktree: Path, days: int) -> None:
        gitfile = worktree / ".git"
        gitdir = Path(gitfile.read_text().strip().removeprefix("gitdir: "))
        timestamp = time.time() - days * 86400
        for relative in ("HEAD", "index", "logs/HEAD"):
            path = gitdir / relative
            if path.exists():
                os.utime(path, (timestamp, timestamp))
        os.utime(worktree, (timestamp, timestamp))

    def audit(self, repository: Path, *, cwd: Path | None = None) -> dict[str, object]:
        result = command(
            str(SCRIPT),
            "--repository",
            str(repository),
            "--compact",
            cwd=cwd,
        )
        return json.loads(result.stdout)

    @staticmethod
    def by_branch(report: dict[str, object], branch: str) -> dict[str, object]:
        worktrees = report["worktrees"]
        assert isinstance(worktrees, list)
        return next(
            entry
            for entry in worktrees
            if isinstance(entry, dict) and entry.get("branch") == f"refs/heads/{branch}"
        )

    def test_age_commit_active_and_recent_dirty_guards(self) -> None:
        clean_five = self.add_worktree("clean-five")
        (clean_five / "node_modules").mkdir()
        self.make_old(clean_five, 5)

        clean_eight = self.add_worktree("clean-eight")
        self.make_old(clean_eight, 8)

        feature = self.add_worktree("feature")
        command("git", "config", "user.name", "Audit-Test", cwd=feature)
        command("git", "config", "user.email", "audit@example.invalid", cwd=feature)
        command("git", "commit", "--allow-empty", "-q", "-m", "feature", cwd=feature)

        old_dirty = self.add_worktree("old-dirty")
        self.make_old(old_dirty, 8)
        (old_dirty / "tracked.txt").write_text("recent dirty edit\n")

        report = self.audit(self.main)
        self.assertEqual(
            self.by_branch(report, "clean-five")["decision"]["action"],
            "regenerable-cleanup-candidate",
        )
        self.assertEqual(
            self.by_branch(report, "clean-eight")["decision"]["action"],
            "worktree-removal-candidate",
        )
        self.assertIn(
            "unmerged-from-origin-head",
            self.by_branch(report, "feature")["decision"]["reasons"],
        )
        dirty_entry = self.by_branch(report, "old-dirty")
        self.assertEqual(dirty_entry["decision"]["action"], "no-op-recent")
        self.assertEqual(dirty_entry["content_state"]["tracked_changes"], 1)
        self.assertLess(dirty_entry["activity"]["age_days"], 3)

        active_report = self.audit(Path("."), cwd=clean_five)
        active_entry = self.by_branch(active_report, "clean-five")
        self.assertTrue(active_entry["active_cwd"])
        self.assertEqual(active_entry["decision"]["action"], "protected-active-cwd")

    def test_status_path_cap_blocks_cleanup(self) -> None:
        capped = self.add_worktree("capped")
        for index in range(STATUS_PATH_CAP + 1):
            (capped / f"untracked-{index:04d}.txt").write_text("x\n")
        self.make_old(capped, 8)

        report = self.audit(self.main)
        entry = self.by_branch(report, "capped")
        status_scan = entry["content_state"]["status_scan"]
        self.assertEqual(status_scan["path_entry_cap"], STATUS_PATH_CAP)
        self.assertTrue(status_scan["path_cap_reached"])
        self.assertFalse(status_scan["complete"])
        self.assertEqual(
            entry["decision"]["action"],
            "protected-activity-evidence-incomplete",
        )

    def test_status_output_byte_cap_blocks_cleanup(self) -> None:
        capped = self.add_worktree("byte-capped")
        for index in range(300):
            name = f"untracked-{index:04d}-{'x' * 220}.txt"
            (capped / name).write_text("x\n")
        self.make_old(capped, 8)

        report = self.audit(self.main)
        entry = self.by_branch(report, "byte-capped")
        status_scan = entry["content_state"]["status_scan"]
        self.assertEqual(status_scan["output_byte_cap"], STATUS_BYTE_CAP)
        self.assertTrue(status_scan["byte_truncated"])
        self.assertFalse(status_scan["complete"])
        self.assertEqual(
            entry["decision"]["action"],
            "protected-activity-evidence-incomplete",
        )


if __name__ == "__main__":
    unittest.main()
