---
name: design
description: UIの方向性、余白、ページやアプリのグリッドを設計・調整する。既存デザインシステムを優先し、局所修正に必要な専門参照を選ぶ。
---

# Design

ユーザーが求める視覚的な変更を、既存のコンポーネント・トークン・実画面に合わせて行う。色値や文言の指定どおりの置換など、判断が不要なら参照を追加せず実行する。

## 必要な参照を選ぶ

依頼の名詞より、変更する対象で選ぶ。局所修正は通常1つで足りる。既存規範で決まっていることを再設計しない。

| 今回決めること | 参照 |
|---|---|
| 色・タイポ・全体のトーン、hover/focus/selectedの視認性 | [design-principles.md](references/design-principles.md) |
| カード・リスト・フォーム内のgap、padding、行高、タップ領域 | [8pt-grid-spacing.md](references/8pt-grid-spacing.md) |
| 固定app shell、sidebar/mainの列、領域margin、Gキーのoverlay | [fixed-app-grid-debug.md](references/fixed-app-grid-debug.md) |
| 編集的なページ構成、Swiss grid、写真・見出しの組版 | [muller-brockmann-grid-systems.md](references/muller-brockmann-grid-systems.md) |

「Linear風」などの名称は参考となる視覚特性として扱い、指定があるだけで複数参照を必読にしない。カード内の余白ならspacing、全体のトーンならdesign-principlesから始める。全体構造と内部余白を同時に変更する時だけ対応する参照を併用する。

## 実装と出力

- ユーザーが指定したrepository、成果物、配信先を保持する。「HTML」「共有」だけで特定のホスティングサービスを選ばない。
- 実装は既存stackと利用可能なtool/skillを使う。未提供のartifact-designやVercel pluginを前提にせず、必要なAPIは公式資料で確認する。
- 未指定の低リスクな見た目は合理的に決めて進める。質問は対象や成果が大きく変わり、手元の画面・code・会話から解消できない点に限る。
- 変更した画面と関連する操作状態を実表示で確認する。グリッドの原点・列・baselineを変更した場合は該当overlay/測定を使う。検証済みの無関係な領域を繰り返し確認しない。
- 成果物または変更箇所と、確認した表示・残る制約を簡潔に返す。
