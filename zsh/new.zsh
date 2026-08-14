# 月と名前から WORK_DIR 配下に作業ディレクトリを作り、そこへ移動する。
# usage: new <name> [name ...]
#        new -g <git-url>
# example: new sotono hogefuga -> $WORK_DIR/2608_sotono_hogefuga
#          new -g https://github.com/bonginkan/design-bonginkami
#            -> clone to $WORK_DIR/2608_bonginkan_design-bonginkami

# git URL / owner/repo から clone 用 URL・owner・repo を取り出す。
# 成功時は _new_git_reply=(clone_url owner repo) をセットする。
_new_git_spec() {
    local spec="$1"
    spec="${spec#"${spec%%[![:space:]]*}"}"
    spec="${spec%"${spec##*[![:space:]]}"}"
    spec="${spec%%[?#]*}"
    spec="${spec%/}"

    if [[ -z "$spec" ]]; then
        echo "git URL が空です" >&2
        return 1
    fi

    local host="github.com"
    local path=""

    if [[ "$spec" == git@*:* ]]; then
        host="${spec#git@}"
        host="${host%%:*}"
        path="${spec#*:}"
    elif [[ "$spec" == ssh://* ]]; then
        local ssh_rest="${spec#ssh://}"
        ssh_rest="${ssh_rest#*@}"
        host="${ssh_rest%%/*}"
        path="${ssh_rest#*/}"
    elif [[ "$spec" == http://* || "$spec" == https://* ]]; then
        local rest="${spec#http://}"
        rest="${rest#https://}"
        host="${rest%%/*}"
        path="${rest#*/}"
    elif [[ "$spec" == github.com/* ]]; then
        path="${spec#github.com/}"
    elif [[ "$spec" == */* && "$spec" != *://* ]]; then
        path="$spec"
    else
        echo "git URL を解釈できません: $1" >&2
        return 1
    fi

    path="${path#/}"
    path="${path%/}"
    path="${path%.git}"

    local owner="${path%%/*}"
    local rest="${path#*/}"
    local repo="${rest%%/*}"
    repo="${repo%.git}"

    if [[ -z "$owner" || -z "$repo" || "$owner" == "$path" ]]; then
        echo "owner/repo を解釈できません: $1" >&2
        return 1
    fi

    if [[ "$owner" == *[^A-Za-z0-9._-]* || "$repo" == *[^A-Za-z0-9._-]* ]]; then
        echo "owner/repo に使えない文字があります: $owner/$repo" >&2
        return 1
    fi

    local clone_url
    if [[ "$spec" == git@*:* || "$spec" == ssh://* ]]; then
        clone_url="git@${host}:${owner}/${repo}.git"
    elif [[ "$spec" == http://* ]]; then
        clone_url="http://${host}/${owner}/${repo}.git"
    else
        clone_url="https://${host}/${owner}/${repo}.git"
    fi

    typeset -g -a _new_git_reply
    _new_git_reply=("$clone_url" "$owner" "$repo")
}

new() {
    local git_spec=""

    if [[ "${1:-}" == "-g" || "${1:-}" == "--git" ]]; then
        shift
        if (( $# != 1 )); then
            echo "usage: new -g <git-url>" >&2
            return 1
        fi
        git_spec="$1"
    elif (( $# == 0 )); then
        echo "usage: new <name> [name ...]" >&2
        echo "       new -g <git-url>" >&2
        return 1
    else
        local part
        for part in "$@"; do
            if [[ -z "$part" || "$part" == */* ]]; then
                echo "名前に空文字や / は使えません: $part" >&2
                return 1
            fi
        done
    fi

    local work_dir="${WORK_DIR:-$HOME/Documents/_work}"
    local directory_name target_path

    if [[ -n "$git_spec" ]]; then
        local clone_url owner repo
        _new_git_spec "$git_spec" || return 1
        clone_url="${_new_git_reply[1]}"
        owner="${_new_git_reply[2]}"
        repo="${_new_git_reply[3]}"
        directory_name="$(date +%y%m)_${owner}_${repo}"
        target_path="$work_dir/$directory_name"

        mkdir -p -- "$work_dir" || return 1
        git clone -- "$clone_url" "$target_path" || return 1
        cd "$target_path" || return 1
        echo "$target_path"
        return
    fi

    directory_name="$(date +%y%m)_${(j:_:)@}"
    target_path="$work_dir/$directory_name"

    mkdir -p -- "$work_dir" || return 1
    mkdir -- "$target_path" || return 1
    cd "$target_path" || return 1
    echo "$target_path"
}
