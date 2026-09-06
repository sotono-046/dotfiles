---
name: review-go-nogo
description: レビュー指摘を実害と証拠でGO/NO-GOに分け、修正ループの終了を判断する。
---

# Review GO / NO-GO

モデル名やレビューワーの強い言い方ではなく、再現条件・証拠・影響で判断する。

| class | 基準 | 次の行動 |
|---|---|---|
| NO-GO | 再現可能なP0/P1の重大な実害 | 修正と関連検証。解消前にmerge/完了しない |
| GO-follow-up | P2以下の限定的影響・任意改善 | 残件として報告し、これだけで修正ループを追加しない |
| 対象外 | 根拠なし、scope外、既に解決 | 指摘件数に含めない |

重大な実害にはデータ損失、誤送信、二重課金/完了、無期限停止、認証/権限境界の破綻、secret/PII露出、required CI失敗がある。file:line、コード上の成立条件、ログまたは再現手順を求める。未確認の重大懸念は低コストに確認し、評価不能な必須条件をpassにしない。

文書の微差、命名、任意の抽象化、補助テストの理想化、限定的な防御強化は通常follow-up。ユーザーがその改善自体を依頼した場合は正規scopeとして実施してよい。

High/Medium/Low等の別尺度は自動変換せず、影響と証拠で上表に分類する。重要な証拠は司令塔が確認し、レビューワーのclassをそのまま採用しない。

## Reviewer packet

独立レビューへ依頼するときは対象repo、exact head/base、scopeと次の契約を渡す。

```text
読み取り専用レビュー。編集・commit・外部投稿を行わない。
NO-GOは再現可能なP0/P1の重大な実害だけ。P2以下はGO-follow-up。
各指摘: id / severity / class / evidence(file:line or repro) / user impact / required change。
根拠のない推測はassumptionとし、証拠と混ぜない。secret/PIIは引用しない。
最後に GO（follow-up N件）またはNO-GOと残blockerを示す。
```

## 終了

NO-GOがゼロになり依頼された検証が済んだら完了する。任意指摘ゼロを目指さない。修正後は変えた範囲と隣接契約だけ再確認する。同じblockerが再発する、または決めた予算内に解消できない場合は原因と必要判断を示して引き継ぐ。未実施・評価不能はそのまま明記する。
