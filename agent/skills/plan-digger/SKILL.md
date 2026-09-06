---
name: plan-digger
description: 計画やSOWを複数の観点から読み取り専用でレビューし、根拠のある改善方針を返す。digやプランレビューで使用する。
---

# Plan Digger

ユーザーが選んだscopeと出力を守り、計画の成立条件・実害・より単純な代替案を確認する。コード変更や外部投稿は行わない。

## 出力を選ぶ

- `レビューだけ` / `dig` → report-only。
- `SOW作って` / `計画にして` → 会話上のdraft-sow。
- 保存先または`保存して`がある → save-sow。保存は親の担当または保存可能なtoolで行う。

SOWを書くときは [agent-note-writing](../agent-note-writing/SKILL.md) を使う。read-onlyのchildは保存用本文を親へ返せばよく、権限を広げない。

## レビュー

1. repo、plan/issue、担当ファイル、除外範囲、既知の制約、最低限のvalidationを固定する。secretや生の顧客データを無条件に読まない。
2. correctness、security、performance、maintainability、test、devil's advocateから必要な観点を選ぶ。ユーザー指定は含める。軽量なら1人で複数観点を確認する。
3. 広い独立調査が有益なら [task-orchestration](../task-orchestration/SKILL.md) で有限予算のreviewerへ分担する。toolがない場合は自分で可能なread-onlyレビューを続ける。子agentから無理に再委譲しない。
4. 主張をコード・仕様・設定・観測に結びつけ、重複をまとめる。根拠の弱い懸念を確定findingにしない。
5. 最後に前提の崩れ、scope過大、単純な代替案を確認する。独立したdevil's advocateは必要な場合だけ追加する。

独立reviewerへのpacketが必要なときは [reviewer-prompts](references/reviewer-prompts.md) を使う。runtime固有のtoolやmodelを固定しない。reviewerは編集・commit・自動修正をしない。

## 判定と終了

[review-go-nogo](../review-go-nogo/SKILL.md) を判定の正本とする。NO-GOには証拠・影響・解消方針を示し、P2はfollow-upとして記録する。SOWを変更した場合だけ関連観点を再確認し、High/Mediumというラベルだけで全面レビューを繰り返さない。

最大3周、または事前予算の短い方を上限とする。同じblockerが再発するなら前提を再評価し、解消不能な判断だけ親/ユーザーへ返す。NO-GOゼロで必要な検証が済めば終了し、未検証事項を明記する。保存・実装・PR作成を暗黙に追加しない。
