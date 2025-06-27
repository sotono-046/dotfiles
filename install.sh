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

rm -f ~/.zshrc
rm -f ~/.config/starship.toml
rm -f ~/.tmux.conf
rm -f ~/.claude/CLAUDE.md
rm -f ~/.gemini/GEMINI.md

# 絶対パスでシンボリックリンクを張る
ln -s "$(pwd)/.zshrc" ~/.zshrc
ln -s "$(pwd)/starship.toml" ~/.config/starship.toml
ln -s "$(pwd)/.tmux.conf" ~/.tmux.conf
ln -s "$(pwd)/CLAUDE.md" ~/.claude/CLAUDE.md
ln -s "$(pwd)/GEMINI.md" ~/.gemini/GEMINI.md

echo -e "\e[1;36mInstall completed!!!!\e[m"
echo "Please restart your terminal or run: source ~/.zshrc"
