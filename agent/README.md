# エージェント設定（Claude Code / Codex / Gemini）

`agent/` は Claude Code・Codex・Gemini 向けのエージェント設定を一元管理する。`install.sh` は設定ファイルと各 top-level skill を個別 symlink で配信し、エージェント本体が管理するディレクトリと共存させる。

```bash
./install.sh --dry-run --agent-only
./install.sh --agent-only
./install.sh --links-only
```

別の home を使う smoke test では `DOTFILES_TARGET_HOME` を指定する。`--agent-only` は agent 設定だけ、`--links-only` は package install を行わず全 link を更新する。

## `./agents`（Claude Code の subagent 定義）

| ファイル              | 用途                                                     |
| --------------------- | -------------------------------------------------------- |
| `plan-digger.md`      | プラン/Issue レビュー・SOW 作成の起動口。詳細な手順は `skills/plan-digger/SKILL.md` を source of truth として参照する |

## workflow の起動口

旧 `agent/commands/` の slash command は skill に移行済み。Codex の custom prompt 配布は非推奨のため行わない。

| 旧コマンド | 移行先 |
| --- | --- |
| `/IssueMasher` | `issue-masher` |
| `/PR-check` | `pr-base-sync` |
| `/wc_WorkingtreeCreaner` | `git-ops` |
| `/Worktree-Remove` | `git-worktree-safe-audit` |

## `./skills`

スキル本体。`install.sh` は `SKILL.md` を持つ top-level directory だけを `~/.claude/skills` と `~/.codex/skills` に個別配信する。repo内の `skills/.system/` は検証用snapshotとして保持するが配信せず、`~/.codex/skills/.system` は Codex 本体の管理に任せる。

| スキル                     | 用途                                                             |
| -------------------------- | ---------------------------------------------------------------- |
| `agent-history-miner`      | Codex / Claude 履歴をboundedに集計し、skill候補を抽出             |
| `agent-note-writing`       | Obsidian vault への作業メモ・SOW・Issue 下書き保存規約             |
| `bonginkami`                | 日本語ドキュメント・LP を Noto Sans JP で組む                      |
| `ci-merge-watch`            | PR の CI 監視・失敗修正・レビュー回収                              |
| `design`                    | デザイン統括（グリッド・余白・タイポの参照集）                     |
| `git-ops`                   | Conventional Commits + 日本語 PR テンプレート                     |
| `git-worktree-safe-audit`   | linked worktreeのread-only監査                                    |
| `gws-cli`                   | Google Workspace CLI (`gws`) 操作                                 |
| `opus-codex-orchestration`  | Opus 司令塔 × Codex オペレーターの多重下請け開発（現在 `CLAUDE-agent.md` は退避中のため既定では不使用。詳細は同ファイル参照） |
| `plan-digger`               | コード品質・セキュリティ・パフォーマンス検証・SOW 策定の本体      |
| `task-orchestration`        | Codex / Claudeのruntime別subagent並列運用                          |
| `herdr`                     | Herdr の pane / agent 操作と本文 + Enter の task packet 送信       |
| `issue-masher`              | Issue解釈からreview済みSOWと作業branch作成まで                     |
| `pr-base-sync`              | PR branchをbase最新状態へ安全に同期して検証                        |
| `subagent-team`             | Codex / Claudeの常駐subagent adapter                              |

## `./hooks`

`~/.claude/hooks` に配信される SessionStart/SessionEnd/Stop/Notification hook 群。Discord にスレッドを作成し、セッション開始・終了通知に加えてターン毎の応答抜粋・権限待ち通知を投稿し、tmux 内であれば Discord への返信をプロンプトとして注入する（双方向連携）。トークンは `~/.discord-ops-env`（git 管理外・600 権限）から環境変数として読み込む。secret はスクリプト本体には含まれない。別マシンへの導入手順は `agent/docs/discord-bridge-setup.md` を参照。

## `./settings.json`

Claude Code の設定ファイル（`~/.claude/settings.json` に配信）。

- 権限設定（allow/deny/ask）
- hooks 設定（通知音、SessionStart/SessionEnd の Discord 連携）
- enabledPlugins / extraKnownMarketplaces

`allow` は読み取り系toolとSerenaのread-only操作に限定し、push・merge・deploy・破壊的commandは `ask` に寄せる。読み取り専用セッションには `.zshrc` が読み込む `claude-ro` / `codex-ro` を使う。Claude向けはlauncherと `readonly-settings.json` の組み合わせでhooks、connectors、MCP、local writeを停止する。

MCP サーバー自体の定義は secret を含むためこのリポジトリでは管理しない。`agent/mcp-servers.md` に再構築手順をドキュメント化している。

## `./templates`

`ide.yml`（tmux/IDE レイアウト）、`wtp.yml`（worktree 作成テンプレート）。launcherはmodelを固定せず、各providerの設定を使う。`wtp.yml` はsecretをcopyせず、依存installも `WTP_INSTALL_DEPS=1` の明示時だけ行う。

## 履歴からの定期最適化

自動編集や常駐scanは行わない。月次または依頼時に対象pathを明示して `$agent-history-miner` を使い、まずroot sessionだけをboundedに集計する。

```bash
python3 agent/skills/agent-history-miner/scripts/history_miner.py \
  /explicit/codex/sessions /explicit/claude/projects \
  --scope root --since-days 90 --max-files 200 \
  --skills-dir agent/skills
```

## `CLAUDE-agent.md` について

Opus 司令塔 × Codex 下請け構造（`opus-codex-orchestration`）を既定の開発スタイルとする指示。現在は `CLAUDE.md` から切り離されて退避中（ファイル冒頭にコメントで理由を明記）。復帰させる場合は `CLAUDE.md` の内容と統合するか、`@CLAUDE-agent.md` の import に切り替える。

## マシンローカルで管理外のもの

- `~/.claude.json`（MCP サーバー定義、プロジェクトごとの許可状態）
- `~/.codex/config.toml`（Codex 本体設定、MCP 定義、trust_level）
- `~/.codex/skills/.system/`（Codex 本体が管理するsystem skills）
- `~/.gemini/settings.json`（Gemini 本体設定）
- `~/.claude/plugins/`（インストール済みプラグイン）

これらは secret やアプリ管理下の状態を含むため symlink 配信の対象外。定義内容は `agent/mcp-servers.md` を参照。

## skills.sh からの追加インストール例

```bash
npx skills add https://github.com/anthropics/skills --skill frontend-design
npx skills add https://github.com/anthropics/skills --skill skill-creator
```
