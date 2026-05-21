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

# Gitリポジトリ履歴ファイル
export REPOHIST_FILE="$HOME/.repo_history"
export WORK_DIR="$HOME/Documents/_work"

# リポジトリまたはワークツリーを選択する共通関数
_select_repo_or_worktree() {
    local WORK_DIR="${1:-/Users/sotono/Documents/_work}"

    # 第1段階: メインリポジトリを選択
    local selected_repo=$(find "$WORK_DIR" \
        -type d \( -name "node_modules" -o -name ".cache" -o -name "Library" -o -name ".Trash" -o -name "venv" -o -name ".venv" \) -prune -o \
        -name ".git" -type d -print 2>/dev/null |
        sed 's|/.git||' |
        sed "s|^$WORK_DIR/||" |
        fzf --header 'Select Git repository')

    if [[ -z "$selected_repo" ]]; then
        return 1
    fi

    local repo_path="$WORK_DIR/$selected_repo"

    # 第2段階: ワークツリーがあるかチェック
    cd "$repo_path"
    local worktrees=$(git worktree list 2>/dev/null)
    local worktree_count=$(echo "$worktrees" | wc -l | tr -d ' ')

    local final_path
    if [[ $worktree_count -gt 1 ]]; then
        # ワークツリーが複数ある場合、ブランチ名を表示して選択
        local selected=$(echo "$worktrees" |
            awk '{
                path = $1
                # ブランチ名を抽出（[branch] の形式）
                for(i=2; i<=NF; i++) {
                    if ($i ~ /^\[.*\]$/) {
                        branch = $i
                        gsub(/^\[|\]$/, "", branch)
                        print branch "\t" path
                    }
                }
            }' |
            fzf --header 'Select branch' --with-nth=1 --delimiter=$'\t')

        # 選択されたパスを取得
        if [[ -n "$selected" ]]; then
            final_path=$(echo "$selected" | cut -f2)
        fi
    else
        # ワークツリーがない場合はそのままメインリポジトリを使用
        final_path="$repo_path"
    fi

    if [[ -z "$final_path" ]]; then
        return 1
    fi

    echo "$final_path"
    return 0
}

repo() {
    local WORK_DIR="${1:-/Users/sotono/Documents/_work}"
    local selected_path=$(_select_repo_or_worktree "$WORK_DIR")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
    fi
}

repo-claude() {
    local WORK_DIR="${1:-/Users/sotono/Documents/_work}"
    local selected_path=$(_select_repo_or_worktree "$WORK_DIR")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        claude
    fi
}

repo-codex() {
    local WORK_DIR="${1:-/Users/sotono/Documents/_work}"
    local selected_path=$(_select_repo_or_worktree "$WORK_DIR")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        codex
    fi
}

# 現在のリポジトリのワークツリーをfzfで選択して移動
wt() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "このディレクトリはGitリポジトリではありません"
        return 1
    fi

    local worktrees
    worktrees=$(git worktree list)
    local worktree_count
    worktree_count=$(printf '%s\n' "$worktrees" | wc -l | tr -d ' ')

    if (( worktree_count <= 1 )); then
        echo "追加のワークツリーはありません"
        return 1
    fi

    local selected
    selected=$(printf '%s\n' "$worktrees" | awk '{print $1}' | fzf --prompt='worktree> ')
    if [[ -n "$selected" ]]; then
        cd "$selected"
    fi
}

# 初期化
if [[ ! -f "$REPOHIST_FILE" ]]; then
    touch "$REPOHIST_FILE"
fi
