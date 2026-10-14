import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("create-pair.zsh")
STUB_HERDR = r'''#!/usr/bin/env python3
import json
import os
import sys

args = sys.argv[1:]
with open(os.environ["STUB_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")

if args[:2] == ["tab", "create"]:
    if os.environ.get("STUB_BAD_TAB") == "1":
        print('{"result": {"tab": {"tab_id": "tab-123"}}}')
    else:
        print(json.dumps({"result": {"tab": {"tab_id": "tab-123"}, "root_pane": {"pane_id": "pane-left-456"}}}))
elif args[:2] == ["pane", "split"]:
    if os.environ.get("STUB_SPLIT_FAIL") == "1":
        print('{"error":"split failed"}')
        sys.exit(9)
    print(json.dumps({"result": {"pane": {"pane_id": "pane-right-789"}}}))
elif args[:2] == ["pane", "rename"]:
    print(json.dumps({"result": {"pane": {"pane_id": args[2]}}}))
else:
    print("unexpected command", file=sys.stderr)
    sys.exit(64)
'''


class CreatePairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        stub = self.bin_dir / "herdr"
        stub.write_text(STUB_HERDR, encoding="utf-8")
        stub.chmod(0o755)
        self.cwd = self.root / "project with spaces"
        self.cwd.mkdir()
        self.record_dir = self.root / "record with spaces"
        self.log = self.root / "herdr-calls.jsonl"

    def tearDown(self):
        self.temp.cleanup()

    def args(self, *extra):
        return [
            "--workspace", "workspace 42",
            "--cwd", str(self.cwd),
            "--label", "work tab",
            "--left", "work chief",
            "--right", "executor pane",
            "--record-dir", str(self.record_dir),
            *extra,
        ]

    def run_script(self, *args, **env_overrides):
        env = os.environ.copy()
        env.update({
            "PATH": f"{self.bin_dir}:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "STUB_LOG": str(self.log),
        })
        env.pop("HERDR_ENV", None)
        env.pop("HERDR_WORKSPACE_ID", None)
        for key, value in env_overrides.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        return subprocess.run(
            ["/bin/zsh", str(SCRIPT), *args],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]

    def test_actual_run_preserves_arguments_and_records_ready_layout(self):
        result = self.run_script(*self.args(), HERDR_ENV="1", HERDR_WORKSPACE_ID="workspace 42")

        self.assertEqual(result.returncode, 0, result.stderr)
        expected = {
            "workspace_id": "workspace 42",
            "cwd": str(self.cwd),
            "tab_id": "tab-123",
            "left_pane_id": "pane-left-456",
            "right_pane_id": "pane-right-789",
            "label": "work tab",
            "left_label": "work chief",
            "right_label": "executor pane",
            "stage": "ready",
        }
        self.assertEqual(json.loads(result.stdout), expected)
        self.assertEqual(json.loads((self.record_dir / "layout.json").read_text()), expected)
        self.assertEqual(
            self.calls(),
            [
                ["tab", "create", "--workspace", "workspace 42", "--cwd", str(self.cwd), "--label", "work tab", "--no-focus"],
                ["pane", "split", "pane-left-456", "--direction", "right", "--cwd", str(self.cwd), "--no-focus"],
                ["pane", "rename", "pane-left-456", "work chief"],
                ["pane", "rename", "pane-right-789", "executor pane"],
            ],
        )
        for receipt in ("tab.json", "split.json", "rename-left.json", "rename-right.json"):
            self.assertTrue((self.record_dir / receipt).is_file(), receipt)

    def test_rejects_outside_herdr_context_before_mutation(self):
        result = self.run_script(*self.args())

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing Herdr mutation", result.stderr)
        self.assertFalse(self.record_dir.exists())
        self.assertEqual(self.calls(), [])

    def test_dry_run_prints_quoted_plan_without_mutation(self):
        result = self.run_script(*self.args(), "--dry-run")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(r"workspace\ 42", result.stdout)
        self.assertIn(r"project\ with\ spaces", result.stdout)
        self.assertIn(r"work\ chief", result.stdout)
        self.assertFalse(self.record_dir.exists())
        self.assertEqual(self.calls(), [])

    def test_split_failure_keeps_created_tab_and_nonready_layout(self):
        result = self.run_script(
            *self.args(), HERDR_ENV="1", HERDR_WORKSPACE_ID="workspace 42", STUB_SPLIT_FAIL="1"
        )

        self.assertNotEqual(result.returncode, 0)
        layout = json.loads((self.record_dir / "layout.json").read_text())
        self.assertEqual(layout["tab_id"], "tab-123")
        self.assertEqual(layout["left_pane_id"], "pane-left-456")
        self.assertIsNone(layout["right_pane_id"])
        self.assertEqual(layout["stage"], "tab_created")
        self.assertTrue((self.record_dir / "tab.json").is_file())
        self.assertTrue((self.record_dir / "split.json").is_file())
        self.assertEqual(len(self.calls()), 2)

    def test_malformed_tab_receipt_is_kept_and_split_is_not_attempted(self):
        result = self.run_script(
            *self.args(), HERDR_ENV="1", HERDR_WORKSPACE_ID="workspace 42", STUB_BAD_TAB="1"
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.record_dir / "tab.json").is_file())
        self.assertFalse((self.record_dir / "layout.json").exists())
        self.assertEqual(len(self.calls()), 1)

    def test_existing_record_directory_is_never_overwritten(self):
        self.record_dir.mkdir()
        sentinel = self.record_dir / "keep.txt"
        sentinel.write_text("user data", encoding="utf-8")

        result = self.run_script(*self.args(), HERDR_ENV="1", HERDR_WORKSPACE_ID="workspace 42")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "user data")
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
