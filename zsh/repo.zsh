# Git リポジトリ選択・移動コマンド群
# WORK_DIR 配下の .git を fzf で選び、cd や IDE / エージェント起動まで一気通貫で行う。

export REPOHIST_FILE="$HOME/.repo_history"
export WORK_DIR="$HOME/Documents"
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
        # .git 自体を1階層として数え、リポジトリルートは最大4階層まで探索する。
        # worktree 一覧は選択後に git worktree list から取得するため、この制限の影響を受けない。
        find "$work_dir" -maxdepth 5 \
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

# y/N を読み、y/yes なら成功を返す内部関数
_wt_confirm() {
    local prompt="$1"
    local reply

    if [[ -n "$prompt" ]]; then
        printf '%s [y/N] ' "$prompt"
    else
        printf '[y/N] '
    fi
    if ! read -r reply; then
        echo
        return 1
    fi

    [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}

# cwd が対象 worktree 配下なら親 worktree へ移る内部関数
_wt_leave_worktree_if_inside() {
    local target_path="$1"
    local main_path="$2"

    if [[ "$PWD" == "$target_path" || "$PWD" == "$target_path"/* ]]; then
        cd "$main_path" || return 1
        echo "作業ディレクトリを親ワークツリーへ移動しました: $main_path"
    fi
}

# 親以外の linked worktree を確認付きで削除する。
# --node は削除せず、各 linked worktree 直下の node_modules だけ消す。
# usage: _wt_clean [--node]
_wt_clean() {
    local node_only=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --node)
                node_only=1
                shift
                ;;
            -*)
                echo "unknown option: $1" >&2
                echo "usage: wt clean [--node]" >&2
                return 1
                ;;
            *)
                echo "usage: wt clean [--node]" >&2
                return 1
                ;;
        esac
    done

    local worktree_choices
    worktree_choices=$(_git_worktree_choices .) || return 1

    local main_line
    main_line=$(printf '%s\n' "$worktree_choices" | sed '/^$/d' | sed -n '1p')
    local main_path
    main_path=$(printf '%s\n' "$main_line" | cut -f2-)

    local linked_choices
    linked_choices=$(printf '%s\n' "$worktree_choices" | sed '/^$/d' | sed '1d')

    if [[ -z "$linked_choices" ]]; then
        echo "追加のワークツリーはありません"
        return 1
    fi

    local branch path
    local -a targets=()

    if (( node_only )); then
        echo "親以外のワークツリーの node_modules:"
        while IFS=$'\t' read -r branch path; do
            [[ -n "$path" ]] || continue
            if [[ -e "$path/node_modules" ]]; then
                targets+=("$branch"$'\t'"$path")
                printf '  %s\n    %s\n' "$branch" "$path/node_modules"
            fi
        done <<< "$linked_choices"

        if (( ${#targets[@]} == 0 )); then
            echo "削除する node_modules はありません"
            return 0
        fi

        echo
        if ! _wt_confirm "これらの node_modules を削除しますか?"; then
            echo "キャンセルしました"
            return 1
        fi

        local removed=0 failed=0
        for entry in "${targets[@]}"; do
            branch=$(printf '%s\n' "$entry" | cut -f1)
            path=$(printf '%s\n' "$entry" | cut -f2-)
            if rm -rf -- "$path/node_modules"; then
                echo "削除しました: $branch  $path/node_modules"
                removed=$((removed + 1))
            else
                echo "削除に失敗しました: $branch  $path/node_modules" >&2
                failed=$((failed + 1))
            fi
        done

        echo "完了: ${removed} 件削除${failed:+, ${failed} 件失敗}"
        (( failed == 0 ))
        return
    fi

    echo "親ワークツリー: $main_path"
    echo "削除候補:"
    while IFS=$'\t' read -r branch path; do
        [[ -n "$path" ]] || continue
        printf '  %s\n    %s\n' "$branch" "$path"
    done <<< "$linked_choices"
    echo

    local removed=0 skipped=0 failed=0
    while IFS=$'\t' read -r branch path; do
        [[ -n "$path" ]] || continue

        printf 'このワークツリーを削除しますか?\n  %s\n  %s\n' "$branch" "$path"
        if ! _wt_confirm ""; then
            echo "スキップしました: $branch"
            skipped=$((skipped + 1))
            echo
            continue
        fi

        if ! _wt_leave_worktree_if_inside "$path" "$main_path"; then
            echo "親ワークツリーへ移動できないためスキップします: $path" >&2
            failed=$((failed + 1))
            echo
            continue
        fi

        if git worktree remove --force --force -- "$path"; then
            echo "削除しました: $branch  $path"
            removed=$((removed + 1))
        else
            echo "削除に失敗しました: $branch  $path" >&2
            failed=$((failed + 1))
        fi
        echo
    done <<< "$linked_choices"

    echo "完了: ${removed} 件削除, ${skipped} 件スキップ${failed:+, ${failed} 件失敗}"
    (( failed == 0 ))
}

# 現在のリポジトリで新しい worktree を作って cd する
# usage: _wt_create [slug]
#   - slug 省略時は sotono/YYYYMMDDHHMMSS のブランチを作成
#   - slug 指定時は sotono/<slug> のブランチを作成
#   - fzf でベースブランチ（ローカル + リモート、更新順）を選択
_wt_create() {
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

# 現在のリポジトリ内の worktree を fzf で選んで cd する（repo の第2段階と同じ UI）
# usage: wt
#        wt create [slug]
#        wt clean
#        wt clean --node
wt() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "このディレクトリはGitリポジトリではありません"
        return 1
    fi

    case "${1:-}" in
        create)
            shift
            _wt_create "$@"
            ;;
        clean)
            shift
            _wt_clean "$@"
            ;;
        "")
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
            ;;
        *)
            echo "unknown option: $1" >&2
            echo "usage: wt" >&2
            echo "       wt create [slug]" >&2
            echo "       wt clean [--node]" >&2
            return 1
            ;;
    esac
}

# worktree / ローカル / リモートブランチを「ブランチ名<TAB>パス」形式で出す内部関数
# worktree があるブランチはパス付き、それ以外はパス空。同じ名前は worktree を優先する
_todev_branch_choices() {
    local repo_path="${1:-.}"

    {
        _git_worktree_choices "$repo_path"
        git -C "$repo_path" for-each-ref --format=$'%(refname:short)\t' refs/heads/
        git -C "$repo_path" for-each-ref --format='%(refname:short)' refs/remotes/ |
            grep -v '/HEAD$' |
            awk -F/ '{
                branch = $2
                for (i = 3; i <= NF; i++) branch = branch "/" $i
                if (branch != "") print branch "\t"
            }'
    } | awk -F '\t' 'NF && $1 != "" && !seen[$1]++'
}

# 指定ブランチの worktree へ移動し、最新化する。
# ブランチが別 worktree で使われている場合はそこへ移動し、
# ブランチが存在しない場合は remote-tracking branch または現在の HEAD から作成する。
# usage: todev [-s] [branch]
#   - 引数なし: develop へ移動する
#   - -s: fzf でブランチを選んでから実行する
#   - branch: そのブランチへ移動する。-s 付きなら絞り込みクエリになる
# example: todev
# example: todev main
# example: todev -s
# example: todev -s main
todev() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "このディレクトリはGitリポジトリではありません" >&2
        return 1
    fi

    local select_branch=0
    local target_branch=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s)
                select_branch=1
                shift
                ;;
            -*)
                echo "unknown option: $1" >&2
                echo "usage: todev [-s] [branch]" >&2
                return 1
                ;;
            *)
                if [[ -n "$target_branch" ]]; then
                    echo "usage: todev [-s] [branch]" >&2
                    return 1
                fi
                target_branch="$1"
                shift
                ;;
        esac
    done

    local repo_root
    repo_root=$(git rev-parse --show-toplevel) || return 1

    if (( select_branch )); then
        local branch_choices
        branch_choices=$(_todev_branch_choices "$repo_root") || return 1

        if [[ -n "$target_branch" ]]; then
            branch_choices=$(printf '%s\n' "$branch_choices" |
                awk -v query="$target_branch" 'index(tolower($1), tolower(query))')
        fi

        local branch_count
        branch_count=$(printf '%s\n' "$branch_choices" | sed '/^$/d' | wc -l | tr -d ' ')

        local selected
        if (( branch_count == 0 )); then
            if [[ -n "$target_branch" ]]; then
                echo "一致するブランチがありません: $target_branch" >&2
            else
                echo "ブランチが見つかりません" >&2
            fi
            return 1
        elif (( branch_count == 1 )); then
            selected="$branch_choices"
        else
            selected=$(printf '%s\n' "$branch_choices" |
                fzf --header 'Select branch' --with-nth=1 --delimiter=$'\t')
        fi

        if [[ -z "$selected" ]]; then
            return 1
        fi

        target_branch=$(printf '%s\n' "$selected" | cut -f1)
    elif [[ -z "$target_branch" ]]; then
        target_branch="develop"
    fi

    local worktree_branch worktree_path target_worktree=""
    while IFS=$'\t' read -r worktree_branch worktree_path; do
        if [[ "$worktree_branch" == "$target_branch" ]]; then
            target_worktree="$worktree_path"
            break
        fi
    done <<< "$(_git_worktree_choices "$repo_root")"

    if [[ -n "$target_worktree" ]]; then
        cd "$target_worktree" || return 1
    elif git show-ref --verify --quiet "refs/heads/${target_branch}"; then
        git switch "$target_branch" || return 1
    else
        local remote_branch=""
        if git show-ref --verify --quiet "refs/remotes/origin/${target_branch}"; then
            remote_branch="origin/${target_branch}"
        else
            local -a remote_branch_candidates
            remote_branch_candidates=(${(f)"$(git for-each-ref \
                --format='%(refname:short)' "refs/remotes/*/${target_branch}")"})

            if (( ${#remote_branch_candidates[@]} == 1 )); then
                remote_branch="${remote_branch_candidates[1]}"
            elif (( ${#remote_branch_candidates[@]} > 1 )); then
                echo "${target_branch} の remote-tracking branch が複数あります:" >&2
                printf '  %s\n' "${remote_branch_candidates[@]}" >&2
                return 1
            fi
        fi

        if [[ -n "$remote_branch" ]]; then
            git switch -c "$target_branch" --track "$remote_branch" || return 1
        else
            git switch -c "$target_branch" || return 1
        fi
    fi

    if git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
        git pull
    else
        echo "${target_branch} に upstream が未設定のため git pull はスキップします。"
    fi
}

# 初期化
if [[ ! -f "$REPOHIST_FILE" ]]; then
    touch "$REPOHIST_FILE"
fi
