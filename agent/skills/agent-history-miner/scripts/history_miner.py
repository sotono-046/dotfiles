#!/usr/bin/env python3
"""Privacy-preserving, bounded mining of Codex and Claude Code JSONL histories."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import math
import os
import re
import secrets
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable


CODEX_OUTER_TYPES = {
    "session_meta",
    "turn_context",
    "response_item",
    "event_msg",
    "world_state",
    "compacted",
}

CATEGORY_PATTERNS: dict[str, tuple[str, ...]] = {
    "git-lifecycle": (
        r"\bgit\b", r"\bcommit\b", r"\bpush\b", r"\bmerge\b", r"pull request",
        r"\bpr\b", r"ブランチ", r"コミット", r"マージ", r"プッシュ",
    ),
    "ci-review-monitoring": (
        r"\bci\b", r"checks?\b", r"review", r"monitor", r"watch", r"レビュー",
        r"監視", r"チェック", r"green", r"failure log",
    ),
    "test-validation": (
        r"\btest", r"\blint\b", r"typecheck", r"type-check", r"verify", r"validation",
        r"regression", r"テスト", r"検証", r"確認", r"実測",
    ),
    "deploy-release": (
        r"deploy", r"release", r"production", r"cloud run", r"cloud build",
        r"デプロイ", r"リリース", r"本番",
    ),
    "subagent-orchestration": (
        r"sub.?agent", r"spawn_agent", r"sendmessage", r"send_message", r"parallel",
        r"orchestrat", r"サブエージェント", r"並列", r"委譲", r"司令塔",
    ),
    "worktree-lifecycle": (
        r"worktree", r"作業ツリー", r"stale branch", r"prune",
    ),
    "skill-maintenance": (
        r"\bskills?\b", r"skill\.md", r"スキル", r"prompt", r"プロンプト",
        r"agent instructions?", r"claude\.md", r"agents\.md",
    ),
    "docs-knowledge": (
        r"document", r"\bdocs?\b", r"obsidian", r"notion", r"sow", r"issue draft",
        r"ドキュメント", r"メモ", r"記録", r"仕様", r"議事録",
    ),
    "web-ui-inspection": (
        r"browser", r"screenshot", r"frontend", r"\bui\b", r"\bux\b", r"playwright",
        r"ブラウザ", r"スクリーンショット", r"画面", r"表示",
    ),
    "data-reporting": (
        r"spreadsheet", r"sheets?\b", r"dashboard", r"analytics?\b", r"report",
        r"集計", r"分析", r"レポート", r"スプレッドシート",
    ),
}

RISK_PATTERNS = (
    r"\bpush\b", r"\bmerge\b", r"deploy", r"production", r"\blive\b", r"delete",
    r"remove", r"--force", r"database", r"firestore", r"external api", r"billing",
    r"プッシュ", r"マージ", r"デプロイ", r"本番", r"削除", r"課金", r"実環境",
)

PROCEDURE_PATTERNS = (
    r"\bthen\b", r"\bafter\b", r"\bbefore\b", r"\bfirst\b", r"\bnext\b",
    r"\bfinally\b", r"\bverify\b", r"\btest\b", r"\bcommit\b", r"\bcheck\b",
    r"その後", r"まず", r"次に", r"最後", r"確認", r"検証", r"実行", r"コミット",
)

OVERLAP_ALIASES: dict[str, tuple[str, ...]] = {
    "git-lifecycle": ("git", "commit", "push", "merge", "pr", "pull request"),
    "ci-review-monitoring": ("ci", "review", "check", "monitor", "merge", "github"),
    "test-validation": ("test", "validation", "verify", "lint", "typecheck"),
    "deploy-release": ("deploy", "release", "cloud", "production"),
    "subagent-orchestration": ("subagent", "agent", "orchestration", "parallel"),
    "worktree-lifecycle": ("worktree", "git", "branch", "prune"),
    "skill-maintenance": ("skill", "prompt", "agent", "instruction"),
    "docs-knowledge": ("document", "note", "obsidian", "sow", "issue"),
    "web-ui-inspection": ("browser", "frontend", "ui", "screenshot", "playwright"),
    "data-reporting": ("data", "analytics", "report", "sheet", "dashboard"),
}

NOISE_ONLY = (
    re.compile(r"^\s*/[a-zA-Z][\w-]*(?:\s+.*)?\s*$", re.DOTALL),
    re.compile(r"^\s*\[Pasted (?:text|image)(?:\s*#\d+)?(?:\s*\+\d+ lines?)?\]\s*$", re.I),
    re.compile(r"^\s*<(?:system-reminder|task-notification|local-command-caveat|command-message)\b", re.I),
    re.compile(r"^\s*This session is being continued from a previous conversation", re.I),
)

AUTOMATIC_BLOCKS = re.compile(
    r"<(?:system-reminder|task-notification|local-command-caveat)\b[^>]*>.*?"
    r"</(?:system-reminder|task-notification|local-command-caveat)>",
    re.I | re.DOTALL,
)
PASTED_MARKER = re.compile(r"\[Pasted (?:text|image)(?:\s*#\d+)?(?:\s*\+\d+ lines?)?\]", re.I)
CODE_BLOCK = re.compile(r"```.*?```", re.DOTALL)
SECRET_ASSIGN = re.compile(
    r"(?i)\b(api[_-]?key|access[_-]?token|auth(?:orization)?|password|passwd|secret|token)"
    r"\s*[:=]\s*(?:['\"])?[^\s,;'\"]+(?:['\"])?"
)
SECRET_TOKEN = re.compile(
    r"(?i)\b(?:sk-[a-z0-9_-]{12,}|ghp_[a-z0-9]{12,}|github_pat_[a-z0-9_]{12,}|"
    r"AKIA[A-Z0-9]{12,}|eyJ[a-z0-9_-]{10,}\.[a-z0-9_-]{10,}\.[a-z0-9_-]{10,})\b"
)
BEARER = re.compile(r"(?i)\bBearer\s+[a-z0-9._~+/-]{8,}")
URL = re.compile(r"https?://[^\s<>)\]]+")
EMAIL = re.compile(r"(?<![\w.+-])[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}")
WINDOWS_PATH = re.compile(
    r"(?i)(?<![\w])(?:[a-z]:\\[^\s'\"<>]+|\\\\[^\\\s'\"<>]+\\[^\s'\"<>]+)"
)
POSIX_PATH = re.compile(r"(?<![\w.:])/(?!/)[^\s'\"<>]+")
RELATIVE_PATH = re.compile(
    r"(?<![\w./\\-])(?:\.\.?[\\/])?(?:[^\s/\\'\"<>:,]+[\\/])+[^\s/\\'\"<>:,]+"
)
UUID = re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b", re.I)
HEX_ID = re.compile(r"\b[0-9a-f]{12,64}\b", re.I)
LONG_NUMBER = re.compile(r"(?<!\w)#?\d{3,}(?!\w)")
WHITESPACE = re.compile(r"\s+")


@dataclass
class Stats:
    discovered_files: int = 0
    discovery_entries: int = 0
    discovery_truncated: bool = False
    selected_files: int = 0
    processed_files: int = 0
    skipped_oversize_files: int = 0
    records_read: int = 0
    malformed_records: int = 0
    oversize_lines: int = 0
    unknown_source_records: int = 0
    user_messages_seen: int = 0
    noise_filtered: int = 0
    duplicate_suppressed: int = 0
    messages_kept: int = 0
    truncated: bool = False
    source_counts: collections.Counter[str] = field(default_factory=collections.Counter)
    scope_counts: collections.Counter[str] = field(default_factory=collections.Counter)


@dataclass
class Message:
    fingerprint: str
    sample: str
    source: str
    scope: str
    session_key: str
    categories: tuple[str, ...]
    risk: float
    procedural: float


@dataclass
class Options:
    source: str
    scope: str
    since_days: int
    max_files: int
    max_discovered_files: int
    max_discovery_entries: int
    max_records: int
    max_file_bytes: int
    max_line_bytes: int
    max_chars: int
    min_frequency: int
    top: int
    include_snippets: bool
    snippet_length: int
    hash_salt: str
    skills_dirs: list[Path]


def parse_timestamp(value: Any) -> dt.datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except ValueError:
        return None


def redact(text: str) -> str:
    text = CODE_BLOCK.sub(" <code> ", text)
    text = AUTOMATIC_BLOCKS.sub(" ", text)
    text = PASTED_MARKER.sub(" <pasted> ", text)
    text = SECRET_ASSIGN.sub(lambda m: f"{m.group(1)}=<secret>", text)
    text = SECRET_TOKEN.sub("<secret>", text)
    text = BEARER.sub("Bearer <secret>", text)
    text = URL.sub("<url>", text)
    text = EMAIL.sub("<email>", text)
    text = WINDOWS_PATH.sub("<path>", text)
    text = POSIX_PATH.sub("<path>", text)
    text = RELATIVE_PATH.sub("<path>", text)
    text = UUID.sub("<id>", text)
    text = HEX_ID.sub("<id>", text)
    text = LONG_NUMBER.sub("<num>", text)
    return WHITESPACE.sub(" ", text).strip()


def is_noise(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    return any(pattern.search(stripped) for pattern in NOISE_ONLY)


def normalized(text: str, max_chars: int) -> tuple[str, str] | None:
    if is_noise(text):
        return None
    safe = redact(text[:max_chars])
    if not safe or is_noise(safe) or safe in {"<pasted>", "<code>"}:
        return None
    template = safe.casefold()
    template = re.sub(r"\b(issue|pr|pull request)\s*#?\s*<num>", r"\1 <num>", template)
    return template, safe


def keyed_fingerprint(text: str, salt: str) -> str:
    return hashlib.blake2b(text.encode("utf-8"), key=salt.encode("utf-8"), digest_size=10).hexdigest()


def pattern_ratio(text: str, patterns: Iterable[str], threshold: int = 1) -> float:
    hits = sum(1 for pattern in patterns if re.search(pattern, text, re.I))
    return min(1.0, hits / max(1, threshold))


def categorize(template: str) -> tuple[str, ...]:
    return tuple(
        name for name, patterns in CATEGORY_PATTERNS.items()
        if any(re.search(pattern, template, re.I) for pattern in patterns)
    )


def discover_files(
    raw_paths: list[str],
    max_files: int,
    max_discovered_files: int,
    max_discovery_entries: int,
) -> tuple[list[Path], int, int, bool]:
    found: dict[str, Path] = {}
    visited_dirs: set[tuple[int, int]] = set()
    discovery_entries = 0
    discovery_truncated = False

    for raw in raw_paths:
        path = Path(raw).expanduser()
        if not path.exists():
            raise FileNotFoundError(f"input path does not exist: {raw}")
        if path.is_symlink():
            continue
        if path.is_file():
            if discovery_entries >= max_discovery_entries:
                discovery_truncated = True
                break
            discovery_entries += 1
            if path.suffix == ".jsonl":
                found[str(path.absolute())] = path
                if len(found) >= max_discovered_files:
                    discovery_truncated = True
                    break
            continue
        if not path.is_dir():
            continue

        stack = [path]
        stop = False
        while stack and not stop:
            directory = stack.pop()
            try:
                stat = os.stat(directory, follow_symlinks=False)
                inode = (stat.st_dev, stat.st_ino)
                if inode in visited_dirs:
                    continue
                visited_dirs.add(inode)
                with os.scandir(directory) as entries:
                    for entry in entries:
                        if discovery_entries >= max_discovery_entries:
                            discovery_truncated = True
                            stop = True
                            break
                        discovery_entries += 1
                        if entry.is_symlink():
                            continue
                        try:
                            if entry.is_dir(follow_symlinks=False):
                                stack.append(Path(entry.path))
                            elif entry.is_file(follow_symlinks=False) and entry.name.endswith(".jsonl"):
                                candidate = Path(entry.path)
                                found[str(candidate.absolute())] = candidate
                                if len(found) >= max_discovered_files:
                                    discovery_truncated = True
                                    stop = True
                                    break
                        except OSError:
                            continue
            except OSError:
                continue
        if stop:
            break

    def mtime(candidate: Path) -> float:
        try:
            return candidate.stat().st_mtime
        except OSError:
            return 0.0

    files = sorted(found.values(), key=mtime, reverse=True)
    return files[:max_files], len(files), discovery_entries, discovery_truncated


def path_scope(path: Path) -> str:
    lowered = [part.casefold() for part in path.parts]
    if "subagents" in lowered or path.name.casefold().startswith("agent-"):
        return "subagent"
    return "root"


def extract_text(value: Any) -> str | None:
    if isinstance(value, str):
        return value
    if not isinstance(value, list):
        return None
    if any(isinstance(item, dict) and item.get("type") == "tool_result" for item in value):
        return None
    parts = []
    for item in value:
        if isinstance(item, dict) and item.get("type") in {"text", "input_text"}:
            candidate = item.get("text")
            if isinstance(candidate, str):
                parts.append(candidate)
    return "\n".join(parts) if parts else None


def record_source(obj: dict[str, Any]) -> str | None:
    outer = obj.get("type")
    if outer in CODEX_OUTER_TYPES:
        return "codex"
    if outer in {"user", "assistant"} and isinstance(obj.get("message"), dict):
        return "claude"
    return None


def codex_scope(obj: dict[str, Any], current: str) -> str:
    if obj.get("type") != "session_meta":
        return current
    payload = obj.get("payload") if isinstance(obj.get("payload"), dict) else {}
    if payload.get("thread_source") == "subagent" or payload.get("agent_path"):
        return "subagent"
    return "root"


def extract_user_message(obj: dict[str, Any], source: str) -> str | None:
    if source == "codex":
        payload = obj.get("payload") if isinstance(obj.get("payload"), dict) else {}
        if obj.get("type") == "event_msg" and payload.get("type") == "user_message":
            return payload.get("message") if isinstance(payload.get("message"), str) else None
        if (
            obj.get("type") == "response_item"
            and payload.get("type") == "message"
            and payload.get("role") == "user"
        ):
            return extract_text(payload.get("content"))
        return None

    if obj.get("type") != "user" or obj.get("isMeta") is True:
        return None
    message = obj.get("message") if isinstance(obj.get("message"), dict) else {}
    if message.get("role") != "user":
        return None
    return extract_text(message.get("content"))


def scan_histories(paths: list[str], options: Options) -> tuple[list[Message], Stats]:
    files, discovered, discovery_entries, discovery_truncated = discover_files(
        paths,
        options.max_files,
        options.max_discovered_files,
        options.max_discovery_entries,
    )
    stats = Stats(
        discovered_files=discovered,
        discovery_entries=discovery_entries,
        discovery_truncated=discovery_truncated,
        selected_files=len(files),
    )
    cutoff = None
    if options.since_days > 0:
        cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=options.since_days)
    messages: list[Message] = []

    for path in files:
        if stats.records_read >= options.max_records:
            stats.truncated = True
            break
        try:
            file_stat = path.stat()
            if file_stat.st_size > options.max_file_bytes:
                stats.skipped_oversize_files += 1
                continue
            file_timestamp = dt.datetime.fromtimestamp(file_stat.st_mtime, dt.timezone.utc)
        except OSError:
            continue

        current_source: str | None = None
        current_scope = path_scope(path)
        session_key = keyed_fingerprint(str(path.resolve()), options.hash_salt)
        seen_session: set[str] = set()
        processed_any = False

        try:
            with path.open("rb") as handle:
                for raw_line in handle:
                    if stats.records_read >= options.max_records:
                        stats.truncated = True
                        break
                    stats.records_read += 1
                    processed_any = True
                    if len(raw_line) > options.max_line_bytes:
                        stats.oversize_lines += 1
                        continue
                    try:
                        obj = json.loads(raw_line)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        stats.malformed_records += 1
                        continue
                    if not isinstance(obj, dict):
                        continue

                    detected = record_source(obj)
                    if detected:
                        current_source = detected
                    if options.source != "auto" and current_source not in {None, options.source}:
                        continue
                    if current_source == "codex":
                        current_scope = codex_scope(obj, current_scope)

                    source = current_source
                    if not source:
                        stats.unknown_source_records += 1
                        continue
                    if options.source != "auto" and source != options.source:
                        continue

                    scope = current_scope
                    if source == "claude" and (obj.get("isSidechain") is True or obj.get("agentId")):
                        scope = "subagent"
                    if options.scope != "all" and scope != options.scope:
                        continue

                    text = extract_user_message(obj, source)
                    if text is None:
                        continue
                    stats.user_messages_seen += 1
                    timestamp = parse_timestamp(obj.get("timestamp"))
                    if cutoff and (timestamp or file_timestamp) < cutoff:
                        continue
                    pair = normalized(text, options.max_chars)
                    if pair is None:
                        stats.noise_filtered += 1
                        continue
                    template, sample = pair
                    fingerprint = keyed_fingerprint(template, options.hash_salt)
                    if fingerprint in seen_session:
                        stats.duplicate_suppressed += 1
                        continue
                    seen_session.add(fingerprint)
                    cats = categorize(template)
                    risk = pattern_ratio(template, RISK_PATTERNS, threshold=3)
                    procedure = pattern_ratio(template, PROCEDURE_PATTERNS, threshold=3)
                    messages.append(Message(
                        fingerprint=fingerprint,
                        sample=sample,
                        source=source,
                        scope=scope,
                        session_key=session_key,
                        categories=cats,
                        risk=risk,
                        procedural=procedure,
                    ))
                    stats.messages_kept += 1
                    stats.source_counts[source] += 1
                    stats.scope_counts[scope] += 1
        except OSError:
            continue
        if processed_any:
            stats.processed_files += 1
    return messages, stats


def load_existing_skills(paths: list[Path]) -> list[tuple[str, str]]:
    skills: list[tuple[str, str]] = []
    seen: set[str] = set()
    for base in paths:
        if not base.is_dir():
            continue
        for skill_file in sorted(base.glob("*/SKILL.md"))[:256]:
            try:
                text = skill_file.read_text(encoding="utf-8")[:65536]
            except OSError:
                continue
            name_match = re.search(r"(?m)^name:\s*['\"]?([^'\"\n]+)", text)
            desc_match = re.search(r"(?m)^description:\s*['\"]?([^\n]+)", text)
            name = (name_match.group(1).strip() if name_match else skill_file.parent.name)
            if name in seen:
                continue
            seen.add(name)
            skills.append((name, f"{name} {desc_match.group(1) if desc_match else ''}".casefold()))
    return skills


def best_overlap(label: str, skills: list[tuple[str, str]]) -> tuple[float, str | None]:
    aliases = OVERLAP_ALIASES.get(label, tuple(label.split("-")))
    best_score = 0.0
    best_name = None
    for name, blob in skills:
        hits = sum(1 for alias in aliases if alias in blob)
        score = hits / max(1, len(aliases))
        if score > best_score:
            best_score, best_name = score, name
    return best_score, best_name


def build_candidates(messages: list[Message], options: Options) -> list[dict[str, Any]]:
    clusters: dict[str, list[Message]] = collections.defaultdict(list)
    uncategorized: dict[str, list[Message]] = collections.defaultdict(list)
    for message in messages:
        if message.categories:
            for category in message.categories:
                clusters[category].append(message)
        else:
            uncategorized[message.fingerprint].append(message)
    for fingerprint, group in uncategorized.items():
        if len(group) >= options.min_frequency:
            clusters[f"repeated-template-{fingerprint[:8]}"] = group

    viable = {name: group for name, group in clusters.items() if len(group) >= options.min_frequency}
    max_count = max((len(group) for group in viable.values()), default=1)
    existing = load_existing_skills(options.skills_dirs)
    results = []
    for label, group in viable.items():
        template_counts = collections.Counter(message.fingerprint for message in group)
        top_fingerprint, top_count = template_counts.most_common(1)[0]
        frequency = math.log1p(len(group)) / math.log1p(max_count)
        stability = top_count / len(group)
        procedural = sum(message.procedural for message in group) / len(group)
        risk = sum(message.risk for message in group) / len(group)
        overlap, existing_name = best_overlap(label, existing)
        recommendation = "optimize" if overlap >= 0.25 else "create"
        fit = overlap if recommendation == "optimize" else 1.0 - overlap
        score = 100 * (
            0.35 * frequency
            + 0.30 * stability
            + 0.15 * procedural
            + 0.10 * (1.0 - risk)
            + 0.10 * fit
        )
        candidate: dict[str, Any] = {
            "id": keyed_fingerprint(label, options.hash_salt)[:12],
            "label": label,
            "recommendation": recommendation,
            "score": round(score, 1),
            "count": len(group),
            "unique_sessions": len({message.session_key for message in group}),
            "frequency_score": round(frequency, 3),
            "stability_score": round(stability, 3),
            "procedural_score": round(procedural, 3),
            "risk_score": round(risk, 3),
            "existing_overlap": round(overlap, 3),
            "existing_skill": existing_name,
            "source_counts": dict(sorted(collections.Counter(m.source for m in group).items())),
            "scope_counts": dict(sorted(collections.Counter(m.scope for m in group).items())),
            "top_template_fingerprint": top_fingerprint,
            "top_template_count": top_count,
        }
        if options.include_snippets:
            candidate["sample_redacted"] = group[0].sample[:options.snippet_length]
        results.append(candidate)
    results.sort(key=lambda item: (-item["score"], -item["count"], item["label"]))
    for rank, item in enumerate(results[:options.top], 1):
        item["rank"] = rank
    return results[:options.top]


def stats_dict(stats: Stats) -> dict[str, Any]:
    return {
        "discovered_files": stats.discovered_files,
        "discovery_entries": stats.discovery_entries,
        "discovery_truncated": stats.discovery_truncated,
        "selected_files": stats.selected_files,
        "processed_files": stats.processed_files,
        "skipped_oversize_files": stats.skipped_oversize_files,
        "records_read": stats.records_read,
        "malformed_records": stats.malformed_records,
        "oversize_lines": stats.oversize_lines,
        "unknown_source_records": stats.unknown_source_records,
        "user_messages_seen": stats.user_messages_seen,
        "noise_filtered": stats.noise_filtered,
        "duplicate_suppressed": stats.duplicate_suppressed,
        "messages_kept": stats.messages_kept,
        "truncated": stats.truncated,
        "source_counts": dict(sorted(stats.source_counts.items())),
        "scope_counts": dict(sorted(stats.scope_counts.items())),
    }


def make_report(messages: list[Message], stats: Stats, options: Options) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "privacy": {
            "raw_prompts_emitted": False,
            "snippets": "redacted-and-truncated" if options.include_snippets else "disabled",
            "fingerprints": "keyed-per-run" if not options.hash_salt else "keyed",
            "input_paths_emitted": False,
        },
        "limits": {
            "source": options.source,
            "scope": options.scope,
            "since_days": options.since_days,
            "max_files": options.max_files,
            "max_discovered_files": options.max_discovered_files,
            "max_discovery_entries": options.max_discovery_entries,
            "max_records": options.max_records,
            "max_file_bytes": options.max_file_bytes,
            "max_line_bytes": options.max_line_bytes,
        },
        "scan": stats_dict(stats),
        "candidates": build_candidates(messages, options),
    }


def render_text(report: dict[str, Any]) -> str:
    scan = report["scan"]
    lines = [
        "Agent history mining summary",
        (
            f"files {scan['processed_files']}/{scan['selected_files']} selected "
            f"({scan['discovered_files']} discovered), records {scan['records_read']}"
        ),
        (
            f"prompts kept {scan['messages_kept']}, noise {scan['noise_filtered']}, "
            f"duplicates {scan['duplicate_suppressed']}"
        ),
        f"sources {json.dumps(scan['source_counts'], ensure_ascii=False, sort_keys=True)}",
        f"scopes {json.dumps(scan['scope_counts'], ensure_ascii=False, sort_keys=True)}",
        "",
        "rank  score  action    count  stability  risk  overlap  candidate / existing",
    ]
    for item in report["candidates"]:
        existing = f" / {item['existing_skill']}" if item.get("existing_skill") else ""
        lines.append(
            f"{item['rank']:>4}  {item['score']:>5.1f}  {item['recommendation']:<8}  "
            f"{item['count']:>5}  {item['stability_score']:>9.3f}  {item['risk_score']:>4.2f}  "
            f"{item['existing_overlap']:>7.3f}  {item['label']}{existing}"
        )
        if item.get("sample_redacted"):
            lines.append(f"      sample: {item['sample_redacted']}")
    if not report["candidates"]:
        lines.append("   -  no candidate reached the minimum frequency")
    if (
        scan["discovery_truncated"]
        or scan["truncated"]
        or scan["skipped_oversize_files"]
        or scan["oversize_lines"]
    ):
        lines.extend(["", "warning: one or more configured scan bounds were reached"])
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Mine bounded Codex/Claude JSONL histories without emitting raw prompts or paths."
    )
    parser.add_argument("paths", nargs="*", help="Explicit JSONL files or directories (required).")
    parser.add_argument("--source", choices=("auto", "codex", "claude"), default="auto")
    parser.add_argument("--scope", choices=("root", "subagent", "all"), default="root")
    parser.add_argument("--since-days", type=int, default=90, help="0 disables timestamp filtering.")
    parser.add_argument("--max-files", type=int, default=200)
    parser.add_argument("--max-discovered-files", type=int, default=2000)
    parser.add_argument("--max-discovery-entries", type=int, default=20000)
    parser.add_argument("--max-records", type=int, default=50000)
    parser.add_argument("--max-file-bytes", type=int, default=64 * 1024 * 1024)
    parser.add_argument("--max-line-bytes", type=int, default=1024 * 1024)
    parser.add_argument("--max-chars", type=int, default=20000)
    parser.add_argument("--min-frequency", type=int, default=3)
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--skills-dir", action="append", default=[], help="Explicit existing skill root.")
    parser.add_argument("--include-snippets", action="store_true")
    parser.add_argument("--snippet-length", type=int, default=96)
    parser.add_argument("--hash-salt", help=argparse.SUPPRESS)
    parser.add_argument("--self-test", action="store_true")
    return parser


def positive_or_zero(name: str, value: int, allow_zero: bool = False) -> int:
    minimum = 0 if allow_zero else 1
    if value < minimum:
        raise ValueError(f"{name} must be >= {minimum}")
    return value


def options_from_args(args: argparse.Namespace) -> Options:
    positive_or_zero("since-days", args.since_days, allow_zero=True)
    for name in (
        "max_files",
        "max_discovered_files",
        "max_discovery_entries",
        "max_records",
        "max_file_bytes",
        "max_line_bytes",
        "max_chars",
        "min_frequency",
        "top",
        "snippet_length",
    ):
        positive_or_zero(name.replace("_", "-"), getattr(args, name))
    return Options(
        source=args.source,
        scope=args.scope,
        since_days=args.since_days,
        max_files=args.max_files,
        max_discovered_files=args.max_discovered_files,
        max_discovery_entries=args.max_discovery_entries,
        max_records=args.max_records,
        max_file_bytes=args.max_file_bytes,
        max_line_bytes=args.max_line_bytes,
        max_chars=args.max_chars,
        min_frequency=args.min_frequency,
        top=args.top,
        include_snippets=args.include_snippets,
        snippet_length=args.snippet_length,
        hash_salt=args.hash_salt or secrets.token_hex(16),
        skills_dirs=[Path(path).expanduser() for path in args.skills_dir],
    )


def run_self_test() -> None:
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    with tempfile.TemporaryDirectory(prefix="agent-history-miner-") as tmp:
        base = Path(tmp)
        codex = base / "codex"
        claude = base / "claude"
        subagents = claude / "session" / "subagents"
        skills = base / "skills" / "git-ops"
        discovery_a = base / "discovery-a"
        discovery_b = base / "discovery-b"
        symlink_target = base / "symlink-target"
        codex.mkdir()
        claude.mkdir()
        subagents.mkdir(parents=True)
        skills.mkdir(parents=True)
        discovery_a.mkdir()
        discovery_b.mkdir()
        symlink_target.mkdir()

        def write_jsonl(path: Path, records: list[dict[str, Any]]) -> None:
            path.write_text("".join(json.dumps(r) + "\n" for r in records), encoding="utf-8")

        codex_prompt = "Review PR 123, token=supersecret, then run tests and verify before merge."
        for index, number in enumerate((123, 456), 1):
            write_jsonl(codex / f"rollout-{index}.jsonl", [
                {"type": "session_meta", "timestamp": now, "payload": {"thread_source": "user"}},
                {"type": "event_msg", "timestamp": now, "payload": {"type": "user_message", "message": codex_prompt.replace("123", str(number))}},
                {"type": "response_item", "timestamp": now, "payload": {"type": "message", "role": "user", "content": [{"type": "input_text", "text": codex_prompt.replace("123", str(number))}]}},
                {"type": "event_msg", "timestamp": now, "payload": {"type": "user_message", "message": "/model opus"}},
            ])
        write_jsonl(claude / "root.jsonl", [
            {"type": "user", "timestamp": now, "isSidechain": False, "message": {"role": "user", "content": "Commit and push branch 789 after tests, then verify."}},
            {"type": "user", "timestamp": now, "isSidechain": False, "message": {"role": "user", "content": "[Pasted text #1 +200 lines]"}},
            {"type": "user", "timestamp": now, "isSidechain": False, "message": {"role": "user", "content": [{"type": "tool_result", "content": "ignore"}]}},
        ])
        write_jsonl(subagents / "agent-a.jsonl", [
            {"type": "user", "timestamp": now, "isSidechain": True, "agentId": "a", "message": {"role": "user", "content": "Review PR 999 then run tests and verify."}},
        ])
        (skills / "SKILL.md").write_text(
            "---\nname: git-ops\ndescription: Commit, push, merge, and pull request workflow.\n---\n",
            encoding="utf-8",
        )
        for directory, names in (
            (discovery_a, ("a-1.jsonl", "a-2.jsonl")),
            (discovery_b, ("b-1.jsonl", "b-2.jsonl")),
        ):
            for name in names:
                write_jsonl(directory / name, [])
        write_jsonl(symlink_target / "hidden.jsonl", [])
        (discovery_a / "linked-directory").symlink_to(symlink_target, target_is_directory=True)

        discovered, discovered_count, entry_count, discovery_truncated = discover_files(
            [str(discovery_a), str(discovery_b)],
            max_files=10,
            max_discovered_files=3,
            max_discovery_entries=100,
        )
        assert len(discovered) == discovered_count == 3
        assert entry_count <= 100
        assert discovery_truncated is True
        assert all(path.name != "hidden.jsonl" for path in discovered)

        _, _, capped_entries, entry_truncated = discover_files(
            [str(discovery_a), str(discovery_b)],
            max_files=10,
            max_discovered_files=100,
            max_discovery_entries=1,
        )
        assert capped_entries == 1
        assert entry_truncated is True

        redacted_paths = redact(
            r"Read /srv/company/private/spec.md, C:\Users\alice\secret\plan.txt, "
            r"\\fileserver\private-share\roadmap.docx, src/private/config.json, "
            r"./local/cache.json, and ../shared/policy.md"
        )
        assert redacted_paths.count("<path>") == 6, redacted_paths
        assert not any(
            value in redacted_paths
            for value in (
                "/srv/",
                "alice",
                "fileserver",
                "src/private/config.json",
                "./local/cache.json",
                "../shared/policy.md",
            )
        )

        args = build_parser().parse_args([
            str(codex), str(claude), "--scope", "all", "--since-days", "0",
            "--min-frequency", "2", "--format", "json", "--hash-salt", "fixture-salt",
            "--skills-dir", str(base / "skills"), "--include-snippets",
        ])
        options = options_from_args(args)
        messages, stats = scan_histories(args.paths, options)
        report = make_report(messages, stats, options)
        serialized = json.dumps(report, ensure_ascii=False)
        assert report["scan"]["discovery_truncated"] is False
        assert stats.source_counts["codex"] == 2, stats.source_counts
        assert stats.source_counts["claude"] == 2, stats.source_counts
        assert stats.scope_counts["root"] == 3, stats.scope_counts
        assert stats.scope_counts["subagent"] == 1, stats.scope_counts
        assert stats.noise_filtered == 3, stats.noise_filtered
        assert stats.duplicate_suppressed == 2, stats.duplicate_suppressed
        assert "supersecret" not in serialized
        assert "Pasted text" not in serialized
        assert not any(str(base) in serialized for _ in (0,))
        git_candidate = next(item for item in report["candidates"] if item["label"] == "git-lifecycle")
        assert git_candidate["recommendation"] == "optimize", git_candidate
        assert git_candidate["existing_skill"] == "git-ops", git_candidate
        assert all("sample_redacted" in item for item in report["candidates"])
        assert render_text(report).startswith("Agent history mining summary")
        options.include_snippets = False
        strict_report = make_report(messages, stats, options)
        assert all("sample_redacted" not in item for item in strict_report["candidates"])
    print("self-test: PASS")


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
        return 0
    if not args.paths:
        parser.error("at least one explicit JSONL file or directory is required")
    try:
        options = options_from_args(args)
        messages, stats = scan_histories(args.paths, options)
        report = make_report(messages, stats, options)
    except (FileNotFoundError, ValueError) as error:
        parser.error(str(error))
    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(render_text(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
