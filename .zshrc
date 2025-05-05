# zshの基本設定
fpath=(~/.zfunc $fpath)
autoload -Uz compinit

# 各種評価とPATH設定
ZSH_THEME="cloud"
eval "$(starship init zsh)"
