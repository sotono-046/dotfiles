---
name: herdr-orchestration
description: Herdr 上で Orca の orchestration と同じ要領の司令塔運用を行う。worker を pane 分割ではなく 1 task 1 tab で起動し、task packet 配信、結果ファイルでの完了報告、escalation への回答、依存関係つきの task 台帳、複数 worker の完了待ち、回収・統合まで管理する。「Herdr でオーケストレーション」「Orca みたいに Herdr で」「タブで分担して」「Herdr のタブで worker を回して」という依頼や、Herdr 内で Orca を使わずに分担実行するときに使う。pane の 2x2 グリッドでのチーム編成は `herdr` スキルの範囲。
---

# Herdr Orchestration（tab 方式）

司令塔は自分の tab に残り、worker を **1 task につき 1 tab** で起動する。pane は split しない。Orca の Run / Task / Dispatch / worker_done / escalation を、Herdr の tab・agent 状態・結果ファイルで置き換える。

CLI の基本操作（`agent prompt` と `pane run` の使い分け、待機の作法、出力 source）は `herdr` スキルに従う。このスキルは tab 単位の配信・台帳・回収だけを定義する。モデルと担当の割り振りは `adaptive-orchestration` に従う。

## 対応表

| Orca | このスキル |
| --- | --- |
| Run | `RUN_DIR` と台帳 `ledger.md` |
| Task / Dispatch | worker tab + task packet（`agent prompt`） |
| worker_done | 結果ファイル `STATUS: DONE` + 最終行 `WORKER_DONE <task-id>` |
| escalation / ask-reply | 結果ファイル `STATUS: ESCALATION` → 司令塔が同じ tab へ回答を `agent prompt` |
| 完了待ち | `agent prompt --wait` または `scripts/wait-workers.zsh` |
| worktree | `git worktree add` → 同じ workspace に `tab create --cwd` |

## 0. 前提

```zsh
test "${HERDR_ENV:-}" = 1   # 失敗したら Herdr 外なので停止して伝える
herdr tab list --workspace "$HERDR_WORKSPACE_ID"
herdr agent list
```

ID（`tab_id`・`pane_id`）は JSON 応答から取り、表示番号から組み立てない。既存の tab・agent は自分の run のものでなければ触らない。

## 1. Run を用意する

```zsh
run_id="$(date +%Y%m%d-%H%M%S)-<slug>"
RUN_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-orchestration/$run_id"
mkdir -p "$RUN_DIR/results" "$RUN_DIR/packets"
herdr tab rename "$HERDR_TAB_ID" "司令塔"
```

`RUN_DIR` は repo の外に置き、作業ツリーを汚さない。台帳 `$RUN_DIR/ledger.md` を作り、task ごとに次を記録する。plan の正本はこの台帳であり、tab の会話履歴を正としない。

```markdown
| task | role / model | tab_id | pane_id | cwd | scope（担当path） | deps | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | 調査 / gpt-6-luna | w1Z:t2 | w1Z:p2 | /abs/repo | read-only | - | DONE |
| T2 | 実装 / gpt-6.1-sol high | w1Z:t3 | w1Z:p3 | /abs/repo | src/a/** | T1 | RUNNING |
```

status は `PENDING / RUNNING / DONE / ESCALATION / FAILED` を使う。deps がすべて DONE になった task だけ配信する。同時に走らせる worker は既定で最大 3 とし、担当 path が重なる task は直列にする。

## 2. worker tab を起動する

```zsh
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd /abs/repo --label "T2 実装" --no-focus
# 応答: result.tab.tab_id と result.root_pane.pane_id を台帳へ記録する
herdr agent start t2-impl --kind codex --pane <pane_id> --timeout 60000 -- \
  -m <確認済みSol ID> -c model_reasoning_effort=high --no-alt-screen --add-dir "$RUN_DIR"
```

- tab label は `<task-id> <役割>`、agent 名は `t<番号>-<役割>` のように一意にする。
- `--add-dir "$RUN_DIR"` で結果ファイルの書き込みを許可する（`claude` も `--add-dir` を持つ）。codex の `--no-alt-screen` は scrollback を `agent read` で読めるようにする。
- Claude worker は `--kind claude -- --model <確認済みID> --add-dir "$RUN_DIR"`。`--add-dir` はアクセス範囲を足すだけで、承認は permission mode に従う。default mode では結果ファイルの作成でも blocked になる。ユーザーが実装を認可している worker には `--permission-mode acceptEdits` を付けてよい。bypass 系の flag は使わない。
- model ID は起動時に `adaptive-orchestration` の手順で確認し、ここの例を固定値として使わない。
- `tab create` 直後は shell の起動前で、`agent start` が `agent_pane_busy` を返すことがある。数秒おいて同じコマンドを再実行する。
- `agent start` が `agent_not_ready`（blocked）を返したら、`herdr pane read <pane_id> --source visible` で画面を見る。初回フォルダの trust 確認なら、ユーザーが作業対象に指定した repo・worktree の場合だけ承認する。それ以外はユーザーに確認する。
- 同じ repo の別 checkout が必要なら `git worktree add <path> -b <branch> <base>` で作り、`tab create --cwd <path>` で開く。`herdr worktree create` は tab ではなく別 workspace を作るため、このスキルでは使わない。

## 3. role packet → task packet を送る

初回は role packet で境界を固定し、task はまだ渡さない。

```text
Role: <task-id> の <実装 / 調査 / レビュー / 検証> worker
司令塔: Herdr tab「司令塔」。あなたへの指示は '[司令塔→<task-id>]' で始まる
作業ディレクトリ: /abs/repo（ブランチ <branch>）。他の checkout では作業しない
担当 path: <scope>。他 worker の担当 <other scopes> は編集しない
禁止: 明示指示のない commit / push / PR / destructive git、scope の独自拡張
報告: 結果は $RUN_DIR/results/<task-id>.md に書く（形式は task packet で指定）
いまは待機。理解したら一行で返答する
```

```zsh
herdr agent prompt t2-impl "$(cat "$RUN_DIR/packets/T2-role.md")" --wait --timeout 120000
```

task packet は自己完結させ、ファイルにも保存してから送る。

```text
[司令塔→T2] Task: <一行の目的>
背景: <依頼・前提・T1 の結論への参照 $RUN_DIR/results/T1.md>
Scope: <対象 path・read-only などの制限>
検証: <実行するコマンド・測定条件>
Deliverable: $RUN_DIR/results/T2.md を次の形式で書く
  1行目: STATUS: DONE | ESCALATION | FAILED
  以降: 変更ファイル(file:line) / 実行コマンドと結果 / 未解決事項
  ESCALATION の場合は、判断が必要な問いと選択肢を書いて作業を止める
最後の応答は 'WORKER_DONE T2' または 'WORKER_ESCALATION T2' の1行で終える
```

単独の task なら `--wait --timeout 1800000` で送信と完了待ちを一度に行う。並列配信では、各 worker が動き出したことだけを確認して次へ進む。

```zsh
herdr agent prompt t2-impl "$(cat "$RUN_DIR/packets/T2-task.md")" --wait --until working --until blocked --timeout 15000
```

## 4. 完了を待つ

複数 worker は同梱スクリプトを background で走らせる（foreground の sleep ループは使わない）。

```zsh
zsh <skill-dir>/scripts/wait-workers.zsh t2-impl t3-impl t4-review
```

- 状態変化ごとに `<target> <status>` を1行出す。全員が working でなくなると `ALL_SETTLED` で exit 0。
- 誰かが `blocked`・`unknown`・取得不能になると `NEEDS_ATTENTION <target> <status>` で exit 3。その worker の画面を `pane read --source visible` で確認する。権限確認が task の認可範囲内なら承認し、範囲外ならユーザーへ確認する。対処後、残りの worker でスクリプトを再起動する。
- 承認キーを送った直後の `agent wait` は古い `blocked` を返すことがある。`--until idle --until done` を付けて待つか、スクリプトを再起動する。
- timeout は異常ではない。再送せず、`agent get` と結果ファイルを確認してから次の待機を決める。

## 5. 回収・判定・次の配信

1. `$RUN_DIR/results/<task-id>.md` を読む。これを完了報告の正とする。Claude Code の worker は alt-screen のため `recent` 系の読み取りが空になることがある。画面確認は `--source visible` を使う。
2. 結果ファイルがない、または `WORKER_DONE` がないまま idle になった場合は、`[司令塔→T2] 結果ファイルが未作成です。形式どおり書いてください` と一度だけ追送する。
3. `DONE` でも採用前に差分（`git diff -- <scope>`）と検証結果を司令塔が確認する。idle・Done 表示だけで完了扱いにしない。
4. `ESCALATION` は司令塔が判断できるなら同じ worker へ `[司令塔→T2] 回答: ...` を送って再開させる。ユーザーの判断が必要なら、まとめて質問する。
5. 台帳の status を更新し、deps が満たされた task を配信する。前提を変える新事実が出たら、該当 worker へ `【追加情報: 前の指示を一部訂正します】` で始めて追送する。
6. 実装 task の後は、実装者とは別 tab の reviewer に read-only でレビューさせる（判定基準は `review-go-nogo`）。reviewer の前後で `git status --short` を比べ、編集されていないことを確かめる。

## 6. Git と終了

- 共有 checkout では stage / commit を一体ずつ行う。各 worker は司令塔の GO 後に自分の担当 path だけを明示 stage する。`git add -A` はさせない。
- 依頼の目標と必須検証を満たし、重大な指摘が解消したら終了する。台帳に最終状態と未解決事項を書く。
- この run で作った worker tab は、結果ファイルの回収と台帳の更新を終えてから `herdr tab close <tab_id>` で閉じる。ユーザーが残すよう指示した場合と、作っていない tab は閉じない。`herdr server stop` は実行しない。
- 最終報告には、成果物、検証結果、未解決事項、実際に起動した model・effort と task の割り当て、`RUN_DIR` の path を含める。
