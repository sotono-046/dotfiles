---
name: task-orchestration
description: "独立性が高く成果物が重複しない調査・実装・検証を、Codex または Claude Code のサブエージェントへ安全に並列委譲する。複数観点の調査、非競合ファイルの同時実装、長時間監視の分離、fan-out を依頼されたときに使用する。同じ相手との継続的な往復は subagent-team、pane ベースの外部エージェント統括は herdr を使う。"
---

# Task Orchestration

一発で完了できる独立サブタスクだけを fan-out する。利用可能な tool schema を最初に確認し、Codex と Claude Code の API を混ぜない。

## 1. 分割可能性を確認する

次をすべて満たすタスクだけ並列化する。

- 成果物または担当ファイル集合が重複しない
- 強い依存関係がなく、完了順に意味がない
- 各 agent に自己完結した scope と完了条件を渡せる
- 並列化の待ち時間短縮が起動・統合コストを上回る

同じ agent と追加相談・差し戻しを何往復も行うことが主目的なら `subagent-team` を使う。軽量な単発タスクは司令塔が直接処理する。

## 2. 起動前に ownership を固定する

1. runtime と利用可能な tool schema
2. 最大同時 agent 数と時間・tool-call 予算
3. 各 agent の役割、担当 path、除外 path、成果物
4. read-only / edit 可否
5. Git mode: 共有 worktree または独立 worktree
6. commit owner と validation owner

実装 packet には必ず次を含める。

```text
role: <investigation|implementation|verification>
repository: <absolute path>
owned_paths:
  - <path>
excluded_paths:
  - <path>
task: <具体的な依頼>
acceptance_criteria:
  - <確認可能な条件>
git_policy: <read-only | shared worktree: edit only; no stage/commit until owner GO | isolated worktree: state branch and commit owner>
report: changed files, checks, results, remaining risks
```

## 3. Runtime adapter を選ぶ

| 操作 | Claude Code adapter | Codex adapter |
| --- | --- | --- |
| 起動 | 公開 schema の `Task` または `Agent` | `collaboration.spawn_agent` |
| 稼働中の追送 | 公開されている task messaging tool | `collaboration.send_message` |
| 完了 turn の再開 | 公開されている task messaging / 再起動 | `collaboration.followup_task` |
| 状態確認 | task 一覧・notification | `collaboration.list_agents` |
| 待機・回収 | `TaskOutput` がある環境ではそれを使う | `collaboration.wait_agent` |
| background option | schema が対応する場合だけ `run_in_background` | 指定しない |

### Codex

- `collaboration.spawn_agent` に一意な `task_name` と具体的な `message` を渡す。
- 実行中 agent への補足は `collaboration.send_message` を使う。
- idle / turn 完了済み agent に新しい turn を開始させる場合は `collaboration.followup_task` を使う。
- 状態は `collaboration.list_agents`、mailbox update は `collaboration.wait_agent` で待つ。timeout だけを失敗と解釈しない。
- `fork_turns` は必要最小限にする。model / reasoning override は明示要件がある場合だけ、その session で許可された値を使う。
- `run_in_background`、`TaskOutput`、Claude の `subagent_type` / model 名を渡さない。

### Claude Code

- session に公開された `Task` または `Agent` schema をそのまま使う。
- `Explore`、`Plan`、`general-purpose` などの `subagent_type` は実在を確認してから選ぶ。
- `run_in_background` と `TaskOutput` は Claude Code 側の schema が対応している場合だけ使う。
- Claude 固有の tool 名・model 名・background option を Codex の呼び出しへコピーしない。

## 4. フェーズごとに実行する

### 調査

異なる観点を read-only agent に割り当てる。秘密情報、除外 path、引用上限を packet に含める。複数 agent に同じ探索をさせない。

### 計画

多視点の SOW review は `plan-digger` を使う。調査結果を要約して渡し、生ログを重複投入しない。

### 実装

非競合の担当 path に分けて編集を並列化する。依存する変更は同じ agent に束ねるか、前段完了後に順次起動する。

### 検証

read-only review と自動修正を同じ packet に混ぜない。まず finding を返させ、`$review-go-nogo` で class 分けする。NO-GO だけを次の実装 turn に渡し、P2 以下は follow-up として報告して修正 turn を起こさない。

### 長時間監視

CI や build の待機は監視 agent 1体へ委譲し、停止条件、最大時間、報告形式を指定する。同じ対象への重複 poller を起動しない。

## 5. 共有 Git 状態を守る

複数 agent が worktree / index / HEAD を共有する場合、編集だけを並列化し、commit phase は直列化する。

1. 起動時に「担当外編集禁止」「stage / commit 禁止」「owner GO を待つ」と伝える。
2. 全 agent の編集完了後、司令塔が担当 path と diff を確認する。
3. commit owner が1グループずつ GO を出す。
4. 対象 path だけを明示的に `git add -- <paths>` する。`git add -A` / `git add .` は使わない。
5. `git diff --cached --name-only` がそのグループだけであることを確認して commit する。
6. 次のグループは前の commit 完了後に進める。

repo 指示が「各実装 agent が commit」を要求しても、共有 Git 状態では commit turn だけを1体ずつ再開する。agent ごとに独立 worktree と branch がある場合のみ並列 commit を許可する。

## 6. 統合する

- notification が届く前に結果を推測しない。
- 各報告を担当 path、変更、検証、未解決事項へ対応づける。
- 司令塔が diff と focused check を再確認する。
- agent の主張と実測が矛盾したら、該当 agent を runtime adapter に従って再開する。
- 全体検証は commit 直列化後、安定した HEAD で行う。

## 完了チェック

- [ ] runtime 固有 API を混在させていない
- [ ] agent 数、担当 path、停止条件が明確
- [ ] 同一ファイルを並列編集していない
- [ ] 共有 Git の commit を owner GO 後に直列化した
- [ ] 各差分と検証結果を司令塔が再確認した
- [ ] 残課題と未実行 validation を明示した
