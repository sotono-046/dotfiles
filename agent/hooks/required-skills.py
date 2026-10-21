#!/usr/bin/env python3
import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).resolve()
SLOTS = 16
CHUNK_UNITS = 8000
BUNDLE_UNITS = 128000
EVENTS = ("SessionStart", "SubagentStart", "UserPromptSubmit", "PreToolUse")
RUNTIME_DIRS = {"codex": ".codex", "claude": ".claude", "pi": ".pi/agent"}
RUNTIME_ENVS = {"codex": "CODEX_HOME", "claude": "CLAUDE_CONFIG_DIR", "pi": "PI_CODING_AGENT_DIR"}
PLUGIN_REFERENCES = {"pstack:poteto-mode": {"identity": "pstack@cursor-plugins", "marketplace": "cursor-plugins", "plugin": "pstack", "skill": "poteto-mode"}}


@dataclass(frozen=True)
class SkillDocument:
    name: str
    path: Path
    text: str
    hash: str


@dataclass(frozen=True)
class Bundle:
    digest: str
    text: str


def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def units(text):
    return len(text.encode("utf-16-le")) // 2


def resolve_skill(name, client, home):
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*(?::[a-z0-9][a-z0-9-]*)?", name):
        raise ValueError(f"必須スキルの参照が不正です: {name}")
    if ":" not in name:
        runtime = Path(os.environ.get(RUNTIME_ENVS[client], home / RUNTIME_DIRS[client]))
        roots = [runtime / "skills", home / ".agents/skills", REPO / "agent/skills"]
        paths = [root / name / "SKILL.md" for root in roots]
        path = next((path for path in paths if path.exists() or path.is_symlink()), None)
        if path is None:
            raise ValueError(f"必須スキルが見つかりません: {name}")
        return path
    if name not in PLUGIN_REFERENCES:
        raise ValueError(f"未対応の必須スキル参照です: {name}。対応する参照は pstack:poteto-mode です")
    reference = PLUGIN_REFERENCES[name]
    source = "codex" if client == "pi" else client
    runtime = Path(os.environ.get(RUNTIME_ENVS[source], home / RUNTIME_DIRS[source]))
    cache = runtime.resolve() / "plugins/cache" / reference["marketplace"] / reference["plugin"]
    identity = reference["identity"]
    if source == "claude":
        settings = json.loads((runtime / "settings.json").read_text(encoding="utf-8"))
        enabled = settings.get("enabledPlugins") if isinstance(settings, dict) else None
        if not isinstance(enabled, dict) or enabled.get(identity) is not True:
            raise ValueError(f"Claude Code の公式プラグイン {identity} が有効ではありません")
        registry = json.loads((runtime / "plugins/installed_plugins.json").read_text(encoding="utf-8"))
        plugins = registry.get("plugins") if isinstance(registry, dict) else None
        if not isinstance(registry, dict) or type(registry.get("version")) is not int or registry["version"] != 2 or not isinstance(plugins, dict):
            raise ValueError("Claude Code の installed_plugins.json は version 2 の登録情報が必要です")
        records = plugins.get(identity)
        if not isinstance(records, list) or any(not isinstance(record, dict) for record in records):
            raise ValueError(f"Claude Code の {identity} の登録情報が不正です")
        selected = [record for record in records if record.get("scope") == "user"]
        if len(selected) != 1:
            raise ValueError(f"Claude Code の {identity} は user scope の登録が1件必要です: {len(selected)}件")
        install_path = selected[0].get("installPath")
        if not isinstance(install_path, str) or not Path(install_path).is_absolute():
            raise ValueError(f"Claude Code の {identity} の installPath は絶対パスが必要です")
        installation = Path(install_path)
    else:
        try:
            import tomllib
        except ImportError as error:
            raise ValueError("公式プラグインの読込には tomllib を含む Python 3.11 以降が必要です") from error
        with (runtime / "config.toml").open("rb") as config_file:
            config = tomllib.load(config_file)
        plugins = config.get("plugins")
        plugin = plugins.get(identity) if isinstance(plugins, dict) else None
        if not isinstance(plugin, dict) or plugin.get("enabled") is not True:
            raise ValueError(f"Codex の公式プラグイン {identity} が有効ではありません")
        versions = [path for path in (cache.iterdir() if cache.exists() else ()) if not path.is_symlink() and path.is_dir() and path.name not in (".", "..") and re.fullmatch(r"[A-Za-z0-9._+-]+", path.name)]
        if len(versions) != 1:
            raise ValueError(f"Codex の {identity} は有効な実ディレクトリが1件必要です: {len(versions)}件。公式インストールを確認・修復してください。更新中の重複や旧版の削除残りには対応していません")
        installation = versions[0]
    installation = installation.resolve()
    if installation == cache or not installation.is_relative_to(cache):
        raise ValueError(f"{identity} の installPath が公式キャッシュの範囲外です: {installation}")
    manifest = installation / ".claude-plugin/plugin.json"
    skill = installation / "skills" / reference["skill"] / "SKILL.md"
    if not manifest.resolve().is_relative_to(installation) or not skill.resolve().is_relative_to(installation):
        raise ValueError(f"{identity} のファイルがインストール先の範囲外です")
    metadata = json.loads(manifest.read_text(encoding="utf-8"))
    if not isinstance(metadata, dict) or metadata.get("name") != reference["plugin"]:
        raise ValueError(f"公式プラグイン {identity} の plugin.json の name が一致しません")
    return skill


def load_bundle(client, home, extra=()):
    registry = (REPO / "agent/AGENTS.md").read_text(encoding="utf-8")
    section = re.search(r"^# 必須スキル\s*\n(.*?)(?=^#|\Z)", registry, re.M | re.S)
    lines = [line for line in section[1].splitlines() if line.strip()] if section else []
    if any(not re.fullmatch(r"- [a-z0-9][a-z0-9-]*(?::[a-z0-9][a-z0-9-]*)?", line) for line in lines):
        raise ValueError("agent/AGENTS.md の必須スキル項目が不正です")
    names = [line[2:] for line in lines]
    if not names:
        raise ValueError("agent/AGENTS.md の必須スキル一覧が空か、不正です")
    documents = []
    for name in dict.fromkeys([*names, *extra]):
        path = resolve_skill(name, client, home)
        raw = path.read_bytes()
        text = raw.decode("utf-8")
        if not text.strip():
            raise ValueError(f"必須スキルが空です: {path}")
        documents.append(SkillDocument(name, path.resolve(), text, digest(text)))
    text = "必須スキルの全文です。各文書を読み、適用してください。要約や抜粋ではありません。\n"
    for doc in documents:
        text += f"\n[skill {doc.name} path={doc.path} sha256={doc.hash}]\n"
        text += doc.text
        text += f"\n[/skill {doc.name}]\n"
    if units(text) > BUNDLE_UNITS:
        raise ValueError(f"必須スキル全文が上限 {BUNDLE_UNITS} UTF-16 units を超えました")
    return Bundle(digest(text), text)


def chunks(bundle):
    prefix = f"[required-skills sha256={bundle.digest} chunk "
    capacity = CHUNK_UNITS - units(prefix + "00/00]\n")
    parts, start, size = [], 0, 0
    for index, char in enumerate(bundle.text):
        width = 2 if ord(char) > 0xFFFF else 1
        if size + width > capacity:
            parts.append(bundle.text[start:index])
            start, size = index, 0
        size += width
    parts.append(bundle.text[start:])
    if len(parts) > SLOTS:
        raise ValueError(f"必須スキル全文が Claude の {SLOTS} 分割枠を超えました")
    return [f"{prefix}{i + 1:02d}/{len(parts):02d}]\n{part}" for i, part in enumerate(parts)]


def direct_git_write_command(payload):
    tool_input = payload.get("tool_input", {})
    command = tool_input.get("command", tool_input.get("cmd", "")) if isinstance(tool_input, dict) else ""
    if not isinstance(command, str):
        return ""
    git = r"(?:^|[\s;&|])(?:\S*/)?git\s+(?:-[^\s]+\s+\S+\s+)*(?:commit|push)(?:\s|$)"
    gh = r"(?:^|[\s;&|])(?:\S*/)?gh\s+pr\s+(?:create|merge)(?:\s|$)"
    return command if re.search(git, command) or re.search(gh, command) else ""


def state_path(client, home, payload, slot, kind):
    session = payload.get("session_id") or payload.get("transcript_path")
    if not session:
        raise ValueError("hook に session_id または transcript_path がありません")
    actor = payload.get("agent_id") or payload.get("transcript_path") or "root"
    cwd = str(Path(payload.get("cwd") or os.getcwd()).resolve())
    key = digest(json.dumps([client, session, actor, cwd, slot, kind], ensure_ascii=False))
    return home / ".local/state/dotfiles/required-skills" / f"{key}.txt"


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as output:
            output.write(text)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def failure(event, client, message):
    reason = f"required-skills: {message}。全文を読み込めるまで作業を進めないでください。"
    if event == "PreToolUse":
        return {"hookSpecificOutput": {"hookEventName": event, "permissionDecision": "deny", "permissionDecisionReason": reason}}
    if event in ("UserPromptSubmit", "Stop"):
        return {"decision": "block", "reason": reason}
    if client == "codex":
        return {"continue": False, "stopReason": reason}
    return {"systemMessage": reason}


def hook(client, home, slot, payload):
    event = payload.get("hook_event_name", "")
    if event not in (*EVENTS, "Stop"):
        raise ValueError(f"未対応の hook event: {event}")
    command = direct_git_write_command(payload) if event == "PreToolUse" else ""
    bundle = load_bundle(client, home, ("git-ops",) if command else ())
    parts = chunks(bundle) if client == "claude" else [bundle.text]
    text = parts[slot] if slot < len(parts) else ""
    if event == "Stop":
        return {}
    deny = False
    if event == "PreToolUse":
        state = state_path(client, home, payload, slot, "git" if command else "mandatory")
        fingerprint = digest(bundle.digest + command)
        if not command:
            state_path(client, home, payload, slot, "git").unlink(missing_ok=True)
        previous = state.read_text() if state.exists() else ""
        if previous == fingerprint:
            if command:
                state.unlink()
            return {}
        atomic_write(state, fingerprint)
        deny = True
    elif payload.get("session_id") or payload.get("transcript_path"):
        state = state_path(client, home, payload, slot, "mandatory")
        atomic_write(state, digest(bundle.digest))
        state_path(client, home, payload, slot, "git").unlink(missing_ok=True)
    output = {"hookEventName": event}
    if text:
        output["additionalContext"] = text
    if deny:
        output.update(permissionDecision="deny", permissionDecisionReason="必須スキルの全文を読み込んでから、この操作を再試行してください。")
    return {"hookSpecificOutput": output} if text or deny else {}


def handlers(client, event):
    result = []
    for slot in range(SLOTS if client == "claude" else 1):
        args = [sys.executable, str(SCRIPT), "hook", "--client", client, "--slot", str(slot)]
        handler = {"type": "command", "command": shlex.join(args), "timeout": 15}
        if client == "codex":
            handler["additionalContextLimit"] = 0
        elif event in ("UserPromptSubmit", "PreToolUse"):
            handler["onFailure"] = "block"
        result.append(handler)
    return result


def owned(handler):
    try:
        tokens = shlex.split(handler.get("command", ""))
    except (ValueError, AttributeError):
        return False
    return len(tokens) >= 3 and tokens[1:3] == [str(SCRIPT), "hook"]


def merge_config(config, client, remove):
    if remove and "hooks" not in config:
        return config
    hooks = config.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("設定の hooks は object である必要があります")
    for event in EVENTS:
        if remove and event not in hooks:
            continue
        groups = hooks.setdefault(event, [])
        if not isinstance(groups, list):
            raise ValueError(f"設定の hooks.{event} は array である必要があります")
        placed = False
        for group in groups:
            original = group["hooks"]
            replacement = []
            for handler in original:
                if owned(handler):
                    if not remove and not placed:
                        replacement.extend(handlers(client, event))
                        placed = True
                else:
                    replacement.append(handler)
            group["hooks"] = replacement
        if not remove and not placed:
            matcher = "startup|resume|clear|compact|fork" if event == "SessionStart" else "*"
            groups.append({"matcher": matcher, "hooks": handlers(client, event)})
    return config


def install(home, dry_run=False, remove=False):
    if not home.is_absolute() or home.resolve() == Path("/"):
        raise ValueError("--home は / 以外の絶対パスにしてください")
    for directory in (home / ".codex", home / ".claude", home / ".pi", home / ".pi/agent", home / ".pi/agent/extensions"):
        if directory.is_symlink():
            raise ValueError(f"設定ディレクトリの symlink は変更しません: {directory}")
    plans = []
    for client, relative in (("codex", ".codex/hooks.json"), ("claude", ".claude/settings.json")):
        path = home / relative
        if path.is_symlink():
            raise ValueError(f"設定の symlink は変更しません: {path}")
        original = path.read_text(encoding="utf-8") if path.exists() else "{}"
        config = json.loads(original)
        if not isinstance(config, dict):
            raise ValueError(f"設定は JSON object である必要があります: {path}")
        merged = merge_config(config, client, remove)
        if json.loads(original) != merged:
            plans.append((path, json.dumps(merged, ensure_ascii=False, indent=2) + "\n"))
    link = home / ".pi/agent/extensions/required-skills.ts"
    source = SCRIPT.with_suffix(".ts")
    if (link.exists() or link.is_symlink()) and (not link.is_symlink() or link.resolve() != source):
        raise ValueError(f"既存の Pi extension は置き換えません: {link}")
    for path, content in plans:
        print(f"{'DRY-RUN ' if dry_run else ''}merge {path}")
        if dry_run:
            continue
        if path.exists():
            backup = home / ".local/state/dotfiles/backups" / f"{path.relative_to(home)}.{time.time_ns()}"
            backup.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.copy2(path, backup)
            print(f"backup {backup}")
        atomic_write(path, content)
    if remove and link.is_symlink():
        print(f"{'DRY-RUN ' if dry_run else ''}unlink {link}")
        if not dry_run:
            link.unlink()
    elif not remove and not link.is_symlink():
        print(f"{'DRY-RUN ' if dry_run else ''}link {link} -> {source}")
        if not dry_run:
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(source)


def main():
    parser = argparse.ArgumentParser(description="Deliver complete mandatory skill documents to Codex, Claude Code, and Pi.")
    parser.add_argument("action", choices=("hook", "bundle", "install"))
    parser.add_argument("--client", choices=RUNTIME_DIRS, default="codex")
    parser.add_argument("--slot", type=int, choices=range(SLOTS), default=0)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--remove", action="store_true")
    args = parser.parse_args()
    payload = {}
    try:
        if args.action == "install":
            install(args.home, args.dry_run, args.remove)
            return 0
        if args.action == "bundle":
            bundle = load_bundle(args.client, args.home)
            result = {"digest": bundle.digest, "text": bundle.text}
        else:
            payload = json.load(sys.stdin)
            if not isinstance(payload, dict):
                raise ValueError("hook 入力は JSON object である必要があります")
            result = hook(args.client, args.home, args.slot, payload)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"required-skills: {error}", file=sys.stderr)
        if args.action == "hook":
            event = payload.get("hook_event_name", "") if isinstance(payload, dict) else ""
            print(json.dumps(failure(event, args.client, str(error)), ensure_ascii=False))
            return 0
        return 1


if __name__ == "__main__":
    sys.exit(main())
