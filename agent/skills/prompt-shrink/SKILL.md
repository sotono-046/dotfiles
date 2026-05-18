---
name: prompt-shrink
description: プロンプト、Skill description、レビュー指示、システム指示など agent instruction を文字数制約付きで圧縮し、意味・トリガー・禁止事項を保持する。`1024文字以内`, `プロンプトを短く`, `指示を圧縮して`, `Skill descriptionを整えて` で使用する。
---

# prompt-shrink

長い指示を、意味を落とさず実用サイズへ圧縮する。

## トリガー

- 文字数上限がある
- Skill description を短くしたい
- プロンプトが冗長で、実行時の読み込みを軽くしたい
- 同じ意味の箇条書きが増えすぎている

通常回答を短くするだけならこの Skill は使わない。

## 圧縮手順

1. 上限文字数、対象読者、保持すべき語句を確認する
2. 指示を trigger / workflow / constraints / output に分ける
3. 重複、例示過多、背景説明を削る
4. 禁止事項と完了条件は残す
5. 固有例は必要なら references に逃がす
6. 文字数を測り、上限内に収める

ユーザー指定がなければ「文字数」は Unicode 文字数として扱う。byte や token 指定がある場合はその単位を優先する。

## 優先して残すもの

- いつ使うか
- 何を入力として受けるか
- 必ず守る制約
- 終了条件
- 他 Skill との使い分け
- must / never / only / always などの強い命令

## 削りやすいもの

- 歴史的経緯
- 過剰な比喩
- 同じ意味の言い換え
- 長いサンプル
- 一度読めば十分な背景説明

## 出力

必要に応じて以下を出す。

- compressed version
- 文字数
- 削った内容の要約
- 意味が変わる可能性のある点

上限内で意味保持が無理な場合は、無理に削らず「保持できない制約」と「追加で削る候補」を返す。

圧縮後は、state-changing gate、secret/PII redaction、stop condition、他 Skill との境界が残っているか検算する。
