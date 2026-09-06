## Lightweight Visual Workers

Use lightweight subagents for image-heavy work by default. This bounds each `$imagegen` rollout to one selected image, keeps contact-sheet vision payloads out of the parent thread, and reduces cost while preserving the full v2 contract.

## Subagent Delegation

Use workers when the runtime supports them and delegation is authorized. Generation can run sequentially without workers; independent direction QA still requires isolated reviewers or explicit user inspection as described below. Do not invent unavailable agent/model APIs.

Parent responsibilities:

- run the brand discovery worker before preparation when the user provides a bare brand/product/company/prospect name
- prepare the run and inspect `imagegen-jobs.json`
- assign the base job, all standard rows, the four-cardinal strip, coherent look rows, blind direction QA, and final contact-sheet QA to lightweight workers
- copy selected worker outputs into their decoded paths and mark jobs complete in `imagegen-jobs.json`
- create `references/canonical-base.png` from the selected base output
- run the approved `running-left` mirror derivation when appropriate
- write the pet-specific look mechanics plan after standard-row QA
- approve the cardinal semantics and compose `decoded/look-anchors-approved.png`
- require immediate deterministic registration, post-registration edge QA, and labeled semantic QA after each coherent look-row generation
- run deterministic v2 assembly, packaging, repair regeneration, and cleanup

Base worker responsibilities:

- handle only the `base` job
- read `prompts/base-pet.md` and use any listed reference images
- use `$imagegen` only
- honor any compact brand inspiration line in the prompt as broad visual/personality guidance, without copying logos, readable marks, UI screenshots, slogans, or text
- return only `selected_source=/absolute/path/to/selected-output.png` and `qa_note=<one sentence>`

Row worker responsibilities:

- handle exactly one row job
- read the row prompt and use all listed input images
- use `$imagegen` only; do not draw, edit, tile, or synthesize sprites locally
- perform a quick visual sanity check for frame count, identity, chroma background, spacing, clipping, and detached effects
- enforce the row prompt's transparency and effects rules, including no detached effects, no wave marks for `waving`, no speed lines or dust for directional running rows, no literal foot-running for the non-directional `running` row, and only attached opaque sprite-like tears/smoke/stars when allowed by the state prompt
- for a `look-row-strip`, synthesize the complete row as one coherent family from the approved cardinals and never independently restyle individual cells
- for a `look-row-strip`, verify the output contains eight separated pose groups in the required order with no overlap or outer-canvas clipping; deterministic assembly owns exact cell cropping, one shared scale and baseline, recentering, and final-cell edge validation
- return only `selected_source=/absolute/path/to/selected-output.png` and `qa_note=<one sentence>`

Blind direction QA worker responsibilities:

- inspect only `qa/direction-blind-pairs.png`; do not provide the labeled direction sheet, atlas, prompt, degree order, prior verdicts, or hidden answer key
- classify A and B for every pair independently on the axis named in the sheet: `screen-left`, `screen-right`, `up`, `down`, or `ambiguous`, using visible pupils, nose, face surface, head turn, or the pet's natural aiming feature
- never infer from pair order; use `ambiguous` honestly when the requested axis is unreadable. Cardinal ambiguity blocks packaging; intermediate ambiguity becomes labeled-review evidence.
- never inspect or receive another blind worker's classifications; the parent combines exactly three isolated verdict files with `combine_direction_blind_verdicts.py`
- return JSON-ready pair classifications only; do not edit files or inspect unrelated artifacts

Final visual QA worker responsibilities:

- inspect the standard and extended contact sheets, direction QA sheet, row GIFs, semantic verdicts, continuity results, and v2 validation
- verify all 11 rows match the Codex app contract and the same pet identity
- return a compact result: `visual_qa=pass` or `visual_qa=fail`, plus row-specific repair notes when failing
- do not edit files, queue repairs, package, or clean up

Model choice for workers:

- Prefer a smaller capable model for brand discovery, since it returns a compact research brief rather than doing orchestration.
- Use an available model capable of inspecting the required image detail; follow runtime and user model choices.
- Use the parent/default model only for orchestration or when a smaller worker model is unavailable.
- Dynamically keep up to three generation workers active while at least three independent jobs are ready and capacity permits; backfill slots as workers finish. Use fewer workers when dependencies expose fewer jobs. Run final visual QA as a single worker after deterministic image processing. Close workers after their result has been consumed.
- Once `look-cardinals` passes, start row 9 immediately. Start row 10 only after row 9 has passed deterministic registration, post-registration edge, semantic, and continuity QA; give row 10 the completed row 9 strip as continuity evidence.

Use this base worker prompt:

```text
Generate the hatch-pet base image.

Run dir: <absolute run dir>
Job id: base
Prompt file: <absolute base prompt file>
Input images:
- <absolute path> — <role>

Use $imagegen only. Read the base prompt and attach every listed input image. If the prompt contains brand inspiration, use it only as broad mascot-safe guidance; do not copy logos, readable marks, UI screenshots, slogans, or text. Before returning, visually check that the result is one centered full-body pet on a flat chroma background, with no text, scenery, shadows, or detached effects.

Do not edit manifests, copy into decoded, mark jobs complete, generate rows, run image-processing scripts, repair, package, or open unrelated files.
Do not include Markdown image previews, base64, or extra attachments in the final response.

Return exactly:
selected_source=/absolute/path/to/selected-output.png
qa_note=<one sentence>
```

Use this cardinal-strip worker prompt:

```text
Generate one hatch-pet four-cardinal anchor strip.

Run dir: <absolute run dir>
Job id: look-cardinals
Prompt file: <absolute prompt file>
Input images:
- <absolute path> — <role>

Use $imagegen only. Read the cardinal-strip prompt and attach every listed input image. Read `qa/look-mechanics.md`. Screen-left and screen-right are viewer/image coordinates, never character-relative coordinates. Before returning, verify all four slots in order without relying on their labels: for a face, cite the nose-tip and pupil positions relative to the head center; for other pets, cite the natural aiming feature. Any ambiguous cardinal fails the strip.

Do not edit manifests, copy files, generate rows, assemble, package, or inspect unrelated files. Do not include image previews or attachments in the final response.

Return exactly:
selected_source=/absolute/path/to/selected-output.png
qa_note=<one sentence with concrete landmark evidence for all four cardinals>
```

Use this row worker prompt:

```text
Generate one hatch-pet row.

Run dir: <absolute run dir>
Row id: <row-id>
Prompt file: <absolute prompt file>
Retry prompt file: <absolute retry prompt file>
Input images:
- <absolute path> — <role>
- <absolute path> — <role>

Use $imagegen only. Read the row prompt and attach every listed input image. For a `look-row-strip` job, also read and obey `qa/look-mechanics.md`; use the approved cardinal strip for direction meaning and draw all eight cells together as one coherent family with even intermediate steps. Never paste, reuse, or independently restyle individual cells. If imagegen returns Bad Request, retry once with the retry prompt and the same input images.

Before returning, visually check: exact frame count, same pet identity as canonical base, flat chroma background, complete separated unclipped poses, and no detached effects or guide marks. For a `look-row-strip`, verify there are eight separated pose groups in the required left-to-right order, neighboring poses do not overlap, no foreground is cropped at the outer canvas edge, and the generated family keeps a consistent scale and baseline. Exact cell cropping, shared-scale normalization, recentering, and final-cell edge validation happen deterministically after generation. The prompt's transparency and effects rules are mandatory: no detached effects, no wave marks for `waving`, no speed lines or dust for directional running rows, no literal foot-running for the non-directional `running` row, and only attached opaque sprite-like tears/smoke/stars when allowed by the state prompt.

Do not edit manifests, copy into decoded, mark jobs complete, mirror rows, run image-processing scripts, repair, package, or open unrelated files.
Do not include Markdown image previews, base64, or extra attachments in the final response.

Return exactly:
selected_source=/absolute/path/to/selected-output.png
qa_note=<one sentence>
```

Use this blind direction QA worker prompt in a fresh worker that has not seen the labeled direction sheet. Spawn it without prior conversation context when the worker system supports context isolation (for example, `fork_turns="none"`):

```text
Classify one required gaze axis in an unlabeled hatch-pet A/B challenge.

Blind sheet: <absolute run dir>/qa/direction-blind-pairs.png

Inspect only this sheet. Do not open the atlas, labeled direction sheet, prompts, prior QA, degree order, answer key, or any other file.

Each row contains two normal-size pet cells labeled A and B and identifies the axis to judge. For a horizontal row, classify each cell as exactly `screen-left`, `screen-right`, or `ambiguous`. For a vertical row, classify each cell as exactly `up`, `down`, or `ambiguous`.

Judge only what is readable at the displayed pet size. Use visible landmarks such as pupils, nose tip relative to head center, face surface, head turn, eyelids, or the pet’s natural aiming feature. If the requested axis is not definite without enlarging or guessing, classify it as `ambiguous`; do not invent confidence.

Do not infer from A/B order. If A and B point the same way, report the same classification; do not force one left and one right.

Return exactly one JSON object and nothing else:
{"pairs":[{"pair":"horizontal-1|vertical-1","A":"screen-left|screen-right|up|down|ambiguous","B":"screen-left|screen-right|up|down|ambiguous","reason":"short landmark evidence"}]}

Include every pair shown in the sheet.
```

Use this final visual QA worker prompt:

```text
Visually QA one finalized hatch-pet contact sheet.

Run dir: <absolute run dir>
Contact sheet: <absolute run dir>/qa/contact-sheet.png
V2 contact sheet: <absolute run dir>/qa/contact-sheet-extended.png
Focused direction QA sheet: <absolute run dir>/qa/look-directions.png
Direction semantics JSON: <absolute run dir>/qa/direction-semantics.json
Blind direction validation JSON: <absolute run dir>/qa/direction-blind-validation.json
Look continuity JSON: <absolute run dir>/qa/look-continuity.json
Preview dir: <absolute run dir>/qa/previews
Review JSON: <absolute run dir>/qa/review.json
V2 validation JSON: <absolute run dir>/final/validation-extended.json

Inspect the contact sheet and the preview GIFs visually. Confirm the same pet identity, style, palette, silhouette, face, proportions, and props across all rows:
0 idle, 1 running-right, 2 running-left, 3 waving, 4 jumping, 5 failed, 6 waiting, 7 running, 8 review.

Require `qa/direction-blind-validation.json` to have `ok: true`, or require an explicit accepted minor override in `qa/blind-review-resolution.json`. Cardinal mismatches or ambiguity are major and block packaging. For intermediate warnings or a worker-level fail, inspect the labeled normal-size pose and ordered loop; accept when the issue is minor and there is no wrong-quadrant pose or reversal.

Inspect the 16 direction cells as a labeled ordered loop against the neutral frame and review `qa/look-continuity.json`. Produce a `pass`, `warning`, or `fail` semantic verdict for every expected direction: `000 up`, `022.5 up-right`, `045 up-right`, `067.5 up-right`, `090 right`, `112.5 down-right`, `135 down-right`, `157.5 down-right`, `180 down`, `202.5 down-left`, `225 down-left`, `247.5 down-left`, `270 left`, `292.5 up-left`, `315 up-left`, and `337.5 up-left`. Record separate horizontal and vertical landmark evidence for every diagonal. Fail wrong or ambiguous cardinals, labeled wrong-quadrant poses, and visible reversals. Record blind uncertainty on intermediate poses as warnings when labeled review and loop context confirm the intended direction.

Fail rows with identity drift, missing/blank frames, copied guide marks, white/nontransparent backgrounds, cropped bodies, slot overlap, detached effects, shadows/glows/smears/dust, motion that does not match the row state, unintended size popping, wrong facing direction, reversed or non-alternating gait, or idle loops that are effectively static. Judge chroma only on the cleaned extended contact sheet, not the pre-cleanup standard contact sheet. Do not fail or retry a row for magenta/chroma fringe after the final despill report and v2 atlas validation pass; those deterministic results are authoritative.

Do not edit files, queue repairs, package, clean up, or inspect unrelated files.

Return exactly:
visual_qa=pass|fail
qa_note=<one sentence summary>
direction_semantics=<semicolon-separated labels with pass/warning/fail and short visual reason>
review_warnings=<semicolon-separated accepted warnings, or none>
repair_rows=<comma-separated row ids, or none>
repair_notes=<short row-specific notes, or none>
```
