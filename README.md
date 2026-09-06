# Sotono's Dotfiles

## 前提環境

- macOS
- zsh
- starship
- tmux
- Claudecode
- Codex CLI
- Gemini CLI

## 使い方

`./install.sh` で依存ツールの導入と設定の symlink 配信を行います。設定だけを反映する場合は `./install.sh --links-only`、エージェント設定だけなら `./install.sh --agent-only` を使います。先に `--dry-run` を付けると変更予定を確認できます。

エージェント設定は Claude Code / Codex / Gemini に配信します。既存ファイルは `~/.local/state/dotfiles/backups/` に保全します。配信対象と権限設定は [agent/README.md](agent/README.md) を参照してください。

installer の隔離テストは `python3 -m unittest discover -s tests -p 'test_install.py'` で実行します。実 HOME の設定は変更しません。

## `./.vscode/launch.json`

- デバッグ用の設定ファイル
- `install.sh`をデバッグするための設定
