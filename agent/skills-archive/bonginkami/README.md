<div align="center">
  <img src="https://gw.alipayobjects.com/zos/k/vl/logo.svg" width="120" />
  <h1>Kami · 紙</h1>
  <p><b>よい内容には、よい版面を。</b></p>
</div>

## これは何か

Kami（紙・かみ）は、AI エージェントに渡して **日本語のドキュメントを組ませる**ためのデザインシステムです。スキル名は `bonginkami`、配布元は private リポジトリ `bonginkan/design-bonginkami`。

AI は人が手作業で作るより速く整った文書を出せます。足りないのは能力ではなく**制約**です。デザインシステムがないと、セッションごとに灰色で平板な、毎回ばらばらのレイアウトに流れてしまう。Kami はその隙間を埋めます。ひとつの制約言語、10 種のテンプレート。エージェントが安定して回せるほど単純で、出力がそのまま世に出せるほど厳格。**日本語専用**です。

書体は **Noto Sans JP**（ゴシック）一書体。本文は Regular(400)、見出しは Medium(500)。温かいパーチメントの地色に、インクブルー 1 色のアクセント。強い影や派手な配色は使いません。

## 見本

架空の SaaS「Kasane（重ね）」を題材に、同じデザインシステムで**スライド**と**ドキュメント**を組むとどう見えるか。すべて Noto Sans JP・日本語です。

<table>
<tr>
  <td align="center" width="25%">
    <a href="samples-ja.html"><img src="assets/showcase/sample-slide-cover.png" alt="スライド表紙"></a>
    <br><b>スライド · 表紙</b>
    <br><sub>16:9 / タイポグラフィのみ</sub>
  </td>
  <td align="center" width="25%">
    <a href="samples-ja.html"><img src="assets/showcase/sample-slide-chart.png" alt="スライド チャート"></a>
    <br><b>スライド · グラフ</b>
    <br><sub>16:9 / インライン SVG 棒グラフ</sub>
  </td>
  <td align="center" width="25%">
    <a href="samples-ja.html"><img src="assets/showcase/sample-doc-onepager.png" alt="一枚もの概要"></a>
    <br><b>ドキュメント · 一枚もの</b>
    <br><sub>A4 / KPI 帯 + ロードマップ</sub>
  </td>
  <td align="center" width="25%">
    <a href="samples-ja.html"><img src="assets/showcase/sample-doc-report.png" alt="レポート"></a>
    <br><b>ドキュメント · レポート</b>
    <br><sub>A4 / 折れ線グラフ + リスク</sub>
  </td>
</tr>
</table>

> スライドとドキュメントの全 8 パターン（ビジュアルあり / なし）は [`samples-ja.html`](samples-ja.html) にまとめています。

## 使い方

private スキルとして `bonginkan/design-bonginkami` から配布しています。スキル名は `bonginkami`。

**Claude Code / 汎用エージェント（skills ディレクトリに clone）**

```bash
git clone https://github.com/bonginkan/design-bonginkami.git ~/.claude/skills/bonginkami
```

`~/.claude/skills/bonginkami/SKILL.md` が自動で認識されます。更新は `git -C ~/.claude/skills/bonginkami pull`。Claude 以外で `~/.agents/` を読むツールは `~/.agents/skills/bonginkami` に clone してください。

**Claude Desktop（ZIP アップロード）**

リポジトリの Releases から `bonginkami.zip` をダウンロード（またはリポ同梱の `dist/bonginkami.zip` を使用）し、Customize > Skills > "+" > Create skill から ZIP をそのままアップロードします（解凍不要）。

```bash
gh release download --repo bonginkan/design-bonginkami --pattern bonginkami.zip
```

ZIP は軽量で、Noto Sans JP の woff2（Regular + Medium, OFL）を同梱しているため日本語がそのまま表示されます。更新時は最新 ZIP をダウンロードし、スキルカードの "..." から Replace でアップロードしてください。

スラッシュコマンドは不要で、自然な依頼から自動起動します。出力は日本語です。

依頼の例:

- `スタートアップ向けの一枚資料を作って`
- `この調査を長文レポートに整えて`
- `正式な依頼文を作って`
- `プロジェクト作品集を作って`
- `履歴書を作って`
- `登壇用スライドを作って`
- `アプリのランディングページを作って`

**任意: ブランドプロファイル**

`~/.config/kami/brand.md` を置くと、氏名・ブランド・既定値・文体の癖を記憶できます。テンプレートは [brand.example.md](references/brand.example.md) を参照してください。

YAML フロントマター（氏名、役割、メール、サイト、GitHub、ブランドカラー、言語、ページサイズ、通貨ロケール、トーンなどの構造化フィールド）と自由記述の Markdown 本文からなります。Kami はこれを最も解像度の低いコンテキストとして扱い、依頼が曖昧なときだけ適用し、個別の文書が必要とする内容で常に上書きできます。毎回同じ見た目にせず、仕事全体で一貫した馴染みを感じさせるのが狙いです。

## デザイン

温かいパーチメントの地色、唯一のアクセントとしてのインクブルー、階層はゴシック（サンセリフ）で作り、強い影や派手な配色は退ける。UI フレームワークではなく、印刷物のための制約システムです。ドキュメントはダッシュボードではなく、組まれた紙面として読まれるべきもの。

テンプレートは 10 種類: 一枚もの・長文ドキュメント・レター・ポートフォリオ・履歴書・スライド・個別株レポート・変更履歴・ランディングページ。インライン SVG 図表が 14 種付属。コードブロックは `Pygments` がインストールされていれば構文ハイライトされ、無くても PDF はモノクロで問題なくレンダリングされます。

| 要素 | ルール |
|---|---|
| 地色 | `#f5f4ed` パーチメント、純白は使わない |
| アクセント | インクブルー `#1B365D` のみ、第二の彩色は入れない |
| グレー | すべて暖色寄り（黄褐色の下地）、冷たいブルーグレーは禁止 |
| サンセリフ | 本文 400、見出し 500。合成ボールドは避ける |
| 行間 | 見出し 1.1-1.3、密な本文 1.4-1.45、可読本文 1.5-1.55 |
| 影 | ring か whisper のみ、強い drop shadow は使わない |
| タグ | 背景は実色 hex のみ。`rgba()` は WeasyPrint の二重矩形バグを誘発 |

**フォント**: 紙面全体を 1 つのゴシック体 Noto Sans JP で組みます。Noto Sans JP（OFL）はスキルに同梱（Regular + Medium）され日本語がそのまま表示されます。Hiragino Sans / Yu Gothic、Helvetica Neue / Arial はシステム同梱のフォールバックです。

仕様の全体: [design.md](references/design.md)。早見表: [CHEATSHEET.md](CHEATSHEET.md)。

## 由来

Kami は元々 [tw93/kami](https://github.com/tw93/kami)（MIT）の日本語専用フォーク。明朝・多言語の構成をゴシック（Noto Sans JP）・日本語専用に作り替え、社内スキル `bonginkami` として配布しています。

## ライセンス

コードとテンプレートは MIT License。

**フォント**: Noto Sans JP は OFL のもとで同梱。Hiragino Sans / Yu Gothic、Helvetica Neue / Arial のフォールバックはシステム同梱またはオープンライセンスです。
