import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class RequiredSkillsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="required-skills-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.repo = self.root / "repo"
        (self.repo / "agent/hooks").mkdir(parents=True)
        self.script = self.repo / "agent/hooks/required-skills.py"
        for name in ("required-skills.py", "required-skills.ts"):
            shutil.copy2(REPO / "agent/hooks" / name, self.script.with_name(name))
        (self.repo / "agent/AGENTS.md").write_text("# 必須スキル\n- alpha\n- beta\n\n## Other\n- ignored\n")
        self.alpha = self.write_skill("alpha", "先頭\r\n" + "日本語😀" * 4000 + "\r\nALPHA-TAIL")
        self.beta = self.write_skill("beta", "一行" * 6000 + "BETA-TAIL\n")
        self.env = os.environ.copy()
        for key in ("CODEX_HOME", "CLAUDE_CONFIG_DIR", "PI_CODING_AGENT_DIR"):
            self.env.pop(key, None)

    def write_skill(self, name, text, root=".agents/skills"):
        path = self.home / root / name / "SKILL.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode("utf-8"))
        return path

    def require_pstack(self):
        (self.repo / "agent/AGENTS.md").write_text("# 必須スキル\n- alpha\n- pstack:poteto-mode\n")
        self.write_skill("poteto-mode", "LOOSE-MUST-NOT-LOAD")

    def write_plugin(self, client, version="1.0.0", text="OFFICIAL-FULL-TAIL", runtime=None):
        runtime = runtime or self.home / f".{client}"
        installation = runtime / "plugins/cache/cursor-plugins/pstack" / version
        manifest = installation / ".claude-plugin/plugin.json"
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(json.dumps({"name": "pstack"}))
        skill = installation / "skills/poteto-mode/SKILL.md"
        skill.parent.mkdir(parents=True, exist_ok=True)
        skill.write_text(text)
        if client == "codex":
            (runtime / "config.toml").write_text('[plugins."pstack@cursor-plugins"]\nenabled = true\n')
        else:
            (runtime / "settings.json").write_text(json.dumps({"enabledPlugins": {"pstack@cursor-plugins": True}}))
            self.write_registry(runtime, [{"scope": "user", "installPath": str(installation)}])
        return skill

    def write_registry(self, runtime, records):
        path = runtime / "plugins/installed_plugins.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"version": 2, "plugins": {"pstack@cursor-plugins": records}}))

    def assert_plugin_failure(self, client, pattern=None):
        result = self.run_cli("bundle", "--client", client, success=False)
        if pattern:
            self.assertRegex(result.stderr, pattern)
        self.assertEqual(result.stdout, "")
        value = self.output(client, "PreToolUse")
        self.assertEqual(value["hookSpecificOutput"]["permissionDecision"], "deny")
        self.assertNotIn("additionalContext", str(value))

    def run_cli(self, *args, payload=None, success=True):
        result = subprocess.run(
            [sys.executable, str(self.script), *args, "--home", str(self.home)],
            input=json.dumps(payload) if payload is not None else None,
            env=self.env, text=True, capture_output=True, timeout=20,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def output(self, client, event, slot=0, **fields):
        payload = {"hook_event_name": event, "session_id": "session", **fields}
        return json.loads(self.run_cli("hook", "--client", client, "--slot", str(slot), payload=payload).stdout)

    def contexts(self, event, **fields):
        return [self.output("claude", event, i, **fields).get("hookSpecificOutput", {}).get("additionalContext", "") for i in range(16)]

    def test_full_text_all_lifecycle_events_and_independent_subagents(self):
        expected = json.loads(self.run_cli("bundle", "--client", "codex").stdout)["text"]
        for source in ("startup", "resume", "clear", "compact", "fork"):
            value = self.output("codex", "SessionStart", source=source)
            self.assertEqual(value["hookSpecificOutput"]["additionalContext"], expected)
        for event, fields in (("UserPromptSubmit", {}), ("SubagentStart", {"agent_id": "child-1"}), ("SubagentStart", {"agent_id": "child-2"})):
            parts = [part for part in self.contexts(event, **fields) if part]
            self.assertGreater(len(parts), 1)
            self.assertTrue(all(len(p.encode("utf-16-le")) // 2 <= 8000 for p in parts))
            self.assertEqual("".join(p.split("\n", 1)[1] for p in parts), expected)
        self.assertIn(self.alpha.read_bytes().decode(), expected)
        self.assertIn(self.beta.read_bytes().decode(), expected)
        self.assertIn("ALPHA-TAIL", expected)
        self.assertIn("BETA-TAIL", expected)

    def test_changed_skills_deny_once_then_allow_retry_per_actor_and_slot(self):
        self.contexts("UserPromptSubmit")
        for i in range(16):
            self.assertEqual(self.output("claude", "PreToolUse", i), {})
        self.alpha.write_text("UPDATED日本語😀TAIL")
        parts = []
        for i in range(16):
            value = self.output("claude", "PreToolUse", i)["hookSpecificOutput"]
            self.assertEqual(value["permissionDecision"], "deny")
            parts.append(value.get("additionalContext", ""))
            self.assertEqual(self.output("claude", "PreToolUse", i), {})
        self.assertIn("UPDATED日本語😀TAIL", "".join(parts))
        child = self.output("claude", "PreToolUse", agent_id="new-child")
        self.assertEqual(child["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_directory_switch_reloads_and_malformed_registry_blocks(self):
        self.output("codex", "UserPromptSubmit", cwd=str(self.root / "first"))
        self.assertEqual(self.output("codex", "PreToolUse", cwd=str(self.root / "first")), {})
        moved = self.output("codex", "PreToolUse", cwd=str(self.root / "second"))
        self.assertEqual(moved["hookSpecificOutput"]["permissionDecision"], "deny")
        (self.repo / "agent/AGENTS.md").write_text("# 必須スキル\n- alpha\n- ../invalid\n")
        self.assertEqual(self.output("codex", "UserPromptSubmit")["decision"], "block")

    def test_git_boundary_includes_git_ops_and_allows_exact_retry(self):
        self.write_skill("git-ops", "GIT-OPS-FULL-TAIL")
        for command in ("git commit -m test", "git -C /tmp push", "gh pr create", "gh pr merge 123"):
            self.output("codex", "UserPromptSubmit")
            value = self.output("codex", "PreToolUse", tool_input={"command": command})["hookSpecificOutput"]
            self.assertEqual(value["permissionDecision"], "deny")
            self.assertIn("GIT-OPS-FULL-TAIL", value["additionalContext"])
            self.assertEqual(self.output("codex", "PreToolUse", tool_input={"command": command}), {})

    def test_git_delivery_survives_skill_reads_and_command_changes(self):
        self.write_skill("git-ops", "GIT-OPS-FULL-TAIL")
        for client in ("codex", "claude"):
            with self.subTest(client=client):
                slots = range(16) if client == "claude" else range(1)
                for slot in slots:
                    self.output(client, "UserPromptSubmit", slot)
                    value = self.output(client, "PreToolUse", slot, tool_input={"command": "gh pr create"})
                    self.assertEqual(value["hookSpecificOutput"]["permissionDecision"], "deny")
                    self.output(client, "PreToolUse", slot, tool_name="Read", tool_input={"file_path": str(self.alpha)})
                    self.output(client, "PreToolUse", slot, tool_input={"command": "cat /skills/git-ops/SKILL.md"})
                    for command in ("gh pr create", "gh pr create --body-file /tmp/body.md", "git push", "gh pr create"):
                        retry = self.output(client, "PreToolUse", slot, tool_input={"command": command})
                        self.assertEqual(retry.get("hookSpecificOutput", {}).get("permissionDecision"), None, f"{client} slot {slot}: retry denied after skill reads")

    def test_git_delivery_is_invalidated_by_content_request_and_scope(self):
        self.alpha.write_text("ALPHA")
        self.beta.write_text("BETA")
        skill = self.write_skill("git-ops", "GIT-OPS-V1")
        command = {"command": "gh pr create"}
        for client in ("codex", "claude"):
            with self.subTest(client=client):
                skill.write_text("GIT-OPS-V1")
                self.output(client, "UserPromptSubmit")
                self.output(client, "PreToolUse", tool_input=command)
                self.assertEqual(self.output(client, "PreToolUse", tool_input=command), {})
                skill.write_text("GIT-OPS-V2")
                changed = self.output(client, "PreToolUse", tool_input=command)["hookSpecificOutput"]
                self.assertEqual(changed["permissionDecision"], "deny")
                self.assertIn("GIT-OPS-V2", changed["additionalContext"])
                self.assertEqual(self.output(client, "PreToolUse", tool_input=command), {})
                self.output(client, "UserPromptSubmit")
                self.assertEqual(self.output(client, "PreToolUse", tool_input=command)["hookSpecificOutput"]["permissionDecision"], "deny")
                for fields in ({"agent_id": "child"}, {"session_id": "other"}, {"cwd": str(self.root / "other")}):
                    value = self.output(client, "PreToolUse", tool_input=command, **fields)
                    self.assertEqual(value["hookSpecificOutput"]["permissionDecision"], "deny")
                skill.unlink()
                missing = self.output(client, "PreToolUse", tool_input=command)["hookSpecificOutput"]
                self.assertEqual(missing["permissionDecision"], "deny")
                self.assertNotIn("additionalContext", missing)
                self.write_skill("git-ops", "GIT-OPS-V1")

    def test_missing_empty_and_over_capacity_never_emit_partial_success(self):
        for contents in (None, "", "😀" * 65000, "x" * 127000):
            if contents is None:
                self.alpha.unlink()
            else:
                self.alpha.write_text(contents)
            for client in ("claude", "codex"):
                for event in ("UserPromptSubmit", "PreToolUse", "Stop"):
                    value = self.output(client, event)
                    if event == "PreToolUse":
                        self.assertEqual(value["hookSpecificOutput"]["permissionDecision"], "deny")
                    else:
                        self.assertEqual(value["decision"], "block")
                    self.assertNotIn("additionalContext", str(value))
        self.alpha.write_text("x" * 115000)
        self.beta.write_text("x" * 11500)
        self.assertEqual(self.output("claude", "UserPromptSubmit")["decision"], "block")

    def test_runtime_root_precedence_and_repo_registry(self):
        self.write_skill("alpha", "RUNTIME-ALPHA", ".codex/skills")
        (self.home / "AGENTS.md").write_text("# 必須スキル\n- malicious\n")
        value = self.output("codex", "UserPromptSubmit")["hookSpecificOutput"]["additionalContext"]
        self.assertIn("RUNTIME-ALPHA", value)
        self.assertNotIn("ALPHA-TAIL", value)
        self.assertNotIn("malicious", value)

    def test_official_plugins_load_full_text_and_environment_roots(self):
        self.require_pstack()
        for client, variable in (("codex", "CODEX_HOME"), ("claude", "CLAUDE_CONFIG_DIR")):
            with self.subTest(client=client):
                self.write_plugin(client, text="DEFAULT-MUST-NOT-LOAD")
                runtime = self.root / f"custom {client}"
                full = "公式日本語😀\n" * 3000 + "OFFICIAL-TAIL"
                skill = self.write_plugin(client, text=full, runtime=runtime)
                self.env[variable] = str(runtime)
                bundle = json.loads(self.run_cli("bundle", "--client", client).stdout)
                self.assertIn(full, bundle["text"])
                self.assertIn(str(skill.resolve()), bundle["text"])
                self.assertIn("[skill pstack:poteto-mode ", bundle["text"])
                self.assertNotIn("LOOSE-MUST-NOT-LOAD", bundle["text"])
                self.assertNotIn("DEFAULT-MUST-NOT-LOAD", bundle["text"])
                del self.env[variable]

    def test_plugin_metadata_failures_never_fall_back(self):
        self.require_pstack()
        cases = ("missing-config", "disabled", "nonboolean", "malformed-config", "missing-manifest", "malformed-manifest", "wrong-identity", "missing-skill", "empty-skill", "escaping-manifest", "escaping-skill")
        for client in ("codex", "claude"):
            for case in cases:
                with self.subTest(client=client, case=case):
                    runtime = self.home / f".{client}"
                    if runtime.exists():
                        shutil.rmtree(runtime)
                    skill = self.write_plugin(client)
                    manifest = skill.parents[2] / ".claude-plugin/plugin.json"
                    config = runtime / ("config.toml" if client == "codex" else "settings.json")
                    if case == "missing-config":
                        config.unlink()
                    elif case in ("disabled", "nonboolean"):
                        value = False if case == "disabled" else "true"
                        config.write_text(f'[plugins."pstack@cursor-plugins"]\nenabled = {json.dumps(value)}\n' if client == "codex" else json.dumps({"enabledPlugins": {"pstack@cursor-plugins": value}}))
                    elif case == "malformed-config":
                        config.write_text("[[invalid")
                    elif case == "missing-manifest":
                        manifest.unlink()
                    elif case == "malformed-manifest":
                        manifest.write_text("{invalid")
                    elif case == "wrong-identity":
                        manifest.write_text('{"name": "impostor"}')
                    elif case == "missing-skill":
                        skill.unlink()
                    elif case == "empty-skill":
                        skill.write_text(" \n")
                    elif case == "escaping-manifest":
                        manifest.unlink()
                        manifest.symlink_to(self.alpha)
                    else:
                        skill.unlink()
                        skill.symlink_to(self.alpha)
                    self.assert_plugin_failure(client)

    def test_claude_registry_errors_and_escaping_paths(self):
        self.require_pstack()
        runtime = self.home / ".claude"
        skill = self.write_plugin("claude")
        installation = skill.parents[2]
        registry = runtime / "plugins/installed_plugins.json"
        cases = (
            None, "{invalid", [], {"version": 1, "plugins": {}},
            {"version": True, "plugins": {}}, {"version": 2, "plugins": []},
            {"version": 2, "plugins": {"pstack@cursor-plugins": ["invalid"]}},
        )
        for contents in cases:
            with self.subTest(contents=contents):
                if contents is None:
                    registry.unlink()
                else:
                    registry.write_text(contents if isinstance(contents, str) else json.dumps(contents))
                self.assert_plugin_failure("claude")
        for records in ([], [{"scope": "project", "installPath": str(installation)}], [{"scope": "user", "installPath": str(installation)}] * 2, [{"scope": "user", "installPath": "relative"}], [{"scope": "user", "installPath": str(self.root)}]):
            with self.subTest(records=records):
                self.write_registry(runtime, records)
                self.assert_plugin_failure("claude")
        link = installation.parent / "escape"
        link.symlink_to(self.root, target_is_directory=True)
        self.write_registry(runtime, [{"scope": "user", "installPath": str(link)}])
        self.assert_plugin_failure("claude", "範囲外")

    def test_codex_directory_eligibility_and_cleanup_residue(self):
        self.require_pstack()
        skill = self.write_plugin("codex", version="local")
        installation = skill.parents[2]
        cache = installation.parent
        for name in ("with space", "日本語", "bad@version"):
            (cache / name).mkdir()
        (cache / "2.0.0").write_text("not a directory")
        (cache / "3.0.0").symlink_to(installation, target_is_directory=True)
        (cache / "4.0.0").symlink_to(cache / "missing", target_is_directory=True)
        self.assertIn("OFFICIAL-FULL-TAIL", self.run_cli("bundle").stdout)
        shutil.rmtree(installation)
        self.assert_plugin_failure("codex", "0件")
        self.write_plugin("codex", version="1.0.0+build_test-1")
        self.assertIn("OFFICIAL-FULL-TAIL", self.run_cli("bundle").stdout)
        self.write_plugin("codex", version="0.9.0", text="OLD-CLEANUP-RESIDUE")
        self.assert_plugin_failure("codex", "2件")

    def test_codex_replacement_changes_digest_and_denies_once(self):
        self.require_pstack()
        skill = self.write_plugin("codex", text="OLD-OFFICIAL")
        before = json.loads(self.run_cli("bundle").stdout)
        self.output("codex", "UserPromptSubmit")
        self.assertEqual(self.output("codex", "PreToolUse"), {})
        shutil.rmtree(skill.parents[2])
        replacement = self.write_plugin("codex", version="2.0.0", text="UPDATED-OFFICIAL")
        after = json.loads(self.run_cli("bundle").stdout)
        self.assertNotEqual(before["digest"], after["digest"])
        self.assertIn(str(replacement.resolve()), after["text"])
        value = self.output("codex", "PreToolUse")["hookSpecificOutput"]
        self.assertEqual(value["permissionDecision"], "deny")
        self.assertIn("UPDATED-OFFICIAL", value["additionalContext"])
        self.assertNotIn("OLD-OFFICIAL", value["additionalContext"])
        self.assertEqual(self.output("codex", "PreToolUse"), {})

    def test_claude_follows_registry_install_path_amid_old_cache(self):
        self.require_pstack()
        self.alpha.write_text("ALPHA")
        old = self.write_plugin("claude", text="OLD-OFFICIAL")
        new = self.write_plugin("claude", version="2.0.0", text="NEW-OFFICIAL")
        runtime = self.home / ".claude"
        before = json.loads(self.run_cli("bundle", "--client", "claude").stdout)
        self.assertIn("NEW-OFFICIAL", before["text"])
        self.contexts("UserPromptSubmit")
        self.write_registry(runtime, [{"scope": "project", "installPath": str(new.parents[2])}, {"scope": "user", "installPath": str(old.parents[2])}])
        after = json.loads(self.run_cli("bundle", "--client", "claude").stdout)
        self.assertNotEqual(before["digest"], after["digest"])
        self.assertIn("OLD-OFFICIAL", after["text"])
        self.assertNotIn("NEW-OFFICIAL", after["text"])
        value = self.output("claude", "PreToolUse")["hookSpecificOutput"]
        self.assertEqual(value["permissionDecision"], "deny")
        self.assertIn("OLD-OFFICIAL", value["additionalContext"])
        self.assertEqual(self.output("claude", "PreToolUse"), {})

    def test_namespace_syntax_rejects_unknown_or_malformed_references(self):
        self.write_plugin("codex")
        for reference in ("other:poteto-mode", "pstack:other", "pstack:poteto-mode:other", "pstack:", ":poteto-mode", "pstack:../poteto-mode"):
            with self.subTest(reference=reference):
                (self.repo / "agent/AGENTS.md").write_text(f"# 必須スキル\n- {reference}\n")
                self.write_skill(reference, "NAMESPACE-SHADOW")
                self.assert_plugin_failure("codex")

    def test_bare_lookup_preserves_shared_repo_and_broken_symlink_behavior(self):
        (self.repo / "agent/skills/beta").mkdir(parents=True)
        (self.repo / "agent/skills/beta/SKILL.md").write_text("REPO-BETA")
        self.assertIn("BETA-TAIL", self.run_cli("bundle").stdout)
        self.beta.unlink()
        self.assertIn("REPO-BETA", self.run_cli("bundle").stdout)
        shadow = self.home / ".codex/skills/alpha/SKILL.md"
        shadow.parent.mkdir(parents=True)
        shadow.symlink_to(self.root / "missing")
        self.assert_plugin_failure("codex")

    def test_install_preserves_positions_backup_idempotence_dry_run_remove(self):
        original = {"model": "preserve", "hooks": {"SessionStart": [{"matcher": "resume", "hooks": [{"type": "command", "command": "echo keep"}]}], "Stop": [{"hooks": [{"type": "command", "command": "echo stop"}]}]}}
        paths = [self.home / ".codex/hooks.json", self.home / ".claude/settings.json"]
        for path in paths:
            path.parent.mkdir()
            path.write_text(json.dumps(original))
        self.run_cli("install", "--dry-run")
        self.assertFalse((self.home / ".local").exists())
        self.assertEqual(json.loads(paths[0].read_text()), original)
        self.run_cli("install")
        before = [path.read_bytes() for path in paths]
        backups = list((self.home / ".local/state/dotfiles/backups").rglob("*.json.*"))
        self.assertEqual(len(backups), 2)
        for path in paths:
            config = json.loads(path.read_text())
            self.assertEqual(config["model"], "preserve")
            self.assertEqual(config["hooks"]["SessionStart"][0], original["hooks"]["SessionStart"][0])
            self.assertEqual(config["hooks"]["Stop"], original["hooks"]["Stop"])
        self.run_cli("install")
        self.assertEqual([path.read_bytes() for path in paths], before)
        self.assertEqual(list((self.home / ".local/state/dotfiles/backups").rglob("*.json.*")), backups)
        self.run_cli("install", "--remove")
        for path in paths:
            config = json.loads(path.read_text())
            self.assertEqual(config["hooks"]["SessionStart"][0], original["hooks"]["SessionStart"][0])
            self.assertEqual(config["hooks"]["SessionStart"][1]["hooks"], [])
        self.assertFalse((self.home / ".pi/agent/extensions/required-skills.ts").exists())

    def test_shell_hooks_only_dry_run_does_not_install_skills_or_dotfiles(self):
        env = {**self.env, "DOTFILES_TARGET_HOME": str(self.home)}
        result = subprocess.run(["bash", str(REPO / "install.sh"), "--hooks-only", "--dry-run"], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("hooks.json", result.stdout)
        self.assertEqual(list(self.home.iterdir()), [self.home / ".agents"])

    def test_install_preflights_collisions_without_partial_changes(self):
        extension = self.home / ".pi/agent/extensions/required-skills.ts"
        extension.parent.mkdir(parents=True)
        extension.write_text("unrelated user extension")
        self.run_cli("install", success=False)
        self.assertFalse((self.home / ".codex").exists())
        self.assertEqual(extension.read_text(), "unrelated user extension")


if __name__ == "__main__":
    unittest.main()
