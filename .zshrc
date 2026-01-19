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
export PATH="$HOME/.local/bin:$PATH"
# OpenJDK (Apple Silicon Mac)
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
export JAVA_HOME="/opt/homebrew/opt/openjdk"export PATH="$HOME/.local/bin:$PATH"


# bun completions
[ -s "$HONE/.bun/_bun" ] && source "$HONE/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by Antigravity
export PATH="$HONE/.antigravity/antigravity/bin:$PATH"


# Gitリポジトリ履歴ファイル
export REPOHIST_FILE="$HOME/.repo_history"
export WORK_DIR="$HOME/Documents/_work"
  
# ネストされたGitリポジトリを再帰的に検索する関数（履歴対応版）
cdrepo() {
    local WORK_DIR="${1:-/Users/sotono/Documents/_work}"
    local selected=$(find "$WORK_DIR" \
        -type d \( -name "node_modules" -o -name ".cache" -o -name "Library" -o -name ".Trash" -o -name "venv" -o -name ".venv" \) -prune -o \
        -name ".git" -type d -print 2>/dev/null |
        sed 's|/.git||' |
        sed "s|^$WORK_DIR/||" |
        fzf --header 'Git repositories')

    if [[ -n "$selected" ]]; then
        local full_path="$WORK_DIR/$selected"
        cd "$full_path"
        echo "$full_path" >> "$REPOHIST_FILE"
    fi
}

# repo + claude を起動する関数
repo() {
    local WORK_DIR="${1:-/Users/sotono/Documents/_work}"
    local selected=$(find "$WORK_DIR" \
        -type d \( -name "node_modules" -o -name ".cache" -o -name "Library" -o -name ".Trash" -o -name "venv" -o -name ".venv" \) -prune -o \
        -name ".git" -type d -print 2>/dev/null |
        sed 's|/.git||' |
        sed "s|^$WORK_DIR/||" |
        fzf --header 'Git repositories')

    if [[ -n "$selected" ]]; then
        local full_path="$WORK_DIR/$selected"
        cd "$full_path"
        echo "$full_path" >> "$REPOHIST_FILE"
        claude
    fi
}

# Gitリポジトリ履歴を閲覧する関数
cdrepoh() {
    local selected=$(tac "$REPOHIST_FILE" 2>/dev/null |
        awk '!seen[$0]++' |
        sed "s|^$WORK_DIR/||" |
        fzf --header 'Repository history')

    if [[ -n "$selected" ]]; then
        local full_path="$WORK_DIR/$selected"
        cd "$full_path"
    fi
}

# repoh + claude を起動する関数
repoh() {
    local selected=$(tac "$REPOHIST_FILE" 2>/dev/null |
        awk '!seen[$0]++' |
        sed "s|^$WORK_DIR/||" |
        fzf --header 'Repository history')

    if [[ -n "$selected" ]]; then
        local full_path="$WORK_DIR/$selected"
        cd "$full_path"
        claude
    fi
}

# 初期化
if [[ ! -f "$REPOHIST_FILE" ]]; then
    touch "$REPOHIST_FILE"
fi