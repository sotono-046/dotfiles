---
name: pr-base-sync
description: "PR branch と対象 PR を一意に対応づけ、dirty worktree・HEAD mismatch・base 誤認を防いで、最新の remote-tracking base branch を安全に merge し検証する。`PR-check`、`PRブランチに最新baseを取り込んで`、`developをマージして競合確認` と依頼されたときに使用する。rebase、force push、stash、push は明示指示なしに行わない。"
---

# PR Base Sync

PR branch を不用意に切り替えず、最新 base を merge して互換性を確認する。

## 1. PR と checkout を対応づける

- PR URL / 番号、または明示 branch から対象を一意に解決する。
- repository root、current branch、HEAD、upstream、`git status --short --branch` を記録する。
- PR の head branch / head SHA / base branch / repository owner を確認する。
- current checkout と PR head が一致しない、detached、dirty、merge / rebase 中なら変更せず停止する。

dirty 変更を自動 commit / stash / restore / reset しない。別 worktree を使う場合は exact PR head から作る。

## 2. 最新 base を取得する

1. project instructions と PR metadata の base が一致するか確認する。PR metadata を最終的な対象 base とする。
2. repository / remote identity を確認する。
3. 対象 remote を fetch し、`<remote>/<base>` の commit SHA を記録する。
4. fetch 後に fresh な `git status --short --branch`、current branch、local HEAD、PR の `headRefOid`、merge / rebase / cherry-pick / revert の in-progress state をすべて再取得する。最初の確認結果を再利用せず、dirty、branch / HEAD / PR head mismatch、進行中操作が 1 つでもあれば停止する。

local base branch へ checkout / pull せず、remote-tracking ref を merge source にする。

## 3. Merge する

ユーザーが base sync を依頼している場合だけ、対象 PR checkout で次を行う。

merge command の直前にも、fetch 後と同じ status、current branch、local HEAD、fresh な PR `headRefOid`、in-progress state を再検証する。記録した `<remote>/<base>` SHA も変わっていないことを確認し、どれかが変化していたら merge せず停止する。

```bash
git merge --no-edit <remote>/<base>
```

- `git add .` / `git add -A` を使わない。
- conflict が出たら unresolved files を報告し、割り当て scope がない限り勝手に解消しない。
- rebase、merge abort、force push、branch deletion を追加指示なしに行わない。
- merge 不要なら `already-up-to-date` として valid no-op を報告する。

## 4. 検証して停止する

- merge 前後の HEAD、base SHA、merge-base を確認する。
- project 指定の focused test / type-check / lint を実行する。
- conflict、検証失敗、未commit state を明示する。
- push は明示指示がある場合だけ `$git-ops` に従って行う。

次を報告する。

- PR、head branch、base branch、取得した base SHA
- merge 結果と新しい HEAD
- conflict の有無
- 実行した validation と結果
- push 未実施 / 実施の状態
