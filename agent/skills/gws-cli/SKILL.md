---
name: gws-cli
description: Google Workspace CLI（gws）を指定したDrive・Gmail・Calendar・Sheets等の操作に使う。
---

# Google Workspace CLI

`gws` が指定された場合や、接続済みtoolで不足するWorkspace API操作に使う。利用可能なconnectorで済む依頼にCLI導入や認証移行を追加しない。

## 実行

1. `command -v gws` と `gws --version` で導入状態を確認する。存在確認の失敗から自動的にglobal installへ進まない。導入が依頼に必要なら、現在の公式手順と対象環境に従う。
2. `gws <service> --help`、必要なら `gws schema <service>.<resource>.<method>` と [公式リポジトリ](https://github.com/googleworkspace/cli) で入力を確認する。導入済みversionを基準にし、料金・scope・制限値を固定の古い数値で判断しない。
3. 対象ID・取得範囲・変更内容を固定し、[コマンド例](references/commands.md)の該当操作だけ参照する。JSON引数は安全にquoteし、Sheetsの `!` 等をshellに解釈させない。
4. 既存の認証を利用する。認証修復が必要なら最小scopeで進め、秘密値は表示・ログ・Gitへ出さない。平文credential exportやCloud project作成・API有効化を、単なる確認手順に含めない。
5. 送信・共有・更新・削除は依頼された対象と操作だけ実施する。対応する `--dry-run` でリクエストを確認し、scopeや対象の拡張には必要な認可を得る。承認済みの分割処理に再承認を挟まない。
6. 結果と可能なら変更後の状態を確認する。部分成功は成功済みIDを保持し、再試行で重複送信・二重作成しない。

## 障害と完了

接続復旧後は元の依頼を継続する。再ログインや不足権限で本人の操作が必要な場合だけ、必要な操作を具体的に伝える。認証警告や証明書警告を無条件に回避させない。

取得・変更した対象と結果を返し、未処理があれば区別する。暗号化された既存認証を優先し、CI向けcredential移行は明示された場合だけ安全な保存先と用途に限定する。
