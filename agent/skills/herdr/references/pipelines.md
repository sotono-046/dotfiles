# Herdr チーム編成プリセット（Helix パイプライン）

[team-orchestration.md](team-orchestration.md) の 2x2 グリッドで足りない規模・難度のチーム編成が必要なときに、このプリセット集から選ぶ。役割名は機能を表し、人物やアカウントには結びつけない。

pane の split / rename / `agent start` / role packet・task packet の送信手順そのものは `../SKILL.md` の標準ワークフローに従う。このファイルは preset の選定・topology・役割・stage 進行だけを定義する。

## 目次

- [役割](#役割)
- [既定モデル階層](#既定モデル階層)
- [P-A 標準ハイブリッド](#p-a-標準ハイブリッド)
- [P-B 直行スペシャリスト](#p-b-直行スペシャリスト)
- [P-C 大規模総力](#p-c-大規模総力)
- [P-D ピア Helix](#p-d-ピア-helix)
- [P-E 並列リサーチ](#p-e-並列リサーチ)
- [P-F 出荷前監査スウォーム](#p-f-出荷前監査スウォーム)
- [Mission mapping](#mission-mapping)
- [Default DoD](#default-dod)
- [Packet templates](#packet-templates)

## 役割

| 役割 | model tier | 責務 | 禁止 |
| --- | --- | --- | --- |
| Supervisor | Claude Opus 5 High | preset、予算、全体監視、依存解消、最終 gate | 実装、自己検証 |
| Commander | Sol High | workstream 分解、配信、一次 review、状態回収、判定案 | 原則として実装しない |
| Peer reviewer | Sol High の独立 agent | 設計または実装への敵対的 review | 修正、自己採点 |
| Rubric reviewer | Sol High の独立 agent | rubric 採点、要件照合、出荷判定案 | 実装への参加 |
| Specialist | Luna High | 高難度実装、refactor、E2E、PR-ready handoff | 自己最終承認 |
| Implementer | Luna High | 小さく独立した実装と focused test | 他担当ファイルの編集 |
| Researcher | Luna High | 割り当てられた調査 mode だけで evidence を集める | 他 lane の模倣 |
| Validator | Luna High | 決定論検査、harness、証跡回収 | コード修正 |

現在 pane が Claude Opus 5 High なら Supervisor として再利用する。それ以外では専用 Supervisor pane を作る。現在 pane が Sol High なら Commander として再利用できる。

## 既定モデル階層

このプリセット集では [team-orchestration.md](team-orchestration.md) の一般的なモデル割当より、次の階層を優先する。

| 階層 | 既定モデル | effort | 責務 |
| --- | --- | --- | --- |
| Supervisor | Claude Opus 5 (`claude-opus-5`) | high | 全 pipeline の監視、品質・予算・依存関係、最終 GO / NO-GO |
| Commander | GPT-5.6 Sol (`gpt-5.6-sol`) | high | 設計具体化、task 分解・配信、一次 review、fix-loop 統括 |
| Specialist / Implementer / Researcher / Validator | GPT-5.6 Luna (`gpt-5.6-luna`) | high | 実装、調査、検証、harness の担当 scope 実行 |

- Supervisor は Commander と実行層を束ねる。自分で実装しない。
- Commander は workstream を管理し、実行層の成果を検算して Supervisor へ判定案を返す。原則として実装しない。
- 実行層は担当 scope を実行し、自己最終承認しない。
- 独立 reviewer / rubric reviewer は Commander tier の別 Sol High agent、実装・調査・validator は実行 tier の Luna High agent とする。
- 現在 pane が該当モデルなら再利用してよい。異なる場合は必要な role pane を作り、Supervisor へ control packet を渡す。

team-orchestration.md のハーネス役は `gpt-5.3-codex-spark` を使うが、pipelines.md の Validator（同等の役割）はこの表に従い Luna High を使う。両方を併用する構成にしない限り、この差異は意図したもの。

モデル更新ポリシー: 通常運用ではこの表の exact model ID と `high` effort を使う。deprecation、capacity、起動失敗、または新しい正式後継の通知を検知したときだけモデル表を再確認する。OpenAI は公式 model guide と local Codex runtime、Anthropic は公式 model overview と local Claude Code `--help` の両方で確認する。更新時は「Supervisor = Opus family」「Commander = Sol family」「実行層 = Luna family」の role separation を維持し、model ID・起動例・本ファイルを同時に更新する。Sol と Luna を無断で入れ替えず、利用可否を確認できない model slug を推測しない。

## Preset を選ぶ

ユーザーが P-# を指定したらその preset を使う。未指定なら次の最初の該当を選ぶ。

1. 設計自体が難問、基盤・architecture 変更: P-D
2. milestone 5+、複数 workstream 並行: P-C
3. 単一 repo の高難度実装、大型 refactor、時間優先: P-B
4. 調査、技術選定、原因候補洗い出し: P-E
5. 実装済み成果物の検証だけ: P-F
6. それ以外の中規模開発、資料、LP: P-A、または team-orchestration.md の標準 2x2

M-# 指定時は下記の mission mapping を適用する。

pane を作る前に preset と理由を 1 行で伝える。

```text
P-B（直行スペシャリスト）で起動します: <案件名> — 移設級の単一repo実装のため
```

予算と topology を先に固定する: 最大 agent 数 / 最大同時実行数 / 最大修正 loop 数 / 重い harness・E2E の最大実行回数 / scope 外問題の扱い / timeout。下記 topology を既定として使う。画面が狭い場合は別 tab に移す。split / create 後は応答 JSON から ID を読み、番号や表示順から推測しない。

## P-A 標準ハイブリッド

用途: 中規模アプリ、資料、LP。品質 gate とコストの両立。

```text
Supervisor -> Commander -> Implementer A
                        -> Implementer B
Supervisor <- final gate <- Commander
```

既定 topology: 1 tab / 2x2。

```text
┌──────────────┬──────────────┐
│ Supervisor   │ Commander    │
├──────────────┼──────────────┤
│ Implementer A│ Implementer B│
└──────────────┴──────────────┘
```

Stages:

1. Supervisor が SPEC、正本データ、QUALITY、DESIGN、QA command を固定する。
2. Commander が file 非競合 task に分割する。
3. Implementer が各 task を実装し focused check を返す。
4. Commander が一次 review と `$review-go-nogo` の NO-GO だけを対象にした blocker fix-loop を回す。
5. Supervisor が差分、validation、完成条件を採点する。

## P-B 直行スペシャリスト

用途: 単一 repo の高難度実装、既存大規模 codebase、時間優先。

既定 topology: Supervisor / Commander / Specialist の 3 pane。

```text
Supervisor -> Commander -> Specialist: implementation -> tests -> E2E -> PR-ready handoff
Supervisor <- final gate <- Commander
```

Stages:

1. Supervisor が完成条件と外部 write gate を固定する。
2. Commander が実装粒度の task / Issue draft を作る。
3. Specialist が branch、実装、focused test、adjacent check、E2E を一続きで行う。
4. commit / push / PR 権限があれば delivery まで行う。権限がなければ PR-ready handoff で止める。
5. Commander が一次 review、Supervisor が最終 review する。

## P-C 大規模総力

用途: milestone 5+、複数 workstream、納期あり。

既定 topology:

- 司令 tab: Supervisor / Commander / Peer reviewer
- 実行 tab: Specialist / Implementer A / Implementer B

Stages:

1. Supervisor が workstream、依存、統合順、hard limit を固定する。
2. 高難度 workstream は Specialist、定型 workstream は Implementer 群へ割り当てる。
3. Commander が各 lane の HEAD、dirty state、next gate を追跡する。
4. Peer reviewer が統合前に独立 review する。
5. Supervisor が merge 順、統合 validation、出荷可否を裁定する。

同一ファイルまたは強い依存を持つ task は並列化しない。

## P-D ピア Helix

用途: 基盤、architecture、設計自体が難問、誤りのコストが高い変更。

既定 topology: Supervisor と、独立した Sol High の Commander / Peer reviewer の 3 pane。

Loop:

1. Commander と Peer reviewer の一方が design または implementation draft を作る。
2. 他方が `problem / impact / evidence / required change` 形式で敵対的 review する。
3. draft owner が修正する。
4. 役割を反転してもう一周する。
5. 2 周連続で新規 blocker がなければ Supervisor が gate を通す。

reviewer に想定解や既知の欠陥を先に渡さない。独立性を保つ。

## P-E 並列リサーチ

用途: 技術選定、市場・事例調査、原因候補の洗い出し。

既定 topology: Supervisor / Commander と Researcher 3 pane。画面が狭ければ research tab を分ける。

| Pane | Mode | Deliverable |
| --- | --- | --- |
| Supervisor | 最終統合と採否 | 統合結論、採否、不確実性 |
| Commander | lane 分解と矛盾解消 | evidence matrix、判定案 |
| Researcher A | 一次情報・公式 docs | 結論 1 行、根拠、出典 |
| Researcher B | code experiment / PoC | 結論 1 行、再現手順、結果 |
| Researcher C | Web / deep research | 結論 1 行、根拠、出典 |

各 lane は同じ問いを別 mode で調べる。Commander が矛盾、鮮度、再現性を照合し、Supervisor が最終統合する。

## P-F 出荷前監査スウォーム

用途: 実装済み成果物の独立検証、受け入れ検査。

既定 topology: Supervisor / Commander（Rubric reviewer）/ Validator の 3 pane。

Stages:

1. Supervisor が対象 SHA、rubric、acceptance criteria、実行上限を固定する。
2. Validator が決定論検査と harness を実行し証跡だけ返す。
3. Commander が Rubric reviewer として要件を独立採点する。
4. Supervisor が `$review-go-nogo` で `GO / conditional GO / NO-GO` を裁定する。conditional GO は follow-up 付き GO であり、P2 を隠れた NO-GO にしない。

実装者は P-F に参加させない。Validator と Rubric reviewer は修正しない。

## Mission mapping

| ID | 用途 | 既定 pipeline |
| --- | --- | --- |
| M-1 | GAP -> Issue -> 修正 -> 前後比較 | P-A |
| M-2 | 防御目的の自社 security 診断 | P-C |
| M-3 | agent 改善 roadmap と benchmark delta | P-D |
| M-4 | 組織 GitHub 棚卸しと優先度付き推奨 | P-E |
| M-5 | 権限境界と記録照合の内部監査 | P-F |
| M-6 | 事業計画・企画書 | P-E 後に P-F |
| M-7 | 未知領域の反復研究 | P-E |

canonical mission YAML が別途指定された場合は、その `stages / gates / guardrails` を省略せず task packet に反映する。アクセスできない場合は内容を推測せず、mission mapping と明示済み要件だけで進め、欠落を pending gate にする。

M-2 は防御目的かつ権限のある対象だけを扱い、secret 値を出力しない。

## Default DoD

明示的に除外されない限り、品質目標として次を確認する。

1. repo に再現可能な成果物を残す。
2. deploy 対象なら本番相当環境で動作確認する。
3. 文書納品で PDF が必要なら PDF 版を検証する。
4. Golden Path E2E を green にする。E2E 未実施を完成扱いにしない。

外部 write の権限がない項目は自動実行せず、`pending gate` として残す。

## 起動条件と機密性

P-# / M-# の明示は、必要な Herdr pane と agent をこの task のために作る許可と解釈する。次は別途明示が必要:

- commit / push / PR / merge
- deploy、本番データ変更、外部メッセージ送信
- 既存 pane / tab / workspace の close
- destructive Git 操作

権限がない完成条件は実行せず、pending gate として報告する。

- このプリセット定義、role packet の正本を外部サービス、Issue、PR、共有文書へ転載しない。
- agent へは担当に必要な最小限の role packet / task packet だけを送る。
- 成果報告では preset 名、成果物、検証結果だけを示し、内部編成の機密情報を展開しない。
- 作業対象の secret、token、private ID を pane 出力やプロンプトへ含めない。

## 共通ルール

- role packet → task packet の順を崩さない（[team-orchestration.md](team-orchestration.md) 参照）。
- agent への指示は `herdr agent prompt`、shell 実行は `herdr pane run` を使う。
- 同一ファイルを複数 agent に同時編集させない。
- review / audit と実装を同じ agent に兼務させない。
- Supervisor、Commander、実行層を同じ agent に兼務させない。
- 1 turn は 1 小 task とし、30 分を超えそうなら分割する。
- blocker は `problem / impact / evidence / proposed next action` で返させる。class は `$review-go-nogo`。
- fix-loop は最大回数を先に決め、NO-GO が残っている間だけ回す。P2 だけで延ばさない。同じ失敗が続いたら停止して再設計する。
- Sol High の review packet には `$review-go-nogo` の reviewer packet を含める。
- full E2E を低レイヤの検査で代替しない。
- 作成した pane だけを管理し、明示指示なしに close しない。

## Packet templates

### Role packet

```text
Role: <role>
Model tier: <Claude Opus 5 High / Sol High / Luna High>

Worktree: /absolute/path
Branch: <branch>
Pipeline: <P-#>

Responsibilities:
- <担当する判断または作業>

Boundaries:
- 担当 scope 外を編集しない
- commit / push / PR / deploy は明示権限がない限り行わない
- destructive Git command を使わない
- 他 pane の担当ファイルへ触らない

Report:
- 結論
- changed files または reviewed files
- commands run と exact result
- blocker（NO-GO のみ） / remaining risk（P2 follow-up）

いまは role を理解したことだけ一行で返してください。
```

### Task packet

```text
Task: <一行の目的>

Repository: /absolute/path
Branch / exact HEAD: <branch / sha>
Pipeline stage: <P-# / stage>
Background: <必要最小限の背景>
Scope: <対象 file / component>
Excluded scope: <触らない file / operation>
Acceptance criteria: <判定可能な条件>
Validation: <focused / adjacent / E2E>
Deliverable: <報告形式と成果物>
```

### Blocker packet

```text
BLOCKED
problem: <何が止めているか>
impact: <どの gate に影響するか>
evidence: <command / output / file:line>
proposed next action: <最小の解消案>
authority needed: <必要なら user approval>
```
