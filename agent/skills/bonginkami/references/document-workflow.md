# Kami document creation

Use for a new document or substantial content/layout revision. Commands and asset paths below are relative to the bonginkami skill root, not this reference directory. Existing narrow edits can use CHEATSHEET and the affected template directly.

## Output choices

The requested language, format, audience and length take precedence. Default to Japanese for this Japanese editorial style, but do not translate away an explicitly requested output language. The `-en` template suffix is a filename convention: set the copied HTML `lang` to the deliverable language.

Infer a suitable page budget from the purpose and actual content. Do not ask for a page count merely because it was omitted. Use the nearest template and adjust sections to the available material; never invent content to fill a fixed card or page count.

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


Templates live under `assets/templates/`. Landing pages are browser HTML and have no required PDF. Slides use [slides-workflow.md](slides-workflow.md). GitHub release notes are an external deliverable, not a request to generate a changelog PDF.

For ordinary documents with no format specified, produce PDF and retain the HTML source. Produce editable PPTX when requested; do not add PPTX to every PDF deck. An explicit HTML-only, PNG-only or other supported format request suppresses unrelated exports. Sharing language alone does not authorize publishing or contacting another person.

## Source and brand context

Use the supplied content and official sources for changeable company/product/date/metric claims. Record the sources and mark facts that remain unknown; a missing logo or screenshot does not by itself require stopping a usable text document. Omit optional imagery or disclose a material gap. Ask only when the missing fact or asset changes the requested result and cannot be resolved from authorized sources. Do not invent logos, data or source images.

If `~/.config/kami/brand.md` or legacy `~/.kami/brand.md` exists, use [brand-profile.md](brand-profile.md). Explicit prompt > editorial judgment > habit notes > profile defaults > built-in defaults. Do not copy private profile contents into this skill. Inspect another project's style only when the user names it as a reference; use its actual tokens without overriding current instructions.

For raw notes or multiple sources, extract the relevant facts and organize them around the document's purpose. Preserve content supplied “as-is”. Missing template slots are a layout decision, not a demand for more facts. Follow the relevant document-quality section of [writing.md](writing.md); use [resume-writing.md](resume-writing.md) for career bullets and outcomes.

## Layout

Copy the nearest template into the task workspace. Keep its existing inline CSS for content-only changes; for requested layout changes adjust the needed styles using [design.md](design.md) rather than introducing a new framework or shared CSS layer. Use [diagrams.md](diagrams.md) only when a chart or diagram explains the content better than prose/table, with primitives in `assets/diagrams/`.

For multipage work, avoid unnecessary empty pages and fragmented sections. Merge sparse material when it improves reading; density targets are editorial guidance, not reasons to add filler, invent statistics or remove a meaningful final page. Cover/closing pages may intentionally be sparse. A material overflow, unreadable text or missing content is a defect; a harmless density warning is not a release blocker.

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


## Build and inspect the requested output

Use the relevant path in [production.md](production.md) and the existing build helper. Do not build every sample template for one document. Source templates intentionally contain placeholders; check the completed document instead.

```bash
python3 scripts/build.py --verify resume-en
python3 scripts/build.py landing-page
python3 scripts/build.py --check-placeholders path/to/filled.html
python3 scripts/build.py --check-density path/to/doc.pdf
```

Inspect the rendered pages or browser view that changed and any affected pagination. Confirm requested text, language, output format, fonts, essential figures and metadata. Fix clipping, missing glyphs, incorrect facts and unreadable layout. Explain any remaining source or environment limitation; do not label an unrendered output visually verified.

For vague visual feedback, inspect the referenced output, identify the likely cause and make a scoped, reversible correction. Ask only if competing interpretations would materially change the result. Keep the user's existing style and content constraints.

## Fonts

The design is sans-serif (gothic) led, Japanese-first. The CSS variables `--serif` and `--sans` are kept as names but both alias the gothic stack (`--sans: var(--serif)`); do not rename the variables.

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

`ensure-fonts.sh` fetches the variable font from the Google Fonts source (`google/fonts` `ofl/notosansjp`), instances the `wght` 400 and 500 weights, converts them to woff2 (unifying the name-table family to `Noto Sans JP`), and writes them back into `assets/fonts/`. Run only when required bundled fonts are missing or damaged; do not add a network operation to ordinary content edits.
