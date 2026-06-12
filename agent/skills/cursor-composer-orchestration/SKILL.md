---
name: cursor-composer-orchestration
description: Codex/Claudeなどの司令塔エージェントをPMにしてCursor Agent CLI（cursor-agent）をコーディング担当として使う開発オーケストレーション。思考・設計・分解・レビューは現在動いている司令塔エージェントまたはそのsubagentが担当し、作業・コード編集は cursor-agent CLI に緻密な指示を与えて委譲する。Cursor、cursor-agent、Cursorに実装させる、Cursor CLIへ委譲、安く速く実装する、などの依頼で使用する。
---

# Cursor Agent CLI Orchestration

現在動いている司令塔エージェント（Codex / Claude / その subagent）は PM として意図整理・タスク分割・レビュー・検証を握り、Cursor Agent は実装ワーカーとして使う。思考は司令塔側に寄せ、Cursor には狭く具体化された作業 packet だけを渡す。

以前は macOS の AppleScript / System Events で Cursor IDE の Composer を叩く構成だったが、IDE 連携（ウィンドウフォーカス、ショートカット、貼り付け）が安定しなかったため、`cursor-agent` CLI を使った headless 実行に切り替えている。

## 前提

- `cursor-agent` CLI がインストール済み（`which cursor-agent` で確認、`/Users/sotono/.local/bin/cursor-agent` 等）。
- `cursor-agent status` で認証済みであること。未認証なら `cursor-agent login`。
- 対象 repo / worktree がローカルに存在し、cwd で `git status` が通る。
- ネットワークと API 利用枠が確保されていること。

## 役割分担

| 役割 | 担当 | 責務 |
| ---- | ---- | ---- |
| PM | 司令塔エージェント | ゴール/非ゴール整理、worktree 状態確認、実装 slice 決定、Cursor への task packet 作成、差分レビュー、検証、Git 管理 |
| 思考補助 | 司令塔側の subagent | 調査、設計案、リスク洗い出し、レビュー観点作成。成果は司令塔エージェントが統合して Cursor 用 packet に落とす |
| 作業 | Cursor Agent CLI | 指定範囲のコード編集、テスト追加、機械的な修正。広い設計判断や Git 操作はしない |

司令塔エージェントは同じファイルを Cursor と同時編集しない。Cursor が実装している間は待ち、完了後に `git diff` と検証コマンドで確認する。

## ワークフロー

1. `git status --short` で既存差分を確認し、ユーザー由来の unrelated diff を触らない方針を決める。
2. 依頼を 1 つの実装 slice に分ける。大きい/曖昧な場合は司令塔エージェントまたは subagent で調査・設計・リスク整理を済ませてから、Cursor へ渡す作業を小さくする。
3. Cursor に渡す task packet を作る。packet は「何を編集するか」まで具体化し、「どう分解するか」「何が本質か」の思考を Cursor に丸投げしない。
4. `scripts/send-to-cursor-composer.zsh` で task packet を `cursor-agent --print` に渡し、headless 実行する。標準出力に結果が返るのでログとして保存する。
5. Cursor の完了後、司令塔エージェントが `git diff` をレビューする。スコープ外変更、意図外の削除、テスト不足を確認する。
6. 必要なら focused follow-up を Cursor に投げる。司令塔エージェントが直接直すのは小さく明白な修正だけにする。
7. 検証コマンドを実行し、失敗したら失敗ログを添えて Cursor に再委譲する。
8. commit / PR が必要なら `git-ops` skill を読み、対象ファイルだけ stage する。

## Task Packet

Cursor へ渡すプロンプトは毎回自己完結にする。

```markdown
You are the coding worker invoked via `cursor-agent --print`. The orchestrating agent is the PM.

Repo: /absolute/path/to/repo
Goal: <何を達成するか>
Why: <ユーザー価値、バグ背景、受け入れ条件>

Scope:
- You may edit: <許可するファイル/ディレクトリ>
- Do not edit: unrelated files, generated artifacts, lockfiles unless necessary
- Do not commit, stage, push, install packages, or run destructive git commands

Implementation notes:
- Follow existing patterns
- Keep changes minimal
- Add/update tests when behavior changes
- Do not broaden the scope; if a design decision is needed beyond this packet, stop and report
- Treat this packet as the full source of truth

Validation to run or preserve:
- <command 1>
- <command 2>

When done:
- Stop after editing
- Print a summary of changed files and validation results to stdout
```

Task packet は緻密に書く。最低限、対象ファイル、禁止ファイル、受け入れ条件、非ゴール、変更してよい範囲、変更してはいけない範囲、既存差分の扱い、検証コマンド、判断に迷ったときの停止条件を入れる。

## Helper Script

Use the bundled helper to feed the task packet into `cursor-agent` in headless mode and capture the transcript.

```bash
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh prompt.md
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh --model sonnet-4-thinking prompt.md
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh --workspace /path/to/repo prompt.md
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh --plan prompt.md
```

Options:

- `--workspace <path>`: 作業ディレクトリ。デフォルトは cwd。
- `--model <name>`: 使用モデル（例: `sonnet-4-thinking`, `gpt-5`）。省略時は CLI 既定。
- `--plan`: 読み取り専用の plan モードで起動（編集させたくない調査用途）。
- `--force`: ツール許可を自動化（破壊的コマンドにも効くので scope を確実に絞った packet にだけ使う）。
- `--output-format <text|json|stream-json>`: 出力形式。ログを機械処理したいときに使う。

直接 CLI を叩く場合は次の通り。

```bash
cursor-agent --print --workspace "$PWD" "$(cat prompt.md)"
```

## Review Loop

After Cursor edits:

```bash
git status --short
git diff -- <expected paths>
```

Check:

- The diff matches the task packet and does not absorb unrelated work.
- No secrets, local paths, generated caches, or accidental formatting churn were introduced.
- Tests cover changed behavior; for docs/skills, frontmatter and referenced paths are valid.
- Validation commands are run by the orchestrating agent even if Cursor claimed they passed.

For follow-up prompts, include only the failing evidence and the expected fix. Do not paste the whole previous conversation unless Cursor needs missing context. `cursor-agent --resume` / `--continue` でセッションを継続できるが、packet を更新して新規セッションで投げ直す方がスコープが明確になることが多い。

## Safety Rules

- Use one cursor-agent worker per worktree. For parallel work, create separate worktrees and non-overlapping file scopes; `--workspace` でそれぞれ指定する。
- Keep thinking on the orchestrating-agent side. Use its subagents for investigation, design options, and review; use cursor-agent for bounded code edits.
- Never ask cursor-agent to commit, push, rebase, reset, or stage files. The orchestrating agent owns Git state.
- Never ask cursor-agent to plan broad work from scratch. If the request is broad, the orchestrating agent/subagents split it first and cursor-agent receives one implementation slice.
- Never tell cursor-agent to edit broad scopes like "fix everything" unless the repo is disposable.
- `--force` や `--sandbox disabled` を使うときは packet の scope と禁止事項を厳密にし、危険な command を任せない。
- If cursor-agent changes unrelated files, do not hide it. Review the diff and ask the user before reverting user-looking work.
- Prefer cursor-agent for medium/large implementation. Keep direct edits for tiny mechanical changes, prompt cleanup, or verification fixes.
