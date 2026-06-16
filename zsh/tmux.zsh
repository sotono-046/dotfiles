# tmux IDE 起動コマンド群
# worktree ごとに 4 分割の tmux session を作り、Claude / Codex / dev server を立ち上げる。
# 依存: zsh/repo.zsh の _select_repo_or_worktree

export CLAUDE_MODEL_MAIN="claude-opus-4-7[1m]"
export CLAUDE_MODEL_SUB="claude-sonnet-4-6"
export CODEX_MODEL="gpt-5.5"

# tmux session 名として安全な短い worktree 識別子を作る内部関数
_tmux_worktree_session_name() {
    local repo_path="$1"
    local real_path
    real_path=$(cd "$repo_path" 2>/dev/null && pwd -P) || return 1

    local project_name
    project_name=$(basename "$real_path")
    local safe_project="${project_name//[^A-Za-z0-9_-]/-}"
    local path_hash
    path_hash=$(printf '%s' "$real_path" | cksum | awk '{print $1}')

    printf 'ide-%s-%s\n' "$safe_project" "$path_hash"
}

# worktree ごとに tmux の 4 分割 IDE session を作成し、既存ならそこへ移動する内部関数
_launch_tmux_ide_or_init() {
    local repo_path="$1"
    if [[ -z "$repo_path" || ! -d "$repo_path" ]]; then
        echo "worktree path が見つかりません: $repo_path"
        return 1
    fi

    local session_name
    session_name=$(_tmux_worktree_session_name "$repo_path") || return 1

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        local dev_command='zsh -lc '\''if [[ -f package.json ]] && command -v bun >/dev/null 2>&1 && grep -q "\"dev:all\"" package.json; then bun run dev:all; else exec zsh; fi'\'''
        local window_target="${session_name}:main"
        local claude_pane codex_pane shell_pane dev_pane

        # 分割中に claude/codex を直接起動すると即終了して pane id が無効になるため、
        # 先に zsh で 4 ペインを作ってから send-keys で各エージェントを起動する
        tmux new-session -d -s "$session_name" -n main -c "$repo_path" "exec zsh" || return 1
        claude_pane=$(tmux display-message -p -t "${window_target}.1" '#{pane_id}') || return 1

        codex_pane=$(tmux split-window -h -P -F '#{pane_id}' -t "$claude_pane" -c "$repo_path" "exec zsh") || return 1
        shell_pane=$(tmux split-window -v -P -F '#{pane_id}' -t "$claude_pane" -c "$repo_path" "exec zsh") || return 1
        dev_pane=$(tmux split-window -v -P -F '#{pane_id}' -t "$codex_pane" -c "$repo_path" "exec zsh") || return 1

        # 配置: [1 opus][2 codex] / [3 haiku][4 dev]
        # tiled は pane index 順に並べ替えるため使わない（index 2=左下, 3=右上 になり逆転する）
        tmux select-pane -t "$claude_pane" -T "Claude --model $CLAUDE_MODEL_MAIN"
        tmux select-pane -t "$codex_pane" -T "Codex --model $CODEX_MODEL"
        tmux select-pane -t "$shell_pane" -T "claude --model $CLAUDE_MODEL_SUB"
        tmux select-pane -t "$dev_pane" -T "Dev Server"

        tmux select-pane -t "$claude_pane"

        tmux send-keys -t "$claude_pane" -l -- "claude --model '${CLAUDE_MODEL_MAIN}'"
        tmux send-keys -t "$claude_pane" Enter
        tmux send-keys -t "$codex_pane" -l -- "codex --model ${CODEX_MODEL}"
        tmux send-keys -t "$codex_pane" Enter
        tmux send-keys -t "$shell_pane" -l -- "claude --model '${CLAUDE_MODEL_SUB}'"
        tmux send-keys -t "$shell_pane" Enter
        tmux send-keys -t "$dev_pane" -l -- "$dev_command"
        tmux send-keys -t "$dev_pane" Enter
    fi

    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    fi
}

# fzf でリポジトリを選び、Cursor + tmux 4 分割 IDE（Claude/Codex ペイン）を起動する
# usage: agent [work_dir]
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

# 現在のリポジトリで新しい worktree を作って tmux 4 分割 IDE を起動する
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
