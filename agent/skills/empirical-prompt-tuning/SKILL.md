---
name: empirical-prompt-tuning
description: スキルやプロンプトの実証評価、またはdescriptionと本文の静的整合チェックを依頼されたときに使う。
---

# Empirical Prompt Tuning

指示の変更が実際の成果を改善したかを調べる。単なる文面整理と実行評価を区別し、通常のskill編集ごとに重い評価ループを追加しない。

## モード

- **静的整合チェック**: description、body、参照先のscope・認可・完了条件が一致するか確認する。実行やsubagentは不要。実証済みとは呼ばない。
- **実証評価**: ユーザーが実測を依頼した場合、または重大なworkflow改訂で行動検証が必要な場合に、独立executorで現実的なscenarioを試す。必要なコスト/副作用が認可範囲内か確認する。

実証する場合だけ [評価プロトコル](references/evaluation.md) を読む。既存の評価基準、代表例、失敗証跡があれば利用し、一から大規模benchmarkを作らない。

実行環境のtool/modelを固定しない。委譲が有益で許可されているときは [runtime adapter](../task-orchestration/references/runtime-adapter.md) を使う。独立実行できなければ可能な静的チェックを返し、実証未実施と明記する。別製品sessionの開始を必須にしない。

## 完了

変更点、scenario、観測した成果、基準の達成/未達、未測定項目と残制約を報告する。自分の再読やexecutorの感想だけで成功と判定しない。実害の修正優先度は [review-go-nogo](../review-go-nogo/SKILL.md) に従い、ユーザーが求めた最適化をP2だからという理由で省略しない。
