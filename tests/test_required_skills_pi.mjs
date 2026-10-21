import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const root = mkdtempSync(join(tmpdir(), "required-skills-pi-"));
try {
  const hooks = join(root, "repo/agent/hooks");
  mkdirSync(hooks, { recursive: true });
  for (const name of ["required-skills.py", "required-skills.ts"]) copyFileSync(join(repo, "agent/hooks", name), join(hooks, name));
  writeFileSync(join(root, "repo/agent/AGENTS.md"), "# 必須スキル\n- alpha\n- pstack:poteto-mode\n");
  process.env.HOME = join(root, "home");
  process.env.CODEX_HOME = join(root, "custom codex");
  process.env.PI_CODING_AGENT_DIR = join(root, "custom pi");
  process.env.CLAUDE_CONFIG_DIR = join(root, "custom claude");
  for (const [runtime, text] of [[process.env.CODEX_HOME, "CODEX-PLUGIN-TAIL"], [process.env.CLAUDE_CONFIG_DIR, "CLAUDE-MUST-NOT-LOAD"]]) {
    const installation = join(runtime, "plugins/cache/cursor-plugins/pstack/1.0.0");
    mkdirSync(join(installation, ".claude-plugin"), { recursive: true });
    writeFileSync(join(installation, ".claude-plugin/plugin.json"), JSON.stringify({ name: "pstack" }));
    mkdirSync(join(installation, "skills/poteto-mode"), { recursive: true });
    writeFileSync(join(installation, "skills/poteto-mode/SKILL.md"), text);
    if (runtime === process.env.CODEX_HOME) {
      writeFileSync(join(runtime, "config.toml"), '[plugins."pstack@cursor-plugins"]\nenabled = true\n');
    } else {
      writeFileSync(join(runtime, "settings.json"), JSON.stringify({ enabledPlugins: { "pstack@cursor-plugins": true } }));
      writeFileSync(join(runtime, "plugins/installed_plugins.json"), JSON.stringify({ version: 2, plugins: { "pstack@cursor-plugins": [{ scope: "user", installPath: installation }] } }));
    }
  }
  const loose = join(process.env.PI_CODING_AGENT_DIR, "skills/poteto-mode/SKILL.md");
  mkdirSync(dirname(loose), { recursive: true });
  writeFileSync(loose, "PI-LOOSE-MUST-NOT-LOAD");
  const skill = join(process.env.HOME, ".agents/skills/alpha/SKILL.md");
  mkdirSync(dirname(skill), { recursive: true });
  const full = "日本語😀".repeat(6000) + "FULL-TAIL";
  writeFileSync(skill, full);
  const handlers = new Map();
  const { default: extension } = await import(pathToFileURL(join(hooks, "required-skills.ts")).href);
  extension({ on: (name, callback) => handlers.set(name, callback) });
  let aborted = 0;
  const ctx = { hasUI: false, abort: () => aborted++ };
  const user = { role: "user", content: "hello", timestamp: 1 };
  const other = { role: "custom", customType: "keep-me", content: "other" };
  const first = await handlers.get("context")({ messages: [user, other] }, ctx);
  assert.equal(first.messages[2].content.includes(full), true);
  assert.equal(first.messages[2].content.includes("CODEX-PLUGIN-TAIL"), true);
  assert.equal(first.messages[2].content.includes("CLAUDE-MUST-NOT-LOAD"), false);
  assert.equal(first.messages[2].content.includes("PI-LOOSE-MUST-NOT-LOAD"), false);
  const again = await handlers.get("context")({ messages: first.messages }, ctx);
  assert.equal(again.messages.length, 3);
  assert.equal(again.messages[0], user);
  assert.equal(again.messages[1], other);
  assert.equal(await handlers.get("tool_call")({}, ctx), undefined);
  writeFileSync(skill, "CHANGED-TAIL");
  assert.equal((await handlers.get("tool_call")({}, ctx)).block, true);
  const changed = await handlers.get("context")({ messages: again.messages }, ctx);
  assert.equal(changed.messages[2].content.includes("CHANGED-TAIL"), true);
  assert.equal(changed.messages[2].content.includes("FULL-TAIL"), false);
  const pluginSkill = join(process.env.CODEX_HOME, "plugins/cache/cursor-plugins/pstack/1.0.0/skills/poteto-mode/SKILL.md");
  writeFileSync(pluginSkill, "UPDATED-CODEX-PLUGIN");
  assert.equal((await handlers.get("tool_call")({}, ctx)).block, true);
  const pluginChanged = await handlers.get("context")({ messages: changed.messages }, ctx);
  assert.equal(pluginChanged.messages[2].content.includes("UPDATED-CODEX-PLUGIN"), true);
  assert.equal(pluginChanged.messages[2].content.includes("CODEX-PLUGIN-TAIL"), false);
  assert.equal(await handlers.get("tool_call")({}, ctx), undefined);
  writeFileSync(join(process.env.CODEX_HOME, "config.toml"), '[plugins."pstack@cursor-plugins"]\nenabled = false\n');
  await assert.rejects(handlers.get("context")({ messages: pluginChanged.messages }, ctx), /required-skills/);
  assert.equal(aborted, 1);
  assert.equal((await handlers.get("tool_call")({}, ctx)).block, true);
  assert.equal(aborted, 2);
  writeFileSync(join(process.env.CODEX_HOME, "config.toml"), '[plugins."pstack@cursor-plugins"]\nenabled = true\n');
  await handlers.get("context")({ messages: pluginChanged.messages }, ctx);
  unlinkSync(skill);
  await assert.rejects(handlers.get("context")({ messages: changed.messages }, ctx), /required-skills/);
  assert.equal(aborted, 3);
  assert.equal((await handlers.get("tool_call")({}, ctx)).block, true);
  assert.equal(aborted, 4);
  console.log("Pi full-context replacement, Codex plugin source, changes, tool blocks, and abort checks passed");
} finally {
  rmSync(root, { recursive: true, force: true });
}
