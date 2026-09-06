# V2 validation and acceptance

Paths in commands are relative to `SKILL_DIR` (the installed hatch-pet directory), not this reference directory. Set `RUN_DIR` to the task-owned run folder; reuse the Python executable selected in the entrypoint. Read only the stage needed for the current task.

For validation-only requests, inspect the existing files and run the relevant checks without generating or installing a pet. A required check that cannot run is unverified, not a pass. Existing valid evidence can be reused if its input atlas and relevant dependencies are unchanged.

Read the run's selected chroma key before any validation or post-assembly command, including a standalone validation request:

```bash
CHROMA_KEY=$(jq -r '.chroma_key.hex' "$RUN_DIR/pet_request.json")
```

### Direction Acceptance Policy

Judge the completed 16-pose loop as an animation family. Cardinals must match their single axis exactly. Intermediate directions should preserve the intended axes, but isolated blind-review uncertainty is evidence for labeled loop review rather than an automatic regeneration trigger.

Hard failures require row regeneration:

- a cardinal anchor is wrong or ambiguous: `000` up, `090` screen-right, `180` down, or `270` screen-left
- a blind cardinal classification contradicts or cannot confirm `000` up, `090` screen-right, `180` down, or `270` screen-left
- labeled normal-size review confirms that an intermediate pose points into the wrong principal quadrant, reverses the loop, or loses a required axis badly enough to read as a different direction
- the ordered loop visibly reverses, backtracks, crosses into the wrong principal quadrant, or contains a conspicuous snap, identity change, scale pop, registration jump, or broken prop attachment
- the source or atlas has a deterministic structural failure, or visual review confirms clipping, an accidental transparent interior hole, a seam band, replacement eyes, or a materially broken sprite
- whole-sprite rotation, deformation, or eye mechanics visibly break the pet's identity or make the motion feel incoherent

Review warnings do not require regeneration by themselves:

- an intermediate pose is similar to a neighbor, a diagonal cue is subtle, or the pet uses less body movement than the ideal mechanics plan
- blind reviewers disagree, return `ambiguous`, or produce an opposite-sign majority for an intermediate direction, provided labeled normal-size review confirms the intended direction and the ordered loop remains coherent
- continuity metrics report a diff, center, area, or alpha-hole candidate without a visible snap, pop, seam, or broken silhouette in the QA sheet or animation loop

Before accepting the v2 atlas, create a focused direction QA sheet showing the neutral/rest frame next to all 16 look cells, labeled by degree and expected direction, at approximately the in-app display size. Run the adjacent continuity measurement separately and treat its findings as motion-review evidence, not automatic direction failures.

Perform an explicit semantic review for every direction and record `pass`, `warning`, or `fail`, plus separate visible evidence for its horizontal and vertical axes. A warning may accept blind-review uncertainty for an intermediate pose when labeled normal-size review confirms the intended axes and the ordered loop remains coherent. It may not waive a wrong or ambiguous cardinal, a labeled wrong-quadrant pose, or a visible reversal. If a direction receives `fail`, strengthen the containing row's instructions and resynthesize that complete coherent row. Never replace the final normalized cell directly.

Run the single deterministic edge-local spill-suppression pass on the assembled v2 atlas, then validate and make a contact sheet:

```bash
"$PYTHON" "$SKILL_DIR/scripts/despill_chroma_edges.py" \
  "$RUN_DIR/final/spritesheet-extended.png" \
  --output "$RUN_DIR/final/spritesheet-extended.png" \
  --webp-output "$RUN_DIR/final/spritesheet-extended.webp" \
  --chroma-key "$CHROMA_KEY" \
  --json-out "$RUN_DIR/qa/chroma-despill-extended.json"
```

Treat `qa/chroma-despill-extended.json` as the authoritative chroma result. When it has `ok: true` and `validate_atlas.py --require-v2` passes, do not fail visual QA for perceived magenta fringe, regenerate any row, rerun despill, tune thresholds, or create an additional chroma-repair script. If either deterministic check fails, stop with a pipeline failure instead of retrying image generation.

This is the only chroma-cleanup invocation in the workflow. The intermediate 8×9 atlas is never despilled; rows `0-8` and the newly assembled look rows `9-10` are cleaned together exactly once in the completed 8×11 atlas.

```bash
"$PYTHON" "$SKILL_DIR/scripts/validate_atlas.py" \
  "$RUN_DIR/final/spritesheet-extended.webp" \
  --json-out "$RUN_DIR/final/validation-extended.json" \
  --chroma-key "$CHROMA_KEY" \
  --require-v2
```

```bash
"$PYTHON" "$SKILL_DIR/scripts/make_contact_sheet.py" \
  "$RUN_DIR/final/spritesheet-extended.webp" \
  --output "$RUN_DIR/qa/contact-sheet-extended.png"
```

Create the focused direction QA sheet:

```bash
"$PYTHON" "$SKILL_DIR/scripts/make_direction_qa_sheet.py" \
  "$RUN_DIR/final/spritesheet-extended.webp" \
  --output "$RUN_DIR/qa/look-directions.png"
```

Create the blind horizontal-and-vertical axis challenge and keep its answer key away from the visual QA worker:

```bash
"$PYTHON" "$SKILL_DIR/scripts/make_direction_blind_qa_sheet.py" \
  "$RUN_DIR/final/spritesheet-extended.webp" \
  --output "$RUN_DIR/qa/direction-blind-pairs.png" \
  --answer-key "$RUN_DIR/qa/direction-blind-answer-key.json"
```

Use the blind-review handoff in [workers.md](workers.md). Give three fresh isolated workers only `qa/direction-blind-pairs.png`. Each row states whether to classify the horizontal or vertical axis. Every worker must classify A and B as `screen-left`, `screen-right`, `up`, `down`, or `ambiguous` as appropriate, without seeing degree labels, expected directions, the labeled direction sheet, the answer key, or another worker's verdicts. Write their classifications separately, then combine them by strict per-cell majority:

```bash
"$PYTHON" "$SKILL_DIR/scripts/combine_direction_blind_verdicts.py" \
  --verdicts "$RUN_DIR/qa/direction-blind-verdicts-1.json" \
  --verdicts "$RUN_DIR/qa/direction-blind-verdicts-2.json" \
  --verdicts "$RUN_DIR/qa/direction-blind-verdicts-3.json" \
  --json-out "$RUN_DIR/qa/direction-blind-verdicts.json"
```

Apply the hidden answer key only to the consensus verdict:

```bash
"$PYTHON" "$SKILL_DIR/scripts/validate_direction_blind_verdicts.py" \
  --answer-key "$RUN_DIR/qa/direction-blind-answer-key.json" \
  --verdicts "$RUN_DIR/qa/direction-blind-verdicts.json" \
  --json-out "$RUN_DIR/qa/direction-blind-validation.json"
```

The hidden answer key contains seven horizontal pairs and seven vertical pairs. The cardinal pairs (`000` vs `180` and `090` vs `270`) are hard gates: a mismatch or ambiguous majority keeps validation at `ok: false`. All intermediate pairs are review gates: mismatches, same-direction votes, and ambiguous majorities are preserved as warnings while validation remains `ok: true`. The blind pass is mandatory, but intermediate warnings are resolved by labeled normal-size loop review instead of repeated regeneration by default.

### Blind Review Severity Resolution

After receiving a blind or final visual QA `pass`/`fail` result:

1. If it passes, continue immediately.
2. If it fails, inspect the worker's semantic reasons, repair note, labeled direction sheet, `qa/direction-semantics.json`, and `qa/look-continuity.json` before regenerating anything.
3. Classify the failure as `major` or `minor`:
   - `major`: wrong or ambiguous cardinal; labeled normal-size review confirms a wrong principal quadrant or visible reversal; conspicuous snap, scale pop, identity change, broken attachment, clipping, interior seam/hole, or deterministic validation failure.
   - `minor`: exact pupil or nose placement differs from the numerical ideal; a near-vertical horizontal cue is subtle; isolated reviewers disagree or return `ambiguous`; an intermediate blind majority conflicts but the labeled ordered loop still reads correctly; continuity metrics warn without a visible defect.
4. Major failures require repair. Minor failures may be overridden and the installation pipeline continues.
5. Record every override in `qa/blind-review-resolution.json` with `decision: "accept"`, `severity: "minor"`, the failed checks, the labeled/continuity evidence that makes them acceptable, and `reviewed_by: "parent"` or `"user"`. Never override a major failure.

An override is a deliberate visual judgment, not a way to silence missing evidence. The blind sheet, consensus verdicts, validation output, labeled semantics, continuity report, and resolution file all remain in the final QA artifacts.

Measure adjacent direction continuity:

```bash
"$PYTHON" "$SKILL_DIR/scripts/measure_direction_continuity.py" \
  "$RUN_DIR/final/spritesheet-extended.webp" \
  --json-out "$RUN_DIR/qa/look-continuity.json"
```

Visually QA `qa/contact-sheet-extended.png`, `qa/look-directions.png`, and `qa/look-continuity.json` before accepting. Inspect the 16 normal-size look cells as an ordered loop, not only as isolated stills. For every direction label, compare the expected direction to the visible gaze/body direction and record `pass`, `warning`, or `fail` in `qa/direction-semantics.json`. Reject only the hard failures in the Direction Acceptance Policy. Record subtler semantic or metric concerns as warnings and accept them when the loop remains cohesive, readable, identity-preserving, and visually pleasing at normal pet size.

If a blind or final visual QA worker returns `fail`, apply Blind Review Severity Resolution before queuing a repair. Continue packaging when the failure is minor and `qa/blind-review-resolution.json` records the accepted override.

## Acceptance Criteria

- Final atlas is PNG or WebP, exactly `1536x2288`, and based on `192x208` cells. The `1536x1872` standard atlas is intermediate-only.
- `pet.json` contains `spriteVersionNumber: 2`, the extended despill report has `ok: true`, and the packaged spritesheet passes `validate_atlas.py --require-v2` with the run's chroma key. These deterministic results close chroma QA; no separate visual chroma-fringe gate or image retry is allowed.
- Used cells are non-empty and unused cells are fully transparent.
- Atlas follows the row/frame counts in [animation-rows.md](animation-rows.md).
- The four-cardinal strip has been deterministically extracted, its clipping report passes, and all four anchors are semantically approved before look-row generation.
- Both coherent look rows use `decoded/look-anchors-approved.png` as the direction basis, interpolate all intermediate directions as even 22.5-degree steps, and preserve the fixed clockwise order.
- Deterministic pose-group registration, post-registration final-cell edge diagnostics, and labeled per-direction semantic QA pass immediately on each coherent source row before final atlas assembly; blind horizontal-and-vertical axis QA runs after both rows exist.
- Contact sheet and per-row motion previews have been produced and inspected by a lightweight visual QA worker.
- A focused neutral-plus-16-directions QA sheet has been produced and inspected before packaging.
- A randomized unlabeled horizontal-and-vertical axis pair sheet has been classified by three isolated blind workers and combined by strict majority. Both cardinal pairs pass. `qa/direction-blind-validation.json` has `ok: true`, or a worker-level/intermediate failure has an accepted minor resolution in `qa/blind-review-resolution.json` backed by labeled and continuity evidence.
- Every expected direction has an explicit `pass`, `warning`, or `fail` semantic verdict with horizontal and vertical axis evidence where applicable; no wrong cardinal, labeled wrong-quadrant pose, or visible reversal remains.
- `qa/direction-semantics.json` records verdicts for all 16 directions from an independent visual QA worker or explicit user inspection, including review notes for accepted warnings.
- `qa/look-continuity.json` has been reviewed; metric warnings are acceptable when the normal-size ordered loop has no visible snap, pop, identity change, or semantic discontinuity.
- `qa/review.json` has no errors.
- Row-by-row review confirms the animation cycles are complete enough for the Codex app.
- Motion previews do not show unintended size popping, reversed directional cadence, or wrong row semantics.
- Look directions follow the fixed clockwise order and form a cohesive, readable loop at normal pet size. Cardinals must be unmistakable. Intermediate blind uncertainty is acceptable as a reviewed warning when labeled normal-size review confirms the intended direction and the loop does not reverse.
- Non-pixel styles are accepted when readable at pet size and consistent across rows.
- `${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/pet.json` and `${CODEX_HOME:-$HOME/.codex}/pets/<pet-name>/spritesheet.webp` are staged together for custom pets.

When required checks pass and minor warnings have evidence-backed resolutions, continue directly to [packaging.md](packaging.md) if packaging/install is requested.
