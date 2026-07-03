# MCP サーバー定義（マシンローカル）

Claude Code / Codex の MCP サーバー設定は `~/.claude.json`（user scope）と `~/.codex/config.toml` にのみ存在し、dotfiles リポジトリでは管理していない。理由は secret（トークン）を含むため。このファイルは再構築手順のドキュメントであり、値そのものは書かない。

## Claude Code（`~/.claude.json` の `mcpServers`）

| サーバー | transport | 用途 |
|---|---|---|
| `codex` | stdio (`codex mcp-server`) | Codex CLI を MCP 経由で呼び出す |
| `pencil` | stdio (`Pencil.app` 同梱バイナリ `--app desktop`) | .pen ファイルのデザイン編集 |
| `discord-ops` | SSE（**非推奨 transport**。Tailscale IP 経由） | Discord 通知・スレッド管理 |
| `serena` | stdio (`uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant --project "$PWD"`) | コードベースのシンボル単位解析・編集 |

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

**注意**: serena は `uvx --from git+...` で毎回リポジトリの最新版を取得して起動する。再現性より最新機能を優先する構成。ピン留めしたい場合は `git+https://github.com/oraios/serena@<tag>` のようにタグ/コミットを指定する。

**SSE の非推奨化**: Claude Code 公式ドキュメントは SSE transport を非推奨とし、HTTP transport への移行を推奨している。discord-ops サーバー側が HTTP に対応したら `--transport http` に切り替える。

## Codex（`~/.codex/config.toml` の `[mcp_servers.*]`）

`codex` / `pencil` / `serena` は Claude Code と同一定義。加えて Codex 固有で以下を持つ:

- `openaiDeveloperDocs`: `https://developers.openai.com/mcp`
- `node_repl`: Codex.app 同梱、browser/chrome 制御用（env 変数あり、詳細は `~/.codex/config.toml` 参照）

config.toml は dotfiles 管理外（アプリ・認証情報が絡むため）。手動で復元する場合は `~/.codex/config.toml` をバックアップから復元するか、上記 4 サーバーを `codex mcp add` 相当のコマンドで登録し直す。

## Gemini（`~/.gemini/settings.json` の `mcpServers`）

`pencil` のみ登録。dotfiles 管理外。
