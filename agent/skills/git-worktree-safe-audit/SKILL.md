---
name: git-worktree-safe-audit
description: Linked Git worktree の整理前に、main・bare・locked・active cwd・missing metadata・未push/未マージcommit・最終利用時刻を読み取り専用で監査する。ユーザーが「worktreeを整理」「古いworktreeを確認」「worktree cleanup」「子worktreeを消したい」と依頼したときに使用する。
---

# Git Worktree Safe Audit

削除前の判定を再現可能にし、存在件数と整理候補件数を分けて報告する。監査と削除を同じステップにしない。

## 監査を実行する

対象 repository の worktree から、または `--repository` で対象を指定して実行する。

```bash
python3 agent/skills/git-worktree-safe-audit/scripts/worktree_audit.py \
  --repository /absolute/path/to/repository
```

この script は JSON を stdout に出すだけで、`remove`、`prune`、branch deletion、dependency directory deletion を実行しない。別 repository から使う場合は skill directory の絶対 path で script を呼ぶ。

## 判定を読む

1. `repository.common_git_dir` が監査単位の canonical Git common directory であることを確認する。
2. `worktrees` の各 entry で `is_main`、`bare`、`locked`、`active_cwd`、`path_exists`、`prunable` を先に確認する。
3. `activity.latest_mtime` と `activity.age_days` が worktree 固有 gitdir の `HEAD`、`index`、`logs/HEAD` に加え、worktree root と status に現れた path の mtime から算出されていることを確認する。
4. `git_safety.origin_head`、`ahead_of_origin_head`、`upstream`、`ahead_of_upstream` を確認する。`origin/HEAD` 不明、未push、基準branch未マージは ordinary cleanup の blocker とする。upstream 不明や detached はそれだけで blocker にしない。
5. `decision.action` を候補として扱い、現在の権限とユーザーの依頼をもう一度照合する。

主な action:

- `protected-*`: 削除候補にしない。
- `no-op-recent`: 最終利用から3日未満なので変更しない。
- `regenerable-cleanup-candidate`: 3日以上7日未満で、`regenerable_directories` に存在する再生成可能 directory だけが別途の削除検討対象。該当 directory がなければ `no-op-no-regenerable-directories` とする。
- `worktree-removal-candidate`: 7日以上かつ ordinary guards を通過した linked worktree。まだ削除済みではない。
- `metadata-prune-candidate`: path が存在せず porcelain が `prunable` と報告した metadata。まだ prune 済みではない。

dirty、untracked、ignored、conflict、in-progress state は報告するが、それだけを ordinary cleanup の blocker にしない。

status は `porcelain=v1 -z`、`untracked-files=normal`、`ignored=matching`、`no-renames` で取得する。出力bytes、path件数、mtime走査entry数、実行時間に上限を設け、`content_state.status_scan` に完了状態を出す。上限到達、timeout、不正path、symlinkを辿らないmtime走査の打ち切りがあれば `activity-evidence-incomplete` として削除候補にしない。

## 安全境界を守る

- main worktree、bare、locked、active cwd は常に保護する。
- active cwd の一括取得に失敗した場合は候補を安全側へ倒す。
- `git worktree list --porcelain` を一次情報にし、先頭 entry を main worktree として保護する。
- path がない entry を直接削除しない。明示承認された別ステップで `git worktree prune -v` を使う。
- branch deletion、`rm -rf`、worktree path の直接削除を行わない。
- この skill の監査結果だけを削除権限と解釈しない。削除を求められた場合も、exact target と直前の再監査を提示してから別ステップで扱う。

## 報告する

日本語で次を簡潔に返す。

- canonical repository、linked worktree 総数、整理候補数
- 各 path の最終利用日時、action、reason
- main/active/locked/missing と commit guard の状態
- `audit_only: true`、`mutations_attempted: false`

候補が0件でも valid zero-action audit として完了させ、対象を勝手に広げない。
