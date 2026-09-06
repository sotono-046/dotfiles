# Repair or upgrade an existing pet

Inspect the supplied atlas, manifest and existing QA before choosing a repair. Preserve supplied art and standard rows that already pass. A valid 8x9 input can become the standard-row intermediate of a v2 upgrade; an existing 8x11 input does not need fresh base art or brand discovery.

- A deterministic extraction, registration, chroma or packaging fault: repair the pipeline/configuration first. Do not regenerate correct art to compensate for processing faults.
- A standard-row visual failure: read the affected state in [animation-rows.md](animation-rows.md) and the relevant operation in [generation.md](generation.md); regenerate only that row.
- A look-direction visual failure: read [look-directions.md](look-directions.md) and [validation.md](validation.md); regenerate the complete containing coherent eight-frame row. Never paste a newly generated repair cell into a final row. An individual cardinal anchor may be repaired before the final rows are synthesized.
- An already approved coherent 16-cell user source may use the documented individual-cell assembly input. That exception does not permit mixing newly generated one-off repair cells.
- A missing/wrong manifest version or export request: use [packaging.md](packaging.md) after validating the unchanged atlas; no generation is needed.

Copy a selected replacement into the same decoded job path, run the relevant incremental checks, then update its `source_path`, completion timestamp and status. Keep failed or in-progress replacements ineligible for packaging. Rebuild and revalidate affected descendants; if repaired row 9 changes registration or continuity, row 10 must be checked against it again.

Classify repeat failures by concrete evidence. Change extraction method or the row/cardinal strategy when the same fault repeats; do not alternate prompts without changing the cause. Elapsed-time targets guide scope and optional polish, not silent abandonment or weaker acceptance.

After a look repair, obtain independent visual direction evidence using [workers.md](workers.md) and the validation policy. Do not have the repairing agent certify its own blind review. Minor intermediate uncertainty may be accepted with labeled-loop evidence; wrong/ambiguous cardinals, wrong quadrants, reversals, clipping, identity drift and alpha holes remain blockers. If independent evidence is unavailable, report that specific check as unverified and continue any independent authorized work.
