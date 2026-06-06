---
name: plan-digger
description: "コードベースの品質・セキュリティ・パフォーマンスを複数サブエージェントで包括検証し、devil's advocate で前提を崩してから SOW 形式の改善計画を策定する。"
---

# plan-digger

コードベースの品質・セキュリティ・パフォーマンスを包括的に検証し、改善計画を策定する。単独レビューで終わらせず、可能な環境では複数の読み取り専用レビューワーを並列起動し、最後に悪魔の代弁者として前提・スコープ・代替案を疑う。

## 前提

- `codex` CLI が利用可能（`codex exec` で非対話実行する）
- Task/Subagent 起動ツールが利用可能な環境では、`task-orchestration` の原則に従って複数レビューワーを並列起動する。専用 reviewer agent は増やさず、読み取り専用が確認できる `Explore` を観点別 prompt で使う。
- `Explore` の公開 tool list に編集・書き込み・mutating Bash・外部投稿系 tool が含まれる、または権限を確認できない場合は、`codex exec -C "$TARGET_REPO" --sandbox read-only -` へフォールバックする。
- レビュー実行は repo を `-C "$TARGET_REPO"` で固定し、prompt を stdin または prompt file から渡す。issue/plan 由来の未信頼テキストを shell 引数へ直接補間しない。
- 長めのコードベース調査や反復レビューで早期終了しないよう、明示的な理由がない限り 30 分を既定タイムアウトにする。`timeout` がない環境では tool 側 timeout、macOS では `gtimeout`、または同等の上限設定を使う。
- 旧 Claude CLI 手順は使用しない。過去の手順や既存プロンプトに残っている場合も `codex exec` に置き換える。
- reviewer 用途では `-c` config override を原則使わない。必要な場合も model 等の安全なキーに限定し、`sandbox*` / `approval*` / `shell_environment_policy*` / `mcp_servers*` / `tools*`、`--dangerously-*`、`--add-dir`、`--ignore-rules` は使わない。

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

1. 入力パッケージ作成: 対象 repo の絶対パス、issue/plan、スコープ内ファイル、除外範囲、secret/PII 除外、既知の制約、保存要否、最小 validation を 1 つにまとめる。`.env`、credential、session dump、cookie、secret-bearing log は原則読ませず、必要な場合はユーザー承認を挟む。
2. 複数レビューワー並列レビュー: `security` / `correctness` / `performance` / `maintainability` / `test` / `devil's advocate` を読み取り専用で起動する。ユーザーが指定した観点は必ず含める。軽量タスクで未指定なら `correctness` / `test` と、リスクに応じた 1 観点に縮退してよい。
   - security-sensitive、secret、権限境界、破壊的操作を含む場合は `security` を入れる。
   - docs、skill、command、設計整理が主対象なら `maintainability` を入れる。
   - Task/Subagent では read-only が確認できる場合だけ `subagent_type: Explore` を使う。
   - fallback では初手を 1 回の multi-perspective `codex exec`、または最大 `correctness` / `test` / `devil's advocate` + 必要観点に縮退する。フル 6 観点へ広げる前に見積もりと必要性を確認する。
3. 統合: 指摘を重複排除し、重大度・根拠・confidence・SOW 反映要否を司令塔が判定する。レビューワー出力をそのまま貼らない。
4. SOW 更新: High は解消方針を必須化し、Medium は対応方針または明示的な受容理由を記載する。Low は必要なものだけ注記する。
5. 最終レビュー: SOW を大きく変更した観点だけ再レビューし、最後に `devil's advocate` で前提崩れ・過大スコープ・代替案を確認する。
6. 収束: High が 0 件、Medium が対応または受容済み、最終 devil's advocate が evidence-backed な新規 High/Medium を出さない時点で終了する。

### サブエージェントに渡す共通指示

すべてのレビューワーは read-only で実行する。編集、commit、PR 作成、テスト自動修正は禁止する。`task-executor`、`quality-gainner`、`task-researcher`、`Research` など編集可能な agent を reviewer として使わない。

Task/Subagent で起動する場合:

```text
subagent_type: Explore
prompt: "<共通指示> role=<観点> reviewer ..."
```

`codex exec` で起動する場合は必ず repo を `-C` で固定し、`--sandbox read-only` を付ける。詳細な prompt template と fallback command は `references/reviewer-prompts.md` を参照する。

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
- レビューワー間で事実認定や重大度が矛盾し、コード根拠で解消できない場合は、利用環境に公開されているユーザー確認ツール（Claude では `AskUserQuestion`、Codex では `request_user_input` 相当）を使う。質問ツールがなければ通常返信で blocking question を返して停止する。
- Low を 0 件にするための反復はしない。

### codex exec の使い方

```bash
# repo を固定し、prompt file を stdin から渡す（既定タイムアウトは 30 分）
TARGET_REPO=/absolute/path/to/repo
timeout 1800 codex exec -C "$TARGET_REPO" --sandbox read-only - < /path/to/reviewer-prompt.txt

# timeout がない macOS 環境では gtimeout または実行ツール側の timeout を使う
gtimeout 1800 codex exec -C "$TARGET_REPO" --sandbox read-only - < /path/to/reviewer-prompt.txt
```

prompt は `references/reviewer-prompts.md` の input package block を先頭に置く。未信頼テキストを shell 引数へ埋め込まない。Bash ツール側でタイムアウトを指定できる環境では 1800000ms を設定し、shell wrapper を使う場合は `timeout 1800` または `gtimeout 1800` を付ける。reviewer 用途では `-C "$TARGET_REPO"` と `--sandbox read-only` を外さない。

## 承認基準

- High: 0 件必須
- Medium: 対応方針または受容理由を SOW に明記。重要フロー、security、data loss、破壊的操作に関わる Medium はユーザー判断を挟む。
- Low: 任意（注記のみ）

## 調査

- 必要に応じて追加調査を行う
- 調査結果は必ずコードベースの該当箇所と紐づけて記録
- 懸念事項など、ユーザーに判断を求める場合は、利用可能なユーザー確認ツールを使う。なければ通常返信で短い確認質問を返して停止する。

## 成果物

### プラン文書

- 形式: SOW（Statement of Work）
- 保存モード:
  - `report-only`: レビュー結果だけ返す。保存しない。
  - `draft-sow`: 会話上に SOW 下書きを返す。保存しない。
  - `save-sow`: 有効な project instructions（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`）と `agent-note-writing` に従って保存する。保存先がない場合は `.temp/YYYY-MM-DD/<slug>.md`（slug はケバブケース）を候補にする。
- mode 判定:
  - `レビューだけ`、`指摘だけ`、`レビューにかけて` は `report-only`。
  - `SOW作って`、`計画にして`、`実装計画をまとめて` は `draft-sow`。
  - `保存して`、保存先パス、Obsidian/vault 指定がある場合のみ `save-sow`。
- SOW / Issue 下書きは保存の有無に関係なく、作成前に `agent-note-writing` を読み、本文構造、repo context、frontmatter、秘匿情報ルールを適用する。
- レビューごとにブラッシュアップし、最終版を残す

## 終了条件

High が 0、Medium が対応または受容済み、採用した指摘に根拠・影響・修正方針があり、最終 devil's advocate で新規 High/Medium が出なくなった時点で終了。

## references 指針

- Core workflow と承認基準はこのファイルを source of truth にする。`agent/agents/plan-digger.md` はこの skill を参照する入口に留め、詳細手順を重複させない。
- Subagent prompt template、fallback command、SOW template、regression scenario は `references/` に分離する。本体に残す command 例は最小起動例 1 つまでにする。

## この skill を変更したときの検証

- `git diff --check`
- `codex exec --help` で `-C/--cd` と `--sandbox read-only` が存在することを確認
- `SKILL.md` の YAML frontmatter が parse できることを確認
- Markdown を目視し、見出し、コードブロック、参照先が壊れていないことを確認
- `rg` で旧式の fallback command、環境固定の質問ツール名、保存モード既定、編集可能 reviewer 名などが `agent/agents/plan-digger.md` と drift していないか確認
- `レビューだけして`、`SOW作って`、`保存して`、`role=maintainability reviewer`、同一 issue family 再発の 5 シナリオで、mode 判定、read-only 契約、ユーザー確認、escalation が期待どおりか確認
