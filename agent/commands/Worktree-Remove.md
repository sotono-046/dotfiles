# Linked worktree 安全監査

`$ARGUMENTS` を対象 repository path と解釈する。未指定なら現在の repository を使う。

最初に `$git-worktree-safe-audit` skill を読み、bundled script で read-only audit を実行する。main、active cwd、locked、missing metadata、最終利用時刻、`origin/HEAD`、未push・未マージcommitを確認し、日本語で存在件数と整理候補件数を分けて報告する。

この command では `git worktree remove`、`--force`、`prune`、branch deletion、direct `rm` を実行しない。削除依頼であっても exact target と blocker を先に提示し、削除は明示された別ステップへ分離する。
