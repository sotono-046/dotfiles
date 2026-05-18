---
name: assigned-pr-merge-watch
description: 自分に assignee が付いた open PR を横断監視し、draft PR は一切触らず、非 draft PR の CI、review thread、update branch、merge readiness を確認する。`マージまで`, `mergeまで`, `マージして` が明示された場合だけ、条件を満たした PR を update branch 後に merge する。`自分がアサインされているPR`, `assigned PR`, `片っ端から監視` で使用する。
---

# assigned-pr-merge-watch

自分が assignee になっている PR 群を、マージ可能になるまで継続的に面倒を見るための上位 Skill。単発 PR の CI 修正は `ci-merge-watch` に寄せ、この Skill は「対象 PR の列挙、draft 除外、状態ゲート、複数 PR の監視ループ、明示された場合の最終 merge」を担当する。

## 絶対ルール

- **draft PR は触らない**。checkout、update branch、CI rerun、review thread resolve、comment、merge、ready 化をしない。最終報告に `skipped: draft` とだけ残す。
- `CI見て` / `監視して` / `片っ端から監視` だけなら read-only。update branch、resolve、commit、push、merge はしない。
- `マージまで` / `mergeまで` / `マージして` がある場合だけ、非 draft PR に対する state-changing 操作を許可する。
- `--admin` merge、branch protection bypass、強制 push、review の勝手な approve、明示なしの branch delete はしない。
- merge 時は必ず head SHA を固定する。`gh pr merge ... --match-head-commit <headRefOid>` または GitHub MCP の `expected_head_sha` を使う。
- secret、token、private URL query、CI env、PII をログやコメントに出さない。引用は最小抜粋にする。

## 併用する Skill / Tool

- 単発 PR の失敗 CI 修正、review comment 回収は `ci-merge-watch` を併用する。
- commit / push / PR 操作は `git-ops` のルールを優先する。
- review thread の解決状態は GitHub MCP があれば優先して読む。なければ `gh api graphql` を使う。
- GitHub CLI の機械的な一覧化には `scripts/assigned_pr_merge_watch.py` を使える。

## 初期スキャン

まず対象を列挙する。

```bash
python3 agent/skills/assigned-pr-merge-watch/scripts/assigned_pr_merge_watch.py --once
```

repo を絞る場合:

```bash
python3 agent/skills/assigned-pr-merge-watch/scripts/assigned_pr_merge_watch.py --once --repo OWNER/REPO
```

この出力で次を分類する。

- `draft`: 絶対に skip
- `blocked`: unresolved review thread、changes requested、CI failure、conflict、権限不足など
- `waiting`: CI pending、update branch 後の check 待ち
- `ready`: merge 前ゲートを満たしている
- `merged`: このループで merge 済み

## 監視 / マージループ

state-changing 指示がある場合のみ、次の順序で非 draft PR を処理する。

1. `gh search prs --assignee @me --state open` または repo 限定の `gh pr list --assignee @me --state open` で候補を取る。
2. 各 PR を `gh pr view --json isDraft,headRefOid,mergeStateStatus,reviewDecision,statusCheckRollup,...` で再確認する。
3. draft なら一覧情報だけで即 skip。`pr view`、review thread 取得、checkout、update branch などの追加操作をしない。
4. review thread を取得し、unresolved があれば修正対象として扱う。
5. actionable thread を修正し、commit / push が必要なら `git-ops` に従う。
6. 修正済み thread だけを resolve する。未対応または判断不能な thread は resolve しない。
7. `gh pr update-branch <PR> --repo OWNER/REPO` を実行する。すでに up-to-date の no-op は許容する。
8. update branch 後に head SHA を取り直す。head が変わった場合は `gh pr checks <PR> --watch --repo OWNER/REPO` を必ず実行し、CI green を待ってから再評価する。
9. merge 前に同じ PR JSON と review thread を再取得する。
10. 全ゲートが揃ったら merge する。repo 慣習が不明なら squash merge を既定候補にする。

補助スクリプトで実行する場合:

```bash
python3 agent/skills/assigned-pr-merge-watch/scripts/assigned_pr_merge_watch.py --watch --merge --merge-method squash
```

`--merge` を付けると、script は draft を除外し、unresolved thread / review required / requested changes / non-green checks / conflict / fork 権限不足を blocker にして、条件を満たした PR だけ update branch と merge を試みる。コード修正や thread 本文への返信は agent が別途行う。

branch delete は `--delete-branch` が明示された場合だけ行う。

## Merge 前ゲート

merge は次をすべて満たす PR だけ。

- PR が open で non-draft
- 自分が assignee
- unresolved review thread が 0
- `reviewDecision` が `CHANGES_REQUESTED` または `REVIEW_REQUIRED` ではない
- required / reported CI が `SUCCESS`。pending、failure、cancelled、timed out、action required、skipped、neutral、unknown は不可
- update branch が実行済み、または GitHub が up-to-date no-op を返している
- merge conflict がなく、`mergeable` と `mergeStateStatus` が merge 可能状態
- merge 直前に取得した `headRefOid` と merge command の `--match-head-commit` が一致している

no checks の PR は原則 blocked。repo の運用上 CI が存在しないことをユーザーが明示した場合だけ例外にする。

## Review Thread 解決

GitHub MCP がある場合:

- `_list_pull_request_review_threads` で unresolved を取る
- 修正が入った thread だけ `_resolve_review_thread` で resolve
- 判断不能、設計判断待ち、未修正、外部依存待ちは resolve しない
- resolve 前に thread URL、latest comment、対応 commit、必要なら test / CI 証跡を対応づける

`gh` fallback:

```bash
gh api graphql -f owner=OWNER -f name=REPO -F number=123 -f query='
query($owner:String!, $name:String!, $number:Int!) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes { id isResolved comments(first:10) { nodes { body url author { login } } } }
      }
    }
  }
}'
```

Resolve mutation は thread ID を間違えると危険なので、必ず PR 番号・repo・thread URL・修正 commit を対応づけてから実行する。

## Blocker 対応

- **unresolved review thread**: thread を読み、actionable なら修正する。修正後にだけ resolve。
- **changes requested**: requested changes の review と thread を優先して回収する。approval が必要なら待つ。
- **CI failure**: `ci-merge-watch` と `green-loop` を使い、failed log の最小再現を作って修正する。
- **pending checks**: watch を継続。古い head の結果を green 判定に使わない。
- **behind / update required**: update branch 後、head SHA と checks を取り直す。
- **conflict / dirty**: 自動解決しない。対象 repo の checkout を作り、通常の conflict 解消フローに移る。
- **fork / permission failure**: maintainer can modify、branch 権限、merge 権限を確認して blocked として報告する。

## 報告形式

各ループで短く状態を残す。

```text
PR #123 OWNER/REPO: waiting
- draft: no
- update branch: done (head abc1234 -> def5678)
- checks: pending 2, success 8
- review threads: unresolved 0
- next: CI watch
```

完了時:

- merged PR: repo、number、title、merge method、head SHA
- skipped draft PR
- blocked PR と blocker
- まだ watch 中なら次に見る条件
