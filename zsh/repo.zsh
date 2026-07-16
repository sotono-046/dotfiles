# Git リポジトリ選択・移動コマンド群
# WORK_DIR 配下の .git を fzf で選び、cd や IDE / エージェント起動まで一気通貫で行う。

export REPOHIST_FILE="$HOME/.repo_history"
export WORK_DIR="$HOME/Documents/_work"
export REPO_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/repo-selector"
export REPO_CACHE_TTL="${REPO_CACHE_TTL:-300}"

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

# WORK_DIR 配下を走査し、Git リポジトリ候補を「表示名<TAB>絶対パス」形式で出力する内部関数
_scan_repo_choices() {
    local work_dir="${1:-$WORK_DIR}"

    {
        find "$work_dir" \
            -type d \( \
                -name "node_modules" -o -name ".cache" -o -name ".next" -o -name ".turbo" -o \
                -name "dist" -o -name "coverage" -o -name "target" -o \
                -name "Library" -o -name ".Trash" -o -name "venv" -o -name ".venv" \
            \) -prune -o \
            -name ".git" -type d -print -prune 2>/dev/null |
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

# 作業ディレクトリごとに衝突しないキャッシュファイル名を返す内部関数
_repo_cache_file() {
    local work_dir="${1:-$WORK_DIR}"
    local cache_key
    cache_key=$(printf '%s' "$work_dir" | cksum | awk '{print $1}')
    printf '%s/repos-%s.tsv\n' "$REPO_CACHE_DIR" "$cache_key"
}

# キャッシュが TTL 内なら成功を返す内部関数
_repo_cache_is_fresh() {
    local cache_file="$1"
    [[ -f "$cache_file" ]] || return 1

    local modified_at
    modified_at=$(stat -f '%m' "$cache_file" 2>/dev/null) || return 1
    (( $(date +%s) - modified_at < REPO_CACHE_TTL ))
}

# Git リポジトリ候補をキャッシュ経由で出力する内部関数
# 第2引数が refresh の場合はキャッシュを使わず再走査する
_repo_choices() {
    local work_dir="${1:-$WORK_DIR}"
    local refresh="${2:-}"
    local cache_file
    cache_file=$(_repo_cache_file "$work_dir") || return 1

    if [[ "$refresh" != "refresh" ]] && _repo_cache_is_fresh "$cache_file"; then
        command cat "$cache_file"
        return
    fi

    mkdir -p "$REPO_CACHE_DIR" || return 1
    local cache_tmp="${cache_file}.tmp.$$"
    if _scan_repo_choices "$work_dir" > "$cache_tmp"; then
        mv "$cache_tmp" "$cache_file" || return 1
        command cat "$cache_file"
    else
        rm -f "$cache_tmp"
        return 1
    fi
}

# fzf でリポジトリを選び、worktree が複数あればブランチも選択してパスを返す
# query が1件だけに一致した場合は、最初の fzf を省略する
# usage: selected_path=$(_select_repo_or_worktree [work_dir] [query] [refresh])
_select_repo_or_worktree() {
    local work_dir="${1:-$WORK_DIR}"
    local query="${2:-}"
    local refresh="${3:-}"

    # 第1段階: メインリポジトリを選択
    local repo_choices
    repo_choices=$(_repo_choices "$work_dir" "$refresh") || return 1

    if [[ -n "$query" ]]; then
        repo_choices=$(printf '%s\n' "$repo_choices" |
            awk -v query="$query" 'index(tolower($0), tolower(query))')
    fi

    local repo_count
    repo_count=$(printf '%s\n' "$repo_choices" | sed '/^$/d' | wc -l | tr -d ' ')

    local selected_repo
    if (( repo_count == 0 )); then
        if [[ -n "$query" ]]; then
            echo "一致するリポジトリがありません: $query" >&2
        else
            echo "リポジトリが見つかりません: $work_dir" >&2
        fi
        return 1
    elif (( repo_count == 1 )); then
        selected_repo="$repo_choices"
    else
        selected_repo=$(printf '%s\n' "$repo_choices" |
            fzf --header 'Select Git repository' --with-nth=1 --delimiter=$'\t')
    fi

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
# usage: repo [--refresh] [work_dir] [query]
# --refresh は work_dir の直後でも指定できる
# example: repo dot
repo() {
    local work_dir="$WORK_DIR"
    local refresh=""

    if [[ "${1:-}" == "--refresh" ]]; then
        refresh="refresh"
        shift
    fi

    # 既存の repo /path/to/work-dir 形式も維持する
    if [[ -n "${1:-}" && -d "$1" ]]; then
        work_dir="$1"
        shift
    fi

    if [[ "${1:-}" == "--refresh" ]]; then
        refresh="refresh"
        shift
    fi

    local query="$*"
    local selected_path
    selected_path=$(_select_repo_or_worktree "$work_dir" "$query" "$refresh") || return 1

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
