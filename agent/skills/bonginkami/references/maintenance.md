# Kami source maintenance and releases

Read only when changing Kami's templates, renderer, assets, public site or release package. Ordinary document creation follows SKILL.md. Commands and paths are relative to the skill root.

## Source map and invariants

- `assets/templates/`: copied self-contained document HTML and slide generators. Keep inline CSS; do not introduce a shared build-time partial.
- `references/design.md`, `writing.md`, `production.md`, `diagrams.md`: design, writing and rendering details. Shared style changes update the governing spec and affected template tokens together.
- `references/tokens.json`: canonical tokens; `stabilizer_profiles.json`: target-specific stabilization; `checks_thresholds.json`: PDF density/rhythm/orphan thresholds. `cool_gray_buckets.json` contains normalization buckets.
- `scripts/shared.py`: canonical `HTML_TEMPLATES` registry used by build and stabilize. Add/remove targets there rather than duplicating registries.
- `scripts/build.py`: command routing; `verify.py`: rendered page/font checks; `lint.py`: CSS checks; `tokens.py`: token consistency; `checks.py`: placeholders/rhythm/density/orphans; `optional_deps.py`: dependency hints.
- `scripts/stabilize.py`: normalize HTML and solve overflow only for targets whose registry `stabilize_max_pages > 0`. Do not force slides-weasy, equity-report, changelog or landing-page through this solver.
- `assets/fonts/`: bundled Noto Sans JP 400/500 with OFL license. Preserve `--serif`/`--sans` alias names. Repair missing/truncated fonts with `scripts/ensure-fonts.sh` only when needed.
- `assets/demos/`: example renders. `assets/showcase/`: README/public-site screenshots excluded from the release ZIP.
- `scripts/package-skill.sh`: release package from `git ls-files`; `dist/bonginkami.zip`: tracked release artifact.

Keep personal profiles and credentials out of examples/packages. Do not add large commercial fonts or public-site-only showcase screenshots to the ZIP. Prefer an existing template/helper; a new module must solve the current requirement and be included in the release package when released.

## Select validation by the change

| Change | Checks |
|---|---|
| Instructions or reference prose only | Frontmatter, relative links, routing consistency; no image generation, full template build or ZIP refresh required for a source-only update |
| Template/CSS/shared token changes | `python3 scripts/build.py --check` plus render/verify affected targets; inspect affected pages |
| Renderer/shared build logic | `python3 scripts/tests/test_build.py` and affected render paths; broaden when the shared behavior warrants it |
| Stabilizer | `python3 scripts/stabilize.py all --report` or the affected target; inspect generated results |
| Deck rhythm | Affected render and `python3 scripts/build.py --check-rhythm slides slides-en` |
| Public positioning/install docs | Related index, README, llms.txt, robots.txt, sitemap and JSON-LD/FAQ links |
| Package/release | Package checks below, then inspect contents |

If only host dependencies are missing, report the unavailable check rather than calling it a code regression. Use the configured runtime or an isolated environment when authorized; do not change global dependencies just to satisfy a document edit.

CI render tests require weasyprint/pypdf/PyMuPDF in the job. A green lighter job with skipped render tests is not render evidence. Validate changed workflows in their relevant CI run when publishing the change. Keep environment exceptions explicit and narrow; `KAMI_ALLOW_FALLBACK_ONLY=1` is for missing primary fonts, not general error suppression.

## Fragile rendering cases

Use [production.md](production.md) Part 4 for diagnosis. Preserve the known constraints when changing related code:

- Use solid hex tag backgrounds; rgba layers or thin rounded borders can render double rectangles/rings.
- Font fallback, synthetic bold, line-height and margin changes can alter resume pagination. The default resume template has a two-page contract; a requested custom document length takes precedence.
- `break-inside` can fail in flex; use a block wrapper where needed. Use explicit mm geometry for PDF pages.
- WeasyPrint does not rotate SVG `marker orient="auto"` reliably; draw arrowheads explicitly.
- Keep section body text at the page width unless a narrower role is intentional.
- When changing diagram primitives, update affected public showcase copies; do not regenerate unrelated demos.

For demo updates, portrait previews are the first A4 page at 150 dpi (`1241x1754`). Slide demos combine the first two landscape pages at 867 px height each with a 20 px parchment gap, extended to `1241x1754`. These are showcase conventions, not every user document's output contract.

## Package and release boundary

A source-only instruction optimization is complete after its focused checks; it does not claim that an existing ZIP contains the new source. Refresh the ZIP when the task includes a release/package update or delivery through the Claude Desktop archive, not on every SKILL.md edit.

Before an authorized package/release handoff:

1. Ensure new modules, references and other package inputs are tracked: `package-skill.sh` uses `git ls-files`, so an untracked helper can work locally but vanish from the archive.
2. Run `bash scripts/package-skill.sh` and inspect `dist/bonginkami.zip` for changed inputs, required fonts/license, and excluded private/debug/showcase files.
3. Confirm the archive meets the current 12 MB ceiling. Commit it with the release changes when requested.
4. Publish/update the release asset only when authorized. The upstream asset is `bonginkan/design-bonginkami` Releases; no automatic upload from a local content edit. Create a new version tag only on an explicit versioned-release request.

Use release notes in the requested language. Keep stable maintenance rules here; do not commit one-off review snapshots or private diagnostic dumps.
