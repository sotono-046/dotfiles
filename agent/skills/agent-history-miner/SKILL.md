---
name: agent-history-miner
description: Codex rollout JSONL と Claude Code project JSONL を安全かつ bounded に集計し、反復タスク、skill 化候補、既存 skill の最適化候補を抽出する。ユーザーが「Codex/Claude の履歴を分析」「繰り返し作業を skill 化」「agent workflow を棚卸し」「履歴から自動化候補を探す」と依頼したときに使用する。
---

# Agent History Miner

構造化された agent 履歴を read-only で走査し、本文をそのまま出さずに再利用候補を集計する。

## 実行手順

1. 対象 path と期間をユーザーの scope から確定する。path を推測して home 全体を探索しない。
2. 最初は root session のみを bounded に集計する。

```bash
python3 scripts/history_miner.py /explicit/codex/sessions /explicit/claude/projects \
  --scope root --since-days 90 --max-files 200 \
  --max-discovered-files 2000 --max-discovery-entries 20000 --max-records 50000 \
  --skills-dir /explicit/repo/agent/skills
```

3. 必要な場合だけ `--scope all` で subagent 指示も含め、`scope_counts` を分けて解釈する。root と subagent を単純合算してユーザー需要とみなさない。
4. 機械処理には `--format json`、人向け確認には既定の text を使う。
5. 候補ごとに `count`、`stability`、`risk`、`existing_overlap` を確認する。
   - `create`: 対応する既存 skill が薄い反復 workflow
   - `optimize`: 既存 skill と重なるが、履歴上の反復や手順安定性が高い workflow
   - 高 risk は自動化範囲を狭め、承認・dry-run・validation を skill に組み込む
6. 必要なときだけ `--include-snippets` を使う。出力は redaction 済みかつ短いが、共有前に目視確認する。

## 安全境界

- 入力 path は必須。既定 path や home-wide scan を持たせない。
- 既定上限は 90 日、2,000 discovered files、20,000 discovery entries、200 selected files、50,000 records、64 MiB/file、1 MiB/line とする。
- directory symlink を辿らない。`discovery_truncated` が true の結果は探索上限内の部分集計として扱う。
- 履歴を変更・削除せず、stdout への集計だけを行う。
- raw prompt、file path、session ID、secret を出力しない。fingerprint は実行ごとの keyed hash にする。
- slash command、`/model`、pasted placeholder、system reminder、tool result を需要として数えない。
- 同一 session 内の同一 normalized prompt は一度だけ数える。
- `--source` / `--scope` の分類が不確かな履歴は集計値を確定事実として扱わず、`unknown_source_records` を報告する。

## 補助コマンド

```bash
python3 scripts/history_miner.py --self-test
python3 scripts/history_miner.py --help
```

`--self-test` は一時 fixture だけを使い、Codex/Claude schema、root/subagent 分離、noise 除外、secret 非露出を検証する。
