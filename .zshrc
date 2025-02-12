# zshの基本設定
fpath=(~/.zfunc $fpath)
autoload -Uz compinit

# 各種評価とPATH設定
ZSH_THEME="cloud"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
eval "$(starship init zsh)"

. "$HOME/.local/bin/env"
source $HOME/.local/bin/env
