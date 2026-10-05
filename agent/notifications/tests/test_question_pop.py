import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("question_pop", ROOT / "question-pop.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class QuestionPopTests(unittest.TestCase):
    def test_only_questions_and_approval_requests_qualify(self):
        question = {"hook_event_name": "PreToolUse", "tool_use_id": "q1", "tool_name": "request_user_input", "tool_input": {"questions": [{"question": "Which?"}]}}
        async_question = {"hook_event_name": "PreToolUse", "tool_name": "request_user_input_async", "tool_input": {"questions": [{"title": "Pick?"}]}}
        approval = {"hook_event_name": "PermissionRequest", "tool_name": "Bash", "tool_input": {"command": "rm x"}}
        self.assertTrue(helper.qualifies("pretool", question))
        self.assertTrue(helper.qualifies("pretool", async_question))
        self.assertTrue(helper.qualifies("permission", approval))
        self.assertFalse(helper.qualifies("pretool", {**question, "tool_name": "Bash"}))
        self.assertFalse(helper.qualifies("pretool", {**question, "tool_name": "Stop"}))
        self.assertFalse(helper.qualifies("pretool", {**question, "tool_input": {"questions": [{"question": " "}]}}))
        self.assertFalse(helper.qualifies("pretool", {**question, "agent_id": "child"}))
        self.assertFalse(helper.qualifies("pretool", None))
        self.assertFalse(helper.qualifies("stop", question))

    def test_mocked_playback_dedup_malformed_and_quiet(self):
        question = json.dumps({"hook_event_name": "PreToolUse", "session_id": "s1", "tool_use_id": "q1", "tool_name": "request_user_input", "tool_input": {"questions": [{"question": "Select"}]}}).encode()
        with tempfile.TemporaryDirectory() as temp:
            env = {"QUESTION_POP_STATE": str(Path(temp) / "state")}
            import io
            from types import SimpleNamespace
            with patch.dict(os.environ, env, clear=True), patch.object(helper.sys, "argv", ["hook", "pretool"]), patch.object(helper.subprocess, "run") as play:
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(question))
                with patch.object(helper.time, "time", return_value=100): helper.main()
                self.assertEqual(play.call_count, 1)
                self.assertEqual(play.call_args.args[0], ["/usr/bin/afplay", helper.SOUND])
                child = json.dumps({"hook_event_name": "PreToolUse", "session_id": "s1", "tool_use_id": "child", "agent_id": "a1", "tool_name": "request_user_input", "tool_input": {"questions": [{"question": "Child?"}]}}).encode()
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(child))
                with patch.object(helper.time, "time", return_value=100.1): helper.main()
                self.assertEqual(play.call_count, 1)
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(question))
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(question))
                with patch.object(helper.time, "time", return_value=100.5): helper.main()
                self.assertEqual(play.call_count, 1)
                helper.sys.argv = ["hook", "permission"]
                approval = json.dumps({"hook_event_name": "PermissionRequest", "session_id": "s1", "tool_use_id": "p1", "tool_name": "Bash", "tool_input": {"command": "rm x"}}).encode()
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(approval))
                with patch.object(helper.time, "time", return_value=103): helper.main()
                self.assertEqual(play.call_count, 2)
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(approval))
                with patch.object(helper.time, "time", return_value=104): helper.main()
                self.assertEqual(play.call_count, 2)
                helper.sys.argv = ["hook", "pretool"]
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(b"not json"))
                with patch.object(helper.time, "time", return_value=103): helper.main()
                self.assertEqual(play.call_count, 2)
                os.environ["AGENT_QUESTION_SOUND"] = "off"
                helper.sys.stdin = SimpleNamespace(buffer=io.BytesIO(question))
                with patch.object(helper.time, "time", return_value=106): helper.main()
                self.assertEqual(play.call_count, 2)

    def test_installer_idempotent_preserves_existing_hooks(self):
        install_spec = importlib.util.spec_from_file_location("installer", ROOT / "install.py")
        installer = importlib.util.module_from_spec(install_spec)
        install_spec.loader.exec_module(installer)
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            hooks = home / ".codex/hooks.json"
            hooks.parent.mkdir()
            original = {"hooks": {"Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "existing"}]}]}}
            hooks.write_text(json.dumps(original))
            installer.install(home)
            first = hooks.read_bytes()
            installed = json.loads(first)
            self.assertEqual(installed["hooks"]["Stop"], original["hooks"]["Stop"])
            self.assertEqual(len(installed["hooks"]["PreToolUse"]), 1)
            self.assertEqual(len(installed["hooks"]["PermissionRequest"]), 1)
            backups = list((home / ".local/state/dotfiles/backups").iterdir())
            self.assertTrue(any(path.name.startswith("hooks.json.") for path in backups))
            installer.install(home)
            self.assertEqual(hooks.read_bytes(), first)
            self.assertTrue((home / ".pi/agent/extensions/pi-question-pop.ts").is_symlink())


if __name__ == "__main__":
    unittest.main()
