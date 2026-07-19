# エージェント設定（Claude Code / Codex / Gemini）

`agent/` は Claude Code・Codex・Gemini 向けのエージェント設定を一元管理する。`install.sh` が symlink で各エージェントのホームディレクトリ（`~/.claude`、`~/.codex`、`~/.gemini`）に配信する。配信先の詳しいマッピングは `install.sh` の `dotfiles` 配列を参照。

## `./agents`（Claude Code の subagent 定義）

| ファイル              | 用途                                                     |
| --------------------- | -------------------------------------------------------- |
| `plan-digger.md`      | プラン/Issue レビュー・SOW 作成の起動口。詳細な手順は `skills/plan-digger/SKILL.md` を source of truth として参照する |
| `quality-gainner.md`  | TypeScript/lint/潜在バグの検出と自動修正                 |
| `task-executor.md`    | 複雑タスクの分割・コミットチェックポイント付き実行       |
| `task-researcher.md`  | 実装前調査、`.temp` へ日付付きレポートを保存              |

## `./commands`（slash command。Claude Code と Codex `prompts/` で共用）

| コマンド                  | 用途                                                       |
| ------------------------- | ------------------------------------------------------------ |
| `/initagent`               | プロジェクトの AGENTS.md / CLAUDE.md 初期化                 |
| `/IssueMasher`             | Issue の解釈 → プラン → 実装                                |
| `/PR-check`                | 対象ブランチにメインを merge して最新状態でチェック          |
| `/Review-Fix-Team`         | code-review → 指摘のファイル非競合グルーピング → 並列修正   |
| `/SecurityChecker`         | セキュリティ調査・対策プラン策定                             |
| `/setmain`                 | メイン開発ブランチへ checkout + 最新化                       |
| `/Team-Create`             | エージェントチーム編成（PO+設計+FE/BE+UIUX+テスト）           |
| `/Team-Create-Test`        | テスト特化のチーム編成                                       |
| `/Team-CleanUp`            | チームの Task 停止・teammate 終了・残タスク確認               |
| `/wc_WorkingtreeCreaner`   | 未コミット変更を分析してコミットし、ワークツリーをクリーンにする |
| `/Worktree-Remove`         | 子ワークツリーを一掃し親だけ残す                              |

## `./skills`

スキル本体。`skills/.system/` には Codex 用のシステムスキル（skill-creator, plugin-creator, skill-installer, openai-docs, imagegen）が入っており通常編集しない。

| スキル                     | 用途                                                             |
| -------------------------- | ---------------------------------------------------------------- |
| `agent-note-writing`       | Obsidian vault への作業メモ・SOW・Issue 下書き保存規約             |
| `bonginkami`                | 日本語ドキュメント・LP を Noto Sans JP で組む                      |
| `ci-merge-watch`            | PR の CI 監視・失敗修正・レビュー回収                              |
| `design`                    | デザイン統括（グリッド・余白・タイポの参照集）                     |
| `git-ops`                   | Conventional Commits + 日本語 PR テンプレート                     |
| `gws-cli`                   | Google Workspace CLI (`gws`) 操作                                 |
| `opus-codex-orchestration`  | Opus 司令塔 × Codex オペレーターの多重下請け開発（現在 `CLAUDE-agent.md` は退避中のため既定では不使用。詳細は同ファイル参照） |
| `plan-digger`               | コード品質・セキュリティ・パフォーマンス検証・SOW 策定の本体      |
| `task-orchestration`        | Task ツールでのサブエージェント並列運用                            |
| `herdr`                     | Herdr の pane / agent 操作と本文 + Enter の task packet 送信       |

## `./hooks`

`~/.claude/hooks` に配信される SessionStart/SessionEnd/Stop/Notification hook 群。Discord にスレッドを作成し、セッション開始・終了通知に加えてターン毎の応答抜粋・権限待ち通知を投稿し、tmux 内であれば Discord への返信をプロンプトとして注入する（双方向連携）。トークンは `~/.discord-ops-env`（git 管理外・600 権限）から環境変数として読み込む。secret はスクリプト本体には含まれない。別マシンへの導入手順は `agent/docs/discord-bridge-setup.md` を参照。

## `./settings.json`

Claude Code の設定ファイル（`~/.claude/settings.json` に配信）。

- 権限設定（allow/deny/ask）
- hooks 設定（通知音、SessionStart/SessionEnd の Discord 連携）
- enabledPlugins / extraKnownMarketplaces

MCP サーバー自体の定義は secret を含むためこのリポジトリでは管理しない。`agent/mcp-servers.md` に再構築手順をドキュメント化している。

## `./templates`

`ide.yml`（tmux/IDE レイアウト）、`wtp.yml`（worktree 作成テンプレート）。

## `CLAUDE-agent.md` について

Opus 司令塔 × Codex 下請け構造（`opus-codex-orchestration`）を既定の開発スタイルとする指示。現在は `CLAUDE.md` から切り離されて退避中（ファイル冒頭にコメントで理由を明記）。復帰させる場合は `CLAUDE.md` の内容と統合するか、`@CLAUDE-agent.md` の import に切り替える。

## マシンローカルで管理外のもの

- `~/.claude.json`（MCP サーバー定義、プロジェクトごとの許可状態）
- `~/.codex/config.toml`（Codex 本体設定、MCP 定義、trust_level）
- `~/.gemini/settings.json`（Gemini 本体設定）
- `~/.claude/plugins/`（インストール済みプラグイン）

これらは secret やアプリ管理下の状態を含むため symlink 配信の対象外。定義内容は `agent/mcp-servers.md` を参照。

## skills.sh からの追加インストール例

```bash
npx skills add https://github.com/anthropics/skills --skill frontend-design
npx skills add https://github.com/anthropics/skills --skill skill-creator
```
