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

スキル本体。`install.sh` は `SKILL.md` を持つ top-level directory を `~/.claude/skills`、`~/.codex/skills`、`~/.gemini/skills` に個別配信する。各 runtime に追加したユーザー所有 skill は保持する。

`skills/.system/` は Codex 用 snapshot。初回に `~/.codex/skills/.system` がなければコピーし、以後の更新は Codex 本体に任せる。既存の実ディレクトリは installer で上書きしない。

置換前のファイルは `~/.local/state/dotfiles/backups/` に元の相対パスを保って退避する。過去の installer が skills 直下に残した `*.dotbackup.*` は、直下に `SKILL.md` があるものだけ同じ退避先へ移す。backup が旧 skill として再登録されないよう、探索ルート内には置かない。`--dry-run` は移動予定の表示だけを行う。

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
| `review-go-nogo`            | レビューの GO/NO-GO。重大な実害だけ blocker、P2 は follow-up         |
| `subagent-team`             | Codex / Claudeの常駐subagent adapter                              |

## `./settings.json`

Claude Code の設定ファイル（`~/.claude/settings.json` に配信）。

- 権限設定（allow/deny/ask）
- hooks 設定（Notification / Stop の通知音）
- enabledPlugins / extraKnownMarketplaces

通常起動は `defaultMode=auto`。読み取り系 tool に加え、push・merge・deploy・削除コマンドも `allow` に登録し、`ask` は sudo に設定している。`auto` でも明示的な allow は classifier より前に適用されうるため、通常設定を読み取り専用として扱わない。

読み取り専用セッションには `.zshrc` が読み込む `claude-ro` / `codex-ro` を使う。Claude 向けは launcher と `readonly-settings.json` の組み合わせで hooks、connectors、MCP、local write を停止する。`codex-ro` は shell の sandbox を read-only にするもので、通常設定の外部 MCP / plugin まで書き込みを制限する保証はない。その経路の実行検証は未実施。

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
