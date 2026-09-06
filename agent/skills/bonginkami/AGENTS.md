# Kami source guide

このディレクトリは文書templateと生成skillを管理する。通常の文書作成は[SKILL.md](SKILL.md)、source・renderer・release保守は[maintenance.md](references/maintenance.md)の該当節を参照する。

- ユーザーが指定した言語・出力形式・変更範囲を優先する。Kamiの意匠や日本語既定を別の依頼に強制しない。
- 文言変更でCSSやtemplateを広げない。共有styleを変える時はspecと影響するtokenを揃える。
- templateはinline CSSの自己完結HTMLを保持。target登録の正本は `scripts/shared.py` の `HTML_TEMPLATES`。
- 私的brand profile、credential、診断dumpをsourceやpackageに入れない。
- 指示文のみの変更はfrontmatter・参照・routingを検証。template/script変更は影響するbuild/renderを確認する。release/archive更新が依頼された時だけZIPを再生成・内容確認する。

詳しい保守手順を毎回読み直したり、既に与えられた承認を再確認したりしない。
