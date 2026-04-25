---
name: cloudbuild-discord-notify
description: 'Cloud Build デプロイ完了時のDiscord webhook通知を実装・デバッグするスキル。cloudbuild.yaml の notify-deploy-webhook ステップの実装パターン、よくあるハマりポイント、デバッグ手順を網羅。'
---

# Cloud Build Discord 通知スキル

`cloudbuild.yaml` のデプロイ完了時 Discord 通知ステップの実装・デバッグガイド。

---

## 通知ステップの実装パターン

### 基本構造

```yaml
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk:latest'
  id: 'notify-deploy-webhook'
  entrypoint: /bin/bash
  args:
    - -e # ← `-eu` ではなく `-e` のみ（重要）
    - -c
    - |
      apt-get install -y -q jq

      WEBHOOK_URL=$$(gcloud secrets versions access latest --secret "<SECRET_NAME>")
      if [[ -z "$$WEBHOOK_URL" ]]; then
        echo "Failed to load webhook URL. Skipping."
        exit 0
      fi

      SERVICE_URL=$$(gcloud run services describe "$_SERVICE_NAME" \
        --platform managed \
        --region "$_DEPLOY_REGION" \
        --format='value(status.url)')
      if [[ -z "$$SERVICE_URL" ]]; then SERVICE_URL="(not available)"; fi

      COMMIT_SHORT="${COMMIT_SHA:0:7}"
      LAST_COMMIT_AUTHOR=$$(git log -1 --pretty=format:'%an' "$COMMIT_SHA" 2>/dev/null || echo "(unknown)")
      LAST_COMMIT_AUTHOR=$$(printf '%s' "$$LAST_COMMIT_AUTHOR" | sed 's/"/\\\"/g')

      # PR番号を推定
      PR_NUMBER=""
      if [[ -n "${_PR_NUMBER:-}" ]]; then
        PR_NUMBER="${_PR_NUMBER}"
      elif [[ -n "${BRANCH_NAME:-}" ]]; then
        PR_NUMBER=$$(echo "$BRANCH_NAME" | sed -n 's#^refs/pull/\([0-9]\+\)/.*#\1#p')
        if [[ -z "$$PR_NUMBER" ]]; then
          PR_NUMBER=$$(echo "$BRANCH_NAME" | sed -n 's#^pull/\([0-9]\+\)/.*#\1#p')
        fi
      fi
      if [[ -z "$$PR_NUMBER" ]]; then
        PR_NUMBER=$$(git log --no-decorate --pretty=%B "$COMMIT_SHA" | sed -n 's/.*#\([0-9][0-9]*\).*/\1/p' | head -n 1)
      fi

      if [[ -z "$$PR_NUMBER" ]]; then
        PR_LABEL="PR番号未検出"
      else
        PR_LABEL="PR #$$PR_NUMBER"
      fi

      # jq -n --arg で JSON 生成（YAML パースエラー回避のための必須パターン）
      jq -n \
        --arg trigger "$TRIGGER_NAME" \
        --arg pr "$$PR_LABEL" \
        --arg author "$$LAST_COMMIT_AUTHOR" \
        --arg url "$$SERVICE_URL" \
        --arg build "$BUILD_ID" \
        '{"embeds":[{"title":"✅ デプロイ完了","color":3062909,"fields":[{"name":"トリガー","value":$trigger,"inline":true},{"name":"PR","value":$pr,"inline":true},{"name":"コミット者","value":$author,"inline":true},{"name":"サービスURL","value":$url,"inline":false}],"footer":{"text":("Build ID: "+$build)}}]}' \
        > /tmp/discord_payload.json

      curl -sS -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/discord_payload.json \
        "$$WEBHOOK_URL" || true
  waitFor: ['set-nextauth-url']
```

### 必要な substitutions

```yaml
substitutions:
  _PR_NUMBER: '' # Cloud Build トリガーの substitution で設定（任意）
  _HEAD_BRANCH: '' # ブランチ名（任意）
```

---

## よくあるハマりポイントと対策

### 1. YAML パースエラー `could not find expected ':'`

**原因**: `|` ブロック内に YAML が誤認識する文字（`{}`, `:-`, `:` 等）が含まれる

**対策**:

- JSON 生成には必ず `jq -n --arg` を使う（ヒアドキュメントや `printf`, Python は全滅）
- `${VAR:-default}` の `:-` は事前に変数代入して回避する

```bash
# NG: YAMLパースエラーになる
HEAD_BRANCH="${_HEAD_BRANCH:-unknown}"

# OK: 事前代入で回避
HEAD_BRANCH="${_HEAD_BRANCH}"
if [[ -z "$$HEAD_BRANCH" ]]; then HEAD_BRANCH="unknown"; fi
```

### 2. `COMMIT_SHA: unbound variable` エラー

**原因**: entrypoint args に `-eu` を使うと、Cloud Build 組み込み変数が `-u` フラグにより未定義扱いされる

**対策**: `-eu` を `-e` のみに変更

```yaml
args:
  - -e # ← -eu ではなく -e のみ
  - -c
```

### 3. bash ローカル変数と Cloud Build 組み込み変数の混在

**ルール**:

- `$VAR` → Cloud Build 組み込み変数（`$COMMIT_SHA`, `$BUILD_ID`, `$TRIGGER_NAME` 等）
- `$$VAR` → bash ローカル変数（スクリプト内で代入した変数）

```bash
# Cloud Build組み込み変数
COMMIT_SHORT="${COMMIT_SHA:0:7}"   # $COMMIT_SHA はそのまま

# bash ローカル変数
WEBHOOK_URL=$$(gcloud secrets ...)  # $$ を使う
echo "$$WEBHOOK_URL"
```

### 4. `jq: command not found`

**原因**: `cloud-sdk` イメージに `jq` が入っていない

**対策**: ステップ冒頭で `apt-get install -y -q jq` を実行

```bash
apt-get install -y -q jq
```

### 5. Secret Manager のシークレットが存在しない

**確認コマンド**:

```bash
gcloud secrets list --project=<PROJECT_ID>
gcloud secrets versions access latest --secret=<SECRET_NAME>
```

**作成コマンド**:

```bash
echo -n "https://discord.com/api/webhooks/..." | \
  gcloud secrets create <SECRET_NAME> --data-file=-
```

---

## Discord embed フォーマット

### 色コード

| 色  | 10進数   | 16進数    | 用途         |
| --- | -------- | --------- | ------------ |
| 緑  | 3062909  | `#2ECC5D` | デプロイ完了 |
| 赤  | 15158332 | `#E74C1C` | 失敗通知     |
| 黄  | 16776960 | `#FFFF00` | 警告         |

### embed 構造

```json
{
  "embeds": [
    {
      "title": "✅ デプロイ完了",
      "color": 3062909,
      "fields": [
        { "name": "トリガー", "value": "...", "inline": true },
        { "name": "PR", "value": "PR #123", "inline": true },
        { "name": "コミット者", "value": "...", "inline": true },
        { "name": "サービスURL", "value": "https://...", "inline": false }
      ],
      "footer": { "text": "Build ID: ..." }
    }
  ]
}
```

---

## デバッグ手順

1. **ビルドログを確認**: Cloud Build コンソール → ビルド履歴 → 該当ビルド → ログ
2. **Secret Manager の値を確認**: `gcloud secrets versions access latest --secret=<SECRET_NAME>`
3. **ローカルで curl テスト**:
   ```bash
   curl -sS -X POST -H "Content-Type: application/json" \
     -d '{"content":"テスト通知"}' \
     "https://discord.com/api/webhooks/..."
   ```

---

## PR番号の取得優先順位

1. `_PR_NUMBER` substitution（トリガーで明示設定）
2. `BRANCH_NAME` から `refs/pull/123/...` パターンで抽出
3. `git log` のコミットメッセージから `#123` を抽出
4. 取得できない場合は「PR番号未検出」と表示
