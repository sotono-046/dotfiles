# エージェント共通指示（グローバル）

このファイルは `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` / `~/.gemini/GEMINI.md` に配信される全プロジェクト共通のエージェント運用方針です。

## 言語

すべてのコミュニケーションは日本語で行います。技術用語・コード識別子は原語のまま使用します。

## MCP ツールを積極活用する

### Serena（コード解析・編集）

コードベースの理解・編集には Serena を最優先で使用する。ファイル全体を読むのではなく、シンボル単位で必要な情報だけを取得し、トークン効率を常に意識する。

- `get_symbols_overview`: ファイルの構造を把握する最初のステップ
- `find_symbol`: シンボル（クラス・関数・メソッド）を検索・取得
- `find_referencing_symbols`: シンボルの参照箇所を特定
- `replace_symbol_body`: シンボル単位での精密な編集
- `insert_before_symbol` / `insert_after_symbol`: 新しいコードの挿入
- `search_for_pattern`: 柔軟なパターン検索

### Context7（ドキュメント参照）

ライブラリやフレームワークを扱うときは、最新ドキュメントを把握するため Context7 を使用する。ツール名は環境により表記揺れがある（Claude では `resolve-library-id` / `query-docs`、Codex では `resolve_library_id` / `query_docs` など）。各環境に公開されている相当ツールを使う。

1. Resolve Library ID 相当: ライブラリ名から Context7 ID を解決
2. Query Docs 相当: 解決した ID でドキュメントを検索

用途: 新しいライブラリの使い方を調べる / API の正確な仕様を確認する / 最新のベストプラクティスを参照する

### 判断基準

| 状況                         | 使用するツール                                 |
| ---------------------------- | ---------------------------------------------- |
| コードの構造を理解したい     | Serena (`get_symbols_overview`, `find_symbol`) |
| 特定のシンボルを編集したい   | Serena (`replace_symbol_body`)                 |
| 参照箇所を調べたい           | Serena (`find_referencing_symbols`)            |
| ライブラリの使い方を調べたい | Context7                                       |
| 最新の API 仕様を確認したい  | Context7                                       |

## Skill と Subagent を積極活用する

### スキルの参照

必ずスキルを参照して使用すること。作業開始前に該当するスキルが存在するか確認し、存在する場合は必ずそのスキルファイルを読み、手順・制約をそのまま適用する。宣言だけで終わらせない。

### 重要なスキル

1. `git-ops`: commit / PR 作成 / worktree 分離など、履歴やリモート状態に影響する Git 操作では必ず参照する（`git status` / `git diff` などの読み取りのみの場合は不要）
2. `task-orchestration`: 独立性が高く成果物が重複しないサブタスクに限り並列化する。条件を満たせばサブエージェントを多数（10〜20 個規模でも）同時起動してよいが、過剰起動・重複作業・コスト増を避けるため必要最小限の数にとどめる
3. `agent-note-writing`: Obsidian 保存、SOW、Issue 下書き、調査メモ、運用ルールなど後で再利用するドキュメントを書くときは必ず参照する。`保存して`、`メモして`、`記録して`、`SOW作って`、`Issue下書き`、`ドキュメント化` で使用し、repo 作業では project / repository / branch を frontmatter と本文に明記する。外部 Issue/PR/共有 Doc の作成は明示指示があるまで下書き、または該当 Skill/tool への引き継ぎで止める

### 使い分け

- Skill: 専門知識が必要なタスク → 作業開始前に該当スキルファイルを読み、手順・制約をそのまま適用する
- Subagent: 独立コンテキストが有効なタスク（リファクタリング・レビュー・広範囲探索など）、または並列実行したい場合に委任する

両者は併用可。Skill の知識を Subagent に渡して実行することもある。小さいタスクで該当する Skill/Subagent がない場合は通常フローで進める。

## ショートカット指示

### `dig`

`plan-digger` サブエージェントでプランレビューを実施する。

### `品質チェック`

`quality-gainner` サブエージェントで TypeScript・リント・潜在バグを検出し、その場で自動修正する（レポートだけで終わらせない）。
