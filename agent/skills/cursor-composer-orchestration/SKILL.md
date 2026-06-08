---
name: cursor-composer-orchestration
description: Codex/Claudeなどの司令塔エージェントをPMにしてCursor IDEのComposer 2.5をコーディング担当として使う開発オーケストレーション。思考・設計・分解・レビューは現在動いている司令塔エージェントまたはそのsubagentが担当し、作業・コード編集はCursor Composerに緻密な指示を与えて委譲する。Cursor、Composer、AppleScript、Cursorに実装させる、Cursor IDEを叩く、CLIを使わずCursorへ委譲、安く速く実装する、などの依頼で使用する。
---

# Cursor Composer Orchestration

現在動いている司令塔エージェント（Codex / Claude / その subagent）は PM として意図整理・タスク分割・レビュー・検証を握り、Cursor Composer は実装ワーカーとして使う。思考は司令塔側に寄せ、Cursor には狭く具体化された作業 packet だけを渡す。Cursor CLI ではなく macOS の AppleScript / System Events で Cursor IDE にプロンプトを投入する。

## 前提

- Cursor が対象 repo / worktree を開いている、または `open -a Cursor "$PWD"` で開ける。
- macOS の Accessibility 権限で terminal / Codex 実行環境が Cursor を操作できる。
- Cursor 側の Composer 起動ショートカットを確認する。既定は `cmd-i` とし、違う場合は helper script の `--shortcut` で変える。
- AppleScript 経由の貼り付けは clipboard を上書きする。重要な clipboard 内容があるときは先に退避する。

## 役割分担

| 役割 | 担当 | 責務 |
| ---- | ---- | ---- |
| PM | 司令塔エージェント | ゴール/非ゴール整理、worktree 状態確認、実装 slice 決定、Cursor への task packet 作成、差分レビュー、検証、Git 管理 |
| 思考補助 | 司令塔側の subagent | 調査、設計案、リスク洗い出し、レビュー観点作成。成果は司令塔エージェントが統合して Cursor 用 packet に落とす |
| 作業 | Cursor Composer | 指定範囲のコード編集、テスト追加、機械的な修正。広い設計判断や Git 操作はしない |

司令塔エージェントは同じファイルを Cursor と同時編集しない。Cursor が実装している間は待ち、完了後に `git diff` と検証コマンドで確認する。

## ワークフロー

1. `git status --short` で既存差分を確認し、ユーザー由来の unrelated diff を触らない方針を決める。
2. 依頼を 1 つの実装 slice に分ける。大きい/曖昧な場合は司令塔エージェントまたは subagent で調査・設計・リスク整理を済ませてから、Cursor へ渡す作業を小さくする。
3. Cursor に渡す task packet を作る。packet は「何を編集するか」まで具体化し、「どう分解するか」「何が本質か」の思考を Cursor に丸投げしない。
4. `scripts/send-to-cursor-composer.zsh` で Cursor Composer に貼り付ける。既定では送信しないので、内容を目視してから送信する。完全に安全なときだけ `--submit` を使う。
5. Cursor の完了後、司令塔エージェントが `git diff` をレビューする。スコープ外変更、意図外の削除、テスト不足を確認する。
6. 必要なら focused follow-up を Cursor に投げる。司令塔エージェントが直接直すのは小さく明白な修正だけにする。
7. 検証コマンドを実行し、失敗したら失敗ログを添えて Cursor に再委譲する。
8. commit / PR が必要なら `git-ops` skill を読み、対象ファイルだけ stage する。

## Task Packet

Cursor へ渡すプロンプトは毎回自己完結にする。

```markdown
You are the coding worker in Cursor Composer. The orchestrating agent is the PM.

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
- Ask the orchestrating agent before making design decisions outside this packet
- Treat this packet as the full source of truth; do not broaden the scope

Validation to run or preserve:
- <command 1>
- <command 2>

When done:
- Stop after editing
- Summarize changed files and validation results in Composer
```

Task packet は緻密に書く。最低限、対象ファイル、禁止ファイル、受け入れ条件、非ゴール、変更してよい範囲、変更してはいけない範囲、既存差分の扱い、検証コマンド、判断に迷ったときの停止条件を入れる。

## Helper Script

Use the bundled helper to activate Cursor, open Composer with a keyboard shortcut, paste the prompt, and optionally submit it.

```bash
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh prompt.md
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh --submit prompt.md
agent/skills/cursor-composer-orchestration/scripts/send-to-cursor-composer.zsh --shortcut cmd-l prompt.md
```

Options:

- `--app <name>`: Cursor application name. Default: `Cursor`.
- `--shortcut <cmd-i|cmd-l|cmd-shift-i|none>`: Composer/chat focus shortcut. Default: `cmd-i`.
- `--submit`: Press Return after paste.

If the shortcut is wrong, use `--shortcut none`, manually focus Composer in Cursor, then run the helper to paste only.

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
- Validation commands are run by Codex even if Cursor claimed they passed.

For follow-up prompts, include only the failing evidence and the expected fix. Do not paste the whole previous conversation unless Cursor needs missing context.

## Safety Rules

- Use one Cursor worker per worktree. For parallel Cursor work, create separate worktrees and non-overlapping file scopes.
- Keep thinking on the orchestrating-agent side. Use its subagents for investigation, design options, and review; use Cursor for bounded code edits.
- Never ask Cursor to commit, push, rebase, reset, or stage files. The orchestrating agent owns Git state.
- Never ask Cursor to plan broad work from scratch. If the request is broad, the orchestrating agent/subagents split it first and Cursor receives one implementation slice.
- Never tell Cursor to edit broad scopes like "fix everything" unless the repo is disposable.
- If Cursor changes unrelated files, do not hide it. Review the diff and ask the user before reverting user-looking work.
- Prefer Cursor for medium/large implementation. Keep Codex direct edits for tiny mechanical changes, prompt cleanup, or verification fixes.
