---
name: subagent-team
description: 名前付きの参謀・実装役と継続的に相談し、追加指示やレビューを往復するチームを編成する。
---

# Subagent Team

一度で終わる分担は [task-orchestration](../task-orchestration/SKILL.md) を使う。このskillは同じ相手へ前提変更・相談・差し戻しを繰り返す場合の運用だけを加える。

- 司令塔は範囲分割、統合、最終判断を持つ。参謀は必要なとき1体、原則read-only。実装役は非競合pathを担当する。
- 起動前に編成と各担当の目的を短く共有し、予算・担当path・Git/検証ownerを決める。共通の起動契約と共有index直列化はtask-orchestrationに従う。
- 実際のtool操作は [runtime adapter](../task-orchestration/references/runtime-adapter.md) に従う。モデル名で性格や役割適性を固定せず、runtime既定とユーザー指定を尊重する。
- 参謀には番号付きの問い、根拠資料、read-only範囲を渡す。実装役には担当外編集禁止、完了条件、共有Gitならcommit待機を渡す。
- 前提変更を対象担当へ共有する。稼働中への追送とidle担当の再開を使い分け、差し戻しにはfileとacceptance criteriaを明記する。
- 返信前に結果を推測せず、待機中は独立した調査や差分確認を進める。主張と実測が矛盾したら根拠を確認する。

成果のdiffとfocused validationを司令塔が確認し、依頼を満たしたらチームの追加turnを止める。レビューの終了判定は [review-go-nogo](../review-go-nogo/SKILL.md)。報告には成果、commit、検証と残課題を対応づける。
