---
name: simulation-quality-loop
description: シミュレーション、生成ログ、評価結果などを使い、品質チェック、問題抽出、修正、再実行を回す汎用ループ。AI対AI、会話、ワークフロー、データ生成の検証改善で使用する。
---

# simulation-quality-loop

生成やシミュレーションの結果を見て、問題を作業化し、修正後に再実行する。

prompt / Skill 指示そのものを subagent で実地評価する場合は `empirical-prompt-tuning` を主役にする。この Skill は生成物、会話、ワークフロー、データ生成 run の品質改善に使う。

## トリガー

- シミュレーション結果の品質を確認する
- 生成ログから問題を抽出する
- 修正後に同じ条件で再実行して改善を見る
- simulation / generation run の改善ループに含まれる人手レビューを work items に落とす

## 実行ゲート

- `確認して` / `抽出して`: 既存ログや既存出力を読み、問題抽出までで停止する
- `実行して`: シミュレーションや生成 run を実行してよい。外部API課金や大量実行がある場合は先に条件を確認する
- `修正して`: prompt / code / data / evaluator / config のうち、指定または文脈上明らかな対象だけ修正する
- `再実行して`: 修正後の再 run まで進める
- code / data / config の永続変更や外部公開は、明示指示または承認後に限定する

## 手順

1. シナリオ、入力、期待品質、失敗条件を明確にする
2. 実行ゲートを確認し、必要ならシミュレーションまたは生成を実行する
3. ログ、出力、評価結果は secret/PII を redaction し、必要最小限を git 管理外の明示パスに保存する。raw log 保存は保持/削除方針を決めてから行う
4. `artifact-to-work-items` で問題を作業単位へ分解する
5. 修正対象が prompt / code / data / evaluator / config のどれかを明確にして修正する
6. 同じ条件または差分条件で再実行する
7. 改善、残課題、次の打ち手を記録する

## Run manifest

before / after を比較するときは、以下を固定または記録する。

- input / scenario
- seed や sampling 設定
- model / evaluator / prompt / code version
- 評価基準
- 今回変えた点
- run_id / timestamp
- command / config
- log / output / evaluation artifact paths
- operator / context

## 品質観点

- 期待仕様とのズレ
- 出力の一貫性
- 欠落、矛盾、過剰生成
- 安全性やポリシー逸脱
- 評価基準との不整合
- 再現性

## 停止条件

- 事前に決めた pass 条件を満たした
- 最大反復回数に達した。指定がなければ 3 回で一度報告する
- 2 回連続で同じ失敗が残り、修正対象の仮説が更新できない
- 外部要因、データ不足、評価基準未確定で比較できない

## 成果物

- redacted run log または必要最小限の raw log metadata
- quality findings
- work items
- before / after 比較
- remaining risks

## 注意

特定プロダクト固有のログ形式や評価基準は、この Skill に直接入れない。必要なら project Skill の references に分離する。
