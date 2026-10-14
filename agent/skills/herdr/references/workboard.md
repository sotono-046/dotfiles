# Workboard連携

タスクの可視化と進捗の正本は [Phoobobo/herdr-workboard](https://github.com/Phoobobo/herdr-workboard) に置く。PMがカードの依頼・理由・担当・状態・成果・確認待ちを管理する。人事は担当を用意し、実行役はPMへ報告する。

2026-10-14に導入済みcommit `4ed467d4ff03b0d8c222e03271686c867d27f85a` のREADME・CLI・実装を確認した。導入versionが違う場合は現行CLIで構文と挙動を確認する。

## 配置と記録

```text
board workspace
  board             全タスクの可視化
  相談              人事 | PM
  todo              未着手taskのpane
  doing             実行中taskのpane
  review            PMの確認待ちtaskのpane
  done              PMが採用したtaskのpane
```

boardがworkspace、列が状態別tab、カードのsessionがpaneに対応する。カードの移動は実paneの移動を伴う。通常の「1担当1タブ」はこの構成では使わない。人事・PMは状態列の外の相談タブに置く。

Workboardのカード状態・内容を正本とし、`tasks.md` を別の進捗台帳として二重管理しない。`RUN_DIR` はrole・packet・成果・検証・checkpointを保存する。`board.json` にboard ID・workspace IDとCLI応答を、registryにcard ID・担当・実pane IDの対応を残す。本文にはそれらの絶対pathを載せる。

1カードに結びつけられるsessionは1つ。並列の独立レビュー・調査は別カードを作って依存関係を記す。既存の稼働paneを任意のカードへbindする公開CLIは確認できていない。移行中の既存担当はカード本文に実IDを記録して追跡し、同じ仕事を二重起動しない。新規taskから下記のsession作成を使う。

## CLIの準備

```zsh
herdr plugin list
command -v herdr-workboard
```

未導入でセットアップを依頼されている場合は `herdr plugin install Phoobobo/herdr-workboard`。プラグイン導入だけではCLIがPATHに入らない。`herdr plugin list` とplugin registryから実際のplugin rootを確認し、以下のいずれかを使う。rootのハッシュ部分を推測しない。

```zsh
bun run "$WORKBOARD_ROOT/src/cli.ts" --help
# plugin rootで bun link を実行するとCLIを登録できる
```

以下は `herdr-workboard` が使える前提。見つからなければ `bun run "$WORKBOARD_ROOT/src/cli.ts"` に置き換える。確認したversionでは `--help` はusageを表示してexit 2になる。これをplugin未導入と誤認しない。

すべてのboard操作で `--board "$BOARD_ID"` または `--workspace "$BOARD_WORKSPACE"` を明示する。focusからの暗黙選択は使わない。JSONの `ok` と終了コードを確認し、取得したIDを保存する。

## Boardを選ぶ・作る

既存boardを一覧し、今回のworkspaceと仕事に対応するものを使う。cwdが同じだけでは選ばない。

```zsh
herdr-workboard board list --json
herdr-workboard board show --workspace "$HERDR_WORKSPACE_ID" --json
```

実workspace操作はHerdr管理pane内から行う。管理外ではCLI準備・packet作成・隔離テストまで進め、既存boardへ書き込まない。

現在workspaceへ追加する場合は、実際のactive workspaceが対象と一致していることを確認してから `herdr plugin action invoke phoobobo.workboard.attach`。attachには対象ID引数がなく、active workspaceを使うため、focusを確認できなければ実行しない。既存相談タブを保持したままboardと状態タブが追加される。既にbind済みなら再利用する。

新しい独立workspaceを作る依頼なら明示的な名前とcwdで作成する。

```zsh
herdr-workboard board new --name "$BOARD_NAME" --cwd "$JOB_CWD" --json
```

戻り値 `.board.id / .board.workspace_id / .board.board_pane_id` を保存する。新規workspaceを作った場合は、以後相談タブもそのworkspaceに置く。現在paneの `HERDR_WORKSPACE_ID` を偽装せず、そのworkspace内の担当へ操作を引き継ぐ。

## PMが状態を決める

自動同期の既定値はONであり、agentのworking・blocked・doneから列が変わる。PMによる成果判定と混同しないよう、チーム運用ではboard画面の `A` でauto-syncをOFFにし、状態バーでOFFを確認する。既にOFFなら押さない。確認したCLIにはauto-sync設定コマンドがないため、未対応flagや保存JSONの直接編集で代替しない。確認できない間はカードと指示の準備まで進め、agentの状態からDoneへ進む運用を開始しない。

| 作業状態 | Workboardの列 | PMの更新条件 |
| --- | --- | --- |
| PLANNED | todo | 依頼と理由・担当候補・依存を記録 |
| RUNNING | doing | PMがtaskを配信し、着手を確認 |
| VERIFYING | review | 成果を回収し、検証・採否を確認中 |
| DONE | done | PMが完了条件と必要な検証を照合し採用 |
| BLOCKED / FAILED | 直前の列 | タイトルを `[BLOCKED]` / `[FAILED]` 付きに更新し、本文に原因と次の判断を書く |
| CANCELLED | 直前の列のまま記録後archive | 中止理由・途中成果を記録し、稼働担当の停止と成果回収を先に確認 |

列名が変更されていれば `board show` の実state IDへ対応づける。上表の名前を固定IDとして扱わない。人間がカードを移動・編集したら、PMは意図を確認し成果と照合する。手動でdoneへ動いたことだけを後続taskの依存解消に使わない。

## カードの作成と更新

PMが本文をファイルに用意する。`task update --body` は本文全体の置換なので、先に `task show` で読み、人間の追記を保持して更新する。boardの書き込みはPMがまとめ、人事のsession作成中も同時更新しない。別々のCLIプロセスやTUIからの同時編集を避け、更新後に読み戻す。

```text
run_id / job_id / task_id / revision:
依頼:
理由:
担当 / report_to / agent / pane:
完了条件:
依存: board ID・card ID・採用済みrevision
担当scope / 除外 / cwd / branch / HEAD / 認可 / git_owner:
role packet / task packet: 絶対path
成果 / 検証: 絶対path、結果と未確認事項
確認待ち / 次の行動:
```

```zsh
herdr-workboard task add "$TITLE" --body "$(cat "$CARD_BODY")" --state todo --board "$BOARD_ID" --json
herdr-workboard task show "$CARD_ID" --board "$BOARD_ID" --json
herdr-workboard task update "$CARD_ID" --body "$(cat "$CARD_BODY")" --board "$BOARD_ID" --json
herdr-workboard task move "$CARD_ID" --state review --board "$BOARD_ID" --json
```

addの応答 `.task.id` を保存する。カード作成にはrequest IDによる重複防止がないため、応答を失ったら `task list` で本文のrun/task/revisionを照合してから再試行する。`--json` や `--board` はagent argv区切りの `--` より前に置く。

## 人事がカードに実行役を用意し、PMが動かす

通常の `task start` はカード本文を初期promptとしてagentを実行する。role確認前の実作業と二重配信を防ぐため、人事は **`task start --shell`** でカードに結びついたshell paneだけを作る。

```zsh
herdr-workboard task show "$CARD_ID" --board "$BOARD_ID" --json
herdr-workboard task start "$CARD_ID" --shell --board "$BOARD_ID" --json
```

startは既存sessionを再利用する保証がない。既に `.task.pane_id` があれば状態を照合してそのpaneを使い、再実行しない。応答喪失時もtask showとHerdrの実状態を確認する。pane作成後・cardへのID保存前に失敗する場合があるため、pane_idがnullでも未作成と断定しない。既存paneを一意に照合できなければstartを再実行せず、未反映記録に状況を残して復旧する。返った `.pane.pane_id` と `.task.pane_id` を保存する。

人事がこのshellに `herdr agent start` で担当を起動し、role packetだけを送る。独立checkoutを使う場合は起動前にshellのcwdを確認し、runtimeの作業ディレクトリ指定などで対象checkoutを明示する。Workboardのshellは既定でboard.cwdを使うため、カード本文に別cwdを書くだけでは変更されない。

role応答を確認して人事がPMへ実IDを返す。その後、PMが `herdr agent prompt` でtaskを送り、着手を確認してdoingへ移す。CLIの `task move` はagentを起動しないが、TUIでsessionのないカードをdoingへ動かすと起動し得るため、チーム配信ではCLIを使う。

移動後はtask showを読み戻し、pane IDを再取得する。moveの応答を失った場合はカードのstateと実paneの所属tabを照合する。既に目標列へ到達していれば再送せず、カード記録だけが古い場合は実状態を確認してから同じ目標列へのmoveで整合させる。人事はregistryを更新し、PMはカード本文の担当情報を揃える。成果回収後にreviewへ、PMの採用後にdoneへ移す。担当交代は [operations.md](operations.md) の停止・回収手順に従い、同じtaskを最初から再配信しない。

Doneカードとboardは履歴として残す。稼働中sessionや成果を未回収のまま `task archive --close-pane` やstate tabのcloseを行わない。不要sessionの終了は担当停止を確認してから行う。

## Workflow機能と障害時

`workflow init / transition / run start / run finish` は必要な場合だけ使う。role runは実agentの起動ではなく実行記録。1workspaceに1つのworkflowを置けるが、今回の役割分担のために全カードを単一workflowへ無理にまとめない。既存workflowを `--force` で置換しない。

Workboardが使えない場合は原因と可視化できていない範囲を報告する。認可済みの進行中作業は成果を回収し、未反映の更新だけ `RUN_DIR/workboard-pending.md` へ記録する。復旧後にカードの実状態と照合してPMが反映する。明示指定がある場合以外、Markdownを恒久的な別の進捗正本にしない。
