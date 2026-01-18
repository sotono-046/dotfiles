# Claude Codeの設定

## `./agents`

サブエージェント定義ファイル（Taskツールで使用）

| ファイル                    | 用途                       |
| --------------------------- | -------------------------- |
| `code-quality-reviewer.md`  | コード品質レビュー         |
| `pre-task-investigator.md`  | 事前調査・コンテキスト収集 |
| `task-splitter-executor.md` | タスク分割・実装実行       |

## `./commands`

カスタムスラッシュコマンド

| コマンド              | 用途                               |
| --------------------- | ---------------------------------- |
| `/InitAgent`          | AGENTSとCLAUDEの初期化             |
| `/IssueMasher`        | イシュー対応                       |
| `/Rabbit`             | CodeRabbitレビュー指示書           |
| `/SecurityChecker`    | セキュリティ調査・対策プラン指示書 |
| `/SkillCreator`       | スキル作成                         |
| `/wc_WorktreeCreaner` | ワークツリー掃除                   |

## `./skills`

スキル定義ファイル（Skillツールで使用）

| スキル                | 用途                                         |
| --------------------- | -------------------------------------------- |
| `code-quality-review` | コード品質・セキュリティ・パフォーマンス検証 |
| `code-reviewer`       | コードレビュー・SOW形式での改善計画策定      |
| `design-principles`   | Linear/Notion/Stripe風のミニマルデザイン     |
| `git-ops`             | Conventional Commits形式のコミット・PR作成   |
| `task-orchestration`  | サブエージェントの並列運用                   |

## `./settings.json`

Claude Codeの設定ファイル

- 権限設定（allow/deny/ask）
- MCPサーバー設定
- フック設定（終了時の通知音など）