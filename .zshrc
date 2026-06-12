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

# Gitリポジトリ履歴ファイル
export REPOHIST_FILE="$HOME/.repo_history"
export WORK_DIR="$HOME/Documents/_work"

_git_worktree_choices() {
    local repo_path="${1:-.}"

    git -C "$repo_path" worktree list --porcelain -z 2>/dev/null |
        perl -0ne '
            chomp;
            if ($_ eq "") {
                if (defined $path) {
                    my $label = defined $branch ? $branch : "detached HEAD";
                    $label =~ s|^refs/heads/||;
                    print "$label\t$path\n";
                }
                undef $path;
                undef $branch;
                next;
            }
            if (s/^worktree //) {
                $path = $_;
            } elsif (s/^branch //) {
                $branch = $_;
            }
            END {
                if (defined $path) {
                    my $label = defined $branch ? $branch : "detached HEAD";
                    $label =~ s|^refs/heads/||;
                    print "$label\t$path\n";
                }
            }
        '
}

_repo_choices() {
    local work_dir="${1:-$WORK_DIR}"

    {
        find "$work_dir" \
            -type d \( -name "node_modules" -o -name ".cache" -o -name "Library" -o -name ".Trash" -o -name "venv" -o -name ".venv" \) -prune -o \
            -name ".git" -type d -print 2>/dev/null |
            sed 's|/.git||' |
            awk -v prefix="$work_dir/" '{
                label = $0
                if (index($0, prefix) == 1) {
                    label = substr($0, length(prefix) + 1)
                }
                print label "\t" $0
            }'

        if [[ -d "$HOME/dotfiles/.git" ]]; then
            printf '~/dotfiles\t%s\n' "$HOME/dotfiles"
        fi
    } | awk -F '\t' '!seen[$2]++'
}

# リポジトリまたはワークツリーを選択する共通関数
_select_repo_or_worktree() {
    local work_dir="${1:-$WORK_DIR}"

    # 第1段階: メインリポジトリを選択
    local selected_repo=$(_repo_choices "$work_dir" |
        fzf --header 'Select Git repository' --with-nth=1 --delimiter=$'\t')

    if [[ -z "$selected_repo" ]]; then
        return 1
    fi

    local repo_path=$(printf '%s\n' "$selected_repo" | cut -f2-)

    # 第2段階: ワークツリーがあるかチェック
    local worktree_choices=$(_git_worktree_choices "$repo_path")
    local worktree_count=$(printf '%s\n' "$worktree_choices" | sed '/^$/d' | wc -l | tr -d ' ')

    local final_path
    if [[ $worktree_count -gt 1 ]]; then
        # ワークツリーが複数ある場合、ブランチ名を表示して選択
        local selected=$(printf '%s\n' "$worktree_choices" |
            fzf --header 'Select branch' --with-nth=1 --delimiter=$'\t')

        # 選択されたパスを取得
        if [[ -n "$selected" ]]; then
            final_path=$(printf '%s\n' "$selected" | cut -f2-)
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
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
    fi
}

cur() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        cursor "$selected_path"
    fi
}

_launch_tmux_ide_or_init() {
    local repo_path="$1"
    local template="$HOME/dotfiles/agent/templates/ide.yml"

    if [[ ! -f "$repo_path/ide.yml" ]]; then
        if [[ -f "$template" ]]; then
            local project_name
            project_name=$(basename "$repo_path")
            sed "s/__PROJECT_NAME__/${project_name}/" "$template" > "$repo_path/ide.yml"
            echo "ide.yml をテンプレートから作成: $repo_path/ide.yml"
        else
            echo "tmux-ide config is not ready; running tmux-ide init..."
            (cd "$repo_path" && tmux-ide init) || return 1
        fi
    fi

    tmux-ide "$repo_path"
}

agent() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        cursor "$selected_path"
        _launch_tmux_ide_or_init "$selected_path"
    fi
}

repo-claude() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        claude
    fi
}

repo-codex() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

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

    local worktree_choices
    worktree_choices=$(_git_worktree_choices .)
    local worktree_count
    worktree_count=$(printf '%s\n' "$worktree_choices" | sed '/^$/d' | wc -l | tr -d ' ')

    if (( worktree_count <= 1 )); then
        echo "追加のワークツリーはありません"
        return 1
    fi

    local selected
    selected=$(printf '%s\n' "$worktree_choices" | fzf --prompt='worktree> ')
    if [[ -n "$selected" ]]; then
        cd "$(printf '%s\n' "$selected" | cut -f2-)"
    fi
}

# 現在のリポジトリで新しい worktree を作って tmux-ide を起動する
# usage: wtptmux [slug]
#   - slug 省略時は sotono/YYYYMMDDHHMMSS のブランチを作成
#   - slug 指定時は sotono/<slug> のブランチを作成
#   - fzf でベースブランチ（ローカル + リモート、更新順）を選択
wtptmux() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "このディレクトリはGitリポジトリではありません"
        return 1
    fi

    local slug="${1:-$(date +%Y%m%d%H%M%S)}"
    local new_branch="sotono/${slug}"

    if git show-ref --verify --quiet "refs/heads/${new_branch}"; then
        echo "ブランチが既に存在します: ${new_branch}"
        return 1
    fi

    local base_choice
    base_choice=$({
        git for-each-ref --sort=-committerdate refs/heads/ \
            --format='%(committerdate:relative)%09%(refname:short)%09%(refname:short)'
        git for-each-ref --sort=-committerdate refs/remotes/ \
            --format='%(committerdate:relative)%09%(refname:short)%09%(refname:short)' |
            grep -v '/HEAD$'
    } | awk -F '\t' '!seen[$2]++' |
        fzf --prompt='base branch> ' \
            --header='ベースブランチを選択 (更新順)' \
            --with-nth=1,2 --delimiter=$'\t')

    if [[ -z "$base_choice" ]]; then
        echo "キャンセルしました"
        return 1
    fi

    local base_branch
    base_branch=$(printf '%s\n' "$base_choice" | cut -f3-)

    local base_commit="$base_branch"
    if [[ "$base_branch" == */* ]] && git show-ref --verify --quiet "refs/remotes/${base_branch}"; then
        base_commit="$base_branch"
    fi

    echo "Creating worktree: ${new_branch} (from ${base_branch})"
    if ! wtp add -b "${new_branch}" "${base_commit}"; then
        echo "wtp add に失敗しました"
        return 1
    fi

    local worktree_path
    worktree_path=$(wtp cd "${new_branch}") || {
        echo "wtp cd でパスを取得できませんでした: ${new_branch}"
        return 1
    }

    cd "${worktree_path}" || return 1
    echo "${worktree_path}" >> "$REPOHIST_FILE"

    _launch_tmux_ide_or_init "${worktree_path}"
}

# 初期化
if [[ ! -f "$REPOHIST_FILE" ]]; then
    touch "$REPOHIST_FILE"
fi

# Added by Devin
export PATH="/Users/sotono/.codeium/windsurf/bin:$PATH"
