# GitHub の owner を選び、ghq 配下に新しいローカル / GitHub リポジトリを作る。
# owner → 名前 → 公開範囲を選び、GitHub に作成して ghq get で取得する。
# usage: ghqnew
new() {
    if ! command -v ghq >/dev/null 2>&1 || ! command -v gh >/dev/null 2>&1 || ! command -v fzf >/dev/null 2>&1; then
        echo "ghqnew には ghq、gh、fzf が必要です" >&2
        return 1
    fi

    local owner
    owner=$(printf '%s\n' sotono-046 bonginkan |
        fzf --prompt='owner> ' --header='GitHub owner を選択') || return 1
    [[ -n "$owner" ]] || return 1

    local repo_name
    printf 'Repository name: '
    IFS= read -r repo_name || return 1
    if [[ -z "$repo_name" || "$repo_name" == *[^A-Za-z0-9._-]* || "$repo_name" == . || "$repo_name" == .. || "$repo_name" == *.git ]]; then
        echo "リポジトリ名には英数字、ピリオド、ハイフン、アンダースコアを指定してください" >&2
        echo "名前 . / .. と末尾 .git は使えません" >&2
        return 1
    fi

    local ghq_root target_path
    ghq_root=$(ghq root) || return 1
    target_path="$ghq_root/github.com/$owner/$repo_name"
    if [[ -e "$target_path" || -L "$target_path" || -n "$(ghq list --exact --full-path "github.com/$owner/$repo_name")" ]]; then
        echo "作成先が既に存在します: $target_path" >&2
        return 1
    fi

    local visibility
    visibility=$(printf '%s\n' private public |
        fzf --prompt='visibility> ' --header='公開範囲を選択: private（非公開） / public（公開）') || return 1
    [[ "$visibility" == private || "$visibility" == public ]] || return 1

    GH_HOST=github.com gh repo create "$owner/$repo_name" "--$visibility" || return 1
    if ! ghq get "https://github.com/$owner/$repo_name.git"; then
        echo "GitHub repo は作成済みです。取得の再実行: ghq get https://github.com/$owner/$repo_name.git" >&2
        return 1
    fi
    target_path=$(ghq list --exact --full-path "github.com/$owner/$repo_name") || return 1
    [[ -n "$target_path" ]] || return 1

    cd "$target_path" || return 1
    echo "$target_path" >> "${REPOHIST_FILE:-$HOME/.repo_history}"
    echo "$target_path"
}
