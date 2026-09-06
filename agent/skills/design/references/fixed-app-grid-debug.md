---
name: fixed-app-grid-debug
description: SaaS、ダッシュボード、Web アプリを固定幅のレイアウトグリッドで構成し、実レイアウトと同じ token から生成した overlay を開発環境で G キー表示して検証する。固定 shell、sidebar + main、12列／4列、8px baseline、margin 可視化、grid debug overlay の依頼で使用する。
---

# Fixed Application Grid + `G` Debug Overlay

アプリの実レイアウトを固定グリッドで組み、その **同じグリッド** を `G` で可視化する。overlay は装飾ではなく検査器である。実レイアウトと別の数値・別の座標系で描かない。

## 適用境界

使用する:

- デスクトップの shell 幅、sidebar 幅、main 幅、列数、gutter を固定したい
- カードや主要コンテンツを列 span で配置したい
- 8px baseline、列、外側 margin、sidebar／main の四辺 inset を `G` で確認したい
- デスクトップは固定、狭い画面は4列など別モードに切り替えたい

使用しない:

- カード内部やリスト項目の gap だけを直す → `8pt-grid-spacing`
- マガジン、記事、写真組版、display type の光学補正 → `muller-brockmann-grid-systems`
- 既存 design system が grid token と debug overlay の方式を規定している → 既存規約を優先

## 1. 先に固定グリッドを方程式で確定する

wide mode では viewport から毎回 track 幅を再計算せず、shell を中央配置する。最小外側 margin を確保できない幅では narrow mode に切り替える。

```text
shellInner = sidebar + main
content    = main - insetLeft - insetRight
column     = (content - gutter * (columns - 1)) / columns
span(k)    = column * k + gutter * (k - 1)
```

列幅が端数になる場合は、shell／main／inset／gutter のどれかを調整してから実装する。カード幅を `%` や `flexBasis: 30%` で近似しない。`span(k)` を使うか、CSS Grid の line 指定で同じ結果にする。

実装例として有効な整数構成:

```text
shell inner 1176 = sidebar 248 + main 928
main content 864 = 928 - left inset 32 - right inset 32
864 = 12 columns * 50 + 11 gutters * 24
sidebar content 216 = 248 - left inset 16 - right inset 16
216 = 2 columns * 100 + 1 gutter * 16
baseline = 8
```

この数値はテンプレートではなく、整合する一例。プロジェクトの既存幅に合わせて方程式を解き直す。

## 2. token を唯一の真実にする

固定幅、列数、gutter、baseline、各領域の四辺 margin を一箇所へ集める。実レイアウトと overlay は必ず同じ object／CSS custom properties を読む。

```ts
export const layoutGrid = {
  baseline: 8,
  columns: { narrow: 4, sidebar: 2, wide: 12 },
  gutter: { narrow: 16, sidebar: 16, wide: 24 },
  main: 928,
  shellInner: 1176,
  shellOuter: 1178, // 1px border * 2 を含む場合
  sidebar: 248,
} as const;

export const layoutMargin = {
  shell: { narrow: 0, wide: 24 },
  main: { top: 24, right: 32, bottom: 24, left: 32 },
  sidebar: { top: 16, right: 16, bottom: 16, left: 16 },
} as const;
```

`horizontal` のような合成値だけで持たず、debug 表示と将来の非対称レイアウトのために `top/right/bottom/left` を明示する。既存の spacing token がある場合は数値を重複定義せず、それを参照する。

## 3. 実レイアウトを token に従わせる

- wide shell は固定幅＋中央配置。余った viewport 幅だけを外側 margin にする。
- sidebar、main、header、scroll content、composer など同じ縦線を共有すべき領域は同じ inset token を使う。
- main 内の主要要素は列 line または `span(k)` で置く。見た目だけ近い `%`、magic number、要素ごとの独自 padding を残さない。
- baseline、padding、gap、line-height は原則8pxの倍数。4pxはアイコンの光学調整など意図が説明できる局所用途に限る。
- narrow mode は別の4列 grid として定義する。wide の固定12列を縮小して押し込まない。

## 4. overlay は実レイアウトと同じ座標系に置く

overlay は次を表示する。

- column fields と gutter
- 8px baseline
- shell の外側 margin
- sidebar の上・右・下・左 margin
- main の上・右・下・左 margin
- `FIXED`、shell／sidebar／main 幅、列数、baseline のラベル

overlay の frame は、実 shell と同じ親 box に置くか、同じ token と border 補正から座標を導出する。viewport 全体に12列を敷いて、中央の固定 shell と偶然重ねる実装は禁止する。

```text
frameWidth     = min(shellOuter, viewportWidth - shellMargin * 2)
frameLeft      = max(shellMargin, (viewportWidth - frameWidth) / 2)
frameInner     = frameWidth - borderLeft - borderRight
availableMain  = frameInner - sidebar
mainWidth      = min(mainToken, availableMain)
mainLeft       = sidebar + max(0, availableMain - mainWidth) / 2
```

debug overlay 自体は操作を奪わない。

- `pointer-events: none` / React Native Web なら `pointerEvents="none"`
- 十分高い `z-index`
- accessibility tree から隠す
- production では render しない
- 自動検証するなら overlay、main、各 margin band に安定した `data-testid` / `testID` を付ける

## 5. `G` キーの切り替えは入力を壊さない

`G` は開発環境の Web だけで有効にする。入力欄、IME composition、長押し repeat、`Alt`／`Ctrl`／`Meta` 付き shortcut を除外する。`Shift+G` は大文字の `G` として同じ切り替えに含めてよい。

```ts
function isEditableTarget(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false;
  return target.isContentEditable
    || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName);
}

function toggleGrid(event: KeyboardEvent) {
  const isG = event.code === 'KeyG' || event.key.toLowerCase() === 'g';
  if (
    !isG
    || event.repeat
    || event.isComposing
    || event.altKey
    || event.ctrlKey
    || event.metaKey
    || isEditableTarget(event.target)
  ) return;

  setVisible((current) => !current);
}
```

listener は mount 時に登録し unmount 時に解除する。framework の開発フラグ（`__DEV__`、`import.meta.env.DEV`、`process.env.NODE_ENV !== 'production'` 等）は実際の stack に合わせる。タッチ中心の開発環境や discoverability が必要なら、同じ state を切り替える小さなボタンも用意する。

## 6. ブラウザで検証する

最低限、次を実ブラウザで確認する。

1. wide viewport を2幅以上で確認し、shell／sidebar／main／column の幅が固定されたまま中央位置だけ変わる。
2. `G` の表示前後で layout の geometry が変化しない。
3. overlay の列端、baseline、8方向の margin band が実コンテンツの端と一致し、ラベル値も token と一致する。
4. narrow viewport で4列など指定した別 grid に切り替わる。
5. `input`、`textarea`、`select`、`contenteditable` では `g` が入力され、overlay は切り替わらない。
6. `Ctrl/Meta/Alt + G`、IME composition、key repeat で切り替わらない。
7. overlay 表示中も click、scroll、focus が妨げられない。
8. production build／export に overlay が出ず、console error がない。

可能なら DOM の `getBoundingClientRect()` で実測し、目視だけで完了しない。列端の誤差、shell border の2px、中央配置時の半端な `frameLeft`、scrollbar 有無によるずれを数値で検出する。

## 典型的な失敗

- **overlay だけ12列**: 実コンテンツは独自 padding／割合幅のまま。overlay と同じ token へ置き換える。
- **viewport 基準の overlay**: 固定 shell が中央へ動くとずれる。shell と同じ box／座標式へ移す。
- **固定と言いながら列幅が流動**: `1fr` を viewport 全体へ適用している。固定 main 幅の内側だけで track を作る。
- **margin を一色一枚で覆う**: どの領域の何pxか分からない。shell、sidebar、main を色分けし四辺を個別表示する。
- **入力中に画面が切り替わる**: editable target、IME、modifier guard を追加する。
- **overlay が操作を遮る**: pointer events と accessibility 設定を見直す。
- **wide を縮めただけの mobile**: breakpoint 以下は独立した4列 grid に切り替える。

## 完了条件

固定 grid の方程式、token、実レイアウト、overlay が同じ値で閉じていること。`G` 表示はその一致を目視・実測でき、通常入力・操作・production を妨げないこと。
