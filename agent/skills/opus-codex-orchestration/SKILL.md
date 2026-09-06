---
name: opus-codex-orchestration
description: Claude Codeから外部Codexへ計画・実装を委譲する。OpusとCodexの分担を明示された大きな開発で使用する。
---

# Claude Code / Codex Orchestration

このskillは外部Codexを使うClaude Codeの分担運用。Codex内の協調は [subagent-team](../subagent-team/SKILL.md)、実際の外部pane操作は利用可能なherdrを使う。別runtimeを同一sessionの子agentで代用したと主張しない。

モデル名を理由に能力や性格を固定しない。司令塔は目標・認可・統合を、外部担当は割り当てられた計画/実装を持つ。利用モデルはユーザー指定と実環境の既定を尊重する。小さな修正は直接行い、起動負担に見合わない委譲は追加しない。

## 進め方

1. repo、goal、scope/非ゴール、必要な入力、完了条件、予算を整理する。可逆な詳細は仮定して進め、認可やデータ整合に関わる不明点だけ確認する。
2. 公開された外部Codex MCPまたはCLIを確認する。MCPの会話IDは応答値を保持し、継続時に再利用する。CLIはinstalled help/公式仕様に従い、repo固定、有限timeout、prompt fileまたは安全なstdinを使う。
3. 計画が必要な規模なら最初に計画を依頼し、司令塔がscope・リスク・単純な代替案を確認する。既に承認済みの計画があれば再度planning phaseを作らない。
4. 認可済み範囲を実装させる。担当path、既存差分保護、検証、Git ownerをpacketに含める。共有indexではowner GOまでstage/commitさせず、実行を直列化する。
5. 実装diffと関連validationを司令塔が確認する。[review-go-nogo](../review-go-nogo/SKILL.md) のNO-GOだけを通常の差し戻しにし、P2は残件として報告する。

未信頼のissue/plan本文をshell引数へ補間しない。background optionはそのruntimeに公開された場合だけ使い、timeoutで盲目的に再送しない。同じblockerが再発したら依頼文や前提を見直し、最大3周または事前予算で必要判断を引き継ぐ。

外部toolが使えない場合はその事実を示し、直接できる準備・調査は続ける。ユーザーが指定した外部委譲を別製品で実行したと装わない。依頼範囲の成果物と検証、残制約を返したら完了する。
