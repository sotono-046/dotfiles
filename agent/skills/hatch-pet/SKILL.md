---
name: hatch-pet
description: Codex用v2アニメーションペットを作成・修復・検証・パッケージ化する。キャラクター画像、コンセプト、ブランドを8×11 spritesheetにする依頼で使う。一般のマスコット画像生成だけには使わない。
---

# Hatch Pet

依頼された作成・修復・検証・出力を行う。名前や説明はコンセプトから補い、参照画像がなければtextからbaseを生成する。材料が揃っている時は追加の承認や入力フォームで止めない。本文の「approve」は特記がなければ担当エージェントによる証拠確認を意味する。

## 今回の操作を選ぶ

| 操作 | 読むもの |
|---|---|
| 新しいペットのbaseと標準9行を作る | [generation.md](references/generation.md)、[appearance.md](references/appearance.md)、[animation-rows.md](references/animation-rows.md) |
| 裸のブランド名からデザインを決める | [brand-discovery.md](references/brand-discovery.md)。具体的な絵や説明があれば省略 |
| look方向を生成・登録する | [look-directions.md](references/look-directions.md) |
| 既存ペットの修復・v2 upgrade | [repair.md](references/repair.md)から該当stageへ |
| 品質検証・最終受け入れ | [validation.md](references/validation.md)、短い基準は[qa-rubric.md](references/qa-rubric.md) |
| 検証済みペットの出力・導入 | [packaging.md](references/packaging.md)、[codex-pet-contract.md](references/codex-pet-contract.md) |
| 画像生成や独立QAをworkerに任せる | [workers.md](references/workers.md)。生成は利用可能な範囲で並列化 |

全参照を先に読まない。新規作成は標準行→cardinal→row 9→row 10→最終検証→依頼されたpackageへ進む。修復は合格済みの入力と検証を再利用する。

## 保持する契約

- 最終atlasは `1536x2288`、8列×11行、cell `192x208`、PNG/WebP。`1536x1872` の8×9は中間物のみ。manifestは `spriteVersionNumber: 2`。
- rows 0–8のstate/frame数はanimation-rowsが正本。rows 9–10は16方向、時計回り22.5度刻み。`000`上、`090`画面右、`180`下、`270`画面左。neutralはidle側であり000ではない。
- visual生成/編集は利用可能なimagegen skill/toolの契約に従う。base以外はmanifestに記載された画像を全て添付する。生成済み画像の抽出・合成・検証だけを同梱scriptで行い、code描画で不足rowを埋めない。
- running-leftだけは、右向きrowのidentity・props・方向が保たれると確認できた場合に同梱scriptでframe順を保ってmirror可。他stateは固有の動作を保持。
- look rowは承認cardinalを元に各8frameを一体生成する。row 9の登録・edge・semantic/continuity確認後にrow 10へ進む。新規の修復cellを混ぜない。
- 未使用cellは完全透明、使用cellは非空。identity、alpha内部穴、clipping、方向・motion意味を確認する。chromaはrequestのkeyで最終v2に単一despillを行い、成功reportとatlas validatorで判定する。
- cardinalの誤り/曖昧さ、wrong quadrant、reversal、重大なidentity/geometry破損は修復する。中間方向のblind不一致やmetric warningだけでは再生成せず、実寸loopの証拠とminor resolutionを残す。独立blind QAと全16方向のsemantic記録は省略しない。

## 実行と完了

同梱scriptを初めて使う時に `load_workspace_dependencies` でPillowを含むPythonを取得し、`PYTHON`に実行path、`SKILL_DIR`にこのskillの実path、`RUN_DIR`に今回のrunを設定する。既存の認証・tool境界を守り、利用不能な機能のために新しい環境を勝手に導入しない。

検証のみの依頼では画像生成・導入をしない。完了時は依頼されたpet/atlas/packageと確認済みQA、残る未検証点を示す。合格または証拠付きminor warningとして扱える条件が揃えば次段階へ進み、再承認を求めない。失敗をpassにせず、再利用に必要なmanifestと最終QAを保持する。
