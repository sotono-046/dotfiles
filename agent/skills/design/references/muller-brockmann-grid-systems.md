---
name: muller-brockmann-grid-systems
description: Müller-Brockmann のモジュラーグリッド（International Typographic Style / Swiss design）でエディトリアル・マガジン・レポート系の Web ページを構築する。CSS 変数を単一の真実とし、コンテンツと同じボックスに住むグリッドオーバーレイ、subgrid バンド、8px ベースラインロック、display type の光学アラインメントを強制し、`grid_tokens.py` スキャフォールド生成器と `verify_grid.js` (Puppeteer) で 0px 適合を検証する。`magazine spread`, `grid system`, `Swiss design`, `editorial layout`, `グリッドオーバーレイ`, `グリッドに揃える`, `Müller-Brockmann`, `スイスデザイン`, `マガジン風レイアウト` で使用。Vignelli Canon スキルとは姉妹関係（あちらは六書体カノン＋交通サイン、こちらはモジュラーマガジングリッドと検証可能な Web グリッドエンジニアリング）。
---

# Müller-Brockmann Grid Systems — built real, visible, and verified

Josef Müller-Brockmann (1914–1996), Zurich; *Grid Systems in Graphic Design* (1981) is the corpus. The grid is treated as an ethic, not decoration: **"The grid system is an aid, not a guarantee. It permits a number of possible uses and each designer can look for a solution appropriate to his personal style. But one must learn how to use the grid; it is an art that requires practice."** This skill encodes that discipline AND — the part most attempts get wrong — the front-end engineering to make the grid genuinely load-bearing on the web, plus a harness that PROVES it.

> Two real review notes this skill exists to prevent:
> 1. *"the grid is just slapped on top and misaligned"* → the overlay wasn't in the same content box as the content (see §2.2).
> 2. *"the H in the headline is off the grid"* → the headline's BOX was on the grid but its INK wasn't; large glyphs carry a side-bearing (see §2.6). **Box-on-grid ≠ ink-on-grid.**

---

## PART 1 — THE DISCIPLINE (decide before drawing)
- **Objective order.** The grid brings "constructive thought," legibility, and "objective and functional" design. Restraint is the point; the system, not the ego, organizes the page.
- **Modular grid.** Divide the type area into a field of **modules** — columns AND rows — separated by consistent **gutters**, inside defined **margins**. Text and images occupy whole modules. Müller-Brockmann specimens common field counts (8 / 20 / 32 fields). For the web, a **12-column grid + 8px baseline** is a robust general default; a **6×6 or 4×8 modular field grid** when you want visible rows too.
- **Baseline grid.** Vertical rhythm is sacred: **leading = a whole multiple of the baseline unit**, and every element snaps to it. This is what makes facing columns and images line up across the page.
- **Typography.** A **grotesque sans** (Akzidenz-Grotesk / Helvetica; on the web Inter, Helvetica Now, Archivo). **Flush-left, ragged-right.** Few sizes, large jumps in **scale** for hierarchy; objective, not expressive. Big **numerals/data set large** is a signature move.
- **Palette.** Pure white paper, near-black ink, **one accent — red is canonical**. Avoid the warm-cream "Claude look"; **never blue/purple gradients** (hard house rule).
- **White space + asymmetry.** Generous margins; asymmetric compositions held in tension by the grid.

---

## PART 2 — MAKE THE GRID REAL ON THE WEB (the load-bearing engineering)
`grid_tokens.py` emits this whole scaffold correctly; the rules below are why it's built the way it is.

### 2.1 One source of truth
Put every grid parameter in `:root` CSS variables — `--cols, --gutter, --margin, --bl (baseline), --lh (leading=3×bl), --maxw`. **Content and the overlay both read these same variables.** Never hand-author the overlay separately or it will drift.

### 2.2 The overlay MUST live in the SAME content box as the content  ← #1 bug
Failure mode: content sits in a centered `max-width` container while the overlay is a **full-width sibling** of the section. On any viewport wider than `--maxw`, the centered content and the full-width overlay no longer share column positions → "slapped on top / misaligned."

**Canonical recipe (use exactly this — `grid_tokens.py` emits the same shape):**
- `.wrap` carries **the margins via `padding: 0 var(--margin)`** and is centered with `max-width: var(--maxw); margin: 0 auto;`. It is `position: relative` so the overlay can anchor to it.
- `.guides` is an **absolute child of `.wrap`** with `inset: 0` and **NO padding of its own**. Its column field (`.guides .cols`) uses absolute `left/right: var(--margin)` — **not** double padding: `inset:0` aligns `.guides` to `.wrap`'s **border-box** (which spans the full padded width), so the inner `left/right: var(--margin)` is what brings the column field back inward to match the content. If you ALSO put padding on `.guides`, the column field gets pushed inward twice and columns drift inside the content gutters.
- `.guides .cols` grid: `repeat(var(--cols),1fr) + column-gap:var(--gutter)` — the **same** track function as the content grid.
- Margin lines: dashed verticals at `left: var(--margin)` / `right: var(--margin)` of `.wrap`.

This is the one recipe — don't invent variants (e.g. `.guides` with its own padding, or `.wrap` without padding plus full-width `.guides` siblings). Different combinations look right at one viewport and drift at another.

### 2.3 Place every element by column LINE via subgrid bands
Don't eyeball spans. Each horizontal **band** spans all columns and re-exposes them:
```css
.band{grid-column:1 / -1; display:grid; grid-template-columns:subgrid; column-gap:var(--gutter); align-items:start;}
@supports not (grid-template-columns:subgrid){ .band{grid-template-columns:repeat(var(--cols),1fr);} }
```
Children place with `grid-column: <startline> / <endline>` (e.g. `1 / 6`, `6 / 13`). Every headline, paragraph, photo, caption now snaps to identical lines.

### 2.4 Lock vertical rhythm to the baseline
- Leading = `--lh` (e.g. 24px = 3×8). **Every line-height a multiple of the baseline, in px (not unitless) for display type** — unitless line-heights on large type push the box off the grid.
- Every margin/padding a multiple of the baseline. Spread top/bottom padding a multiple too, so content starts on a line.
- **Media heights = multiples of the leading** (e.g. 240/360/432/480px) so a photo's top AND bottom both land on lines.
- Hairline rules sit inside a baseline-height band, not free-floating.

### 2.5 The toggle (sizzle within the sizzle)
A control (button **+ `G` key**) toggles `body.grid-on`; overlay fades 0→1. Overlay draws: translucent **numbered column fields**, the **baseline** (major line every `--lh`, faint minor every `--bl`), and **margin lines**. Showing the real grid the page is built on IS the demo.

Minimal baseline overlay (two stacked `repeating-linear-gradient`s — major on `--lh`, faint minor on `--bl`):
```css
.guides .baseline{
  position:absolute; inset:0;
  background-image:
    repeating-linear-gradient(to bottom, rgba(17,17,17,.10) 0 1px, transparent 1px var(--lh)),
    repeating-linear-gradient(to bottom, rgba(17,17,17,.04) 0 1px, transparent 1px var(--bl));
}
```

### 2.6 OPTICAL ALIGNMENT — display ink, not its box  ← the subtle bug
A 180px headline whose layout box is exactly on line 1 still looks misaligned against body text, because the letterform's **ink** is inset by its **left side-bearing**. Cure at runtime.

**Sign — derived from MDN, verified by the harness.**

Per MDN, `ctx.measureText(ch).actualBoundingBoxLeft` is **the distance from the alignment point going LEFT to the ink's left edge**; **positive ⇒ ink lies to the LEFT of the alignment point** (overhang). With `textAlign='left'` the alignment point sits at the element's **box-left**, which itself sits on the column line (because we placed the element via `grid-column: <line>`).

So when `abl > 0`, the ink hangs `abl` px to the **left** of the column line — to slide it ONTO the line we move the box **right** by `abl`. CSS `margin-left` is positive-rightward, so:

```
dx_css = +abl           // positive margin pushes box RIGHT by abl → ink lands on column line
```

This is the canonical sign — `grid_tokens.py` emits it and `verify_grid.js`'s `ink=0px` check asserts it. (If you wrote `-abl` instead, the box would move left and the ink would end up `2·abl` to the left of the line — the verify harness catches that immediately.)

Edge cases the harness will surface if the sign is wrong somewhere downstream (font fallback, `text-align` flipped, RTL): `ink=` prints non-zero with a directional hint — re-check, don't ship by eyeball.

```js
// after document.fonts.ready and on resize:
var cvs=document.createElement('canvas'),ctx=cvs.getContext('2d');
document.querySelectorAll('.masthead,.numeral,.shead h2,.h2b').forEach(function(el){
  el.style.marginLeft='0px';
  var cs=getComputedStyle(el),ch=(el.textContent||'').trim()[0]; if(!ch) return;
  if(cs.textTransform==='uppercase') ch=ch.toUpperCase();
  ctx.font=cs.fontStyle+' '+cs.fontWeight+' '+cs.fontSize+' '+cs.fontFamily; ctx.textAlign='left';
  var abl=ctx.measureText(ch).actualBoundingBoxLeft;   // MDN: +ve = ink LEFT of origin (overhang)
  if(isFinite(abl)) el.style.marginLeft=abl.toFixed(2)+'px'; // +abl pushes box RIGHT → ink lands on line
});
```
Apply to the masthead, big numerals, and section headlines. It scales with fluid type (re-runs on resize) and uses the **actually-loaded** font, so it's correct in the user's browser.
**CRITICAL measurement caveat:** side-bearing is **font-specific**. If you measure with the wrong font you get the wrong nudge. Headless/sandbox Chrome usually lacks the webfont, so canvas falls back to a different grotesque — e.g. for the same `H` we observed `abl ≈ 16px` on the fallback vs `abl ≈ 7px` on real Inter, a 9px error in the nudge. To verify optics offline you must **embed the real webfont** via `@font-face` (local TTF). In production the runtime JS measures the loaded font and is correct.

---

## PART 3 — VERIFY (don't trust, measure)  → `verify_grid.js`
Render with headless Chrome (Puppeteer) and assert, at **several widths including > and < `--maxw`** (to catch centered-container drift, e.g. 1440 / 1180 / 900):
1. **Column adherence** — every placed `.band > *` left snaps to a column START and right to a column END (~0px). **Exclude the optically-aligned display elements** from this box check (their box is intentionally side-bearing-offset; they're validated in step 4). **Gotcha:** build BOTH the column-start set and the column-end set — a grid item spanning "to line N" ends at the *far* side of the gutter, so single-edge math falsely reports a one-gutter error.
2. **Overlay match** — each `.guides .col` rect equals the computed column rect (~0px).
3. **Baseline** — text tops modulo the baseline ≈ 0 (tolerance ≈ half a baseline; the box-top is a proxy — the leading does the real work).
4. **Optical ink** — each display element's ink-left (box − `actualBoundingBoxLeft`, real font) equals **its own** column line (nearest column-start to its box), not always line 1.

Sandbox Chrome flags that work: `--headless=new --no-sandbox --disable-gpu --disable-dbus --use-gl=angle --use-angle=swiftshader`. `file://` works for non-ES-module pages; the CLI `--screenshot` can hang on tall pages — drive via Puppeteer and screenshot per viewport. Read PNGs back with the image-capable Read tool to eyeball a **zoom crop of the top-left corner** (masthead vs body vs column line) — the fastest human check.

A clean run looks like: `col=0px overlay=0px baseline≤4px ink=0px` → `GRID VERIFY: PASS`.

Typical failure prints (so you know what to fix):
```
[1440] col=24px (.b-hero .photo: left=88, expected col-start=64 — off by 1 gutter)
[1180] overlay=0px baseline≤4px ink=7px (.masthead: ink_left=71, nearest col-line=64)
[ 900] GRID VERIFY: FAIL (3 elements)
```
Reading: `col=24px` → almost always single-edge math missing the end-of-gutter (see Gotcha in step 1). `ink=Xpx` → optical-alignment sign wrong OR font fell back (re-check `@font-face` embed or that `document.fonts.ready` resolved before measurement). `baseline>4` → a line-height somewhere isn't a `--bl` multiple, or unitless on display type.

---

## PART 4 — CRAFT DEFAULTS (so it looks excellent, not just aligned)
- **Palette:** white `#fff`, ink `#111`, one accent (Swiss red `#e4002b`). No warm-cream Claude look; no blue/purple gradients.
- **Type:** a real grotesque webfont (Inter / Helvetica Now / Archivo) for display + body; a **mono** (Space Mono / IBM Plex Mono) for folios, captions, grid annotations — reinforces the technical register. Non-Latin via Noto Sans JP etc.
- **Hierarchy** through scale + weight + white space, not color. Treat key data as **large numerals**. Kicker labels in mono caps. Per-spread folios.
- **Real photography.** Ground real subjects in real photos (`SearchImages`). **Host each image via `PublishFilePublicly` and embed the `pub.hyperagent.com` URL** — a `PublishWebpage` artifact runs in a sandboxed iframe that can't authenticate thread-scoped `/api/files/...` URLs (broken-image trap).
- **Type fidelity if you ever rasterize art** (cairosvg / headless screenshots / image-gen reference): a `Helvetica`/`Arial` CSS stack silently falls back to **Noto Sans** (reads like Calibri). Render in **Liberation Sans** or an embedded Helvetica/Arimo TTF before trusting it. (Same trap as the optical-measurement caveat: wrong font in → wrong result out.)
- **Spread model:** full-width sections, each its own per-spread `.grid` + `.guides`, consistent margins/folios.

---

## PART 5 — WORKFLOW
1. Pick the subject; gather real photos; host them publicly.
2. Generate the scaffold: `python3 grid_tokens.py` (or `--scaffold` for a full page; `--cols/--baseline/--gutter/--margin/--maxw/--accent` to taste; it warns if gutter/margin aren't baseline multiples).
3. Build spreads as **subgrid bands**; place everything by **column line**; lock spacing/line-heights/media heights to the **baseline**.
4. Add the overlay (same content box) + toggle + optical-alignment JS (already in the scaffold; point its selector list at your display elements).
5. Publish (or skip — `verify_grid.js` accepts `file:///abs/path/to/index.html` for local checks; use `PublishWebpage` only when you need a shared/iframe-able URL), then **verify**: `CHROME=… PUP=… node verify_grid.js <file-or-url> --widths=1440,1180,900`. Eyeball a top-left zoom crop. Fix, republish.

## SCRIPTS

Both scripts ship inside this skill at `<skill_dir>/scripts/`. Invoke them by their full path (recommended) or copy/symlink into your working dir. They have no network or credentials.

### `grid_tokens.py` — scaffold generator
Deterministic; emits `:root` tokens, `.grid`/`.band` (subgrid) scaffold, `.guides` overlay CSS, toggle JS, and the canonical-sign optical-alignment JS — all wired to one source of truth. No network/credentials.

CLI flags (type · default · example):

| Flag | Type | Default | Example |
|---|---|---|---|
| `--cols` | int (columns) | `12` | `--cols 12` |
| `--baseline` | int (px) | `8` | `--baseline 8` |
| `--gutter` | int (px, must be multiple of baseline) | `24` | `--gutter 24` |
| `--margin` | int (px, must be multiple of baseline) | `72` | `--margin 64` |
| `--maxw` | int (px) | `1296` | `--maxw 1280` |
| `--accent` | CSS color string | `"#e4002b"` (Swiss red) | `--accent "#e4002b"` |
| `--scaffold` | flag (no value) | off | `--scaffold` → emits full minimal HTML page (CSS + JS); without it, only the token block |

Invocation example:
```bash
python3 scripts/grid_tokens.py --scaffold \
  --cols 12 --baseline 8 --gutter 24 --margin 64 --maxw 1280 \
  --accent "#e4002b" > index.html
```
If `--gutter` or `--margin` is not a multiple of `--baseline`, a `# WARNING:` is emitted (baseline lock breaks otherwise).

### `verify_grid.js` — Puppeteer verification harness
Implements all four checks from PART 3 with the corrected both-edges column math, the optical-exclusion, per-element column-line ink targeting, and PASS/FAIL output at multiple widths.

Required env:
- `CHROME` — absolute path to Chrome/Chromium binary (e.g. `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`)
- `PUP` — absolute path to the `puppeteer-core` module (e.g. `$(node -e "console.log(require.resolve('puppeteer-core'))")`)

CLI:
- positional: file URL or http(s) URL (e.g. `file:///abs/path/to/index.html`)
- `--widths=<csv>` — viewport widths in px (default examples: `1440,1180,900` to bracket `--maxw`)

Invocation example:
```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
PUP="$(node -e "console.log(require.resolve('puppeteer-core'))")" \
node scripts/verify_grid.js file:///abs/path/to/index.html --widths=1440,1180,900
```
Clean output: `col=0px overlay=0px baseline≤4px ink=0px` → `GRID VERIFY: PASS`. Any non-zero number prints the failing element/line so you can fix → republish → re-verify (loop until PASS).

## CREED
A grid you can't toggle on and measure is a mood board, not a system. Build it from one source of truth, prove it at 0px, and align the **ink**.
