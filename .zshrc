# OSC無効化を最優先で実行
export STARSHIP_DISABLE_OSC=true

# Ghostty 等の macOS ターミナルは非 login shell のため .zprofile を明示的に読み込む
if [[ -z "${ZPROFILE_SOURCED:-}" && -f "$HOME/.zprofile" ]]; then
  ZPROFILE_SOURCED=1
  source "$HOME/.zprofile"
fi

# Ghostty shell integration: Starship / SSH との競合を抑止
if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
  # no-ssh-* が部分一致判定で効かず ssh ラッパーが有効になるため、ssh 関連文字列を除去
  _ghostty_features="${GHOSTTY_SHELL_FEATURES:-}"
  _ghostty_features="${_ghostty_features//no-ssh-env/}"
  _ghostty_features="${_ghostty_features//no-ssh-terminfo/}"
  _ghostty_features="${_ghostty_features//ssh-env/}"
  _ghostty_features="${_ghostty_features//ssh-terminfo/}"
  _ghostty_features="${(j:,:)${(s:,:)${_ghostty_features}//(#m)($|,|^)/}}"
  # PS1 書き換え・タイトル更新は Starship と競合しやすい
  [[ "$_ghostty_features" != *no-cursor* ]] && _ghostty_features="${_ghostty_features},no-cursor"
  [[ "$_ghostty_features" != *no-title* ]] && _ghostty_features="${_ghostty_features},no-title"
  export GHOSTTY_SHELL_FEATURES="$_ghostty_features"
  unset _ghostty_features

  if [[ -z "${SSH_CONNECTION:-}${SSH_TTY:-}" ]]; then
    ssh() { TERM=xterm-256color command ssh "$@"; }
  fi
fi

# SSH 先で xterm-ghostty terminfo が無いと vim/tmux 等が壊れる
if [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" && "${TERM:-}" == xterm-ghostty ]]; then
  export TERM=xterm-256color
fi

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

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
export PATH="$HOME/.local/bin:$PATH"
# OpenJDK (Apple Silicon Mac)
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
export JAVA_HOME="/opt/homebrew/opt/openjdk"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# リポジトリ選択 / tmux IDE 起動コマンドは zsh/ 配下に分割
for _zshrc_part in "$HOME/dotfiles/zsh/repo.zsh" "$HOME/dotfiles/zsh/tmux.zsh"; do
    [[ -f "$_zshrc_part" ]] && source "$_zshrc_part"
done
unset _zshrc_part


# Added by Devin
export PATH="$HOME/.codeium/windsurf/bin:$PATH"
