# 起動・共有タスク一覧・回収

CLIの送信・待機・エラー処理は [cli.md](cli.md)、役割とpacketは [roles.md](roles.md) に従う。通常は [workboard.md](workboard.md) を併用し、カード・sessionの作成と状態更新はそちらの手順を使う。

## 準備

実Herdrを操作する依頼であることを確認する。管理外ではpacketとdry-runまで準備できる。

```zsh
test "${HERDR_ENV:-}" = 1
test -n "${HERDR_WORKSPACE_ID:-}"
herdr --version
```

上の確認後に同じworkspaceのtab・agentを照会する。今回のrunと無関係な既存tabは流用しない。

```zsh
herdr tab list --workspace "$HERDR_WORKSPACE_ID"
herdr agent list
```

既存の人事・PMが今回の認可範囲で使えるなら再利用する。新規構成は相談タブに人事とPM、実行役はWorkboardカードに結びつけ、状態別タブ内のpaneに置く。以下の単独タブ作成例はWorkboardを使わない明示指定時の手順。

PMは同時実行数、修正ループ数、重い検証の回数と終了条件を仕事に応じて決める。実行役の同時実行は未指定なら最大3を目安にし、子担当は上限を独自に増やさない。別問題の発見だけでscopeを広げない。

## 保存先と共有タスク一覧

`RUN_DIR` はrepo外の新しいrunディレクトリ。例は `${XDG_STATE_HOME:-$HOME/.local/state}/herdr/runs/<run-id>`。以下の変数は実際の絶対pathに設定する。

```text
RUN_DIR/
  registry.md                 人事のみ更新。役割・能力・ID・model・利用可否
  board.json                  対象board・workspaceのIDとCLI応答
  workboard-pending.md         障害時だけ、PMが未反映更新を一時記録
  roles/<role-id>.md           人事が用意する役割定義
  packets/<id>-<revision>.md   送信側が保存する指示
  results/<id>-<revision>.md   担当本人が書く結果
  checkpoints/<role-id>.md     担当本人が書く引き継ぎ
  layouts/<layout-id>/         CLI応答・実ID・途中状態
```

PMは開始時と進捗報告時にWorkboardのboard名・ID・workspaceを示す。カードに依頼・理由・担当・状態・成果・確認待ちを残し、状態とsessionの扱いは [workboard.md](workboard.md) に従う。依存taskはPMが成果を採用してから後続へ進める。Workboardを使わない明示指定時だけ `tasks.md` を同じ項目の台帳として使う。

registryには `role_id / role / report_to / agent / workspace / tab / pane / cwd / definition / requested_model / actual_model / effort / availability / quota_source / checked_at / lifecycle` を記録する。利用可否は `available / unavailable / unknown`。起動状態とtask状態は分ける。

複数PMでは仕事別のboardを使うか、共有boardの更新担当を一人に固定する。人事のsession作成もPMと直列化する。仕事間の依存はカード本文に他board/card IDと採用済みrevisionを記録する。

## 相談タブの起動

初回の人事・PMだけは呼び出し元がbootstrapする。人事自身を人事に起動させる循環を作らない。`SKILL_DIR` はこのherdrスキル、`JOB_CWD` は対象repo。既存PMを利用する場合は、新しいPMを重ねず必要な人事paneだけ用意する。

```zsh
mkdir -p "$RUN_DIR/layouts" "$RUN_DIR/roles" "$RUN_DIR/packets" "$RUN_DIR/results" "$RUN_DIR/checkpoints"
zsh "$SKILL_DIR/scripts/create-pair.zsh" \
  --workspace "$HERDR_WORKSPACE_ID" --cwd "$JOB_CWD" \
  --label "人事・PM" --left "人事" --right "PM" \
  --record-dir "$RUN_DIR/layouts/control" --dry-run
```

予定がscopeに合えば `--dry-run` を外して実行する。`stage=ready` を確認し、`layout.json` の `left_pane_id / right_pane_id` を読む。途中失敗では保存済みreceiptと実タブを照合し、同じ作成を繰り返さない。

agent名はrunごとに一意な32文字以内とする。`HR_NAME / PM_NAME / LEFT_PANE / RIGHT_PANE / HR_MODEL / PM_MODEL` を実際値に設定する。modelと引数は使うruntimeで確認する。

```zsh
herdr agent start "$HR_NAME" --kind codex --pane "$LEFT_PANE" --timeout 60000 -- \
  -m "$HR_MODEL" -c model_reasoning_effort=high --no-alt-screen --add-dir "$RUN_DIR"
herdr agent start "$PM_NAME" --kind codex --pane "$RIGHT_PANE" --timeout 60000 -- \
  -m "$PM_MODEL" -c model_reasoning_effort=high --no-alt-screen --add-dir "$RUN_DIR"
herdr agent prompt "$HR_NAME" "$(cat "$HR_ROLE_PACKET")" --wait --timeout 60000
herdr agent prompt "$PM_NAME" "$(cat "$PM_ROLE_PACKET")" --wait --timeout 60000
```

起動成功は入力可能状態の確認。role設定の完了とは分ける。役割の理解を読み、人事とPMへ互いの実IDを渡す。呼び出し元が初期roleを渡した後は、人事がregistryを管理する。

## 人事が実行役を用意する

PMが人事依頼packetとWorkboard card IDを送る。人事は [workboard.md](workboard.md) の `task start --shell` でカードに結びついたpaneを用意する。通常の `task start` でカード本文を実作業として起動しない。

以下はWorkboardを使わない明示指定時だけのタブ作成例。

```zsh
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$TASK_CWD" --label "$TASK_ID $ROLE_LABEL" --no-focus
```

応答の `result.tab.tab_id / result.root_pane.pane_id` を保存する。タブ作成直後に `agent_pane_busy` なら画面とshellの準備状態を確認してから、同じpaneへの起動だけを再試行する。タブを追加作成しない。

人事が相談タブと同じ `agent start` の形式で担当を起動し、role packetを送り、応答を確認する。Claude等は各CLIの現行引数を使う。`--add-dir` はアクセス範囲を足すだけで承認modeを変えない。trustや権限画面は、今回認可された対象と操作の範囲だけ対応する。

編集範囲が重なる場合はPMと調整し直列化するか、認可範囲内で独立checkoutを用意する。Git操作は導入済みの `git-ops` に従う。同じworkspaceの別タブを使うなら `tab create --cwd` を使う。`herdr worktree create` はworkspaceを新設する操作なので混同しない。

人事がregistryと編成結果を返し、PMが担当の実ID・role応答を確認してtaskを送る。人事はtask送信を代行しない。

## 配信・待機・相談

送信直前に一覧・状態を更新する。working中の担当には別taskを送らない。blockedなら画面の質問や権限確認を読む。

```zsh
herdr agent prompt "$TARGET" "$(cat "$TASK_PACKET")" --wait --until working --until blocked --timeout 15000
```

これは着手の観測であり完了待ちではない。すぐ終了するtaskやtimeoutでも、再送前に現在状態・出力・該当revisionの結果を確認する。

複数担当の待機はbackgroundまたはtoolのyieldを使う。

```zsh
zsh "$SKILL_DIR/scripts/wait-workers.zsh" "$IMPL_NAME" "$REVIEW_NAME"
```

- 状態変化時だけ1行を出し、全員idle/doneなら `ALL_SETTLED` でexit 0。
- blocked・unknown・取得不能は `NEEDS_ATTENTION` でexit 3。PMが画面と結果を確認する。対処後に残る担当で再開する。
- timeoutや `agent_prompt_stalled` は未送信の証拠ではない。同じpacketを即再送せず、`agent get / read / wait` と結果ファイルで確認する。
- 相談中に目標が変わったらPMがrevisionと一覧を更新する。中断が必要なら現行CLIの手順で実行を止め、途中成果を確認してから変更したtaskを渡す。
- PMは人事に届いた相談や編成変更も受け取り、作業指示との整合を保つ。チーム外へのメッセージやOS通知は別の認可がない限り追加しない。

## 回収と完了判定

1. 該当packet ID・revisionの結果ファイルを読む。画面だけに依存しない。alt-screenの出力が読めなければ `--source visible` を使う。
2. 結果が欠けたままidleになったら出力を確認し、一度だけ結果報告を依頼する。結果が揃っていれば完了文字列の欠落だけで仕事をやり直させない。
3. PMはWorkboardのreview列へ更新し、実物・差分・必要な検証を照合する。独立レビューが必要なら人事へread-only担当を依頼する。
4. 質問はPMが判断できる範囲で回答し、必要な人間の判断だけをまとめる。担当のDONEを採用後にカードをdoneへ進める。
5. 後続taskへ採用済みの成果revisionを渡す。必須E2E・live確認をfocused testやCI表示で置き換えない。

## 途中交代・終了

利用枠切れと待機timeoutを区別する。交代時は現在のrole・task revision、実際の状態、HEAD・dirty差分・成果・残作業を回収する。checkpointには担当とIDの一覧、正本台帳のpath、認可・予算、未解決事項と次の行動を残す。

旧担当のprocess停止とshellへの復帰を確認してから、人事が同じ認可範囲の後任を用意する。確認できなければ同じcheckoutに新しいwriterを起動しない。PMの交代は人事、人事の交代はPMがbootstrapする例外を認める。同じ起動失敗は根拠を確認して一度修復し、解消しなければ該当配信を止めて報告する。

後任は最新台帳と現物を照合し、未完部分だけ再開する。人事とPMがそれぞれ担当IDと台帳を更新する。

終了時は成果を回収し、今回作成した不要な担当だけを停止する。Workboardのカード・board・状態タブは履歴として残し、タブのcloseは保持対象でないものに限る。ユーザーの保持指示、未保存成果、稼働中serverを先に確認する。checkoutの削除は終了を理由に自動実行しない。`herdr server stop` は使わない。

最終報告は成果・検証・未解決事項・実際の担当とmodel・runのpathとWorkboardのboard ID・workspaceを含める。実Herdr確認では相談タブの配置、起動、role設定、小さな仕事の完走、担当追加・交代の各確認範囲を分ける。画面を確認する場合は `ui-screenshot` を使う。stub成功だけでlive完走と報告しない。
