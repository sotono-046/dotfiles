# デザインとグリッド

## 公式の参照先

確認日: 2026-09-16。専用サイト表示は DADS β v2.18.0。更新される仕様なので新規実装時に必要なページを確認し、採用日を成果物へ記録する。

- [ユーザー指定の入口](https://www.digital.go.jp/policies/servicedesign/designsystem)
- [専用サイト](https://design.digital.go.jp/dads/)
- [レイアウト](https://design.digital.go.jp/dads/foundations/layout/)
- [カラー](https://design.digital.go.jp/dads/foundations/color/)
- [タイポグラフィ](https://design.digital.go.jp/dads/foundations/typography/)
- [コンポーネント](https://design.digital.go.jp/dads/components/)
- [公式コード・デザイントークン](https://design.digital.go.jp/dads/resources/)

公式はマージン・カラム・ガターを定義し、12列や768pxの切替例を示す。ガターは原則として本文文字サイズの2倍。単に青色にするだけで「DADS準拠」と呼ばない。必要なボタン・入力・エラー・フォーカスの仕様まで確認する。starterは公式認証済みコンポーネントではなく、下記を具体化した実装例。

## このスキルの標準値

| 項目 | 標準 |
| --- | --- |
| 本文 | 16px、line-height 1.7、Noto Sans JPがあれば利用、system sansへfallback |
| コンテンツ上限 | 1360px、中央配置 |
| 列 | 768px以上12列、未満4列 |
| ガター | 32px（16px本文の2倍） |
| 外側余白 | desktop32px、mobile16px |
| 比較 | desktop Before6列/After6列、mobileは対応する1工程ずつ縦積み |
| 余白単位 | 原則8px、局所の微調整4px |

上限幅、mobile4列、役割色はアプリ側の選択。公式の必須値と説明しない。狭い幅で読めないときはカードを全列へ広げ、文字を縮めて押し込まない。

ヘッダー、サマリー、比較行に同じコンテナとCSS変数を使用する。`column = (contentWidth - gutter × (columns - 1)) / columns`、`span(k) = column × k + gutter × (k - 1)`。実レイアウトをCSS Gridで配置し、見かけだけのグリッド装飾にしない。

グリッド検査overlayを追加するなら実コンテナと同じtoken・座標系を使用。開発環境だけで表示、pointer-events:none、aria-hidden。Gキーを割り当てるなら入力欄・IME・modifier・長押しを除外する。overlay自体は必須機能ではない。

## 情報と操作

白地、濃色本文、罫線で階層をつける。アクションのblue、役割の「人」「アプリ」、状態の「未確認」はテキストでも表示する。役割と実装状態は別属性であり、緑色だから実装済みとは限らない。

概要→各フロー→対応する工程→コメントの順に見せる。大きい数字は根拠ある比較だけ。人の確認や条件付きの追加作業を隠さないが、説明をすべて大型カードにしない。

コメントの浮動パネル・選択overlayは文書レイアウトを押し広げない。タッチやキーボードでも同じ操作を可能にする。常時の装飾的ハイライトは避けつつ、`:focus-visible`による操作位置の識別は残す。入力にはラベル、アイコンだけの操作には名前、保存状態にはlive regionを用意する。
