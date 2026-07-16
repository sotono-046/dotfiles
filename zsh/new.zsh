# 月と名前から WORK_DIR 配下に作業ディレクトリを作る。
# usage: new <name> [name ...]
# example: new sotono hogefuga -> $WORK_DIR/2607_sotono_hogefuga
new() {
    if (( $# == 0 )); then
        echo "usage: new <name> [name ...]" >&2
        return 1
    fi

    local part
    for part in "$@"; do
        if [[ -z "$part" || "$part" == */* ]]; then
            echo "名前に空文字や / は使えません: $part" >&2
            return 1
        fi
    done

    local work_dir="${WORK_DIR:-$HOME/Documents/_work}"
    local directory_name="$(date +%y%m)_${(j:_:)@}"
    local target_path="$work_dir/$directory_name"

    mkdir -p -- "$work_dir" || return 1
    mkdir -- "$target_path" || return 1
    echo "$target_path"
}
