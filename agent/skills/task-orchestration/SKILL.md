---
name: task-orchestration
description: 独立した調査・実装・検証をサブエージェントへ分担する。並列化による時間短縮が起動・統合の負担を上回る場合に使う。
---

# Task Orchestration

担当成果物が重ならず、強い依存がなく、各担当に自己完結した完了条件を渡せる仕事だけ分割する。軽量な単発処理は直接行う。同じ相手との継続相談が中心なら [subagent-team](../subagent-team/SKILL.md)、外部pane制御が目的なら利用可能なherdrを選ぶ。

## 起動前

最大agent数、時間/tool予算、担当path/除外path、read-onlyまたはedit、成果物、commit owner、validation ownerを決める。実際に起動するときだけ [runtime adapter](references/runtime-adapter.md) を読む。

```text
repository: <absolute path>
owned_paths / excluded_paths: <担当と除外>
task / acceptance_criteria: <依頼と確認可能な完了条件>
permissions: <read-onlyまたは編集範囲、禁止操作>
git: <共有ならstage/commit禁止・owner GO待ち、独立ならbranchとowner>
report: changed files / checks / results / remaining risks
```

秘密を含む生ログや全会話を無条件に複製せず、必要な根拠だけ渡す。レビューと自動修正は別の依頼にする。

## 共有Gitの所有権

- 編集は非競合pathだけ並列化する。依存する変更は同一担当に束ねる。
- 共有worktree/index/HEADでstage/commitを並列実行しない。各担当はownerのGOまで待つ。
- commit ownerは差分を確認し、1グループずつ明示stageしてcached diffのpath/内容を検証する。前のcommit完了後に次へGOを出す。
- 独立worktree/branchだけ並列commit可。既存の他者変更を巻き込まない。

## 統合と終了

報告を担当path・検証・未解決事項に対応づけ、司令塔が差分と重要な根拠を確認する。最終検証は対象変更が安定した状態で行う。review判定が必要なら [review-go-nogo](../review-go-nogo/SKILL.md) を使う。

待機中は独立した作業を進め、結果を推測しない。長時間監視は対象ごとに1担当にし、停止条件を明示する。担当の完了・未実施・blockerを統合して報告したら閉じる。P2だけで新しい修正turnを増やさない。
