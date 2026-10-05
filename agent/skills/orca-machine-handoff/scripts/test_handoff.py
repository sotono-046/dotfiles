#!/usr/bin/env python3
"""Offline regression checks for sensitive paths introduced by merge commits."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


SCRIPT = Path(__file__).with_name("handoff.py")


class MergeHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="handoff-merge-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.commit_file("base.txt", "base")
        self.base = self.git("rev-parse", "HEAD")
        self.git("checkout", "-b", "side")
        self.commit_file("side.txt", "side")
        self.git("checkout", "main")
        self.commit_file("main.txt", "main")
        self.git("merge", "--no-commit", "--no-ff", "side")
        self.note = self.root / "note.md"
        self.note.write_text("Offline test packet", encoding="utf-8")
        self.packet = self.root / "packet.zip"

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.repo), *args], check=True,
            capture_output=True, text=True,
        ).stdout.strip()

    def commit_file(self, name, content):
        (self.repo / name).write_text(content, encoding="utf-8")
        self.git("add", "--", name)
        self.git("commit", "-m", "test commit")

    def pack(self):
        return subprocess.run(
            [sys.executable, str(SCRIPT), "pack", "--repo", str(self.repo),
             "--base-ref", self.base, "--note", str(self.note),
             "--out", str(self.packet)],
            capture_output=True, text=True,
        )

    def test_merge_only_sensitive_path_is_rejected(self):
        self.commit_file(".env", "DUMMY_TEST_VALUE=example\n")
        result = self.pack()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sensitive paths need separate handling", result.stderr)
        self.assertFalse(self.packet.exists())

    def test_removed_merge_only_sensitive_path_is_rejected(self):
        self.commit_file("credentials.json", '{"dummy": true}')
        self.git("rm", "credentials.json")
        self.git("commit", "-m", "remove dummy path")
        result = self.pack()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("credentials.json", result.stderr)
        self.assertFalse(self.packet.exists())

    def test_benign_merge_can_be_packed(self):
        self.commit_file("resolution.txt", "safe merge addition")
        result = self.pack()
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(self.packet) as packet:
            manifest = json.loads(packet.read("manifest.json"))
        self.assertIn("resolution.txt", manifest["historyPaths"])


if __name__ == "__main__":
    unittest.main()
