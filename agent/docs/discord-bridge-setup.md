# Discord ⇄ Claude Code 連携のセットアップ手順（別マシン導入用）

`agent/hooks/*discord*` が提供する Discord 連携（セッション開始/終了通知、ターン毎の応答抜粋投稿、権限待ち通知、Discord からのプロンプト注入）を新しいマシンに導入する手順。

## できること

- Claude Code のセッション開始/終了が Discord のスレッドとして記録される
- 各ターンの応答抜粋・権限待ち通知がスレッドに流れる（進捗が Discord だけで追える）
- **tmux 内で Claude Code を起動している場合**、Discord のスレッドに書いたメッセージが動作中のセッションにプロンプトとして注入される（tmux 外では通知のみ・注入は無効）

## 前提

- macOS（zsh 前提のスクリプト。Linux でも zsh があれば動く可能性が高いが未検証）
- Homebrew, `jq`, `tmux` がインストール済み
- Discord サーバー（guild）に bot を招待済みで、通知先チャンネルがある
- 別マシン間で Discord プロジェクト名・チャンネルを分けたい場合は環境変数で上書きできる（後述）

## 手順

### 1. dotfiles を導入する

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

`agent/hooks` → `~/.claude/hooks`、`agent/settings.json` → `~/.claude/settings.json` が symlink される（`install.sh` の `dotfiles` 配列を参照）。

### 2. discord-ops CLI を導入する

discord-ops 本体のインストール・MCP サーバー登録手順は `agent/mcp-servers.md` を参照（このドキュメントでは Discord 連携 hook 特有の部分のみ扱う）。CLI 単体（`discord-ops run ...`）が使えれば hook は動作する。

```bash
discord-ops init --project my-project --guild-id <guild-id> \
  --channel bus=<channel-id> --token-env DISCORD_TOKEN --default
```

`--project` に渡した名前が hook 側のデフォルト `CC_DISCORD_PROJECT`（既定値 `my-project`）と一致している必要がある。別名にする場合は手順4の環境変数で上書きする。

### 3. 認証トークンを設置する

`~/.discord-ops-env`（600権限、git 管理外）を作成する:

```bash
cat > ~/.discord-ops-env <<'EOF'
DISCORD_TOKEN=xxxxx
DISCORD_OPS_HTTP_TOKEN=xxxxx
EOF
chmod 600 ~/.discord-ops-env
```

hooks はこのファイルを自前で `source` するため、`.zshrc` での export は必須ではない（MCP サーバー自体を使う場合は `.zshrc` 側の export も必要。詳細は `agent/mcp-servers.md`）。

### 4. プロジェクト/チャンネル名をこのマシン用に変える場合

hook・デーモンは以下の環境変数で上書きできる（`agent/hooks/discord-session-lib.zsh` 参照）。既定値のままでよければ何もしなくてよい。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `CC_DISCORD_PROJECT` | `my-project` | discord-ops の project 名 |
| `CC_DISCORD_CHANNEL` | `bus` | スレッドを作る親チャンネルの alias |
| `CC_DISCORD_POLL_INTERVAL` | `10` | 注入デーモンのポーリング間隔（秒） |
| `CC_DISCORD_PROGRESS` | (未設定) | `off` にすると Stop/Notification の進捗投稿を止める（開始・終了通知のみに戻る） |

マシン固有の値にしたい場合は `~/.zshrc` や `~/.discord-ops-env` に `export CC_DISCORD_PROJECT=...` のように追記する（hook は `source ~/.discord-ops-env` するので、ここに書いても読み込まれる）。

### 5. Claude Code を tmux 内で起動する（注入を使う場合）

Discord → Claude への注入は tmux ペインへの `send-keys` で行うため、Claude Code は tmux のペイン内で起動すること。tmux 外で起動した場合は自動的に「注入無効・通知のみ」にフォールバックする（セッション開始メッセージに注記が出る）。

## 動作確認

1. tmux 内で対象リポジトリに `cd` して Claude Code を起動する
2. Discord の `bus` チャンネルに `[host] repo @ branch (時刻)` という名前のスレッドが作られることを確認する
3. 適当なプロンプトを打ってターンを1つ終える → スレッドに `🤖 応答 (HH:MM)` として応答抜粋が投稿されることを確認する
4. 権限確認が必要な操作（例: 未許可の Bash コマンド）を実行させる → スレッドに `⏸ 入力待ち: ...` が投稿されることを確認する
5. `pgrep -fl discord-inject` で注入デーモンが起動していることを確認する
6. Discord のスレッドに適当なメッセージ（例: 「1+1は？」）を書く → 10秒程度で Claude Code のペインにそのメッセージが入力され、実行されることを確認する。投稿の直後に `📥 注入: ...` がスレッドに投稿される
7. Claude Code を `/exit` で終了する → スレッドに `🏁 セッション終了 (...)` が投稿され、注入デーモンが終了する（`pgrep -fl discord-inject` で確認）

## トラブルシューティング

- **注入デーモンが起動しない**: `$TMUX_PANE` が空でないか確認する（`echo $TMUX_PANE`）。tmux 外で起動している場合は仕様通り無効
- **セッション開始通知が来ない**: `~/.discord-ops-env` の権限・内容、`discord-ops health` の結果を確認する。git リポジトリ外で起動した場合も通知は出ない（意図的な仕様）
- **GUI（Dock/Spotlight）から Claude Code を起動すると MCP の discord-ops が認証エラーになる**: `agent/mcp-servers.md` に記載の既知の制約（`.zshrc` を読まないため）。ただし本ドキュメントの hook 自体はこの制約を受けない（自前で `~/.discord-ops-env` を source するため）
- **孤児化したデーモンが残っている**: 次回 `SessionStart` 時に自動掃除される（`claude_pid` が死んでいるセッションの `daemon_pid` を kill）。手動で確認するには `pgrep -fl discord-inject`
- **同じメッセージが繰り返し投稿される**: Stop hook は直前と同一内容の応答なら投稿しない。それでも頻度が気になる場合は `CC_DISCORD_PROGRESS=off` で進捗投稿自体を止められる
