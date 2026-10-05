# MCP サーバー定義（マシンローカル）

Claude Code / Codex / PiのMCPサーバー設定はmachine-localで管理する。設定先は`~/.claude.json`（user scope）、`~/.codex/config.toml`、`~/.pi/agent/mcp.json`。トークンを含むため、設定ファイル全体はdotfilesで管理しない。この文書には復元手順を記載し、秘密情報そのものは書かない。

## Claude Code（`~/.claude.json` の `mcpServers`）

| サーバー      | transport                                                                                                                  | 用途                                 |
| ------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| `codex`       | stdio (`codex mcp-server`)                                                                                                 | Codex CLI を MCP 経由で呼び出す      |
| `pencil`      | stdio (`Pencil.app` 同梱バイナリ `--app desktop`)                                                                          | .pen ファイルのデザイン編集          |
| `discord-ops` | SSE（**非推奨 transport**。Tailscale IP 経由）                                                                             | Discord 通知・スレッド管理           |
| `serena`      | stdio (`uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$PWD"`) | コードベースのシンボル単位解析・編集 |

### 再構築コマンド

```bash
claude mcp add --transport stdio --scope user codex -- codex mcp-server

claude mcp add --transport stdio --scope user pencil -- \
  /Applications/Pencil.app/Contents/Resources/app.asar.unpacked/out/mcp-server-darwin-arm64 --app desktop

claude mcp add --transport stdio --scope user serena -- \
  zsh -lc 'exec uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$PWD"'

# discord-ops: トークンは ~/.discord-ops-env (600権限, git管理外) の
# DISCORD_OPS_HTTP_TOKEN を .zshrc 経由で export している。
# ~/.claude.json 側は "Authorization": "Bearer ${DISCORD_OPS_HTTP_TOKEN}" と参照形式で保存。
claude mcp add --transport sse --scope user discord-ops http://<tailscale-ip>:3847/sse \
  --header "Authorization: Bearer \${DISCORD_OPS_HTTP_TOKEN}"
```

**トークンの置き場所**: `~/.discord-ops-env`（600権限、git 管理外）に `DISCORD_OPS_HTTP_TOKEN=...` を書き、`.zshrc` が `set -a; source ~/.discord-ops-env; set +a` で export する。`~/.claude.json` に平文トークンを書かないこと。

**制約**: `${DISCORD_OPS_HTTP_TOKEN}` の展開は Claude Code プロセス自身の環境変数に依存するため、**ターミナル（インタラクティブシェル経由）起動が前提**。Dock/Spotlight などから launchd 経由で起動した GUI アプリでは `.zshrc` を読まないため変数が渡らず、discord-ops MCP の認証に失敗する。GUI 起動もサポートしたい場合は `launchctl setenv DISCORD_OPS_HTTP_TOKEN ...` を行う LaunchAgent の追加を検討する（今回は未対応）。

**注意**: serena は `uvx --from git+...` で毎回リポジトリの最新版を取得して起動する。再現性より最新機能を優先する構成。ピン留めしたい場合は `git+https://github.com/oraios/serena@<tag>` のようにタグ/コミットを指定する。

**SSE の非推奨化**: Claude Code 公式ドキュメントは SSE transport を非推奨とし、HTTP transport への移行を推奨している。discord-ops サーバー側が HTTP に対応したら `--transport http` に切り替える。

## Codex（`~/.codex/config.toml` の `[mcp_servers.*]`）

`codex` / `pencil` / `serena` は Claude Code と同一定義。加えて Codex 固有で以下を持つ:

- `openaiDeveloperDocs`: `https://developers.openai.com/mcp`
- `node_repl`: Codex.app 同梱、browser/chrome 制御用（env 変数あり、詳細は `~/.codex/config.toml` 参照）

config.toml は dotfiles 管理外（アプリ・認証情報が絡むため）。手動で復元する場合は `~/.codex/config.toml` をバックアップから復元するか、上記 5 サーバーを `codex mcp add` 相当のコマンドで登録し直す。

## Gemini（`~/.gemini/settings.json` の `mcpServers`）

`pencil` のみ登録。dotfiles 管理外。

## UI registries（Claude Code / Codex / Pi共通）

`design`スキルのKibo UI・Aceternity UI・blocks.so・shadcn公式Registry Directory用に、公式の`shadcn` MCPを登録する。共通のregistry機能で扱えるため、ライブラリごとのMCPは追加しない。

```bash
claude mcp add --transport stdio --scope user shadcn -- npx -y shadcn@latest mcp
codex mcp add shadcn -- npx -y shadcn@latest mcp
pi mcp add shadcn --description 'Kibo UI・Aceternity UI・blocks.soを含むshadcn互換registryの部品検索・確認・導入' -- npx -y shadcn@latest mcp
```

Piはnative MCP対応版が対象。`pi mcp --help`で利用可否を確認する。設定は`~/.pi/agent/mcp.json`の`mcpServers.shadcn`へ保存される。追加のMCP bridge extensionは不要。

Claude Code / Codexは追加後に再起動する。Piは`/reload`または新しいセッションで読み直し、`pi mcp list`で接続を確認できる。user scopeで登録し、MCPの作業ディレクトリを特定のアプリへ固定しない。対象アプリの`components.json`へ追加するregistryは [designの利用手順](skills/design/references/ui-registries.md) を参照する。

一次資料: [shadcn MCP](https://ui.shadcn.com/docs/mcp)、[Codex MCP](https://developers.openai.com/codex/mcp)。Piの設定とCLIはインストール版の`docs/mcp.md`と`pi mcp --help`で確認する。
