# エージェント共通指示（グローバル）

このファイルは `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md` / `~/.gemini/GEMINI.md` に配信される全プロジェクト共通のエージェント運用方針です。

## 言語

Think in English, interact with the user in Japanese.

内部の思考・推論・計画立案は英語で行い、ユーザーへの応答（説明・回答・コミュニケーション）はすべて日本語で行います。技術用語・コード識別子は原語のまま使用します。

## MCP ツールを積極活用する

### Serena（コード解析・編集）

コードベースの理解・編集には Serena を最優先で使用する。ファイル全体を読むのではなく、シンボル単位で必要な情報だけを取得し、トークン効率を常に意識する。

- `get_symbols_overview`: ファイルの構造を把握する最初のステップ
- `find_symbol`: シンボル（クラス・関数・メソッド）を検索・取得
- `find_referencing_symbols`: シンボルの参照箇所を特定
- `replace_symbol_body`: シンボル単位での精密な編集
- `insert_before_symbol` / `insert_after_symbol`: 新しいコードの挿入
- `search_for_pattern`: 柔軟なパターン検索

### 判断基準

| 状況                         | 使用するツール                                 |
| ---------------------------- | ---------------------------------------------- |
| コードの構造を理解したい     | Serena (`get_symbols_overview`, `find_symbol`) |
| 特定のシンボルを編集したい   | Serena (`replace_symbol_body`)                 |
| 参照箇所を調べたい           | Serena (`find_referencing_symbols`)            |

## 公式ドキュメントを一次情報にする

ライブラリ・フレームワーク・CLI・クラウドサービスを扱うときは、事前学習の記憶ではなく **公式ドキュメントを WebSearch / WebFetch で取得して確認する**。専用スキルは持たない（ドキュメントで足りるものはスキル化しない方針）。

- **必ず確認するケース**: API シグネチャ、CLI のフラグ・サブコマンド、設定ファイルのスキーマ、バージョン依存の挙動、料金・制限値、非推奨化の有無
- **参照先の優先順位**: 公式 docs / リポジトリの README・CHANGELOG > 公式ブログ > それ以外。二次情報（Qiita、ブログ、Stack Overflow）は手がかりに留め、最終確認は一次情報で行う
- **代表的な参照先**: Cloudflare (developers.cloudflare.com)、Vercel / Next.js (vercel.com/docs, nextjs.org/docs)、Playwright (playwright.dev)、dotenvx (dotenvx.com)、GitHub CLI (cli.github.com/manual)、Google Cloud (cloud.google.com/docs)
- バージョンが問題になる場合は、まず手元の lockfile / `--version` で実際のバージョンを確認してから、そのバージョンに対応するドキュメントを読む
- ネットワークが使えない環境では、記憶ベースであることと検証未実施であることを明記する

## Skill と Subagent を積極活用する

### スキルの参照

必ずスキルを参照して使用すること。作業開始前に該当するスキルが存在するか確認し、存在する場合は必ずそのスキルファイルを読み、手順・制約をそのまま適用する。宣言だけで終わらせない。

### 重要なスキル

1. `git-ops`: commit / PR 作成など、履歴やリモート状態に影響する Git 操作では必ず参照する（`git status` / `git diff` などの読み取りのみの場合は不要）
2. `task-orchestration`: 独立性が高く成果物が重複しないサブタスクに限り並列化する。条件を満たせばサブエージェントを多数（10〜20 個規模でも）同時起動してよいが、過剰起動・重複作業・コスト増を避けるため必要最小限の数にとどめる
3. `agent-note-writing`: Obsidian 保存、SOW、Issue 下書き、調査メモ、運用ルールなど後で再利用するドキュメントを書くときは必ず参照する。`保存して`、`メモして`、`記録して`、`SOW作って`、`Issue下書き`、`ドキュメント化` で使用し、repo 作業では project / repository / branch を frontmatter と本文に明記する。外部 Issue/PR/共有 Doc の作成は明示指示があるまで下書き、または該当 Skill/tool への引き継ぎで止める
4. `fairy-tale`: 以下のいずれかに当てはまるタスクでは、作業開始前に `fairy-tale` スキルを読み、Glass Slipper Gate（予算: 最大サブタスク数 / ファイル数 / web 検索数 / tool call 数 / 経過時間）と Implementation Validation Gate（focused check + 隣接互換チェック + validation ledger）を適用する。description マッチを待たず、条件に該当した時点で能動的にロードする。
   - 長時間コーディング / コードベース横断のリファクタリング・移行（Fable Harness）
   - 多エージェント fan-out、長い autonomous run、context resume を伴う作業
   - 防御目的のセキュリティレビュー（Mythos / Cyber Frontier Defense Harness、OWASP LLM 含む）
   - 法務 / HLE 風の閉形式回答 / bio・health / 財務・文書分析 / 3D・CAD / ARC 系発見タスク（Domain Router で経路選択）
   - SWE-Bench Pro / ExploitBench などのベンチマーク再現・フィードバック適用
   - 同じ失敗が 3 回以上繰り返される、または validation ledger を作れないとき（Fairy Fusion 自動発火条件）
   - 小規模な単発タスク・対話・ドキュメント執筆のみの作業では適用しない（過剰になるため）

### 使い分け

- Skill: 専門知識が必要なタスク → 作業開始前に該当スキルファイルを読み、手順・制約をそのまま適用する
- Subagent: 独立コンテキストが有効なタスク（リファクタリング・レビュー・広範囲探索など）、または並列実行したい場合に委任する

両者は併用可。Skill の知識を Subagent に渡して実行することもある。小さいタスクで該当する Skill/Subagent がない場合は通常フローで進める。

### 並列修正（ファイル非競合グループ + サブエージェント直接修正）

レビュー指摘の一括修正など、独立した修正タスクを並列でこなす場合は、**指摘をファイル非競合のグループに束ね、グループ数分のサブエージェントを並列起動し、各サブエージェントが担当分を自分でコード修正してコミットする**。Codex 等への委譲はしない。

- 司令塔（発動エージェント）→ 修正サブエージェント（並列）の2層で進める。司令塔はレビュー・グルーピング・ループ判定に専念し、1グループ・軽量なら自分で直接修正してよい。
- 各修正サブエージェントは「担当ファイル以外を編集しない」「割り当て指摘のみ修正」「担当分を1コミット（`git add -A` 禁止）」を担う。編集は Serena 優先（上記 MCP 節）。
- 競合回避（同一ファイルの同時編集禁止）は `task-orchestration` の原則どおり、グループ間でファイル集合が重ならないよう束ねてから並列起動する。強い依存がある指摘はファイルが重ならなくても同一グループに束ね、グループ内で順次対応する。
- 手順の詳細: `Review-Fix-Team` slash command（レビュー → 修正オーケストレーション）を参照する。

大規模な機能開発・リファクタリングで Codex 下請けを使う場合は、`agent/CLAUDE.md` と `opus-codex-orchestration` スキルに従う（並列レビュー修正とは別経路）。

## ショートカット指示

### `dig`

`plan-digger` サブエージェントでプランレビューを実施する。

### `品質チェック`

`quality-gainner` サブエージェントで TypeScript・リント・潜在バグを検出し、その場で自動修正する（レポートだけで終わらせない）。
