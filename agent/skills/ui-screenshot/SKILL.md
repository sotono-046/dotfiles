---
name: ui-screenshot
description: UIの作成・修正・見た目のレビューで、実画面のスクリーンショットを撮影・比較し、依頼されたPRへGitHub CLIで添付する。レイアウト、余白、表示崩れ、レスポンシブ、表示状態の確認に使う。
---

# UI Screenshot

UI作業では、変更前後の実画面を撮って確認する。画像から見つかった問題を修正し、確認済みの画像を成果物とPRに残す。

## 撮影する画面を決める

- 対象checkout・アプリ・URL・routeを確認する。既存サーバーが別checkoutを表示していないか確かめる。起動・復旧が必要なら、利用可能な `local-preview-start` を使う。
- 修正前に、指摘された画面と操作状態を撮る。既に変更済みなら、手元の変更を戻さず、変更前画像がないことを記録する。新規画面は変更後から撮る。
- 変更後は、同じviewport、zoom、データ、テーマ、スクロール位置、操作状態で比較する。画像にはURL、viewportの幅×高さ、表示状態、撮影時点のHEADを添える。未コミット変更を表示した画像は、その旨も記す。
- viewport全体を基本とし、細部には対象要素の画像、長いページにはfull-page画像を追加する。高さに関する指摘では幅と高さの両方を合わせる。FHDが対象なら1920×1080で確認し、WQHDの画像で代用しない。
- レスポンシブ変更は影響するdesktop・mobile幅で撮る。loading、empty、error、modal、hover、dark modeなどは変更に関係する状態を選ぶ。動きや遷移が問題なら、静止画に加えて利用可能な録画も使う。

## 実画面を撮って確認する

利用可能な環境の撮影機能を使い、返された画像または保存ファイルを目視確認する。スクリーンショットを保存しただけで確認済みと扱わない。

- T3 Codeの `preview_*` toolsがある場合は、`preview_status` を呼び、未接続なら `preview_open` を使う。目的のページへ移動し、必要なviewport・操作状態を設定する。`preview_snapshot` に `save: true` を渡してPNGを保存する。返された `screenshotPath` を添付用の実ファイルとして使い、回答では `![修正後の画面](絶対パス)` で表示できる。`includeImage: false` で保存した場合は、別途画像を開いて確認する。
- Orca内蔵browserでは、利用可能な `orca-cli` と現行ガイドの撮影手順を使う。その他のbrowserやnative appでは、その環境のtool契約と対象アプリに合う撮影機能を使う。
- 撮影前に、目的の表示が読み込まれ、loadingやanimationが比較に影響しない状態まで待つ。待機表示そのものが対象なら、その状態を撮る。
- 文字の切れ、重なり、余白、位置、スクロール、操作要素の見え方を画像で確認する。問題があれば修正し、影響した画面を再撮影する。最終画像が最後のUI変更を反映していることを確かめる。
- 画像は一時ディレクトリかproject指定のartifact保存先へ置く。既存画像を上書きせず、画面・状態・viewport・before/afterが分かる名前を付ける。PR添付のためだけに画像をGitへcommitしない。
- 共有用の画面にはテストデータを使い、秘密情報や個人情報が写っていないか添付前に確認する。

browserや撮影機能が使えなければ、試した方法と未確認の画面を報告し、コード変更や実行できる検証は続ける。HTTP応答やbuild成功だけで見た目まで確認済みとしない。

## PRへCLIで添付する

PR作成・更新が依頼されたUI作業では、確認済みの変更後画像を添付する。変更前画像があれば比較用に添える。撮影だけの依頼でPRを新規作成・更新しない。

Git操作と添付の詳細は [git-ops](../git-ops/SKILL.md) の「PR・Issueへの画像添付」を参照する。実環境の `gh --version` と対象commandの `--help` で `--attach` 対応を確認する。以下のrepository、PR番号、branch、ファイル名は実際の対象に置き換える。

```bash
# 新規PR。本文には比較条件と確認した内容も記載する
gh pr create --repo OWNER/REPO --base main --head feature-branch \
  --title '画面表示を修正' --body-file /tmp/pr-body.md \
  --attach '/tmp/before.png#変更前' --attach '/tmp/after.png#変更後'

# 既存PRの本文を保ち、末尾へ添付する
gh pr edit 123 --repo OWNER/REPO \
  --attach '/tmp/after.png#修正後の画面'

# 追加修正の確認結果は、画像付きコメントにもできる
gh pr comment 123 --repo OWNER/REPO --body-file /tmp/ui-check.md \
  --attach '/tmp/after.png#追加修正後の画面'
```

- 画像を本文の任意の位置に置く場合は、body fileに `![変更後](/tmp/after.png)` を書き、同じpathを `--attach` に渡す。ローカルpathを書くだけではアップロードされない。
- 添付の一部が失敗して終了codeが非zeroでも、PR作成・更新が済んでいる場合がある。出力URLと実際の本文を確認し、足りない画像だけを追加する。PRを重複作成しない。
- `--attach` 非対応なら、利用可能なブラウザ添付を使うか、その制約とローカル画像を報告する。CLI更新は実行環境の権限に従い、撮影や実装の停止条件にしない。
- 投稿後は、本文またはコメントにアップロード先URLが入り、GitHub上で画像を表示できることを確認する。T3 CodeでPR登録toolがあれば、作成・作業対象のPRを登録する。

添付仕様の出典: [GitHub CLIの公式ガイド](https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli)。

## 完了報告

撮影した画面・viewport・状態、画像のリンク、目視で確認した修正結果を簡潔に伝える。PRへ添付した場合はPRまたはコメントURLを添える。未撮影・未確認の範囲があれば明記する。
