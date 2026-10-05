import contextlib
import io
import json
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch

import notify_result as notifier


class NotifyResultTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.state_dir = Path(self.temp.name) / "state"
        self.args = [
            "--task-id", "request-123",
            "--title", "Done", "--message", "Finished",
            "--state-dir", str(self.state_dir),
        ]

    def tearDown(self):
        self.temp.cleanup()

    def invoke(self, extra=()):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = notifier.main(self.args + list(extra))
        return status, json.loads(output.getvalue())

    def test_silent_default_and_worker_suppress_without_state(self):
        status, result = self.invoke()
        self.assertEqual((status, result["status"], result["reason"]), (0, "suppressed", "no_explicit_request"))
        status, result = self.invoke(["--request", "result", "--role", "worker"])
        self.assertEqual((status, result["status"], result["reason"]), (0, "suppressed", "worker"))
        self.assertFalse(self.state_dir.exists())

    def test_submission_then_duplicate_suppression(self):
        with patch.object(notifier, "backend", return_value=["fake"]), patch.object(notifier, "notify") as notify:
            self.assertEqual(self.invoke(["--request", "result"])[1]["status"], "submitted")
            status, result = self.invoke(["--request", "result"])
        self.assertEqual(status, 0)
        self.assertEqual((result["status"], result["reason"], result["previous_status"]),
                         ("suppressed", "duplicate", "submitted"))
        notify.assert_called_once_with(["fake"], "Done", "Finished")
        files = list(self.state_dir.iterdir())
        self.assertTrue(files)
        self.assertTrue(all("Done" not in path.name and "Finished" not in path.name for path in files))
        state = json.loads(next(self.state_dir.glob("*.json")).read_text())
        self.assertEqual(set(state), {"task_id", "task_hash", "status", "time"})

    def test_dry_run_leaves_no_state(self):
        status, result = self.invoke(["--request", "result", "--dry-run"])
        self.assertEqual((status, result["status"]), (0, "dry_run"))
        self.assertFalse(self.state_dir.exists())

    def test_notification_text_is_literal_argv(self):
        title = '-e quote " ; $(touch nope)\nline'
        message = "it's * & |\nsecond line"
        command = ["/fake/osascript", "-e", notifier.APPLESCRIPT]
        with patch.object(notifier.platform, "system", return_value="Darwin"), \
             patch.object(notifier.shutil, "which", return_value=command[0]), \
             patch.object(notifier.subprocess, "run") as run:
            notifier.notify(command, title, message)
        run.assert_called_once_with(command + ["--", title, message], check=True, timeout=10)

        with patch.object(notifier.subprocess, "run") as run:
            notifier.notify(["/fake/notify-send"], "--urgency=critical", message)
        run.assert_called_once_with(
            ["/fake/notify-send", "--", "--urgency=critical", message], check=True, timeout=10
        )

    def test_backend_failure_is_error_and_is_not_retried(self):
        with patch.object(notifier, "backend", return_value=["fake"]), \
             patch.object(notifier, "notify", side_effect=notifier.subprocess.CalledProcessError(1, ["fake"])) as notify:
            status, result = self.invoke(["--request", "result"])
            self.assertEqual((status, result["status"]), (1, "error"))
            status, result = self.invoke(["--request", "result"])
        self.assertEqual((status, result["status"], result["previous_status"]), (0, "suppressed", "error"))
        notify.assert_called_once()

    def test_unsupported_backend_does_not_mark_submitted(self):
        with patch.object(notifier, "backend", side_effect=RuntimeError("unsupported")):
            status, result = self.invoke(["--request", "result"])
        self.assertEqual((status, result["status"]), (1, "error"))
        self.assertFalse(self.state_dir.exists())

    def test_concurrent_invocations_submit_once(self):
        lock = threading.Lock()
        submitted = []
        emitted = []

        def fake_notify(*args):
            with lock:
                submitted.append(args)

        def fake_emit(status, **extra):
            with lock:
                emitted.append(status)

        def invoke():
            return notifier.main(self.args + ["--request", "result"])

        with patch.object(notifier, "backend", return_value=["fake"]), \
             patch.object(notifier, "notify", side_effect=fake_notify), \
             patch.object(notifier, "emit", side_effect=fake_emit):
            with ThreadPoolExecutor(max_workers=8) as pool:
                statuses = list(pool.map(lambda _: invoke(), range(8)))
        self.assertEqual(statuses, [0] * 8)
        self.assertEqual(len(submitted), 1)
        self.assertEqual(emitted.count("submitted"), 1)
        self.assertEqual(emitted.count("suppressed"), 7)


if __name__ == "__main__":
    unittest.main()
