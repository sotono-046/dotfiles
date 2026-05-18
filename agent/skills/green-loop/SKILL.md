---
name: green-loop
description: テスト、型チェック、lint、format、差分チェックを確認し、明示された場合は全通まで修正と再実行を繰り返す品質ゲートループ。`品質チェック` は確認のみ、`テスト通して`, `greenにして`, `全通まで` は修正込みで使用する。
---

# green-loop

品質ゲートを確認し、修正依頼があるときは失敗を読んで直し、全通まで回す。

## トリガー

- ユーザーが test / type-check / lint / format を通すよう依頼した
- PR 前、移植後、リファクタ後の検証を求められた
- CI failure をローカルで再現して直す必要がある

PR の CI 監視や merge まで含む場合は `ci-merge-watch` を主役にする。

## 編集ゲート

- 「品質チェック」「品質確認」「見て」「確認して」「検出して」だけなら、実行結果と失敗を報告して停止する
- 「直して」「通して」「greenにして」なら、対象範囲内の修正まで進める
- 対象外の既存失敗、外部サービス障害、依存未導入だけが原因なら、原因と次操作を報告して停止する

## 標準ループ

1. package manager と既存 scripts を確認する
2. まず対象範囲の最小テストを実行する
3. 失敗を分類する
4. 修正する
5. 同じコマンドを再実行する
6. 範囲を広げる
7. 最後に `git diff --check` を実行する

同一失敗が 3 回続く場合は、同じ修正を繰り返さず原因仮説を更新する。外部要因で再現不能な場合は無理に修正しない。

## 推奨順序

1. 対象 test
2. 対象 package の type-check
3. 対象 package の lint
4. repo 標準の test / type-check / lint
5. format check または formatter
6. `git diff --check`

formatter が広範囲の unrelated 差分を出しそうな場合は、まず check だけ実行する。書き込み formatter は対象範囲が明確なときだけ使う。

## 失敗時の見立て

- 多数の test が setup で全滅: 実装バグより依存、env、test setup、node_modules を先に疑う
- module not found: install 状態、workspace link、lockfile、package script を確認
- targeted test が広がる: app / package root へ移動し、runner を直接叩けないか探す
- lint のみ失敗: 自動修正可能か確認し、意味のない disable は消す
- lockfile が動いた: その変更が必要か確認し、不要なら commit に含めない
- unrelated failure: 触っていない領域なら、修正せず分離して報告する

## 停止条件

- 指定された品質ゲートが全通した
- 対象外失敗だけが残った
- 同じ失敗が 3 回続き、追加情報なしでは進めない
- 依存、認証、外部サービスなどローカル修正で解けない blocker になった

## 報告

最終報告には、実行したコマンド、成功/失敗、残ったリスクだけを書く。ログ全文は不要。
