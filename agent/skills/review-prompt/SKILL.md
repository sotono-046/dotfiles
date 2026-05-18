---
name: review-prompt
description: レビュー文脈の出力形式を、重大度、根拠、ファイル名、再現性、指摘件数つきで揃える。専門レビューSkillの整形補助や、レビューで`重大度分類`, `根拠付き指摘`, `指摘件数` を求められたときに使用する。
---

# review-prompt

レビュー出力を毎回同じ判定軸で揃える。

## トリガー

- 重大度分類、根拠、ファイル名、指摘件数を求められた
- subagent や外部 reviewer に渡すレビュー指示を作る
- 他のレビュー Skill の出力形式を揃える

セキュリティレビューは `security-best-practices`、包括的な改善計画は `plan-digger`、プロンプト/Skill実地評価は `empirical-prompt-tuning` を主役にする。

## 指摘フォーマット

```markdown
## Findings

### [High|Medium|Low] タイトル

- 根拠: ファイル/行/ログ/仕様
- 問題: 何が壊れるか
- 再現性: どの条件で起きるか
- 修正案: 最小修正
```

## レビュー観点

- correctness
- security
- data loss
- regression
- performance
- maintainability
- test coverage

## 重大度

- High: data loss、security issue、production outage、重大な権限/課金/破壊的操作
- Medium: 現実的な regression、仕様不整合、重要フローの失敗、修正しないとCIや運用に影響する問題
- Low: maintainability、軽微な test gap、nit、将来の改善余地

## ルール

- findings を先に出す
- 重大度順に並べる
- 指摘がない場合は「Findingsなし」と明記する
- High がなく Medium/Low がある場合は「重大な指摘なし。ただし以下あり」と分ける
- 推測は推測と書く
- ファイルやログに紐づかない指摘は弱いものとして扱う
- ログや設定値を根拠にする場合、secret/PII は引用せず redacted excerpt か要約にする
- 最後に指摘件数を `High: 0 / Medium: 0 / Low: 0` 形式で書く

## subagent に渡す短縮版

```text
対象をレビューし、Findingsを重大度順に出してください。各指摘には根拠、影響、再現条件、最小修正案を含め、最後に High/Medium/Low の件数を必ず明記してください。根拠のない推測は分け、secret/PII は引用せず redacted excerpt か要約にしてください。
```
