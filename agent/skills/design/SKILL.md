---
name: design
description: >-
  デザイン・UI 関連依頼の統括スキル。決定木で方向を定め、references/ 配下の
  専門リファレンス（design-principles: プロダクトUIの方向決め・色・タイポ /
  muller-brockmann-grid-systems: Swiss モジュラーグリッド /
  8pt-grid-spacing: 余白・gap・行高）を読み分ける。「デザインして」「UI を作って」
  「レイアウトを整えて」「ダッシュボード作って」「マガジン風」「サイドバーの余白」
  「Linear 風」「Swiss デザイン」「グリッドに揃えて」で使用する。
---

# Design — 決定木 + 専門リファレンス索引

デザイン系リファレンスが複数あり、依頼内容と特性のマッチングを誤ると的外れな出力になる。
この SKILL.md は **判断だけ** を担う軽量レイヤー。本体ロジックは `references/` 配下の各リファレンスに任せる。

> **使い方**: ユーザーの依頼を読んだら、まず § 決定木 を上から順に当てはめる。
> マッチしたリファレンス（`references/<名前>.md`）を Read してから作業に入る。
> 1 タスクで複数リファレンスを併用するパターンは § 併用 を参照。
> 決定木内の `design-principles` 等の名前は `references/` 配下の同名ファイルを指す。

## リファレンス一覧（守備範囲）

| リファレンス | 守備範囲 | 主な成果物 |
|--------|---------|----------|
| **references/design-principles.md** | プロダクト UI（SaaS、ダッシュボード、管理画面、Web アプリ）の **デザイン方向決定**：personality（Precision/Warmth/Sophistication/Boldness/Utility/Data）、カラーパレット、タイポ、影、コンポーネント美意識。Linear / Notion / Stripe / Vercel / Mercury 系の精密ミニマル UI。 | 方向性のコミット → トーン・色・コンポーネント仕様 |
| **references/muller-brockmann-grid-systems.md** | エディトリアル／マガジン／レポート／ランディングページの **モジュラーグリッド構築**。Swiss design、International Typographic Style。CSS 変数を真実とした 12 列＋8px ベースライン、subgrid バンド、display type の光学アラインメント、`scripts/grid_tokens.py` で雛形生成、`scripts/verify_grid.js` (Puppeteer) で 0px 検証。 | グリッド付き HTML/CSS、検証スクリプト |
| **references/8pt-grid-spacing.md** | リスト／ナビ／フォーム／カード／モーダル／テーブル等の **余白・gap・行高** を 8 ポイントグリッドで統一。トークン化された 4/8 倍数、近接（項目間 < グループ間）、クリック領域 40+、垂直 edge と水平 inset の分離。 | スペーシング仕様（トークン + 値） |
| **artifact-design**（システム配信スキル） | claude.ai Artifact として配信する **単発の HTML ページ**。報告書、可視化、コミュニケーション用の見栄えあるレンダリング。デザインプロセス（パレット brainstorm → 確定 → 構築）と render-verified の仕組み。 | self-contained HTML（外部依存なし） |
| **vercel:shadcn**（vercel プラグイン経由） | shadcn/ui を使った Next.js コンポーネント実装。CLI、テーマ、custom registry、Tailwind 連携。 | shadcn コマンド + コンポーネント |
| **vercel:react-best-practices** | TSX コンポーネントの構造・hooks・a11y レビュー。 | レビュー結果 |

## 決定木（上から順に当てはめる）

### Q0: そもそもデザイン判断を伴うか？

- ❌ **No**（色値だけ変える、コピー修正、既存トークンへの単純置換、リネーム、文章校正・議事録清書など視覚デザイン判断を伴わない作業）→ **ルーター終了**。リファレンスは読まずに通常フローで作業する。
- ✅ **Yes**（色・余白・タイポ・構成のいずれかについて判断が要る）→ Q1 へ

### Q1: 出力先は claude.ai の Artifact か？

判定条件: **一時 URL での共有が目的**（Anthropic がホストする使い捨てページ）なら **Yes**。**自分のリポジトリ／プロダクトに永続化するコード**として書くなら **No**。

ポジ／ネガ最小ペア:
- ✅ Yes 寄り語: 「Artifact にして」「claude.ai で共有」「共有用 HTML 一枚で」「パッと共有」「リンクで配って見せたい」
- ❌ No 寄り語: 「自社サイトに公開」「自社の〜リポジトリ」「Next.js プロジェクトに追加」「リポジトリにコミット」「社内 HTML」「社内向け」「Web 化（公開先が暗黙にある）」「ローカル保存」「手元で使うファイルに書き出す」
- 📌 メタルール: **所有先（リポジトリ / プロダクト / 自社サイト / 社内）が示された時点で No 確定**。中間語があっても上書きされる。
- 🟡 中間語（単独では確定不可）: 「配布する」「エクスポート」「書き出す」「HTML にして」「PDF っぽく」など、配信先を含意しない動詞。
  - **インタラクティブモード**: 配信先を 1 回確認する（ポジ/ネガどちらも示唆が無いとき）。
  - **auto モード**: 確認せず **`artifact-design` を既定** とする。
  - **No 寄り語が 1 つでもあれば常に No 確定**（中間語があっても優先）。

判定（3 値）:
- ✅ **Yes（明示あり）**: 「Artifact にして」「claude.ai で共有」「Anthropic 側に置きたい」など明示 → **`artifact-design`**。
- ⚠️ **配信先曖昧**: 「リンクで共有したい」「HTML 一枚にして」など、永続化先が示されない場合 → 既定で **`artifact-design`** を選ぶ（曖昧なら一時 URL 配信が最小コスト）。ただし「自社サイト」「リポジトリ」「コミット」「プロジェクトに追加」などの語が一つでもあれば No に倒す。可能なら 1 回ユーザーに配信先を確認する。
- ❌ **No**: 自社プロダクト・公式サイト・既存リポジトリへの永続化が明示 → Q2 へ

### Q2: 依頼の核心は「**何を作るか**（方向決め・personality・色・トーン）」か、「**どう組むか**（グリッド・余白・行高）」か？

- **方向決め / personality / 色 / トーン / 状態表現** が核心
  - SaaS / ダッシュボード / 管理画面 / Web アプリ / 業務ツールの UI
  - 「Linear 風」「Notion 風」「Stripe 風」「Mercury 風」「Vercel 風」「Raycast 風」など **固有プロダクト名指定**
  - 「Jony Ive 級の精度」「ミニマル」「ダークモード基調」
  - 「カラーパレットを決めて」「コンポーネント美意識」「全体のトーン」
  - **状態表現**: hover / active / focus / selected / disabled / pressed の視認性、コントラスト、focus ring、押下フィードバック、selected highlight。「active が目立たない」「ホバーが弱い」「focus が見えない」など。
  - → **`design-principles`** を読む。Q3〜Q5 と併用可。
  - 💡 **固有プロダクト名指定ルール（inline）**: 固有名指定は personality（方向）と密度（余白）を同時に含意するため、**既定で `design-principles` → `8pt-grid-spacing` の二段構え** を採用する。**固有名ルールが発火した時点で第一スキルは確定。** Q3 の LP 二分岐／Q5 の実装スタックは「併用追加」として後段で判定する（例: Mercury 風 + shadcn DataGrid → 第一 `design-principles`、併用 `8pt-grid-spacing` + `vercel:shadcn`）。
- **どう組むか（構造）** が核心 → Q3 へ

### Q3: コンテンツの性質はどちらに近いか？

- **エディトリアル / マガジン / レポート / 記事**（読み物寄り、視覚的にコンポジションを見せたい、display type が主役）
  - 「マガジンスプレッド」「Swiss デザイン」「Müller-Brockmann」「グリッドオーバーレイ」「ベースライン揃え」「活字組」
  - 12 列 / 6×6 / 4×8 のモジュラー格子、subgrid バンド、display type の光学調整が必要
  - → **`muller-brockmann-grid-systems`** を読む。
- **ランディングページ (LP)**: 2 つに分岐する。
  - 読み物・活字組・写真・ストーリーの流れが主役（コーポレート LP、ブランドサイト、年次レポート LP）→ **`muller-brockmann-grid-systems`**
  - 機能カード・CTA・プロダクト訴求・スクショ中心の SaaS 製品 LP → **`design-principles` + `8pt-grid-spacing`** の二段構え（アプリ UI 寄り）
- **実用ドキュメント / 読み物 HTML**（社内 docs、KPI / 数値レポート（グラフ・表中心）、README 風 / docs サイトの 1 ページ、リサーチサマリ — エディトリアル装飾は不要、display type や写真組版は不要）
  - 判別の手がかり語: 「グラフ」「表中心」「数値レポート」「README」「docs」「社内 HTML」「Web 化」
  - → **`design-principles`（軽い方向決め）+ `8pt-grid-spacing`（タイポ・余白）** の二段構え。
  - 途中で display type 構成や写真組版が必要になれば `muller-brockmann-grid-systems` に切替。
- **アプリケーション UI**（操作する、リスト・フォーム・カード・テーブル・モーダルが主体）
  - → Q4 へ

### Q3.5: 対象は全体構造か、局所要素か？

> **前提**: 固有プロダクト名（Q2 inline ルール）を含む依頼はここに来た時点で既に二段構えで確定している。本問は固有名を含まない依頼にのみ適用する。

Q3 でマガジン／LP に分類されたページであっても、依頼が「フッターのリンク集の余白」「カード内の gap」のように **局所要素のスペーシング** に閉じていれば、第一スキルは **`8pt-grid-spacing`** に切り替える。`muller-brockmann-grid-systems` は全体グリッドが論点のときの選択肢。

- 全体（ページレイアウト、ベースライン、列構成、ヒーロー組版）→ Q3 の選択を維持
- 局所（フッター内・カード内・リスト内の gap / padding / 行高）→ Q4 へ進む
- ⚠️ **固有プロダクト名（Q2 inline ルール）が含まれる場合は局所であっても Q2 の二段構えを優先**（第一スキル `design-principles`、`8pt-grid-spacing` は併用）。

### Q4: 「余白・gap・行高・タップ領域」が依頼の中心か？

- ✅ **Yes**（「スペーシング」「余白」「8pt」「サイドバーの余白」「タップしづらい」「グループが読み取れない」「のっぺりして見える」）
  - → **`8pt-grid-spacing`** を読む。
  - ⚠️ ただし「のっぺり」の原因が **状態表現のコントラスト不足**（disabled / focus / hover が見えない等）の場合は密度の問題ではないので Q2 に戻り `design-principles` を使う。
- ❌ **No** → Q5 へ

### Q5: 実装スタック・コンポーネントライブラリへの依存があるか？

- **shadcn/ui / Next.js / Tailwind** で組む → **`vercel:shadcn`** + **`vercel:react-best-practices`**
- **その他のフレームワーク・素の HTML/CSS** → 該当するリファレンスなし。`design-principles` + `8pt-grid-spacing` の組合せで進める。

## 併用パターン（よくある組合せ）

| 依頼の型 | 推奨される読み込み順 |
|---------|--------------------|
| SaaS ダッシュボードを作る | `design-principles`（personality・色）→ `8pt-grid-spacing`（コンポーネント余白）→ shadcn 環境なら `vercel:shadcn` |
| 既存 UI のレビュー / スペーシング監査 | `8pt-grid-spacing`（4 列テーブル形式で違反洗い出し） |
| マガジン風ランディングを作る | `muller-brockmann-grid-systems`（グリッド構築）→ 必要なら `8pt-grid-spacing` を内部の小要素に局所適用 |
| 「Linear っぽくして」と言われた | `design-principles`（Precision & Density を選ぶ）→ `8pt-grid-spacing`（密度高めのトークン選択） |
| Artifact で報告書を可視化 | `artifact-design` 単独。`design-principles` の personality 観点だけ参考にする |
| 既存 Next.js プロジェクトにコンポーネント追加 | `vercel:shadcn` → `vercel:react-best-practices` |

**固有プロダクト名で雰囲気指定された場合のルール**: 「Linear 風」「Stripe 風」「Notion 風」「Mercury 風」「Vercel 風」「Raycast 風」のように既存プロダクト名で雰囲気を指定された依頼は、既定で **`design-principles`（方向決め）→ `8pt-grid-spacing`（実装値）の二段構え** を採用する。固有名は personality の指定であると同時に密度・余白の指定でもあるため。

## 起動しないでよい場合

- 「色だけ変えて」「テキスト直して」「コピー修正」など、デザイン判断を伴わない単発修正
- 既に CLAUDE.md / 別の規範でデザインシステムが固定されているプロジェクト（その規範に従う）
- アイコンやイラスト素材の生成（別途画像生成系スキルや Eagle 等）

## ルーターの分岐ミスを防ぐコツ

1. **依頼の名詞より「動詞 + 対象」を読む**。「サイドバーの**余白**を整えて」は対象＝余白 → `8pt-grid-spacing`。「サイドバーの **トーン**を Linear 風に」は対象＝トーン → `design-principles`。
   ⚠️ **ただし固有プロダクト名（Linear / Notion / Stripe / Mercury / Vercel / Raycast 等）が依頼に含まれた時点で、Q2 の固有名ルール（二段構え）が優先される**。動詞+対象ルールは固有名が無いときに限り適用する。
2. **「グリッド」だけで `muller-brockmann` に飛ばない**。アプリ UI で「グリッドに揃える」は多くの場合 8pt スペーシングの話。マガジン／読み物の文脈が無ければ `8pt-grid-spacing`。
3. **複数スキルが該当する時は併用 OK**。「Linear 風ダッシュボード作って」は `design-principles` で方向を決めてから `8pt-grid-spacing` で実装値を決めるのが定石。
4. **迷ったら最も「方向決め」寄りの `design-principles` から読む**。下流のスペーシング決定はその後にいつでも乗る。

## 自己更新

新しいデザイン系リファレンスを references/ に追加したら、§ リファレンス一覧と § 決定木を更新する。重複が出たら統合か役割再定義を行い、ルーターが単一の真実であり続けるようにする。
