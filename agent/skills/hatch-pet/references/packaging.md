# Package and retain evidence

Paths in commands are relative to `SKILL_DIR` (the installed hatch-pet directory), not this reference directory. Set `RUN_DIR` to the task-owned run folder; reuse the Python executable selected in the entrypoint. Read only the stage needed for the current task.

Read [codex-pet-contract.md](codex-pet-contract.md) for the manifest contract. Packaging/install proceeds when authorized by the request; validation-only work does not write into the custom-pet directory. Preserve an unrelated existing pet.

After required deterministic and visual checks pass and any minor warnings are resolved with evidence, package the approved extended spritesheet as a v2 pet. `spriteVersionNumber: 2` is mandatory; without it the app defaults to the 9-row v1 contract and rejects the 2288-pixel-tall asset.

```bash
PET_ID=$(jq -r '.pet_id' "$RUN_DIR/pet_request.json")
DISPLAY_NAME=$(jq -r '.display_name' "$RUN_DIR/pet_request.json")
DESCRIPTION=$(jq -r '.description' "$RUN_DIR/pet_request.json")
PET_DIR="${CODEX_HOME:-$HOME/.codex}/pets/$PET_ID"
# For export-only requests, set PET_DIR to the requested output directory instead.
mkdir -p "$PET_DIR"
cp "$RUN_DIR/final/spritesheet-extended.webp" "$PET_DIR/spritesheet.webp"
jq -n --arg id "$PET_ID" --arg displayName "$DISPLAY_NAME" --arg description "$DESCRIPTION" \
  '{id: $id, displayName: $displayName, description: $description, spriteVersionNumber: 2, spritesheetPath: "spritesheet.webp"}' \
  > "$PET_DIR/pet.json"
```

Write `qa/run-summary.json` after packaging:

```bash
jq -n --arg run_dir "$RUN_DIR" --arg spritesheet "$RUN_DIR/final/spritesheet-extended.webp" --arg validation "$RUN_DIR/final/validation-extended.json" --arg chroma_despill "$RUN_DIR/qa/chroma-despill-extended.json" --arg contact_sheet "$RUN_DIR/qa/contact-sheet-extended.png" --arg direction_sheet "$RUN_DIR/qa/look-directions.png" --arg direction_semantics "$RUN_DIR/qa/direction-semantics.json" --arg blind_direction_validation "$RUN_DIR/qa/direction-blind-validation.json" --arg blind_review_resolution "$RUN_DIR/qa/blind-review-resolution.json" --arg continuity "$RUN_DIR/qa/look-continuity.json" --arg review "$RUN_DIR/qa/review.json" --arg package "$PET_DIR" '{ok: true, spriteVersionNumber: 2, run_dir: $run_dir, spritesheet: $spritesheet, validation: $validation, chroma_despill: $chroma_despill, contact_sheet: $contact_sheet, direction_sheet: $direction_sheet, direction_semantics: $direction_semantics, blind_direction_validation: $blind_direction_validation, blind_review_resolution: $blind_review_resolution, continuity: $continuity, review: $review, package: $package}' > "$RUN_DIR/qa/run-summary.json"
```

After all QA and packaging succeed, keep `pet_request.json`, `imagegen-jobs.json`, `final/spritesheet-extended.webp`, `final/validation-extended.json`, `qa/chroma-despill-extended.json`, `qa/contact-sheet-extended.png`, `qa/look-directions.png`, `qa/direction-semantics.json`, `qa/direction-blind-pairs.png`, `qa/direction-blind-answer-key.json`, `qa/direction-blind-verdicts.json`, `qa/direction-blind-validation.json`, `qa/blind-review-resolution.json` when an override was used, `qa/look-continuity.json`, `qa/previews/`, `qa/review.json`, and `qa/run-summary.json`. Remove prompts, layout guides, generated row strips, extracted frames, PNG intermediates, the 8x9 intermediate atlas, unless the user wants debug artifacts. Delete only run-owned intermediates after verifying the retained package. Preserve user source images.
