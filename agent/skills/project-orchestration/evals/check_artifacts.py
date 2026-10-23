#!/usr/bin/env python3
import hashlib
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit("usage: check_artifacts.py INITIAL_DIRECTORY RESULT_DIRECTORY")

initial, result = (Path(value).resolve() for value in sys.argv[1:])
unchanged_paths = [
    "project/maple/maple.md",
    "project/harbor/handoffs/h001.md",
    "delivery/items.csv",
    "delivery/docs.csv",
    "delivery/requirements.md",
    "delivery/reports.md",
]
preserved_fragments = [
    "---\nproject: Harbor\nowner_note: 人が管理する項目\n---",
    "この言い回しは残す。「資料が見つからない」を起点に相談する。",
    "[[参考ノート#検索]]",
    "- 2026-10-20: 予算上限を月10,000円とした。",
]
failures = []
for relative in unchanged_paths:
    if not (result / relative).is_file():
        failures.append(f"missing: {relative}")
    elif (initial / relative).read_bytes() != (result / relative).read_bytes():
        failures.append(f"changed: {relative}")

note = result / "project/harbor/harbor.md"
content = note.read_text() if note.is_file() else ""
for fragment in preserved_fragments:
    if fragment not in content:
        failures.append(f"lost note content: {fragment}")

for number in (1, 2, 3):
    response = result / f"inbox/{number:02d}-response.md"
    if not response.is_file() or not response.read_text().strip():
        failures.append(f"missing response: {response.name}")

handoffs = result / "project/harbor/handoffs"
new_handoffs = [p for p in handoffs.glob("*.md") if p.name != "h001.md"]
if not new_handoffs:
    failures.append("missing new handoff")

for relative in unchanged_paths:
    target = result / relative
    if target.is_file():
        print(hashlib.sha256(target.read_bytes()).hexdigest(), relative)
for failure in failures:
    print(f"FAIL {failure}")
print("Artifact preservation:", "FAIL" if failures else "PASS")
print("Decision semantics, dispatch history and out-of-scope writes require separate review.")
raise SystemExit(bool(failures))
