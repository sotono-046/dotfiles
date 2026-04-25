---
name: gws-cli
description: Google Workspace CLI (`gws`) を使って Drive / Gmail / Calendar / Sheets / Docs / Chat / Admin など Google Workspace の API を操作するスキル。ユーザーが「gws」「Google Workspace CLI」「Drive/Gmail/Calendar/Sheets/Docs/Chat を CLI で操作したい」「Workspace API を叩きたい」などと依頼したときに使用する。認証セットアップ、Discovery ベースのコマンド構造、ヘルパーコマンド（+send / +agenda / +upload など）、ページネーション、Sheets のシェルエスケープ、構造化 JSON 出力、終了コードを扱う。
---

# gws (Google Workspace CLI)

`gws` は Google の Discovery Service を実行時に読み、Workspace API のコマンドを動的に構築する CLI。全出力は構造化 JSON。

Repo: https://github.com/googleworkspace/cli

## インストール確認

```bash
which gws || npm install -g @googleworkspace/cli
gws --version
```

Homebrew: `brew install googleworkspace-cli` / Nix: `nix run github:googleworkspace/cli`

## 認証

優先度順：
1. `GOOGLE_WORKSPACE_CLI_TOKEN`（アクセストークン直接指定）
2. `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE`（OAuth / Service Account JSON）
3. `gws auth login` の暗号化済みクレデンシャル
4. `~/.config/gws/credentials.json`

初回セットアップ（gcloud がある場合）:

```bash
gws auth setup        # Cloud project 作成・API 有効化・ログイン
gws auth login        # 以降のスコープ選択とログイン
```

**重要**: OAuth app が testing mode のときスコープは ~25 が上限。`recommended` プリセットは 85+ スコープで失敗する。個別指定すること:

```bash
gws auth login -s drive,gmail,sheets
```

ヘッドレス/CI:
```bash
gws auth export --unmasked > credentials.json
export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/credentials.json
```

既存トークン流用:
```bash
export GOOGLE_WORKSPACE_CLI_TOKEN=$(gcloud auth print-access-token)
```

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

## 終了コード

| Code | 意味 |
|------|------|
| 0 | 成功 |
| 1 | API エラー（4xx/5xx） |
| 2 | 認証エラー |
| 3 | バリデーション（引数不正、サービス不明） |
| 4 | Discovery 取得失敗 |
| 5 | 内部エラー |

スクリプト内で `$?` を見て分岐できる。

## 環境変数

| 変数 | 用途 |
|------|------|
| `GOOGLE_WORKSPACE_CLI_TOKEN` | OAuth アクセストークン（最優先） |
| `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` | 認証 JSON パス |
| `GOOGLE_WORKSPACE_CLI_CLIENT_ID` / `_CLIENT_SECRET` | OAuth client 代替 |
| `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` | 設定ディレクトリ（デフォ `~/.config/gws`） |
| `GOOGLE_WORKSPACE_CLI_SANITIZE_TEMPLATE` / `_MODE` | Model Armor（`warn`/`block`） |
| `GOOGLE_WORKSPACE_CLI_LOG` | ログレベル（例 `gws=debug`） |
| `GOOGLE_WORKSPACE_CLI_LOG_FILE` | ログ出力ディレクトリ |
| `GOOGLE_WORKSPACE_PROJECT_ID` | GCP project override |

`.env` ファイルからも読まれる（dotenvy）。

## トラブルシューティング

- **"Access blocked" / 403**: OAuth consent → Test users に自分を追加して再試行
- **"Google hasn't verified this app"**: testing mode なら Advanced → Go to app (unsafe) で進む
- **スコープ過多エラー**: `--scopes drive,gmail,calendar` のように絞る
- **`redirect_uri_mismatch`**: OAuth client を **Desktop app** タイプで再作成
- **`accessNotConfigured` (403)**: エラー JSON の `enable_url` で API を有効化 → 10 秒待って再試行。`gws auth setup` が一括有効化可能
- **`gcloud` 不在**: Manual OAuth setup で `~/.config/gws/client_secret.json` を配置

## 利用時のガイドライン

1. **まず `gws <service> --help` を見る** — Discovery method と helper を同時に表示する
2. **スキーマ不明時は `gws schema <service>.<resource>.<method>` で確認**
3. **破壊的操作は `--dry-run` を先に実行**
4. **JSON 引数は single quote で囲う**（特に Sheets の `!`）
5. **大量取得は `--page-all | jq` でストリーム処理**
6. **認証エラー(exit 2) なら `gws auth login` を案内、スコープ不足なら `-s` で個別指定を案内**
7. **helper で済むものは helper を使う**（gmail +send などの方が `users messages send` + raw MIME 組み立てより簡単）

## 参考

- Repo / Issues: https://github.com/googleworkspace/cli
- Skills Index: https://github.com/googleworkspace/cli/blob/main/docs/skills.md
- Discovery Service: https://developers.google.com/discovery
- Model Armor: https://cloud.google.com/security/products/model-armor

> NOTE: これは Google 公式サポートプロダクトではない。active development 中で breaking changes がありうる。
