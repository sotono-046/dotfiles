---
name: review-go-nogo
description: "レビュー判定を「重大な実害だけ NO-GO」に固定し、GPT-5.6 Sol High などの重箱の隅で修正ループを延ばさない。`レビュー基準`、`GO/NO-GO`、`Solにレビューさせて`、`重箱の隅`、`重大な実害だけ` で使用する。blocker 判定の正本。SOW 手順は plan-digger、実装委譲は task-orchestration / subagent-team。"
---

# Review GO / NO-GO

レビューは欠陥を探す作業であり、指摘がゼロになるまで修正し続ける作業ではない。NO-GO は再現可能な実害だけ。P2 以下は follow-up にしてループを閉じる。

GPT-5.6 Sol High を一次 reviewer / Commander / Peer reviewer / Rubric reviewer にするときは、この基準を packet に必ず含める。Sol は実害も nit も同列に出しやすい。

## 1. いつ読むか

- 実装差分・PR・プラン・SOW をレビューする
- 参謀 / Sol High / 独立 `codex exec review` / plan-digger の指摘を「直すか残すか」に落とす
- `レビュー基準` / `GO/NO-GO` / `重大な実害だけ` / `重箱の隅で止めない` と言われた
- 修正ループの 2 周目以降で、残件が文書・テスト理想化・防御強化だけになっている

## 2. 判定

| class | 重大度 | 意味 | 次の手 |
| --- | --- | --- | --- |
| NO-GO | 再現可能な P0/P1 | 今の成果を通すと実害が出る | 修正ループを続ける。merge / 完了にしない |
| GO-follow-up | P2 以下 | 実害が限定的、または低確率 | 完了してよい。一覧だけ残す。新しい実装 turn を起こさない |
| 対象外 | — | 根拠なし、scope 外、既に直済み | 指摘として数えない |

NO-GO の例（いずれも再現手順またはコード / ログ根拠が要る）:

- データ損失、録画・セッションデータの孤立
- 別 session / 別宛先への誤送信
- 二重課金、二重完了、状態マシンの二重適用
- 無期限停止、デッドロック、待ちの上限がないハング
- セキュリティ境界の破綻、PII / secret の露出
- CI の必須ゲート失敗（required check が red）
- 認証回避、静かな破壊、金銭・在庫・完了フラグが本番で誤発火しうるバグ

GO-follow-up の例:

- 文書の微差、表現ゆれ、コメント不足
- 補助テストの理想化、カバレッジ願望、まだ起きていない失敗へのテスト追加
- 低確率で影響が限定された防御強化
- 命名、style、任意リファクタ、抽象化の好み
- nit、任意提案、重複した bot comment

根拠のない推測は NO-GO にしない。assumption と書いて GO-follow-up にするか、確認質問にする。

過去に妥当だった NO-GO の例: 録画データの孤立、別 session への誤送信。このクラスを nit 扱いにしない。

## 3. plan-digger / herdr との対応

このスキルは blocker 判定の正本。SOW の書き方は `$plan-digger`。

- High → 既定 NO-GO。解消するまで完了しない
- Medium で security / data loss / 金銭 / 停止状態 / 誤送信に関わるもの → NO-GO、またはユーザー判断
- その他の Medium と Low → GO-follow-up
- herdr の `conditional GO` → follow-up リスト付きの GO。隠れた NO-GO にしない

## 4. Reviewer packet（Sol High に必ず渡す）

参謀・Peer reviewer・Rubric reviewer・`codex exec review` には、依頼本文へ次をそのまま含める。

```text
## レビュー判定（必須）
- NO-GO は再現可能な P0/P1 の実害だけ。データ損失、誤送信、二重課金/二重完了、無期限停止、セキュリティ/PII、CI必須ゲート失敗。
- 文書の微差、補助テストの理想化、低確率で影響が限定された防御強化は P2 以下として GO-follow-up。blocker にしない。
- 重箱の隅で修正ループを延ばさない。P2 だけの指摘で Changes requested 相当にしない。
- 各指摘は id / severity(P0|P1|P2|Low) / class(NO-GO|GO-follow-up) / evidence(file:line or repro) / user impact / required change or none で返す。
- 最終行は判定: NO-GO | GO（follow-up N件）。
- 編集しない。
```

## 5. 修正ループ

1. 指摘を class で分ける。NO-GO だけを実装 turn に渡す。
2. NO-GO が 0 になったらループを止める。残った GO-follow-up は報告して終わる。
3. P2 だけで新しい実装役 / 修正サブエージェントを起動しない。
4. 最大周回数に達しても NO-GO が残るときだけユーザーへエスカレートする。P2 残件ではエスカレートしない。
5. 「指摘ゼロまで」は禁止。正しくは「NO-GO ゼロまで」。

## 6. 司令塔の裁定

- Sol の class 付けを鵜呑みにしない。低コストな根拠は再検証する。
- Sol が P2 を NO-GO と書いていても、実害と再現がなければ GO-follow-up に落とす。
- 実害があるのに Sol が nit 扱いにしていたら NO-GO に上げる。

## 完了チェック

- [ ] reviewer packet に判定基準を入れた
- [ ] NO-GO が 0 件、または残 NO-GO を修正中
- [ ] GO-follow-up を blocker にしていない
- [ ] P2 だけで追加の実装 turn を起こしていない

## この skill を変更したときの検証

- `git diff --check`
- YAML frontmatter が parse できる
- Markdown の見出しとコードブロックが壊れていない
- `$review-go-nogo` を参照するファイルから、このディレクトリ名がずれていない
