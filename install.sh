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
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# バックアップと既存ファイルの削除
[ -e ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.dotbackup
[ -e ~/.config/starship.toml ] && mv ~/.config/starship.toml ~/.config/starship.toml.dotbackup

mkdir -p ~/.config

rm -f ~/.zshrc
rm -f ~/.config/starship.toml

# 絶対パスでシンボリックリンクを張る
ln -s /workspace/.zshrc ~/.zshrc
ln -s /workspace/starship.toml ~/.config/starship.toml

# starship 初期化を .zshrc に追加（なければ）
grep -q 'starship init zsh' ~/.zshrc || echo 'eval "$(starship init zsh)"' >>~/.zshrc

echo -e "\e[1;36mInstall completed!!!!\e[m"
echo "Please restart your terminal or run: source ~/.zshrc"
