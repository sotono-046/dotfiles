---
name: plan-digger
description: "コードベースの品質・セキュリティ・パフォーマンスを複数サブエージェントで包括検証し、devil's advocate で前提を崩してから SOW 形式の改善計画を策定する。"
---

# plan-digger

コードベースの品質・セキュリティ・パフォーマンスを包括的に検証し、改善計画を策定する。単独レビューで終わらせず、可能な環境では複数の読み取り専用レビューワーを並列起動し、最後に悪魔の代弁者として前提・スコープ・代替案を疑う。

## 前提

- `codex` CLI が利用可能（`codex exec` で非対話実行する）
- Task/Subagent 起動ツールが利用可能な環境では、`task-orchestration` の原則に従って複数レビューワーを並列起動する。専用 reviewer agent は増やさず、読み取り専用の `Explore` を観点別 prompt で使う。`Explore` が使えない場合は同じ観点を `timeout 1800 codex exec --sandbox read-only ...` の reviewer prompt として順次実行する。
- レビュー実行は `timeout 1800 codex exec --sandbox read-only ...` を基本形にする。長めのコードベース調査や反復レビューで早期終了しないよう、明示的な理由がない限り 30 分を既定タイムアウトにする。
- 旧 Claude CLI 手順は使用しない。過去の手順や既存プロンプトに残っている場合も `codex exec` に置き換える。

## レビュー観点

下記について厳しくレビューを行う。
また、すべての指摘はコードベースを根拠とすること。

- **security**: 認証・認可、secret、injection、data exposure、権限境界
- **correctness**: 状態遷移、edge case、例外系、競合、型・契約違反
- **performance**: hot path、I/O、再計算、メモリ、スケール時の劣化
- **maintainability**: 責務分離、重複、命名、変更容易性、過剰抽象化
- **test**: 既存テスト不足、必要な regression、最小 validation command
- **devil's advocate**: 前提・スコープ・実装順序・より単純な代替案

## レビュー方法

1. 入力パッケージ作成: 対象 repo、issue/plan、スコープ内ファイル、除外範囲、既知の制約、保存要否を 1 つにまとめる。
2. 複数レビューワー並列レビュー: `security` / `correctness` / `performance` / `maintainability` / `test` / `devil's advocate` を読み取り専用で起動する。Task/Subagent では `subagent_type: Explore` を使い、`Explore` がなければ `codex exec --sandbox read-only` にフォールバックする。軽量タスクでは `security` / `correctness` / `test` の 3 観点に縮退してよい。
3. 統合: 指摘を重複排除し、重大度・根拠・confidence・SOW 反映要否を司令塔が判定する。レビューワー出力をそのまま貼らない。
4. SOW 更新: High は解消方針を必須化し、Medium は対応方針または明示的な受容理由を記載する。Low は必要なものだけ注記する。
5. 最終レビュー: SOW を大きく変更した観点だけ再レビューし、最後に `devil's advocate` で前提崩れ・過大スコープ・代替案を確認する。
6. 収束: High が 0 件、Medium が対応または受容済み、最終 devil's advocate が evidence-backed な新規 High/Medium を出さない時点で終了する。

### サブエージェントに渡す共通指示

すべてのレビューワーは read-only で実行する。編集、commit、PR 作成、テスト自動修正は禁止する。`task-executor`、`quality-gainner`、`task-researcher` など編集可能な agent を reviewer として使わない。

Task/Subagent で起動する場合:

```text
subagent_type: Explore
prompt: "<共通指示> role=<観点> reviewer ..."
```

`codex exec` で起動する場合は必ず `--sandbox read-only` を付ける。

```text
対象を <観点> としてレビューしてください。編集・commit・PR 作成は禁止です。
根拠のない推測は assumption と明記してください。
High/Medium を優先し、最大 5 件までに絞ってください。
各指摘は id / severity / confidence / evidence(file:line) / risk / recommendation / validation / assumptions の形式で返してください。
secret/PII は引用せず redacted excerpt または要約にしてください。
```

`devil's advocate` には追加で次を渡す。

```text
この計画が失敗するとしたらどこか、より小さく安全な代替案はないか、前提・スコープ・実装順序を疑ってください。
差し戻し可能なのは evidence-backed な High/Medium のみです。根拠の弱い Low は SOW のリスク注記候補に留めてください。
```

### ループ制限

- フル 6 観点レビューは最大 2 周まで。
- 3 周目以降は、SOW の変更箇所に関係する観点だけ再実行する。targeted review は最大 2 回まで。ただし同一 issue family が再発した場合は最大回数より優先してその時点で止め、ユーザー判断へエスカレーションする。
- レビューワー間で事実認定や重大度が矛盾し、コード根拠で解消できない場合は `AskUserQuestion` で確認する。
- Low を 0 件にするための反復はしない。

### codex exec の使い方

```bash
# プロンプトを引数で渡し、結果を標準出力で受け取る（既定タイムアウトは 30 分）
timeout 1800 codex exec --sandbox read-only 'このディレクトリのコードを security 観点でレビューし、id / severity / confidence / evidence(file:line) / risk / recommendation / validation / assumptions の形式で最大5件まで返してください'

# プロンプトを stdin から渡す（長文や heredoc 向け）
timeout 1800 codex exec --sandbox read-only - <<'EOF'
以下の観点で <対象ファイル> をレビューせよ:
- security
- correctness
- performance
- maintainability
- test
- devil's advocate
EOF
```

`-c` オプションで `~/.codex/config.toml` の設定を一時オーバーライド可能。永続的な MCP セットアップは不要で、一回の `codex exec` 呼び出しで完結する。Bash ツール側でタイムアウトを指定できる環境では 1800000ms を設定し、shell wrapper を使う場合は `timeout 1800` を付ける。reviewer 用途では `--sandbox read-only` を外さない。

## 承認基準

- High: 0 件必須
- Medium: 対応方針または受容理由を SOW に明記。重要フロー、security、data loss、破壊的操作に関わる Medium はユーザー判断を挟む。
- Low: 任意（注記のみ）

## 調査

- 必要に応じて追加調査を行う
- 調査結果は必ずコードベースの該当箇所と紐づけて記録
- 懸念事項など、ユーザーに判断を求める場合は `AskUserQuestion` ツールを使って質問してください。

## 成果物

### プラン文書

- 形式: SOW（Statement of Work）
- 保存モード:
  - `report-only`: レビュー結果だけ返す。保存しない。
  - `draft-sow`: 会話上に SOW 下書きを返す。保存しない。
  - `save-sow`: `CLAUDE.md` にて指定された保存先がある場合はそれに準じ、ない場合は `.temp/YYYY-MM-DD/<slug>.md`（slug はケバブケース）に保存する。
- ユーザーが保存を明示した場合、または `SOW作って` が保存先つきで指示された場合のみ `save-sow` を選ぶ。明示がなければ `draft-sow` を既定にする。
- レビューごとにブラッシュアップし、最終版を残す

## 終了条件

High が 0、Medium が対応または受容済み、採用した指摘に根拠・影響・修正方針があり、最終 devil's advocate で新規 High/Medium が出なくなった時点で終了。

## references 指針

- Core workflow はこのファイルに残す。subagent prompt template や SOW template が肥大化する場合は `references/reviewer-prompts.md`、`references/sow-template.md` 等へ分離する。
