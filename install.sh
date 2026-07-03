#!/usr/bin/env bash
set -ue

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Homebrewのインストール (macOS / Linux)
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ "$OS" = "Darwin" ]; then
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
fi

# oh-my-zshのインストール
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
fi

# brewで導入するCLIツール
brew_formulae=(
  starship
  tmux
  git
  gh
  jq
  fzf
  ripgrep
  fd
  bat
  eza
  zoxide
  node
)

for formula in "${brew_formulae[@]}"; do
  if ! brew list --formula "$formula" &>/dev/null; then
    echo "Installing $formula..."
    brew install "$formula" || true
  fi
done

# Claude Code CLI のインストール (npm経由)
if ! command -v claude &>/dev/null; then
  echo "Installing Claude Code..."
  if command -v npm &>/dev/null; then
    npm install -g @anthropic-ai/claude-code || true
  else
    echo "npm not found, skipping Claude Code install"
  fi
fi

# ccstatusline のインストール (npm経由)
if ! command -v ccstatusline &>/dev/null; then
  echo "Installing ccstatusline..."
  if command -v npm &>/dev/null; then
    npm install -g ccstatusline || true
  else
    echo "npm not found, skipping ccstatusline install"
  fi
fi

# tpm (tmux plugin manager) のインストール
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing tpm..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" || true
fi

# バックアップと既存ファイルの削除
[ -e ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.dotbackup
[ -e ~/.config/starship.toml ] && mv ~/.config/starship.toml ~/.config/starship.toml.dotbackup
[ -e ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux.conf.dotbackup

mkdir -p ~/.config
mkdir -p ~/.config/starship
mkdir -p ~/.config/ccstatusline
mkdir -p ~/.claude
mkdir -p ~/.codex
mkdir -p ~/.gemini

# dotfilesの設定
# "hoge:huga"みたいな感じで書く
dotfiles=(
  ".zshrc:$HOME/.zshrc"
  "starship.toml:$HOME/.config/starship.toml"
  ".tmux.conf:$HOME/.tmux.conf"
  "ccstatusline.json:$HOME/.config/ccstatusline/settings.json"
  "agent/CLAUDE.md:$HOME/.claude/CLAUDE.md"
  "agent/AGENTS.md:$HOME/.codex/AGENTS.md"
  "agent/AGENTS.md:$HOME/.gemini/GEMINI.md"
  "agent/agents:$HOME/.claude/agents"
  "agent/commands:$HOME/.claude/commands"
  "agent/commands:$HOME/.codex/prompts"
  "agent/settings.json:$HOME/.claude/settings.json"
  "agent/skills:$HOME/.claude/skills"
  "agent/skills:$HOME/.codex/skills"
  "agent/hooks:$HOME/.claude/hooks"
)

# 既存ファイルの削除とシンボリックリンクの作成
for dotfile in "${dotfiles[@]}"; do
  src="${dotfile%%:*}"
  dest="${dotfile##*:}"
  # symlink 以外の既存物（実ファイル・実ディレクトリ）は上書き前に退避する
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.dotbackup"
  fi
  rm -rf "$dest"
  ln -s "$SCRIPT_DIR/$src" "$dest"
done


echo "✌️ Install completed!!!!"
echo "✌️ Please restart your terminal or run: source ~/.zshrc"