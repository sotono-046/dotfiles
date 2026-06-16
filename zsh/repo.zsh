# Git リポジトリ選択・移動コマンド群
# WORK_DIR 配下の .git を fzf で選び、cd や IDE / エージェント起動まで一気通貫で行う。

export REPOHIST_FILE="$HOME/.repo_history"
export WORK_DIR="$HOME/Documents/_work"

# 指定リポジトリの worktree 一覧を「ブランチ名<TAB>パス」形式で出力する内部関数
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

# WORK_DIR 配下の Git リポジトリ候補を「表示名<TAB>絶対パス」形式で出力する内部関数
# ~/dotfiles は WORK_DIR 外でも常に候補に含める
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

# fzf でリポジトリを選び、worktree が複数あればブランチも選択してパスを返す
# usage: selected_path=$(_select_repo_or_worktree [work_dir])
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

# fzf でリポジトリを選んで cd する
# usage: repo [work_dir]
repo() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
    fi
}

# fzf でリポジトリを選び、cd して Cursor で開く
# usage: cur [work_dir]
cur() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        cursor "$selected_path"
    fi
}

# fzf でリポジトリを選び、cd して Claude Code を起動する
# usage: repo-claude [work_dir]
repo-claude() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        claude
    fi
}

# fzf でリポジトリを選び、cd して Codex を起動する
# usage: repo-codex [work_dir]
repo-codex() {
    local work_dir="${1:-$WORK_DIR}"
    local selected_path=$(_select_repo_or_worktree "$work_dir")

    if [[ -n "$selected_path" ]]; then
        cd "$selected_path"
        echo "$selected_path" >> "$REPOHIST_FILE"
        codex
    fi
}

# 現在のリポジトリ内の worktree を fzf で選んで cd する（repo の第2段階と同じ UI）
# usage: wt
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

# 現在のリポジトリで新しい worktree を作って cd する（tmux を起動しない wtptmux）
# usage: wtcl [slug]
#   - slug 省略時は sotono/YYYYMMDDHHMMSS のブランチを作成
#   - slug 指定時は sotono/<slug> のブランチを作成
#   - fzf でベースブランチ（ローカル + リモート、更新順）を選択
wtcl() {
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
    echo "${worktree_path}"
}

# 初期化
if [[ ! -f "$REPOHIST_FILE" ]]; then
    touch "$REPOHIST_FILE"
fi
