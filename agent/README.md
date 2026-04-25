# Claude Codeの設定

## `./agents`

サブエージェント定義ファイル（Taskツールで使用）

| ファイル             | 用途                                               |
| -------------------- | -------------------------------------------------- |
| `plan-digger.md`     | プランレビュー・SOW作成（反復レビューで品質確保）  |
| `quality-gainner.md` | コード品質チェック・自動修正（TypeScript/リント）  |
| `task-executor.md`   | タスク分割・実装実行（コミットチェックポイント付） |
| `task-researcher.md` | 事前調査・コンテキスト収集（調査レポート作成）     |

## `./commands`

カスタムスラッシュコマンド

| コマンド              | 用途                                     |
| --------------------- | ---------------------------------------- |
| `/CreateBranch`       | ブランチ作成（プラン策定→レビュー→作成） |
| `/InitAgent`          | AGENTSとCLAUDEの初期化                   |
| `/IssueMasher`        | イシュー対応                             |
| `/Rabbit`             | CodeRabbitレビュー指示書                 |
| `/SecurityChecker`    | セキュリティ調査・対策プラン指示書       |
| `/SkillCreator`       | スキル作成                               |
| `/wc_WorktreeCreaner` | ワークツリー掃除                         |

## `./skills`

スキル定義ファイル（Skillツールで使用）

| スキル               | 用途                                                         |
| -------------------- | ------------------------------------------------------------ |
| `design-principles`  | Linear/Notion/Stripe風のミニマルデザイン                     |
| `git-ops`            | Conventional Commits形式のコミット・PR作成・ワークツリー管理 |
| `plan-digger`        | コード品質・セキュリティ・パフォーマンス検証・SOW策定        |
| `task-orchestration` | サブエージェントの効率的な並列運用                           |

## `./settings.json`

Claude Codeの設定ファイル

- 権限設定（allow/deny/ask）
- MCPサーバー設定
- フック設定（終了時の通知音など）

## add from skills.sh

https://skills.sh/ からインストールしてます

```bash
npx skills add https://github.com/anthropics/skills --skill frontend-design
npx skills add https://github.com/anthropics/skills --skill skill-creator
```
