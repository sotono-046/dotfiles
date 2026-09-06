# Kami slides

Use only for a slide deck in this editorial style. Paths are relative to the skill root.

## Choose the output

Honor the requested language and format. With no format specified, use `assets/templates/slides-weasy-en.html` for HTML-to-PDF. For an editable PPTX request, use `assets/templates/slides-en.py` and the current Presentations capability where appropriate. Do not automatically deliver both paths.

Infer audience, flow and reasonable length from the request and supplied material. Ask only about unresolved information that would change the deck substantially; do not require a six-question preflight or another format confirmation. Default PDF page size is `280mm 158mm`; use a user-specified size when provided.

## Template-specific rendering

Read the applicable slide guidance in [design.md](design.md), including the Deck Recipe for long decks. Let each slide communicate a clear point with supporting evidence; avoid empty divider slides or one-line bullets used as arbitrary hard limits. Preserve literal quotes, technical notation and the requested writing style.

For the WeasyPrint template, use `table.t2x2` for 2×2 layouts where CSS Grid is not supported. The template's pinned conclusion uses `.co` with `position: absolute; bottom: 12mm`; account for its space to avoid clipping. PDF pagination should use explicit millimeter geometry instead of `100vh`. Other output paths follow their own layout engine.

Use [document-workflow.md](document-workflow.md) for source handling and PDF metadata. Use [diagrams.md](diagrams.md) when embedding diagrams, and [production.md](production.md) for rendering problems. Do not read unrelated resume or brand procedures.

## Verification

Build the requested slide target and inspect the changed deck. Check content order, legibility, complete figures, text bounds and the requested file format. A density warning requires judgment, not automatic regeneration. Do not rebuild all document families for a single deck or force extra pages just to meet a template default.
