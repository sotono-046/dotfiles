---
name: artifact-to-work-items
description: ログ、CSV、議事録、Wiki、ドキュメント、レビュー結果、調査メモ、コード片など任意のartifactから、Issue下書き、TODO、SOW、チェックリスト、Skill候補へ分解する。`Issue化`, `作業に分けて`, `スキル化候補`, `ログから問題抽出`, `TODO化` で使用する。
---

# artifact-to-work-items

素材を読み、根拠を保ったまま実行可能な作業単位へ変換する。

## 入力

- 実行ログ、ユーザー報告、CSV、スプレッドシート、Wiki、Docs、議事録
- PR review、品質レポート、調査メモ、プロンプト、仕様、コード断片
- 複数 artifact の組み合わせ

## 出力形式

ユーザーの目的に合わせて選ぶ。迷う場合は、まず checklist に落とし、外部公開するものだけ Issue にする。

- GitHub Issue
- TODO / checklist
- SOW
- Skill 候補
- 調査観点リスト
- 修正タスク分解

## 手順

1. artifact の種類、期間、対象範囲を明示する
2. 事実、推測、要確認を分ける
3. 重複する症状や要求をクラスタリングする
4. 各クラスタに根拠 artifact と再現条件を紐づける
5. 1 work item = 1 成果物 / 1 検証軸になるよう分割する
6. 優先度、影響範囲、完了条件を付ける
7. `Issue化` は title/body/checklist の下書きまでで停止する。`gh issue create` やファイル保存は明示指示または承認後のみ進める

## 外部作成ゲート

- Issue 作成、PR コメント、共有ドキュメント保存はユーザーの明示指示がある場合のみ行う
- 作成前に title / body / labels / target repo を提示する
- 既存 Issue や重複 work item を確認する
- secret、PII、顧客名、内部URLなどは通常回答、下書き、ローカル保存、公開物のすべてで既定 redaction する
- 公開物は repo / visibility / audience を確認してから作成する
- ローカル保存でも、保存先とファイル名が曖昧なら確認する

## Issue 本文テンプレート

```markdown
## 背景

## 観測された事象

## 根拠

## 対応方針

## 完了条件

- [ ] TODO

## 補足
```

## Skill 候補抽出

Skill 化を求められた場合は、以下を必ず出す。

- Skill 名
- trigger になるユーザー発話
- 入力
- 手順
- 終了条件
- 既存 Skill との重複
- 汎用 Skill か project Skill か

## 注意

プロジェクト固有語彙は、汎用 Skill 候補の名前や description へ直接入れない。固有語彙は examples や references に逃がす。
