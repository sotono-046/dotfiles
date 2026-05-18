---
name: sheet-csv-sync
description: Google SheetsとローカルCSV/TSVを同期し、Before/After列、差分適用、バックアップ、作業ログを扱う。質問集、営業リスト、台帳、レビュー表などのシートCSV双方向更新で使用する。
---

# sheet-csv-sync

Sheets と CSV/TSV の往復作業を、差分が追える形で進める。

## トリガー

- シートを CSV に落として編集する
- CSV の結果を Sheets に戻す
- Before / After 列で修正案を作る
- 大量行の進捗保存や再開が必要

## 前提

- Google Workspace 操作は `gws-cli` Skill を併用する。Connector や spreadsheets skill が明示されている場合はそちらを優先してよい
- 書き込み前に必ず対象 sheet / range / key column を確認する
- 破壊的更新の前にバックアップを作る
- この Skill は値の同期を主対象にする。formula、format、filter view、権限設定は別途扱う

## 基本手順

1. spreadsheet id、sheet name、range、header row を確認する
2. 現在値を取得し、必要最小限の backup を git 管理外の明示パスに保存する。PII/営業リストの full raw backup は既定で避ける
3. key column を決め、行順ではなく key で照合する
4. CSV/TSV を読み、型と空欄の扱いを決める
5. dry-run diff を出す
6. ユーザー承認または明示指示があれば書き戻す
7. 更新件数、skip 件数、conflict 件数を報告する

## Conflict ルール

- duplicate key、missing key、空 key があれば apply しない
- 書き戻し直前に対象 range を再取得し、backup 時点からの変更を conflict として扱う
- conflict は上書きせず、別ファイルまたは別列に出す
- dry-run diff が大きい場合は、件数とサンプルを見せてから apply する

## Before / After ワークフロー

- `Before` は元値を保持する
- `After` は提案値または確定値
- 空欄の `After` は「変更なし」とみなすか「空欄へ更新」とみなすか事前に決める
- conflict は上書きせず別列や別ファイルに出す

## 成果物

- backup metadata または必要最小限の raw backup
- normalized CSV
- dry-run diff
- apply log
- conflict report

## 注意

- セル内改行、カンマ、引用符、全角スペースを壊さない
- 大量更新は chunk 分割し、進捗と resume point を残す
- 個人情報や営業リストは不要にログへ全文出さない
- PII を含む backup / apply log は full dump を避ける。必要な場合だけ git 管理外の明示パス、最小範囲、保持期限、削除方針を確認する
- 共有や最終報告では件数、key、redacted sample を優先し、行全文を貼らない
