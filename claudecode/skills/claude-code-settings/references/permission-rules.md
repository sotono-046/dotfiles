# Permission Rules 詳細リファレンス

Claude Code の permissions 設定における詳細なパターン構文とベストプラクティス。

## 基本構文

権限ルールは `Tool` または `Tool(specifier)` の形式に従う。

```json
{
  "permissions": {
    "allow": ["Tool", "Tool(specifier)"],
    "ask": ["Tool(specifier)"],
    "deny": ["Tool(specifier)"]
  }
}
```

## ルール評価順序

1. **Deny** ルールが最初にチェックされる
2. **Ask** ルールが2番目にチェックされる
3. **Allow** ルールが最後にチェックされる

最初にマッチするルールが動作を決定する。

## ツール別パターン

### Read & Edit

gitignore 仕様に従う4つのパターンタイプをサポート。

| パターン               | 意味                                     | 例                                                           |
| ---------------------- | ---------------------------------------- | ------------------------------------------------------------ |
| `//path`               | ファイルシステムルートからの**絶対パス** | `Read(//Users/alice/secrets/**)` → `/Users/alice/secrets/**` |
| `~/path`               | **ホーム**ディレクトリからのパス         | `Read(~/Documents/*.pdf)` → `/Users/alice/Documents/*.pdf`   |
| `/path`                | **設定ファイルに相対的な**パス           | `Edit(/src/**/*.ts)` → `<settings file path>/src/**/*.ts`    |
| `path` または `./path` | **現在のディレクトリに相対的な**パス     | `Read(*.env)` → `<cwd>/*.env`                                |

#### よくある間違い

```json
// ❌ 間違い - これは絶対パスではない
"Read(/Users/sotono/dotfiles/**)"

// ✅ 正しい - 絶対パスには // を使用
"Read(//Users/sotono/dotfiles/**)"
```

#### グロブパターン

- `*` - 任意の文字列（パスセパレータ以外）
- `**` - 任意のディレクトリ（再帰的）
- `?` - 任意の1文字

```json
{
  "allow": [
    "Read(//Users/alice/projects/**)", // プロジェクト内すべて
    "Edit(//Users/alice/projects/**/*.ts)", // TypeScriptファイルのみ
    "Read(~/.zshrc)" // ホームの.zshrc
  ],
  "deny": [
    "Read(./.env)", // カレントディレクトリの.env
    "Read(./.env.*)", // .env.local など
    "Read(./secrets/**)" // secretsディレクトリ
  ]
}
```

### Bash

2種類のワイルドカードをサポート。

| ワイルドカード | 位置               | 動作                                     | 例                                                        |
| -------------- | ------------------ | ---------------------------------------- | --------------------------------------------------------- |
| `:*`           | パターンの末尾のみ | プレフィックスマッチング（単語境界付き） | `Bash(ls:*)` → `ls -la` にマッチ、`lsof` にはマッチしない |
| `*`            | 任意の場所         | グロブマッチング（単語境界なし）         | `Bash(ls*)` → `ls -la` と `lsof` の両方にマッチ           |

#### プレフィックスマッチング（`:*`）

```json
{
  "allow": [
    "Bash(npm run:*)", // npm run build, npm run test など
    "Bash(git commit:*)", // git commit -m "..." など
    "Bash(docker compose:*)" // docker compose up など
  ],
  "deny": [
    "Bash(git push:*)", // git push をブロック
    "Bash(rm -rf:*)" // rm -rf をブロック
  ]
}
```

#### グロブマッチング（`*`）

```json
{
  "allow": [
    "Bash(git * main)", // git checkout main, git merge main など
    "Bash(* --version)" // node --version, npm --version など
  ]
}
```

#### 重要な注意事項

1. **`Bash(*)` はすべてにマッチしない**

   ```json
   // ❌ すべての Bash コマンドにマッチしない
   "Bash(*)"

   // ✅ すべての Bash コマンドを許可
   "Bash"
   ```

2. **引数制限パターンは脆弱**

   ```json
   // ⚠️ バイパス可能なパターン
   "Bash(curl http://github.com/:*)"

   // 以下はマッチしない：
   // - curl -X GET http://github.com/...（オプションが先）
   // - curl https://github.com/...（プロトコル違い）
   ```

3. **シェルオペレーターは認識される**
   ```json
   // safe-cmd && other-cmd は許可されない
   "Bash(safe-cmd:*)"
   ```

### WebFetch

ドメイン指定をサポート。

```json
{
  "allow": ["WebFetch(domain:github.com)", "WebFetch(domain:example.com)"],
  "deny": [
    "WebFetch" // すべてのWebFetchを拒否
  ]
}
```

### MCP ツール

MCP サーバーとツールの指定。

```json
{
  "allow": [
    "mcp__puppeteer", // サーバーのすべてのツール
    "mcp__puppeteer__*", // ワイルドカード構文（同上）
    "mcp__puppeteer__puppeteer_navigate" // 特定のツールのみ
  ]
}
```

### Task（サブエージェント）

```json
{
  "deny": [
    "Task(Explore)", // Explore サブエージェントを無効化
    "Task(Plan)", // Plan サブエージェントを無効化
    "Task(Verify)" // Verify サブエージェントを無効化
  ]
}
```

## ベストプラクティス

### 1. 最小権限の原則

```json
{
  "allow": [
    // プロジェクトディレクトリのみ許可
    "Read(//Users/me/project/**)",
    "Edit(//Users/me/project/**)",
    // 特定のコマンドのみ許可
    "Bash(npm run:*)",
    "Bash(git add:*)",
    "Bash(git commit:*)"
  ],
  "ask": [
    // 危険な操作は確認を求める
    "Bash(git push:*)",
    "Bash(rm:*)"
  ],
  "deny": [
    // 機密ファイルは完全にブロック
    "Read(./.env)",
    "Read(./secrets/**)"
  ]
}
```

### 2. deny ルールを活用する

deny ルールは常に優先されるため、機密ファイルの保護に有効。

```json
{
  "allow": [
    "Read(//Users/me/**)" // ホーム全体を許可
  ],
  "deny": [
    "Read(~/.ssh/**)", // SSHキーをブロック
    "Read(~/.aws/**)", // AWS認証情報をブロック
    "Read(./.env)", // 環境変数をブロック
    "Read(./credentials/**)" // 認証情報をブロック
  ]
}
```

### 3. ask ルールで確認を求める

元に戻しにくい操作には ask ルールを使用。

```json
{
  "ask": [
    "Bash(git push:*)", // リモートへのプッシュ
    "Bash(rm:*)", // ファイル削除
    "Bash(sudo:*)", // 管理者権限
    "Bash(gh release:*)", // リリース作成
    "Write(//Users/me/**)" // ホーム全体への書き込み
  ]
}
```

## 設定ファイルの優先順位

1. **Managed設定**（`managed-settings.json`）- 最高優先度
2. **コマンドライン引数**
3. **ローカルプロジェクト設定**（`.claude/settings.local.json`）
4. **共有プロジェクト設定**（`.claude/settings.json`）
5. **ユーザー設定**（`~/.claude/settings.json`）- 最低優先度

## トラブルシューティング

### パスが認識されない

```json
// ❌ 問題: /Users/... は設定ファイルからの相対パス
"Read(/Users/sotono/file)"

// ✅ 解決: // で絶対パスを指定
"Read(//Users/sotono/file)"
```

### Bash コマンドが許可されない

```json
// ❌ 問題: スペースがないとマッチしない
"Bash(git add*)"  // "git add -A" にマッチしない

// ✅ 解決: :* でプレフィックスマッチング
"Bash(git add:*)"  // "git add -A" にマッチ
```

### MCP ツールが許可されない

```json
// ❌ 問題: ツール名の形式が違う
"mcp__serena__find_symbol"

// ✅ 正しい形式
"mcp__serena"  // サーバー全体を許可
```
