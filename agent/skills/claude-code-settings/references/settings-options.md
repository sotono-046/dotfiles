# Settings Options リファレンス

Claude Code の settings.json で利用可能な設定オプション一覧。

## 設定ファイルの場所

| スコープ    | 場所                                                            | 用途                           |
| ----------- | --------------------------------------------------------------- | ------------------------------ |
| **User**    | `~/.claude/settings.json`                                       | すべてのプロジェクトに適用     |
| **Project** | `.claude/settings.json`                                         | チームと共有（git にコミット） |
| **Local**   | `.claude/settings.local.json`                                   | 個人設定（gitignore）          |
| **Managed** | `/Library/Application Support/ClaudeCode/managed-settings.json` | 組織ポリシー                   |

## 主要な設定オプション

### permissions

権限の設定。詳細は `permission-rules.md` を参照。

```json
{
  "permissions": {
    "allow": ["Tool", "Tool(specifier)"],
    "ask": ["Tool(specifier)"],
    "deny": ["Tool(specifier)"],
    "additionalDirectories": ["../docs/"],
    "defaultMode": "default"
  }
}
```

#### defaultMode

| モード              | 説明                                                |
| ------------------- | --------------------------------------------------- |
| `default`           | 標準動作 - 各ツールの最初の使用時に権限を促す       |
| `acceptEdits`       | セッションのファイル編集権限を自動的に受け入れる    |
| `plan`              | プランモード - ファイルを分析できるが変更はできない |
| `dontAsk`           | 事前に承認されていないツールを自動的に拒否          |
| `bypassPermissions` | すべての権限プロンプトをスキップ（危険）            |

### hooks

ツール実行の前後に実行するカスタムコマンド。

```json
{
  "hooks": {
    "PreToolUse": {
      "Bash": "echo 'Running command..'"
    },
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "source ~/.bashrc"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Hero.aiff"
          }
        ],
        "matcher": ""
      }
    ]
  }
}
```

#### 利用可能なフックイベント

- `SessionStart` - セッション開始時
- `SessionEnd` - セッション終了時
- `PreToolUse` - ツール実行前
- `PostToolUse` - ツール実行後
- `Notification` - 通知時
- `Stop` - 停止時
- `PermissionRequest` - 権限リクエスト時

### env

すべてのセッションに適用される環境変数。

```json
{
  "env": {
    "FOO": "bar",
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1"
  }
}
```

### model

使用するデフォルトモデル。

```json
{
  "model": "claude-sonnet-4-5-20250929"
}
```

### language

Claude の応答言語。

```json
{
  "language": "Japanese"
}
```

### MCP サーバー設定

```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["memory", "github"],
  "disabledMcpjsonServers": ["filesystem"]
}
```

### statusLine

カスタムステータスライン。

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

### plansDirectory

プランファイルの保存場所。

```json
{
  "plansDirectory": "./.temp/plans"
}
```

### attribution

git コミットとPRの属性設定。

```json
{
  "attribution": {
    "commit": "Generated with AI\n\nCo-Authored-By: AI <ai@example.com>",
    "pr": ""
  }
}
```

空文字列で属性を非表示にできる。

### その他のオプション

| キー                    | 説明                                 | 例                           |
| ----------------------- | ------------------------------------ | ---------------------------- |
| `alwaysThinkingEnabled` | 拡張思考をデフォルトで有効           | `true`                       |
| `cleanupPeriodDays`     | 非アクティブセッションの削除期間     | `30`                         |
| `showTurnDuration`      | ターン時間メッセージを表示           | `true`                       |
| `spinnerTipsEnabled`    | スピナーにヒントを表示               | `true`                       |
| `autoUpdatesChannel`    | アップデートチャネル                 | `"stable"` または `"latest"` |
| `respectGitignore`      | ファイルピッカーが .gitignore を尊重 | `true`                       |

## sandbox 設定

bash コマンドのサンドボックス設定（macOS、Linux、WSL2）。

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "git"],
    "network": {
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": true
    }
  }
}
```

## プラグイン設定

```json
{
  "enabledPlugins": {
    "formatter@acme-tools": true,
    "deployer@acme-tools": true
  },
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/claude-plugins"
      }
    }
  }
}
```

## 完全な設定例

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "language": "Japanese",
  "model": "claude-sonnet-4-5-20250929",
  "alwaysThinkingEnabled": false,
  "plansDirectory": "./.temp/plans",
  "permissions": {
    "allow": [
      "Glob",
      "Grep",
      "WebFetch",
      "WebSearch",
      "Read(//Users/me/projects/**)",
      "Write(//Users/me/projects/**)",
      "Edit(//Users/me/projects/**)",
      "Bash(npm:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "mcp__serena",
      "mcp__context7"
    ],
    "ask": ["Bash(git push:*)", "Bash(rm:*)", "Bash(sudo:*)"],
    "deny": ["Read(./.env)", "Read(./secrets/**)"],
    "defaultMode": "default"
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Hero.aiff"
          }
        ],
        "matcher": ""
      }
    ]
  },
  "enabledMcpjsonServers": ["playwright"],
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

## 関連ドキュメント

- 権限ルールの詳細: `permission-rules.md`
- 公式ドキュメント: https://code.claude.com/docs/ja/settings
- IAM ドキュメント: https://code.claude.com/docs/ja/iam
