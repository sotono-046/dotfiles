---
name: orca-machine-handoff
description: 「退勤するから現状をminiに引き継いで」「MBPに引き継ぎ」「MacBookへ戻して」など、MacBook/MBP と Mac mini の間で Orca の作業やオーケストレーションを引き継ぐ。未コミット差分と判断メモを移し、指定先の agent に続きを任せる。
---

# Orca machine handoff

「miniへ引き継ぐ」「MBPに引き継ぎ」では、会話プロセスの移動ではなく、コードの同一 HEAD、作業ツリー差分、判断メモを指定先の新しい worktree に復元する。元の agent は新しい agent の開始を確認してから作業を止める。

## 宛先と引き継ぐ範囲

- 「mini」「Mac mini」は Mac mini、「MBP」「MacBook」は MacBook を**宛先**として扱う。現在いるマシンから決め打ちしない。「退勤するから現状をminiに引き継いで」「MBPに引き継ぎ」のような自然な依頼で実行する。宛先の明示を優先し、別名と Orca の実際の接続先は毎回照合する。
- 宛先が省略された「退勤するから引き継いで」は、現在のマシンと会話から相手が一意ならそこへ渡す。一意でない場合だけ宛先を聞く。「現状」は進行中の作業に関係する repo/worktree と、それを統括する Orca Run・Task を指す。複数の無関係な作業から対象を一意に決められない場合だけ特定する。
- 完了後の成果回収は逆方向の新しい handoff として行う。「MBPに引き継ぎ」は mini 側の作業を MBP に戻して続ける依頼でもある。元の dirty worktree を上書きせず、新しい clean worktree に復元する。

## オーケストレーションの引き継ぎ

1. 現在の Orca Run、Task、依存関係、Dispatch、未処理の質問・gate、担当 worker の配置と状態、関係する worktree を読み取り、引き継ぎメモに進捗・次の判断・許可済み操作を記録する。複数の worktree に必要な変更があれば、それぞれを梱包・復元し、元と先の対応を note に残す。`orca skills get orchestration` の現行ガイドと CLI の `--help` に従う。Run/Task/Dispatch ID は追跡用に残すが、別 runtime で同じ ID や実行中の process が移ると仮定しない。
2. 元マシン上の編集・検証・worker は、完了を待って結果を取り込むか、競合しない地点で区切る。未完了の worker や質問を放置して元マシンを閉じない。既存の supervised Dispatch を新マシンの agent に二重配信せず、元 coordinator の所有関係を明確にする。
3. 宛先の agent には「残作業の owner として続ける」ことを伝える。元の Run に未完了 Task があれば、元の Dispatch を完了・区切り済みとして記録し、宛先で新しい Run に残 Task と依存関係を作り直す。既存 Run への bind は、現行 CLI で coordinator の所有権を競合なく移せると確認できた場合に限る。宛先の agent が必要な worker を dispatch し、元 coordinator は新旧 Run を同時に進めない。単なる full handoff なら元マシン側で追跡用の Task/Dispatch を作らない。引き継ぎ元は宛先の agent が復元内容と指示を受理したところまで確認し、その後の進捗監視は新 owner に任せる。

## 開始前

1. `orca skills get orca-cli` と実行中の CLI の `--help` で現行構文を確認する。`orca status --json`、`orca environment list --json`、相手の `orca status --environment <name> --json` で両 runtime を確認する。接続先の表示名や host ID を固定しない。
2. 元 worktree の `git status --short --untracked-files=all`、HEAD、branch、upstream、submodule、実行中の terminal を確認する。別 agent の編集や test が動いていれば、その担当を区切る。梱包開始から相手側の受理確認まで、元 worktree に書き込む agent と process を止める。
3. 引き継ぎメモに目的、ここまでの判断、変更した path、実行済み検証と結果、残作業、Orca の進捗、実行許可の範囲、費用や live 操作の境界を書く。secret の値を書かない。ignored file と端末固有設定のうち必要なものは列挙し、自動梱包されたものと混同しない。
4. [補助スクリプト](scripts/handoff.py) の `pack` で snapshot を作る。dirty file と bundle 内の commit 履歴にある機密らしい path は拒否される。拒否された file は利用者と安全な受け渡し方法を確認し、無断で除外または転送しない。bundle の共通 base は target repo に存在する ref を選ぶ。`inspect` の `historyPaths` と `changedPaths` を転送前に確認する。

```bash
python3 agent/skills/orca-machine-handoff/scripts/handoff.py pack \
  --repo "$PWD" --base-ref '<base-ref>' --note /path/to/handoff-note.md \
  --out /path/to/task-handoff.zip
python3 agent/skills/orca-machine-handoff/scripts/handoff.py inspect \
  --packet /path/to/task-handoff.zip
```

## 転送と再開

- Orca に dirty file の転送コマンドはない。両端で認証できる `scp`/`rsync` を使えるなら packet を転送する。認証できない場合は補助スクリプトの `serve` / `fetch` を使い、Orca の remote terminal から受信する。`serve` は Tailscale IP のみに bind し、ランダムな一度限りの URL を期限付きで公開する。公開 URL はチャットや Issue に貼らない。転送後に SHA-256 を照合する。
- 相手の project host setup と repo を `orca project setups --project <project-id> --host runtime:<environment-id> --json` で確認する。未登録なら現行 CLI の `project setup-existing-folder` または `setup-clone` を使う。`orca worktree create --project <project-id> --host runtime:<environment-id> --name <task-name> --no-parent --setup run --json` で作業用に**新しい** worktree を作る。復元が先なので、この段階では agent を起動しない。既存の dirty worktree に直接復元しない。
- 相手側で `inspect` の HEAD、base、path を確認し、`restore --packet ... --repo <new-worktree> --note-out <worktree外の新しいメモpath>` を実行する。復元先は clean な linked worktree である必要がある。復元後に `git status --short`、HEAD、note、想定する差分を確認する。
- `restore` が途中で失敗したら、その worktree の状態を保って原因を調べる。`reset` や `clean` で再試行せず、新しい clean worktree を作って復元し直す。
- agent をその worktree で `orca terminal create --environment <target-name> --worktree id:<full-worktree-id> --command codex --json` などの現行 CLI で起動し、note の残作業と許可境界、オーケストレーションを続ける場合は新 coordinator の役割を渡す。`orca terminal wait --for tui-idle --timeout-ms ...` と terminal の応答で、agent が指示を受け取ったことを確認する。使われていない fallback shell ができた場合だけ確認して閉じる。元 worktree に `orca worktree set --worktree id:<source-full-worktree-id> --comment 'handed off; do not edit' --json` などで所有者変更を明示する。実際のテストや成果は相手の agent が再実行する。「閉じて大丈夫」は復元・起動・指示受理に加え、元マシンで依存する worker/process が残っていないと確認できた場合だけ伝える。

`serve` / `fetch` の例（送信元と受信先で補助スクリプトが利用できる場合）:

```bash
python3 agent/skills/orca-machine-handoff/scripts/handoff.py serve \
  --packet /path/to/task-handoff.zip --bind <source-tailscale-ip> --timeout 600
python3 agent/skills/orca-machine-handoff/scripts/handoff.py fetch \
  --url '<serve が表示した URL>' --sha256 '<serve が表示した SHA-256>' \
  --out /path/to/received-handoff.zip
```

## 逆方向へ戻す

mini から MBP に戻す場合も、検証結果と新しい判断、Orca の残 Task を note に更新し、同じ `pack` で成果を梱包する。MBP 側も新しい clean worktree に `restore` して確認する。元の作業ツリーへは自動で上書きしない。両側の変更を比較し、必要な commit や差分を明示的に統合する。mini の agent と test が終了し、MBP 側に成果と証跡が揃うまでは、元 worktree を削除しない。

`pack` は Git 管理下の staged/unstaged 差分と非 ignored の untracked file、選んだ base 以降の commit を含める。ignored file、端末固有の credential、実行中のプロセス、agent の会話履歴は移らない。path による機密検査は内容中の secret を検出できないため、転送前に差分と履歴も確認する。submodule を含む repo は自動梱包せず、別途扱う。pack の実行結果だけで引き継ぎ完了と判断しない。
