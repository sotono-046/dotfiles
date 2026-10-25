# エージェント設定（Claude Code / Codex / Gemini / pi）

`agent/` は Claude Code・Codex・Gemini・pi 向けのエージェント設定を一元管理する。`install.sh` は設定ファイルと各 top-level skill を個別 symlink で配信し、エージェント本体が管理するディレクトリと共存させる。

```bash
./install.sh --dry-run --agent-only
./install.sh --agent-only
./install.sh --skills-only
./install.sh --links-only
```

別の home を使う smoke test では `DOTFILES_TARGET_HOME` を指定する。`--agent-only` は agent 設定だけ、`--skills-only` はスキルとPiプロンプトの配信先だけ、`--links-only` は package install を行わず全 link を更新する。

## `./agents`（Claude Code の subagent 定義）

| ファイル              | 用途                                                     |
| --------------------- | -------------------------------------------------------- |
| `plan-digger.md`      | プラン/Issue レビュー・SOW 作成の起動口。詳細な手順は `skills/plan-digger/SKILL.md` を source of truth として参照する |

## workflow の起動口

旧 `agent/commands/` の slash command は skill に移行済み。Codex の custom prompt 配布は非推奨のため行わない。Piの短縮入口だけ `agent/prompts/*.md` を `~/.pi/agent/prompts/` へファイル単位で配信する。手順本体は共通スキルに置く。

| 環境 | Herdrの人事・PM・Workboardを準備 | 仕事も指定 |
| --- | --- | --- |
| Pi | `/herdr` | `/herdr ログインの不具合を直して` |
| Codex | `$herdr start` | `$herdr start ログインの不具合を直して` |

Piは追加後に `/reload`、Codexは新しいセッションで使う。Herdr内では現在の会話をPMとして再利用し、起動済みの担当とboardを確認して不足分だけ準備する。Herdr管理外では準備まで行い、実タブを操作しない。

| 旧コマンド | 移行先 |
| --- | --- |
| `/wc_WorkingtreeCreaner` | `git-ops` |
| `/Worktree-Remove` | `git-worktree-safe-audit` |

## `./skills`

スキル本体。`install.sh` は `SKILL.md` を持つ top-level directory を `~/.claude/skills`、`~/.codex/skills`、`~/.gemini/skills`、`~/.pi/agent/skills` に個別配信する。配信元にないユーザー所有 skill は保持する。同名の配置を置換する場合は、既存の配置をbackupへ退避する。

新しいスキルを追加しただけでは、各runtimeの一覧には登録されない。追加・移動・削除後は `./install.sh --skills-only --dry-run` で予定を確認してから `./install.sh --skills-only` を実行し、対象の `SKILL.md` を配信先から読めることを確認する。このモードは `~/.claude/settings.json` などのagent設定を置換しない。

`skills/.system/` は Codex 用 snapshot。初回に `~/.codex/skills/.system` がなければコピーし、以後の更新は Codex 本体に任せる。既存の実ディレクトリは installer で上書きしない。

置換前のファイルは `~/.local/state/dotfiles/backups/` に元の相対パスを保って退避する。過去の installer が skills 直下に残した `*.dotbackup.*` は、直下に `SKILL.md` があるものだけ同じ退避先へ移す。backup が旧 skill として再登録されないよう、探索ルート内には置かない。`--dry-run` は移動予定の表示だけを行う。

| スキル                     | 用途                                                             |
| -------------------------- | ---------------------------------------------------------------- |
| `agent-history-miner`      | Codex / Claude 履歴をboundedに集計し、skill候補を抽出             |
| `agent-note-writing`       | Obsidian vault への作業メモ・SOW・Issue 下書き保存規約             |
| `notify-result`            | 明示依頼・リーダー指名時だけ、確認済みの結果を一度通知する          |
| `ci-merge-watch`            | PR の CI 監視・失敗修正・レビュー回収                              |
| `design`                    | デザイン統括（グリッド・余白・タイポの参照集）                     |
| `git-ops`                   | Conventional Commits + 日本語 PR テンプレート                     |
| `git-worktree-safe-audit`   | linked worktreeのread-only監査                                    |
| `gws-cli`                   | Google Workspace CLI (`gws`) 操作                                 |
| `pen-design`                | pen.dev CLI で視覚デザイン（`.pen` / 画像）を生成。`@pen.dev/cli@0.3.7` の SKILL.md |
| `plan-digger`               | コード品質・セキュリティ・パフォーマンス検証・SOW 策定の本体      |
| `task-orchestration`        | Codex / Claudeのruntime別subagent並列運用                          |
| `herdr`                     | Herdr の操作、人事・PM・実行役の編成、Workboardでのタスク可視化       |
| `review-go-nogo`            | レビューの GO/NO-GO。重大な実害だけ blocker、P2 は follow-up         |
| `subagent-team`             | Codex / Claudeの常駐subagent adapter                              |

## piでpstackを使う

共通の指示は`~/.pi/agent/AGENTS.md`、共通スキルは`~/.pi/agent/skills/`から読み込む。Codex・Claude向けと同じ配信元を使う。

pstackは拡張とスキルを含むpackageとして別途導入する。`install.sh`はpackageのインストールやpi本体の設定の置換を行わない。

```bash
pi install git:github.com/michael-denyer/pstack-claude
pi list
```

`agent/pi-pstack-models.md`は`~/.pi/agent/pstack-models.md`へ配信する。Codexと同じく起動hookをOFFにし、共通AGENTS.mdでpstackを使うよう指示する。明示的な起動には`/skill:poteto-mode`、読み込み直しには`/reload`を使う。

## `./settings.json`

Claude Code の設定ファイル（`~/.claude/settings.json` に配信）。

- 権限設定（allow/deny/ask）
- hooks 設定（状態報告用hookを保ち、通常の通知音hookは置かない）
- enabledPlugins / extraKnownMarketplaces

通常のterminal通知とRemote Controlの自動pushはOFF。明示的に「終わったら教えて」と頼んだ作業や、指名されたリーダーの集約結果は `notify-result` で一度通知する。Orca自身の自動通知は別設定なので、[通知の抑制・配信手順](skills/notify-result/references/quiet-notifications.md)を参照する。

Codex・piの質問と承認待ちには、`agent/notifications/` のhookで `Pop` を鳴らす。完了音を戻す設定ではない。質問音も止めるセッションは `AGENT_QUESTION_SOUND=off` で起動する。導入方法とCodexのhook信頼確認は上記の手順を参照する。

通常起動は `defaultMode=auto`。読み取り系 tool に加え、push・merge・deploy・削除コマンドも `allow` に登録し、`ask` は sudo に設定している。`auto` でも明示的な allow は classifier より前に適用されうるため、通常設定を読み取り専用として扱わない。

読み取り専用セッションには `.zshrc` が読み込む `claude-ro` / `codex-ro` を使う。Claude 向けは launcher と `readonly-settings.json` の組み合わせで hooks、connectors、MCP、local write を停止する。`codex-ro` は shell の sandbox を read-only にするもので、通常設定の外部 MCP / plugin まで書き込みを制限する保証はない。その経路の実行検証は未実施。

MCP サーバー自体の定義は secret を含むためこのリポジトリでは管理しない。`agent/mcp-servers.md` に再構築手順をドキュメント化している。

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
