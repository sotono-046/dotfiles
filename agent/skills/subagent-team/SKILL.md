---
name: subagent-team
description: "名前付きの常駐サブエージェントで司令塔・参謀・実装役のチームを編成し、同じ相手との相談・追加指示・レビューを何往復も行う。Codex と Claude Code の tool lifecycle を切り替えて運用する。「チーム編成して」「参謀を立てて」「サブエージェントチームで」「参謀と相談」で使用する。使い捨て並列 fan-out は task-orchestration、pane ベースの外部エージェント統括は herdr を使う。"
---

# サブエージェントチーム運用

メインセッションを司令塔とし、名前付きの参謀・実装役と複数 turn を往復する。最初に利用可能な tool schema を確認し、Codex と Claude Code の API を混ぜない。

## 1. 適用範囲を判定する

- 同じ相手へ追加質問、前提変更、差し戻しを繰り返す場合に使う。
- 独立サブタスクを一発並列で処理するだけなら `task-orchestration` を使う。
- Herdr / pane が明示された場合、または外部プロセスの agent を統括する場合は `herdr` を使う。
- プランの多視点レビューだけなら `plan-digger` を使う。

## 2. 編成と Git 所有権を先に固定する

起動前に次を決め、ユーザーへ編成を一言で共有する。

1. runtime: Codex または Claude Code
2. 役割: 司令塔、参謀 1 体、必要最小限の実装役
3. 各実装役の担当ファイル集合: 相互に重複させない
4. Git mode: 共有 worktree または agent ごとの独立 worktree
5. commit owner と validation owner

| 役割 | 責務 |
| --- | --- |
| 司令塔 | 分解、指示、差分レビュー、統合検証、最終判断、ユーザー報告 |
| 参謀 | 公式一次情報の調査、設計レビュー、反証、リスク提示。原則 read-only |
| 実装役 | 割り当てられたファイル集合だけを編集・検証 |

### 共有 worktree / index / HEAD の制約

複数 agent が同じ Git worktree を共有する runtime では、編集だけを非競合ファイルへ並列化し、commit phase は直列化する。並列 agent に同時 commit させない。

- 各実装役へ「担当外編集禁止」「`git add -A` 禁止」「commit は GO が出るまで禁止」と伝える。
- 全員の編集完了後、司令塔が diff を確認する。
- commit は司令塔が担当パスを明示 stage して直列に行うか、実装役へ 1 体ずつ GO を送り直列に行わせる。
- repo 指示が「各実装役が commit」を要求する場合も、共有 Git 状態では commit turn だけを 1 体ずつ再開する。
- agent ごとに独立 worktree と branch を割り当てた場合のみ、各 agent が並列に commit してよい。

## 3. Runtime adapter を選ぶ

tool の実在と引数は、その session に表示された schema を正とする。別 runtime の tool 名、model 名、background option を移植しない。

| 操作 | Claude Code | Codex |
| --- | --- | --- |
| agent 起動 | `Agent` | `spawn_agent` |
| 稼働中 agent へ連絡 | `SendMessage` | `send_message` |
| turn 完了後の再開 | `SendMessage` | `followup_task` |
| 一覧・状態確認 | `ListAgents` | `list_agents` |
| 待機 | 非同期 notification / 利用可能な待機 tool | `wait_agent` |

### Claude Code adapter

- `Agent` に名前、役割、prompt を渡す。
- 常駐運用では Claude Code 側の schema が対応している場合に `run_in_background: true` を使う。
- 追加指示と turn 完了後の再開は `SendMessage` を使う。
- 生存・宛先確認は `ListAgents` を使う。
- deferred tool の環境だけ、必要に応じて `ToolSearch` で tool をロードする。
- `subagent_type`、`model`、background option は Claude Code 固有として扱い、Codex の呼び出しへコピーしない。

### Codex adapter

- `spawn_agent` に一意な `task_name` と具体的な `message` を渡す。
- `send_message` は実行中 agent への追送に使う。idle / turn 完了済み agent の新しい turn は開始しない。
- idle / turn 完了済み agent を同じ文脈で再開する場合は `followup_task` を使う。
- 状態確認は `list_agents`、mailbox update の待機は `wait_agent` を使う。`wait_agent` の timeout を agent の失敗と解釈しない。
- `fork_turns` は必要最小限にする。`model` / `reasoning_effort` override は明示要件がある場合だけ使い、その runtime で利用可能な値を選ぶ。
- Codex の `spawn_agent` に `run_in_background` や Claude Code の model 名を渡さない。

## 4. 依頼 packet を作る

参謀には次を渡す。

- プロジェクトの絶対パスと読むべき一次資料
- 番号付きの問い
- read-only 範囲
- 公式一次情報で裏どりし、URL と未確認事項を分ける指示
- 司令塔の実測と矛盾する場合に指摘する指示

実装役には次を必ず渡す。

- 担当ファイル集合と担当外編集禁止
- 割り当てタスクだけを直し、ついで修正をしないこと
- 共有 Git 状態なら commit 待機、独立 worktree なら commit 規約
- 完了時の変更ファイル一覧、検証コマンド、結果

Codex の例:

```text
spawn_agent:
  task_name: "api_impl"
  message: |
    担当: /absolute/repo/src/api/** のみ。担当外は編集禁止。
    <具体的な実装依頼>
    共有 worktree のため commit しない。
    変更ファイル、検証コマンド、結果を返す。
```

## 5. 往復と統合を行う

- 前提変更は対象メンバーへ即時共有する。
- 稼働中 agent への補足と、turn 完了後の再開を runtime adapter に従って使い分ける。
- 進捗確認は「確定した項目だけ先に共有」のように具体化し、「どう思う？」だけを送らない。
- 返信前に内容を推測しない。待つ間は司令塔が実測・diff review・別タスクを進める。
- 参謀の主張を鵜呑みにせず、低コストな根拠は司令塔が再検証する。
- 実装成果は diff review、focused check、隣接互換チェックの順で検証する。
- 差し戻しは対象 agent を同じ名前で再開し、ファイルと acceptance criteria を明記する。

## 6. 完了条件

- [ ] runtime adapter を混在させていない
- [ ] 担当ファイル集合が重複していない
- [ ] 共有 Git 状態で commit を直列化した、または独立 worktree を使った
- [ ] 各成果の diff と検証結果を司令塔が再確認した
- [ ] 参謀の重要な根拠を一次情報または実測で確認した
- [ ] ユーザー報告に各メンバーの成果、commit、検証、残課題を対応づけた
