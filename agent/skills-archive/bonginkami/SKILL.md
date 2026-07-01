---
name: bonginkami
description: '日本語ドキュメントと製品ランディングページを Noto Sans JP (ゴシック) で組む: 履歴書、一枚もの、白書、手紙、ポートフォリオ、スライド、ランディングページ。温かみのあるパーチメント、インクブルーのアクセント、ゴシック (サンセリフ) の階層。日本語専用。Triggers on "PDF作って / 資料作って / 一枚もの / 提案書 / 履歴書 / スライド / ランディングページ / PPT / slides / landing page / product page", or "build me a resume / make a one-pager / design a slide deck / turn this into a PDF / make this presentable / create a landing page".'
---

# kami · 紙

**紙 · かみ** - the paper your deliverables land on.

Good content deserves good paper. One design language across eight document types, Japanese-only: warm parchment canvas, ink-blue accent, sans-serif (gothic) hierarchy, tight editorial rhythm.

Part of `Kaku · Waza · Kami` - Kaku writes code, Waza drills habits, **Kami delivers documents**.

## Step 0 · Load brand profile (if exists)

Check `~/.config/kami/brand.md` (preferred) or `~/.kami/brand.md` (legacy fallback). If found, read `references/brand-profile.md` for the full four-layer application spec (placeholder substitution, session defaults, visual customization, habit notes) and its six guardrails. If no profile exists, continue without interruption.

Key rule: explicit prompt > editorial judgment > habit notes > frontmatter defaults > built-in defaults. Profile fills gaps silently; it never overrides the current conversation.

## Step 0.5 · User project style scan (opt-in)

Run this only when the user explicitly references a sibling project as a visual reference: "like my <project> site", "match the style of <repo>", "use the look from <directory>". Skip silently when no such reference exists.

When triggered, before generating:

1. Locate the referenced project's style files:
   ```bash
   find <referenced-path> -maxdepth 4 \( -name "*.css" -o -name "tailwind.config.*" -o -name "theme.*" -o -name "tokens.*" \) | head -20
   ```
2. Extract: dominant color values (hex / hsl), font stack, spacing scale, border-radius scale. Prefer values declared in CSS variables or design tokens over inline literals.
3. Merge into the in-session brand profile as Layer C (visual customization), not Layer B (session defaults). Do not override an explicit `--brand` flag or values that the user typed in this turn.
4. Report back in one line before continuing: "scanned <project>, extracted N colors / M fonts; using as visual reference."

Skip and fall back to the brand profile defaults if the referenced path does not exist, no CSS-like files are found, or the extraction would conflict with the user's explicit values in the current message.

---

## Step 1 · Set up the document (Japanese-only)

**Kami builds Japanese documents only.** Even when the user writes the brief in English, the deliverable is Japanese. Use the `-en.html` templates as the document templates (the `-en` suffix is an internal filename convention, not a language label; there are no unsuffixed templates). Copy the template and set the root to `<html lang="ja">`; the `html[lang="ja"]` rules in `styles.css` then prefer the Japanese gothic stack (Noto Sans JP, with Hiragino Sans etc. as local-preview fallbacks). Reference docs are written in English but describe this Japanese-only system.

| Document family | HTML templates | Slides (PDF default) | Slides (PPTX fallback) |
|---|---|---|---|
| Japanese | `*-en.html` (copy, set `<html lang="ja">`) | `slides-weasy-en.html` (set `lang="ja"`) | `slides-en.py` |

> Default to the WeasyPrint HTML path; fall back to PPTX (`slides-en.py`) only when the user explicitly needs an editable deck.

Always use `CHEATSHEET.md` and `references/*.md` for design, writing, production, and diagram guidance.

Code blocks with `class="language-*"` are highlighted only when optional `Pygments` is installed in the build environment. Without it, PDFs still render and code blocks stay monochrome.

## Step 1.5 · Intent extraction (silent checklist)

Before choosing a template, verify these four dimensions are clear. Do not ask unless 2+ are missing and cannot be inferred from context.

| Dimension | What to extract | Example |
|---|---|---|
| **Purpose** | Why this document exists | Persuade investor vs. align internal team vs. close a candidate |
| **Audience** | Who reads it, what they already know | Technical CTO (skip basics) vs. non-technical board (explain terms) |
| **Constraint** | Hard limits on length, format, tone, or delivery | "One page max", "formal English", "print-ready A4" |
| **Success** | What outcome counts as success | They schedule a meeting / they approve the budget / they understand the architecture |

Rules:
- If the conversation already answered a dimension, skip it silently.
- If a dimension can be inferred from the document type (e.g. resume purpose is always "get an interview"), skip it.
- If 2+ dimensions are genuinely unclear, ask in a single compact question (max 2 sub-questions).
- Never ask all four as a checklist. This is a background verification, not a form.

## Execution contract

Before creating or modifying an output, lock the contract: language, template, output format, page or length target, visual acceptance check, and verification command. Infer from the user's request when clear; ask only when missing fields materially change the deliverable.

Use the nearest existing template and verification path. Do not add a new template, stabilizer profile, shared CSS layer, dependency, script flag, or optional mode unless the current request cannot be satisfied without it.

If a change touches `SKILL.md`, templates, scripts, references, or package inputs, decide whether `dist/bonginkami.zip` must be refreshed before handoff. Shipped behavior is not ready until the package contains the changed files.

---

## Step 2 · Pick the document type

| User says | Document | Template |
|---|---|---|
| "one-pager / 一枚もの / 提案書 / 要約 / exec summary" | One-Pager | `one-pager-en.html` |
| "white paper / 白書 / 長文 / 年次まとめ / technical report" | Long Doc | `long-doc-en.html` |
| "formal letter / 手紙 / 退職届 / 推薦状 / memo" | Letter | `letter-en.html` |
| "portfolio / ポートフォリオ / 作品事例 / case studies" | Portfolio | `portfolio-en.html` |
| "resume / CV / 履歴書 / 職務経歴書" | Resume | `resume-en.html` |
| "slides / PPT / deck / スライド / プレゼン" | Slides | `slides-weasy-en.html` |
| "equity report / 個別株レポート / バリュエーション / investment memo / 株式分析" | Equity Report | `equity-report-en.html` |
| "changelog / 更新履歴 / release notes / 変更履歴" | Changelog | `changelog-en.html` |
| "landing page / ランディングページ / product page / 製品ページ" | Landing Page | `landing-page-en.html` |

> **Changelog vs. release notes**: The changelog template above is for styled document output. GitHub release notes are a separate deliverable; use `/write` with Release Note Template Mode.

> **Landing Page**: Screen-first interactive template. No PDF output. Includes gallery carousel with auto-rotate, hero entrance animation, responsive breakpoints (880px / 480px), and prefers-reduced-motion support. Deploy as static HTML to Vercel / Netlify / any host. The agent fills {{PLACEHOLDER}} values and HTML comment blocks, then saves as a ready-to-serve `.html` file.

> Slides: default to `slides-weasy-en.html` (WeasyPrint HTML → PDF). Use `slides-en.py` only when the user explicitly requires an editable PPTX file.

> Deck recipe: read design.md Section 8 before drafting slides.

### Decision tree (use before asking)

Walk this tree before reaching for a one-liner question. Ask only when two cells genuinely both fit.

| Signal | Document |
|---|---|
| Length target unknown | Ask "how many pages" before classifying |
| ≤ 1 page + investor / recruiter / exec summary audience | one-pager |
| ≤ 1 page + formal correspondence (sales, hiring, resignation, memo) | letter |
| 1.5-2 pages + career narrative + project bullets | resume |
| 3-6 pages + project showcase + visual heavy | portfolio |
| 6-15 pages + sustained argument + low visual density | long-doc |
| Presentation flow + speaker support + per-slide assertion | slides |
| Financial / metrics dashboard + thesis + price or risk view | equity-report |
| Version-by-version log + release facts | changelog |
| Product showcase + pricing + screenshots + FAQ for browser | landing-page |

Ambiguity examples that justify a one-liner:
- "1.5 page career story with heavy visuals" -> ask "resume or portfolio?"
- "2 page exec summary with metric tiles" -> ask "one-pager or equity-report?"
- "5 page argument with several charts" -> ask "long-doc or portfolio?"

Pick from the tree first. Ask only when the tree is genuinely silent.

### Diagrams (primitives, not a separate template type)

When the user asks for **a diagram inside** a long-doc / portfolio / slide (not a standalone document), route to `assets/diagrams/` rather than a template:

| User says | Diagram | Template |
|---|---|---|
| "構成図 / architecture / システム図 / components diagram" | Architecture | `assets/diagrams/architecture.html` |
| "フロー図 / flowchart / 分岐フロー / branching logic" | Flowchart | `assets/diagrams/flowchart.html` |
| "象限図 / quadrant / 優先度マトリクス / 2×2 matrix" | Quadrant | `assets/diagrams/quadrant.html` |
| "棒グラフ / bar chart / カテゴリ比較 / grouped bars" | Bar Chart | `assets/diagrams/bar-chart.html` |
| "折れ線グラフ / line chart / 推移 / 株価 / time series" | Line Chart | `assets/diagrams/line-chart.html` |
| "ドーナツ図 / donut / pie / 構成比 / 分布構造" | Donut Chart | `assets/diagrams/donut-chart.html` |
| "状態遷移図 / state machine / 状態図 / lifecycle" | State Machine | `assets/diagrams/state-machine.html` |
| "タイムライン / timeline / マイルストーン / milestones / roadmap" | Timeline | `assets/diagrams/timeline.html` |
| "スイムレーン / swimlane / 役割横断フロー / cross-team flow" | Swimlane | `assets/diagrams/swimlane.html` |
| "ツリー図 / tree / hierarchy / 階層 / 組織図" | Tree | `assets/diagrams/tree.html` |
| "レイヤー図 / layer stack / 階層アーキテクチャ / OSI / stack" | Layer Stack | `assets/diagrams/layer-stack.html` |
| "ベン図 / venn / 共通部分 / overlap / 集合関係" | Venn | `assets/diagrams/venn.html` |
| "ローソク足 / candlestick / OHLC / 株価推移 / price history" | Candlestick | `assets/diagrams/candlestick.html` |
| "ウォーターフォール / waterfall / 売上ブリッジ / revenue bridge / decomposition" | Waterfall | `assets/diagrams/waterfall.html` |

Read `references/diagrams.md` before drawing - it has the selection guide, kami token map, and the AI-slop anti-pattern table. Extract the `<svg>` block from the template and drop it into a `<figure>` inside long-doc / portfolio.

Before drawing, always ask: **would a well-written paragraph teach the reader less than this diagram?** If no, don't draw.

**Auto-select charts from data.** When content contains numerical data, choose the chart type and embed it without waiting for the user to specify. Decision tree (first match wins):

| Data shape | Chart |
|---|---|
| Has open/high/low/close fields, or per-day price | Candlestick |
| Has + and - contributions that sum to a total (bridge, waterfall, P&L) | Waterfall |
| One series, values sum to ~100%, items ≤ 6 | Donut |
| One series, values sum to ~100%, items ≥ 7 | Horizontal bar |
| Two or more series across time (months, quarters, years) | Line |
| One series across time, large count changes dominate (not rate) | Bar |
| Multiple categories, same time snapshot, 2+ series | Grouped bar |
| 2×2 strategic or priority positioning | Quadrant |
| Hierarchical data with depth ≥ 2 | Tree |
| Process with decision branches | Flowchart |
| Cross-team or cross-role process with ≥ 3 actors | Swimlane |
| Set overlaps or shared attributes between 2-3 groups | Venn |
| Category comparison, single series, no time axis | Bar |

When data fits multiple types, prefer the one that shows variance most clearly. Always embed inside a `<figure>` with a caption that states the insight, not just the data range.

## Step 2.1 · Source and material pass

Run this before distilling or filling content when the document depends on facts or materials outside the user's draft. Skip it only for personal drafts where the user already supplied everything needed.

### Source check

Trigger when the document mentions a specific company, product, person, release date, version, funding round, metric, market fact, technical spec, or any current fact likely to change.

- Use primary sources before writing: user-provided material, official site, docs, filings, press release, app store page, or repo release
- Keep a short note of source names and dates for facts that drive the document
- If sources conflict or a fact cannot be checked quickly, ask the user instead of choosing silently
- Avoid current-sounding claims such as "latest", "recent", "new", version numbers, launch dates, or financial figures unless they are checked

### Material check

Trigger when the document is about a company, product, project, venue, or personal brand.

Confirm the materials that make the subject recognizable before layout:

| Need | Required when | Accept |
|---|---|---|
| Logo | Any branded document | User file or official SVG/PNG |
| Product image | Physical product / venue / object | Official image, user image, or marked gap |
| UI screenshot | App / SaaS / website / tool | Current screenshot, official product image, or user capture |
| Brand colors | Branded one-pager / portfolio / deck | Official value, extracted asset value, or keep kami ink-blue |
| Fonts | Only if brand typography matters | Official font, close system fallback, or kami default |

If a required item is missing, use a compact gap table and ask once. Do not replace missing material with generic imagery, approximate logo drawings, or invented values.

### Materials status block

After the material check, output a structured status block before continuing. This is a one-shot transparency display, not a question:

```
Materials status:
- Logo: OK assets/client-logo.svg
- Brand colors: OK #1B365D mapped to --brand
- Product screenshot: MISSING (proceeding with kami default placeholder)
- UI screenshot: not required for this doc type
```

Use `OK`, `MISSING`, or `not required`. If a required item is missing and no user input arrived, ask once with the gap table; otherwise continue silently.

## Step 2.5 · Distill raw content (if applicable)

**Auto-detect whether to distill.** Do not ask the user; judge from the input:

| Skip distill (fill directly) | Run distill |
|---|---|
| Content has explicit section labels matching template structure | Raw prose without section structure |
| Metrics already quantified with units in place | Numbers scattered or implied, not extracted |
| User wrote "use this as-is" / "このまま使って" / "そのまま" | User pasted multi-source dump (chat / email thread / multiple docs) |
| Content count matches template (e.g. 4 metrics for 4 metric cards) | Content count mismatches template (too many or too few items) |
| One coherent voice with consistent claims | Conflicting claims or duplicate facts across sources |

When in doubt, run distill. Distill is cheap; rebuilding a misaligned doc is not.

When the user hands over **raw material** (meeting notes, brain dump, existing doc in different format, chat transcript, scattered points):

1. **Extract**: pull out every factual claim, number, date, name, source, material reference, and action item
2. **Classify**: map each extract to the target template's sections (see `references/writing.md` for section structure per doc type)
3. **Gap-check**: list what the template needs but the raw content doesn't have - include missing facts, missing proof, and missing materials
4. **Ask once**: share the gap table with the user. Do not guess to fill gaps.

Example gap-check:

| Template needs | Found | Missing |
|---|---|---|
| 4 metric cards | "8 years", "50-person team" | 2 more quantifiable results |
| 3-5 core projects | 2 mentioned | at least 1 more with outcome |
| Materials | logo file provided | product screenshot source |

Then proceed to Step 2.6 (slides) or the layout note (all other doc types) with structured, distilled content.

## Step 2.6 · Deck pre-flight (slides only)

Skip this step for every doc type except slides.

### Path selection

Default to the WeasyPrint HTML path. Switch to pptx only if the user explicitly requires an editable PPTX file.

| Path | Template | When |
|---|---|---|
| WeasyPrint HTML → PDF (default) | `slides-weasy-en.html` | All cases unless PPTX is required |
| python-pptx → PPTX (fallback) | `slides-en.py` | User explicitly requires editable PPTX |

### Page size

Default is `280mm 158mm`. Ask only if the user has mentioned length or density constraints.

| Size | When |
|---|---|
| `280mm 158mm` | Default; fits most decks |
| `297mm 167mm` | User wants a bit more room |
| `338mm 190mm` | Heavy content slide or many data points per page |

### Content pre-flight

Before drafting any slide, confirm these points with the user. Ask all at once, skip any already answered:

| # | Question |
|---|---|
| 1 | **Audience + venue** - who is in the room, and is it live keynote, investor 1:1, or async share link? |
| 2 | **Length target** - presentation time or slide count? (15 min: ~10 slides / 30 min: ~20 slides / 45 min: ~25-30 slides) |
| 3 | **Source material** - what content is already ready: outline, doc, notes, data? |
| 4 | **Images** - are screenshots, charts, logos, or product images available, or are gaps expected? |
| 5 | **Hard constraints** - brand colors, required logo, PPTX required, any slides that must exist? |
| 6 | **Format confirmation** - slides deck, or a one-pager that looks like a deck? |

### Content rules for slides

- No section divider slides: use `.eyebrow` for section numbering, not a dedicated blue-background page
- No full-width parentheses: replace `（...）` with `·` or `,`
- Each bullet fits one line: trim until it does
- 2×2 layouts: use `table.t2x2`, not CSS Grid
- Pinned conclusions: use `.co` at `position: absolute; bottom: 12mm`

## Step 2.7 · Layout note (transparent, non-blocking)

Before loading specs and filling the template, write a short editor-style note stating the layout intent: template choice, length target, narrative arc, embedded diagrams, material status, and output formats. Write it in Japanese to match the deliverable. Keep it under 80 words (200 文字目安), written as prose, not a status panel. Continue immediately after; do not wait.

Example (JA):

> レイアウト方針：Equity Report 日本語版、A4 2 ページ。冒頭で論点と目標株価を提示し、バリュエーション (DCF と類似企業比較) に進み、カタリストとリスクで締める。中段に売上推移の折れ線と FY26 売上ブリッジのウォーターフォールを配置。ロゴは確保済み、製品画像は未入手のためヘッダーはテキストのみ。出力は HTML と PDF。

The note is for transparency, not approval. If the user pushes back, adjust; otherwise proceed to Step 3.

---

## Step 3 · Load the right amount of spec

Pick the tier that matches the task. Default to the lowest tier that covers the work.

| Tier | When | Read |
|---|---|---|
| **Content-only** | Updating text, swapping bullets, translating an existing doc. CSS stays untouched. | `CHEATSHEET.md` only |
| **Layout tweak** | Adjusting spacing, moving sections, changing font size within spec. CSS touched. | `CHEATSHEET.md` + template (tokens already inline) |
| **New document** | Building from scratch or from raw content. | Full design spec + writing spec + template |
| **Resume content** | Resume-specific bullet structure, project framing, scope-result-outcome rules. | `resume-writing.md` + template |
| **Sources / materials** | Company, product, market, launch, funding, specs, or branded subject. | `writing.md` source rules + user/source material |
| **Deck (>20 slides)** | Long presentation needing Part Divider, Code Cards, section headers. | Full design spec + Deck Recipe (design.md section 8) |
| **Troubleshoot** | Rendering bug, font issue, page overflow. | `production.md` (+ design spec if CSS is the cause) |
| **Anti-patterns** | Reviewing AI-generated drafts before shipping. | `anti-patterns.md` (six-category checklist) |
| **Diagram** | Embedding SVG in a doc. | `diagrams.md` only (has its own token map) |

You can always escalate mid-task if the work turns out to need more than the initial tier.

The full spec files for reference:
- Design: `references/design.md`
- Writing (general): `references/writing.md`
- Writing (resume-specific): `references/resume-writing.md`
- Production: `references/production.md`
- Diagrams: `references/diagrams.md`
- Anti-patterns: `references/anti-patterns.md`

## Step 4 · Fill content into the template

- Copy the template into your working directory; don't write HTML from scratch
- **CSS stays untouched**, only edit the body
- Content follows `writing.md`: data over adjectives, distinctive phrasing over industry clichés
- Avoid patterns listed in `references/anti-patterns.md`: emptiness, fabrication, mimicry, excess, source gaps, tone contamination
- **Before filling, read the quality bar for your document type** in `writing.md` section "Quality bars by document type". Structure is necessary but not sufficient: a resume bullet needs Action + Scope + Result + Business Outcome; an equity report needs variant perception + quantified catalysts; slides need assertion-evidence titles. Meeting the quality bar is as important as filling every placeholder.

### Do not generate

These are the most common AI document failures. Cross-reference `references/anti-patterns.md` for the full list.

- Do not leave placeholder text in the final document ("Lorem ipsum", "[Insert here]", "TBD")
- Do not invent metrics, financial data, or statistics; mark gaps with `[DATA NEEDED: description]`
- Do not use stock-image descriptions as image placeholders ("A diverse team collaborating in a modern office")
- Do not pad content to fill template slots (a resume with 3 real projects does not need 5 fabricated ones)
- Do not write a paragraph that merely restates its own heading in sentence form

### Fill PDF metadata (WeasyPrint reads these into the PDF)

Every template has meta placeholders in `<head>`. Fill all four before building:

| Placeholder | Rule |
|---|---|
| `{{AUTHOR}}` | Resume/letter/portfolio: use the person's name from the doc. All others: leave as-is (build script infers from git config or env) |
| `{{DESCRIPTION}}` | Extract one sentence (≤150 chars) from the first 2 paragraphs |
| `{{KEYWORDS}}` | 3-5 keywords from the title + section headings, comma-separated |
| `{{DOC_TITLE}}` / `{{LETTER_SUBJECT}}` etc. | Infer from the H1 or `.header .title` text |

`<meta name="generator" content="Kami">` is already fixed in the template; do not change it.

**Author inference**: `build.py` automatically sets PDF `/Author` metadata from:
1. `git config user.name` (primary)
2. `KAMI_AUTHOR` environment variable (fallback)
3. `"Kami"` (final fallback)

For personal documents (resume/letter/portfolio), the HTML `<meta name="author">` should match the person's name in the content. For non-personal documents (one-pager/long-doc), leave the placeholder as-is and let the build script infer it.

## Step 4.1 · Per-page density target (multi-page templates only)

対象：slides-weasy / long-doc / portfolio / equity-report / changelog。対象外は resume / one-pager / letter (これらは独立した長さの契約を持つ)。

本文ページの充填率目標は 60-80%。表紙 / 目次 / 末尾の署名ページは免除。このルールは、AI が複数ページ文書を生成するときに最も多い draft 欠陥、つまり内容を細かく分けすぎて各ページがスカスカになる問題に対処する。

### Items-per-page contract

| Template | Typical body page | Hard floor (merge if below) |
|---|---|---|
| slides-weasy | 1 assertion title + 3-5 supporting items, or 1 chart + 2-3 callouts | <3 items and no chart → merge into adjacent slide |
| long-doc | 1 chapter heading + 2-4 paragraphs + at most 1 figure | Chapter renders to <40% page → merge into neighbor chapter |
| portfolio | 1 project header + 1 hero image + 3-5 outcome bullets | No image and <3 outcomes → merge with adjacent project |
| equity-report | 1 section + 1 table/chart + supporting prose | Only a 2-row table on the page → combine sections |
| changelog | 1 version block + 4-8 entries | Version has <4 entries → place on the same page as the prior version |

### Sparse-page merge rule

Before finalizing, scan the draft. Any body page that would render under 50% full → apply one of, in order:

1. Merge upward into the previous section.
2. Merge downward into the next section.
3. Promote a list to a small diagram or table that earns the space.
4. Pin a `.co` callout to bottom (slides-weasy only). Whitespace above a pinned callout is intentional, not sparse.

Forbidden ways to "fill" a sparse page: padding with filler prose, repeating the heading as a sentence, inventing statistics, restating the prior page in different words. If the merge options don't apply, the page itself shouldn't exist.

### Last-page exemption

The last body page is allowed to run 40-60% fill. Forcing balance on the last page usually means padding. The colophon / closing slide may have any fill level.

### Verify after build

```bash
python3 scripts/build.py --check-density   # flags >25% (WARN) / >50% (SPARSE) trailing whitespace
```

If a body page (not cover, not last page) gets a SPARSE warning, treat it as a draft defect and re-author with the merge rule.

## Step 4.5 · Auto-select output format

Do not ask the user which format to export. Decide from context:

| Signal | Output | Why |
|---|---|---|
| Any document request | HTML + PDF | PDF is the default deliverable, HTML is the source |
| Slides / PPT / deck | HTML + PDF + PPTX | Presentations need a projectable format |
| "共有して" / "シェア" / "share" / "post" / "preview" | + PNG | Social platforms and messaging need images |
| "埋め込み" / "差し込み" / "embed in another doc" | PNG only | Used as material inside other documents |
| User explicitly says a format | Follow the user | Explicit request overrides auto-selection |

PDF always ships for document templates. Landing pages ship as a ready-to-serve static HTML file. PPTX follows slides. PNG follows sharing context. The user should never need to think about formats.

## Step 5 · Build & verify

```bash
python3 scripts/build.py --verify           # build all templates + page count + font check + slides
python3 scripts/build.py --verify resume-en # single target full verification
python3 scripts/build.py landing-page        # screen-first static HTML template check
python3 scripts/build.py --verify slides    # single slide deck verification
python3 scripts/build.py --check-placeholders path/to/filled.html
python3 scripts/build.py --check-density              # page whitespace scanner (skips cover)
python3 scripts/build.py --check            # CSS rule violations only (fast, no build)
```

Source templates intentionally keep `{{...}}` fields. Run placeholder checks on completed documents, not on the template library.

Visual anomalies (tag double rectangle, font fallback, page break issues) -> `production.md` Part 4.

## Fonts

The design is sans-serif (gothic) led, Japanese-only. The CSS variables `--serif` and `--sans` are kept as names but both alias the gothic stack (`--sans: var(--serif)`); do not rename the variables.

**Bundled (embedded in PDF)**
- Noto Sans JP (Google Fonts, OFL), woff2, two weights: Regular (400) + Medium (500)
- Files: `assets/fonts/NotoSansJP-Regular.woff2` and `assets/fonts/NotoSansJP-Medium.woff2`; license at `assets/fonts/NotoSansJP-OFL.txt`
- A single typeface carries the whole Japanese document — body and headings alike
- Templates declare dual @font-face: Regular for body text, Medium for headings / emphasis. No Black / Bold / Light — Medium is the only heavier weight, for restraint over synthetic bold
- These are bundled in the Claude Desktop skill ZIP and embedded into the PDF, so Japanese renders identically everywhere

**Font stack**
- Stack: `"Noto Sans JP", "Hiragino Sans", "Yu Gothic", YuGothic, "Helvetica Neue", Arial, sans-serif`
- Noto Sans JP (bundled) leads; Hiragino Sans / Yu Gothic are macOS system fonts for local preview; Helvetica Neue / Arial are the final fallback

**Mono**
- Stack: `"JetBrains Mono", "Fira Code", "SF Mono", Consolas, Monaco, "Noto Sans JP", "Hiragino Sans", monospace`
- Noto Sans JP / Hiragino Sans provide the Japanese fallback for code blocks containing Japanese

Font files next to HTML with relative `@font-face` paths is the most stable setup. `scripts/package-skill.sh` bundles the Noto Sans JP woff2 files (Regular + Medium) into the Claude Desktop ZIP.

**Font auto-recovery (Claude Desktop)**

Before building, ensure the bundled fonts are present. If the woff2 files are missing or truncated, the script restores them:

```bash
bash scripts/ensure-fonts.sh
```

`ensure-fonts.sh` fetches the variable font from the Google Fonts source (`google/fonts` `ofl/notosansjp`), instances the `wght` 400 and 500 weights, converts them to woff2 (unifying the name-table family to `Noto Sans JP`), and writes them back into `assets/fonts/`. Run once before building.

## Feedback protocol

When the user gives **vague visual feedback** ("looks off", "詰まってる", "not elegant"), do not guess. Ask back with current values:

| User says | Ask about |
|---|---|
| "詰まってる" / "too cramped" | Which element? Line-height (current: X)? Padding (current: Y)? Page margin? |
| "間延びしてる" / "too loose" | Same direction, reversed |
| "色が違う" / "color feels wrong" | Which element? Brand blue overused? A gray reading too cool? |
| "イマイチ" / "not polished" | Font rendering? Alignment? Whitespace distribution? Hierarchy unclear? |
| "プロっぽくない" / "unprofessional" | Content wording? Or layout (alignment, consistency)? |

Template response: "X is currently set to Y. Would you like (a) [specific alternative within spec] or (b) [another option]?"

Never say "I'll adjust the spacing" without naming the exact property and its new value.

---

## When not to use this skill

- User explicitly wants Material / Fluent / Tailwind default - different design language
- Need dark / cyberpunk / futurist aesthetic (this is deliberately anti-future)
- Need saturated multi-color (this has one accent)
- Need cartoon / animation / illustration style (this is editorial)
- Web dynamic app UI (this is for print / static documents)

---

Next: **apply Step 3's tier table to decide what to read**, then copy the matching template and start filling.
