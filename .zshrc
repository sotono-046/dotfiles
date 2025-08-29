# OSC無効化を最優先で実行
export STARSHIP_DISABLE_OSC=true

# zshの基本設定
fpath=(~/.zfunc $fpath)
autoload -Uz compinit
compinit

# starship プロンプト（OSC無効化）
export STARSHIP_DISABLE_OSC=true
eval "$(starship init zsh)"

ZSH_THEME="cloud"
# iTerm2 shell integration無効化（OSC出力を防ぐため）
# test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


. "$HOME/.local/bin/env"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
