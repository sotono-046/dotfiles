---
name: bonginkami
description: Kamiの日本語編集スタイル（Noto Sans JP、パーチメント、インクブルー）で文書や静的LPを組む。この意匠が求められる時に使い、一般のPDF・スライド依頼だけでは発火しない。
---

# Kami · 紙

Noto Sans JPを中心にした文書・静的ページのテンプレート集。ユーザーの言語・形式・ブランド指定を優先し、別の意匠が求められる場合は該当する文書/デザイン能力を使う。動的なapp UIや単独イラストの作成をこのworkflowへ取り込まない。

## 必要な手順だけ読む

| 依頼 | 参照 |
|---|---|
| 既存文書の文言・数値更新、局所layout修正 | [CHEATSHEET.md](CHEATSHEET.md)と対象template。CSSを触る場合だけ対応するdesign節 |
| 新規文書、内容・構成を大きく編集 | [document-workflow.md](references/document-workflow.md) |
| スライド | [slides-workflow.md](references/slides-workflow.md) |
| 履歴書の内容 | [resume-writing.md](references/resume-writing.md) |
| 図を埋め込む | [diagrams.md](references/diagrams.md) |
| render、font、overflowの不具合 | [production.md](references/production.md)の該当節 |
| 任意のブランドprofileが存在する | [brand-profile.md](references/brand-profile.md) |
| skill自体・template・script・releaseの保守 | [maintenance.md](references/maintenance.md) |

詳細は[design.md](references/design.md)、[writing.md](references/writing.md)、[anti-patterns.md](references/anti-patterns.md)の今回必要な節を読む。全規範や全templateを先にロードしない。

## 文書の契約

- 言語、出力形式、目的と長さは依頼・会話から決める。指定がなければこのスタイルでは日本語が既定だが、明示された別言語を上書きしない。ページ数未指定だけで質問しない。
- `assets/templates/*-en.html` の `-en` はファイル名の慣例。コピー先の `lang` を成果物の言語に合わせる。Noto Sans JP 400/500、既存の `--serif` / `--sans` aliasを保持する。
- 未指定の通常文書はPDF、LPはHTML。HTML sourceは保持する。編集可能PPTXやPNGは依頼・用途に必要な時だけ作り、明示されたformat-onlyを尊重する。
- 既存templateをコピーし、今回必要な内容・layoutだけ変える。素材や数値を捏造せず、不足する任意の枠は省略・統合する。質問は結果を左右する未解決情報に限る。
- 変更した成果物の内容・見た目・font・overflowを確認し、依頼されたfileと確認結果を返す。未実施を検証済みにせず、軽微な体裁調整や既承認の操作のために再承認を挟まない。

この入口の言語・形式・scopeの契約は参照内の既定値より優先する。skill sourceだけの改訂でZIPや全templateを作り直さない。releaseを依頼された時はmaintenanceのpackage確認を行う。
