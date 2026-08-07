---
name: herdr
description: Herdr の workspace / tab / pane / agent を CLI から確認・操作し、別ペインの Claude Code・Codex などへ指示を送って協調させる。ユーザーが Herdr を明示したとき、Herdr の別エージェントへ送る、ペインへタスクを投げる、agent 状態を待つ、pane 出力を読む、pane を split して agent を起動する、司令塔・参謀・レビュー・ハーネス・実行役といったチーム編成で複数 agent を統括する、といった依頼で使用する。プロンプト送信は `herdr agent prompt --wait` で送信と完了待ちを一度に行う。
---

# Herdr

Herdr の実行中 session を CLI から操作し、別 pane の agent と協調する。

## 前提を確認する

制御コマンドを実行する前に、現在の agent が Herdr 管理 pane 内にいることを確認する。

```zsh
test "${HERDR_ENV:-}" = 1
```

失敗したら、Herdr 内で動いていないことをユーザーへ伝えて停止する。外部から、ユーザーが操作中の Herdr session を推測で制御しない。

インストール済み CLI を構文の正とする。CLI は更新で subcommand が増減する（旧 `herdr wait` と `herdr agent send` は廃止済み）。bare `herdr` は TUI を起動するため、調査には使わない。

下の早見表（`herdr 0.8.0` 基準）でほとんどの操作は足りる。`--help` の実行は、早見表のコマンドがエラーになる・見当たらないなど CLI バージョン差異を検知したときだけにする。

```zsh
herdr --version
herdr --help
herdr agent --help
herdr pane --help
herdr tab --help
```

bare subcommand（`herdr agent` 等）も usage を表示するが非ゼロで終了するため、調査には `--help` を使う。

### コマンド早見表

| 操作 | コマンド |
| --- | --- |
| agent 一覧 | `herdr agent list` |
| agent 状態確認 | `herdr agent get <target>` |
| agent が idle になるまで待つ | `herdr agent wait <target> --until idle --timeout <ms>` |
| agent へ送信して完了待ち | `herdr agent prompt <target> "<text>" --wait --timeout <ms>` |
| agent 出力を読む | `herdr agent read <target> --source recent-unwrapped --lines <n>` |
| pane 出力を読む | `herdr pane read <pane_id> --source recent-unwrapped --lines <n>` |
| pane で shell command 実行 | `herdr pane run <pane_id> "<command>"` |
| pane に Enter だけ追送 | `herdr pane send-keys <pane_id> enter` |
| pane を split して新 pane を作る | `herdr pane split --current --direction right\|down --no-focus` |
| pane を rename | `herdr pane rename <pane_id> "<label>"` |
| pane で agent を起動 | `herdr agent start <name> --kind <claude\|codex> --pane <pane_id> -- <agent args>` |
| agent 検出根拠を調べる | `herdr agent explain <pane_id>` |
| worktree 一覧 / 作成 / open | `herdr worktree list` / `herdr worktree create ...` / `herdr worktree open ...` |
| herdr 外の出力パターンを待つ | `herdr pane wait-output <pane_id> --regex <pattern> --timeout <ms>` |

`workspace_id`、`tab_id`、`pane_id`、`terminal_id` は opaque な値として扱う。番号や表示順から組み立てず、JSON 応答から取得する。

## 鉄則: agent へは `agent prompt`、shell へは `pane run`

別 pane の **agent** へプロンプトを送るときは `agent prompt` を使う。本文の送信と Enter が atomic で、`--wait` を付ければ完了待ちまで一度に行える。

```zsh
herdr agent prompt "$target" "$message" --wait --timeout 1800000
```

- `--wait` は送信後に settled 状態（既定: idle / done / blocked）を待つ。`--until <status>` で待つ状態を指定できる。
- 送信先 agent が non-working 状態のときに送信すると、5 秒以内に状態変化が観測されない場合 `agent_prompt_stalled` が返る。返ったら `pane read` で画面を確認する。
- `--wait` は turn を追跡しない。agent が既に working のときは進行中 turn の完了にマッチしうるため、先に `agent wait` で idle を確認してから送る。

agent ではない **shell pane** でコマンドを実行するときは `pane run` を使う。

```zsh
herdr pane run "$pane_id" "$command"
```

- 入力済み文字列へ Enter だけ追送するときは `herdr pane send-keys "$pane_id" enter`。
- Enter を押さず入力欄へ置くだけ、とユーザーが明示した場合だけ `pane send-text` を使う。
- shell metacharacter を含む本文は shell で再解釈させず、引数として quote して渡す。

## 標準ワークフロー

### 1. 送り先を特定する

agent 一覧を取得し、対象の `pane_id` と状態を確認する。

```zsh
herdr agent list
herdr agent get <target>
```

`target` には unique agent name と、agent をホストしている pane ID を使用できる。複数候補がある場合は送信せず、対象を確認する。

`agent target ... not found` は、pane の split / rename / close をまたいで古い pane ID や agent 名を使い回したときに起きる代表的な失敗。`agent prompt` / `agent wait` を送る直前には必ず `herdr agent list` で現在の一覧を取り直し、ID や名前を確認済みの値に更新する。前の turn で取得した ID をキャッシュしたまま次の turn で使わない。

現在の pane や同一 workspace の pane を確認するときは、focus に依存せず明示的な ID を使う。

```zsh
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
herdr pane current --current
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
```

### 2. agent が入力待ちになるまで待つ

`agent_status` が `working` の間は新しい指示を重ねない。`idle` を待ってから送る。

```zsh
herdr agent get "$target"
herdr agent wait "$target" --until idle --timeout 30000
```

`agent wait` は `--until` なしだと idle / done / blocked のいずれかで返る。`blocked` の場合は `pane read` で画面を確認し、権限確認や質問への回答が必要か判断する。timeout したら再送せず、状態と出力を読む。

### 待機の作法（timeout は異常ではない）

`agent wait` / `agent prompt --wait` の timeout（exit 1）は「まだ working」を示す正常な信号であり、失敗ではない。実測でも大半の agent 起因エラーは timeout の取り扱いミスに集中している。

- 長時間タスクには `--timeout 300000`（5分）以上を指定する。実装・調査系の task packet では `1800000`（30分）を既定にする。
- timeout（`--timeout` 超過）と `agent_prompt_stalled`（非 working 状態から送信して 5 秒以内に状態変化が観測されない）は別のエラーだが、対処は同じ。どちらも即座に再送しない。`herdr agent get "$target"` で現在状態を確認し、必要なら `pane read` で出力を読んでから次の待機を判断する。
- `herdr agent wait "$target" ... >/dev/null 2>&1; herdr agent prompt "$target" "$message"` のように wait のエラーを握りつぶして盲目的に送信しない。wait が失敗した状態を無視して送ると、working 中の agent へ指示を重ねる事故につながる。
- foreground の `sleep N` で待ってから `pane read` するパターンは harness にブロックされるため使わない。herdr 外の状態（CI・ビルド・成果物ファイルなど）を待つ場合は `herdr pane wait-output` か、background の polling script（Monitor / `run_in_background`、状態変化時のみ 1 行出力し番兵文字列で exit する）を使う。

### 3. task packet を送信して完了まで待つ

暗黙の会話文脈に依存せず、repo、goal、scope、制約、成果物を含む自己完結した指示を作る。

```zsh
message='Repo: /absolute/path
Goal: 対象テストを実行して原因を調べる
Scope: 読み取りとテスト実行のみ。ファイルは編集しない
Deliverable: 実行コマンド、結果、原因候補を報告する'

herdr agent prompt "$target" "$message" --wait --timeout 1800000
```

初回の実装 agent には、task packet の前に同じ方法で role packet を送る。

```text
Role: implementation agent
- 指示された scope だけを扱う
- commit / push / destructive git command は明示指示なしで行わない
- 不明点や blocker は作業を広げず報告する
- changed files / commands run / result を返す
```

follow-up も必ず `agent prompt` で送る。

### 4. 結果を読む

agent 名や pane ID が既に分かっている場合は `herdr agent read "$target"` で直接読める（`pane read` と同じ `--source` / `--lines` を取る）。pane ID を経由せずに読みたいときはこちらを優先する。

```zsh
herdr agent read "$target" --source recent-unwrapped --lines 120
herdr pane read "$pane_id" --source recent-unwrapped --lines 120
```

送信が CLI 側で拒否された場合（例: フラグの組み合わせが無効、対象が unknown 状態など）、プロンプトは**未送信**として扱う。エラーを無視して次の待機に進まず、`agent read` / `pane read` で実際に届いたかを確認してから、必要なら送り直す。

`--wait` を使わず送信だけした場合や、外部イベント（CI・ビルド・成果物ファイル）を待つ場合は、`herdr pane wait-output "$pane_id" --regex <pattern> --timeout <ms>`（`--timeout` なしは無期限待機）や background の polling script（状態変化時のみ 1 行出力し、番兵文字列で exit する）で待つ。

foreground でユーザーが見ている pane は完了時に `done` ではなく `idle` になる場合がある。`agent get` で `idle` または `done` なら完了として扱う。`blocked` なら必要な入力を確認し、`unknown` なら agent 検出と pane 出力を確認する。

## helper agent を新しい pane で起動する

ユーザーが Herdr で別 agent を起動するよう明示した場合だけ、現在 pane の geometry を確認し、focus を奪わず split する。

```zsh
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --no-focus
```

横幅が狭い場合は `--direction down` を使う。応答 JSON から新しい pane_id を読み（`pane split` は `result.pane.pane_id`。フィールド名は CLI 更新で変わりうるため応答を確認する）、`agent start` で起動する。readiness 検出まで行われるため、`pane run` で起動コマンドを打つより確実。

```zsh
herdr pane rename <returned-pane-id> "reviewer"
herdr agent start reviewer --kind codex --pane <returned-pane-id> -- -m <model> -c model_reasoning_effort=high
herdr agent prompt <returned-pane-id> "現在の差分をレビューし、actionable な指摘だけ報告してください。" --wait
```

agent の起動コマンドへ task を argv として混ぜない。interactive agent が `idle` になった後、task を `agent prompt` で送る。

- codex の終了に `/quit` は効かない。`herdr pane send-keys "$pane_id" "ctrl+c"` を 2 回送る。
- モデルが "at capacity" で落ちることがある。起動直後に `pane read --source visible` で確認する。

## チーム編成（司令塔・参謀・レビュー・ハーネス・実行役）

複数 pane を役割分担させて実装→レビュー→検証のループを回す場合は、[references/team-orchestration.md](references/team-orchestration.md) を読んで適用する。標準レイアウト（2x2 グリッド + 役割ごとの既定モデル割当）、役割モデル、role packet / task packet のテンプレート、`[司令塔→参謀]` prefix のメッセージプロトコル、ハードリミット、司令塔の引き継ぎパケットを定義している。ユーザーが別指定しない限り、チーム編成の依頼にはこの標準レイアウトをそのまま適用する。

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
- `agent wait` / `agent prompt --wait` の timeout で即座に再送しない。状態確認を挟む。
