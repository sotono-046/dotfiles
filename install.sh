#!/usr/bin/env bash
set -ue

# oh-my-zshのインストール
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi

# starshipのインストール
if ! command -v starship &>/dev/null; then
  echo "Installing starship..."
  brew install starship
fi

# バックアップと既存ファイルの削除
[ -e ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.dotbackup
[ -e ~/.config/starship.toml ] && mv ~/.config/starship.toml ~/.config/starship.toml.dotbackup
[ -e ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux.conf.dotbackup

mkdir -p ~/.config
mkdir -p ~/.config/starship
mkdir -p ~/.claude
mkdir -p ~/.codex
mkdir -p ~/.gemini

# dotfilesの設定
# "hoge:huga"みたいな感じで書く
dotfiles=(
  ".zshrc:$HOME/.zshrc"
  "starship.toml:$HOME/.config/starship.toml"
  ".tmux.conf:$HOME/.tmux.conf"
  "AGENTS.md:$HOME/.claude/CLAUDE.md"
  "AGENTS.md:$HOME/.codex/AGENTS.md"
  "AGENTS.md:$HOME/.gemini/GEMINI.md"
  ".sleep:$HOME/.sleep"
  ".wakeup:$HOME/.wakeup"
)

# 既存ファイルの削除とシンボリックリンクの作成
for dotfile in "${dotfiles[@]}"; do
  src="${dotfile%%:*}"
  dest="${dotfile##*:}"
  rm -f "$dest"
  ln -s "$(pwd)/$src" "$dest"
done


echo "✌️Install completed!!!!"
echo "✌️ Please restart your terminal or run: source ~/.zshrc"
