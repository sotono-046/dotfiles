---
name: herdr
description: Herdr の workspace / tab / pane / agent を CLI から確認・操作し、別ペインの Claude Code・Codex などへ指示を送って協調させる。ユーザーが Herdr を明示したとき、Herdr の別エージェントへ送る、ペインへタスクを投げる、agent 状態を待つ、pane 出力を読む、pane を split して agent を起動する、といった依頼で使用する。プロンプト送信は `herdr pane run` で本文と Enter を一度に送る。
---

# Herdr

Herdr の実行中 session を CLI から操作し、別 pane の agent と協調する。

## 前提を確認する

制御コマンドを実行する前に、現在の agent が Herdr 管理 pane 内にいることを確認する。

```zsh
test "${HERDR_ENV:-}" = 1
```

失敗したら、Herdr 内で動いていないことをユーザーへ伝えて停止する。外部から、ユーザーが操作中の Herdr session を推測で制御しない。

インストール済み CLI を構文の正とする。bare `herdr` は TUI を起動するため、調査には使わない。

```zsh
herdr --version
herdr --help
herdr agent
herdr pane
herdr wait
```

`workspace_id`、`tab_id`、`pane_id`、`terminal_id` は opaque な値として扱う。番号や表示順から組み立てず、JSON 応答から取得する。

## 鉄則: 本文と Enter を `pane run` で送る

別 pane へプロンプトやコマンドを送信するときは、原則として `pane run` を使う。

```zsh
herdr pane run "$pane_id" "$message"
```

`pane run` は本文と Enter を atomic に送る。送った文字列が入力欄に残らず、そのまま実行・送信される。

- `herdr agent send <target> <text>` は文字列を入力するだけで Enter を押さない。送信・実行まで必要な通常用途では使わない。
- 入力済みの文字列へ Enter だけ追送するときは `herdr pane send-keys "$pane_id" enter` を使う。
- Enter を押さず入力欄へ置くだけ、とユーザーが明示した場合だけ `agent send` または `pane send-text` を使う。
- shell metacharacter を含む本文は shell で再解釈させず、引数として quote して渡す。

## 標準ワークフロー

### 1. 送り先を特定する

agent 一覧を取得し、対象の `pane_id` と状態を確認する。

```zsh
herdr agent list
herdr agent get <target>
```

`target` には terminal ID、unique agent name、detected / reported agent label、pane ID を使用できる。複数候補がある場合は送信せず、対象を確認する。

現在の pane や同一 workspace の pane を確認するときは、focus に依存せず明示的な ID を使う。

```zsh
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
herdr pane current --current
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
```

### 2. agent が入力待ちになるまで待つ

`agent_status` が `working` の間は新しい指示を重ねない。`idle` を待ってから送る。

```zsh
herdr pane get "$pane_id"
herdr wait agent-status "$pane_id" --status idle --timeout 30000
```

`blocked` の場合は `pane read` で画面を確認し、権限確認や質問への回答が必要か判断する。timeout したら再送せず、状態と出力を読む。

### 3. task packet を送信して Enter まで実行する

暗黙の会話文脈に依存せず、repo、goal、scope、制約、成果物を含む自己完結した指示を作る。

```zsh
message='Repo: /absolute/path
Goal: 対象テストを実行して原因を調べる
Scope: 読み取りとテスト実行のみ。ファイルは編集しない
Deliverable: 実行コマンド、結果、原因候補を報告する'

herdr pane run "$pane_id" "$message"
```

初回の実装 agent には、task packet の前に同じ `pane run` で role packet を送る。

```text
Role: implementation agent
- 指示された scope だけを扱う
- commit / push / destructive git command は明示指示なしで行わない
- 不明点や blocker は作業を広げず報告する
- changed files / commands run / result を返す
```

follow-up も必ず `pane run` で送る。

```zsh
herdr pane run "$pane_id" "次に failing test のログを確認して、原因だけ報告してください。"
```

### 4. 開始・完了を待って結果を読む

```zsh
herdr wait agent-status "$pane_id" --status working --timeout 30000
herdr wait agent-status "$pane_id" --status done --timeout 120000
herdr pane read "$pane_id" --source recent-unwrapped --lines 120
```

foreground でユーザーが見ている pane は完了時に `done` ではなく `idle` になる場合がある。`pane get` で `idle` または `done` なら完了として扱う。`blocked` なら必要な入力を確認し、`unknown` なら agent 検出と pane 出力を確認する。

## helper agent を新しい pane で起動する

ユーザーが Herdr で別 agent を起動するよう明示した場合だけ、現在 pane の geometry を確認し、focus を奪わず split する。

```zsh
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --no-focus
```

横幅が狭い場合は `--direction down` を使う。応答の `result.pane.pane_id` を読み、適切な label と通常の interactive command を設定する。

```zsh
herdr pane rename <returned-pane-id> "reviewer"
herdr pane run <returned-pane-id> "codex"
herdr wait agent-status <returned-pane-id> --status idle --timeout 30000
herdr pane run <returned-pane-id> "現在の差分をレビューし、actionable な指摘だけ報告してください。"
```

agent の起動コマンドへ task を argv として混ぜない。interactive agent が `idle` になった後、task を `pane run` で送る。

## 出力を読む

- UI の見た目を確認する: `--source visible`
- 通常の scrollback を読む: `--source recent`
- soft wrap を結合したログや transcript を読む: `--source recent-unwrapped`
- agent 検出の根拠を調べる: `--source detection`

```zsh
herdr pane read "$pane_id" --source recent-unwrapped --lines 120
herdr agent explain "$pane_id"
```

## 安全ルール

- `--current` または明示 ID を使い、別 client の focused pane に依存しない。
- mutation 後は応答から新しい ID を読み直す。
- background 操作は `--no-focus` を使う。
- 作成していない workspace / tab / pane / session を明示指示なしで閉じない。
- active session 内から `herdr server stop` を実行しない。
- 同じファイルを複数 agent に同時編集させない。
- agent の応答は司令塔側で差分と検証結果を確認してから採用する。
