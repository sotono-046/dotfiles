#!/usr/bin/env bash
set -ue

# oh-my-zshのインストール
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# starshipのインストール
if ! command -v starship &>/dev/null; then
  echo "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# バックアップと既存ファイルの削除
if [ -e ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.dotbackup
fi

if [ -e ~/.config/starship.toml ]; then
  mv ~/.config/starship.toml ~/.config/starship.toml.dotbackup
fi

# ~/.configディレクトリがない場合は作成
mkdir -p ~/.config

# 削除
rm -rf ~/.zshrc
rm -rf ~/.config/starship.toml

# シンボリックリンクの作成
ln -s $(pwd)/.zshrc ~/.zshrc
ln -s $(pwd)/starship.toml ~/.config/starship.toml

command echo -e "\e[1;36m Install completed!!!! \e[m"
echo "Please restart your terminal or run: source ~/.zshrc"
