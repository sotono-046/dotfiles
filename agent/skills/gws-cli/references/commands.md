# gwsコマンド例

以下は操作形の例。実行前に導入済みversionのhelp/schemaと必要な公式仕様を確認し、対象ID・scope・更新内容を依頼に合わせる。大量取得に全pageを既定とせず、回答に必要な範囲だけ取得する。

## コマンド構造

基本形：
```bash
gws <service> <resource> <method> [--params '<JSON>'] [--json '<body JSON>'] [--upload <file>] [--dry-run]
```

- `--params`: URL パス / クエリパラメータを JSON で渡す
- `--json`: リクエストボディを JSON で渡す
- `--upload`: マルチパートアップロードのファイル
- `--dry-run`: 送信前にリクエストをプレビュー
- `--sanitize <template>`: Model Armor によるレスポンス検査

スキーマ確認:
```bash
gws schema drive.files.list
```

ヘルプ:
```bash
gws <service> --help   # Discovery method と helper (+) の両方を表示
```

## 代表的な例

```bash
# Drive 一覧
gws drive files list --params '{"pageSize": 10}'

# Drive アップロード（メタ + ファイル）
gws drive files create --json '{"name": "report.pdf"}' --upload ./report.pdf

# Sheets 作成
gws sheets spreadsheets create --json '{"properties": {"title": "Q1 Budget"}}'

# Chat 送信（dry-run）
gws chat spaces messages create \
  --params '{"parent": "spaces/xyz"}' \
  --json '{"text": "Deploy complete."}' \
  --dry-run
```

## ヘルパーコマンド（`+` 接頭辞）

手作りの高レベル helper。Discovery メソッドと衝突しないよう `+` が付く。

| Service | Command | 用途 |
|---------|---------|------|
| gmail | `+send` / `+reply` / `+reply-all` / `+forward` | メール送信・返信・転送 |
| gmail | `+triage` | 未読受信箱サマリ |
| gmail | `+watch` | 新着を NDJSON でストリーム |
| sheets | `+append` / `+read` | 行追加・値読み取り |
| docs | `+write` | ドキュメントにテキスト追記 |
| chat | `+send` | スペースにメッセージ送信 |
| drive | `+upload` | メタ自動付与アップロード |
| calendar | `+insert` / `+agenda` | 予定作成・アジェンダ |
| script | `+push` | Apps Script プロジェクトの全置換 |
| workflow | `+standup-report` / `+meeting-prep` / `+weekly-digest` / `+email-to-task` / `+file-announce` | ワークフロー |
| events | `+subscribe` / `+renew` | Workspace Events 購読 |
| modelarmor | `+sanitize-prompt` / `+sanitize-response` / `+create-template` | Model Armor |

時刻系 helper (`+agenda` など) は Calendar Settings API からタイムゾーン取得（24h キャッシュ）。`--timezone` / `--tz` で上書き。

例:
```bash
gws gmail +send --to alice@example.com --subject "Hello" --body "Hi there"
gws gmail +reply --message-id MESSAGE_ID --body "Thanks!"
gws sheets +append --spreadsheet SPREADSHEET_ID --values "Alice,95"
gws calendar +agenda --today --timezone America/New_York
gws drive +upload ./report.pdf --name "Q1 Report"
gws workflow +standup-report
```

## Sheets のシェルエスケープ（重要）

Sheets の range は `!` を含む。bash が履歴展開として解釈するので**必ず single quote** で囲む:

```bash
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "SPREADSHEET_ID", "range": "Sheet1!A1:C10"}'

gws sheets spreadsheets values append \
  --params '{"spreadsheetId": "ID", "range": "Sheet1!A1", "valueInputOption": "USER_ENTERED"}' \
  --json '{"values": [["Name","Score"],["Alice",95]]}'
```

## ページネーション

| Flag | 説明 | Default |
|------|------|---------|
| `--page-all` | 自動ページング、1 ページ 1 JSON 行 (NDJSON) | off |
| `--page-limit <N>` | 最大ページ数 | 10 |
| `--page-delay <MS>` | ページ間遅延 | 100ms |

```bash
gws drive files list --params '{"pageSize": 100}' --page-all | jq -r '.files[].name'
```
