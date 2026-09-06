# Generate and register the look rows

Paths in commands are relative to `SKILL_DIR` (the installed hatch-pet directory), not this reference directory. Set `RUN_DIR` to the task-owned run folder; reuse the Python executable selected in the entrypoint. Read only the stage needed for the current task.

Apply [appearance.md](appearance.md) and the direction acceptance policy in [validation.md](validation.md). Read [workers.md](workers.md) only when assigning visual jobs. Cardinal/row approval is evidence review by the agent; do not ask for another approval when the supplied design and authorized task are clear.

Use the run's selected chroma key for every assembly path; omitting it falls back to green and can misclassify a magenta background as clipped sprite pixels.

```bash
CHROMA_KEY=$(jq -r '.chroma_key.hex' "$RUN_DIR/pet_request.json")
```

## Required V2 Look-Direction Stage

Every new pet must complete this stage. After standard-row QA passes, write `qa/look-mechanics.md`, approve the four cardinals, synthesize and validate the complete `look-row-9`, then synthesize `look-row-10`. Row 10 becomes ready only after row 9 is deterministically registered, clears post-registration edge checks, and has no semantic or continuity hard failure; reviewed warnings may remain. It uses row 9 plus the approved cardinal strip as continuity evidence.

Before either look row, run the prepared `look-cardinals` strip job, extract its four cells with `extract_cardinal_anchors.py`, and approve them. Do not let a two-row sweep invent its own left/right basis. `090` must point toward the viewer's screen-right edge and `270` toward the viewer's screen-left edge; for faces, the nose tip and pupils must cross to the corresponding side of the head center. If one cardinal is ambiguous, regenerate only that anchor before continuing.

After copying row 9 into `decoded/look-row-9.png`, register and edge-check it with the same transform used by final assembly:

```bash
"$PYTHON" "$SKILL_DIR/scripts/assemble_extended_atlas.py" \
  --base-atlas "$RUN_DIR/final/spritesheet.webp" \
  --look-row-9 "$RUN_DIR/decoded/look-row-9.png" \
  --neutral-cell "$RUN_DIR/frames/idle/00.png" \
  --chroma-key "$CHROMA_KEY" \
  --chroma-threshold 96 \
  --registered-row-output "$RUN_DIR/qa/look-row-9-registered.png" \
  --registration-manifest-output "$RUN_DIR/qa/look-row-9-registration.json"
```

Inspect the eight registered cells at normal pet size in `000` through `157.5` order. Record the row-9 semantic and adjacent-continuity review, resynthesize the complete row for any hard failure, and mark `look-row-9` complete only after this check passes. That completion makes row 10 ready in `imagegen-jobs.json`.

Generate only the additional look-direction visuals with `$imagegen`:

- Required for new pets: two coherently synthesized 8-frame row strips, one for row 9 and one for row 10.
- Always include the canonical base reference and approved 8x9 contact sheet.
- Keep the body scale, baseline, head size, face, materials, palette, markings, and props consistent with the standard atlas.
- Before prompting, write a short look mechanics decision for this specific pet. First ask: **what is the best natural motion for this character when looking around?** Describe what stays anchored, what leads the gaze, what follows, and what bends, shifts, turns, squashes, stretches, or deforms. Include eyes and props: decide whether eyes rotate as physical eyeballs, irises move on a fixed surface, eyelids reshape, pupils slide, props stay stable, props lag slightly, or props move with the body. Use the character's physical construction as the guide: flexible wire should bend, soft bodies should deform, separate heads should turn, ears/fur/antennae may follow through, physical eyeballs should rotate as whole eye globes in their sockets, flat screen or sticker eyes may change their drawn features on a fixed surface, and rigid or screen-like characters may stay body-locked while facial features move.
- Define a motion budget before generation: each 22.5-degree step should move the same parts by roughly the same visual amount, with no single adjacent pair doing a larger bend, scale change, prop shift, or silhouette change unless the mechanics decision explicitly calls out that asymmetry. Generate row 9 first along `000 -> 090 -> 180`, then give completed row 9 to row 10 so `180` begins exactly one step after `157.5`. Row 10 follows `180 -> 270 -> 000`, and `337.5` in row 10 must land one step before the approved `000` in row 9.
- Do not use whole-sprite rotation, whole-cell rotation, skewing, or affine tilting to fake gaze direction. A direction row built by rotating the entire pet is failed unless the pet is literally a rotating rigid object and the look mechanics decision explicitly says the whole object should rotate. Whole-body tilt that makes the item/background appear to rock left or right is not natural look behavior for ordinary pets.
- Generate a coherent 16-pose gaze set, not 16 unrelated variants. Each direction should feel like a point on one continuous arc around the clock.
- The look mechanics decision must name the natural pose family for each cardinal direction before generation, including which body side becomes more visible, which features become occluded, and how any held prop follows or lags. Do not let the generator infer all directions from one front-facing pose. For characters with a face or head, leftward directions must visibly turn or bend the face/head left, rightward directions must visibly turn or bend right, up/down directions must use the eyes, eyelids, head angle, neck, and upper body as physically appropriate, and diagonals must interpolate between those pose families. A set where every cell remains essentially front-facing, or where all leftward cells still read as front/right-facing, is failed.
- Adjacent direction cells must have continuous body movement. Compare every neighboring pair in direction order, including `157.5 -> 180`, `337.5 -> 000`, and any row-strip boundary. Anchored parts must not jump, flip sides, or teleport between adjacent states; if a body part moves laterally, bends, stretches, or rotates, its position should progress gradually across the intervening directions.
- Do not mirror, re-center, or independently regenerate adjacent direction cells in a way that changes the pet's body registration. Keep a stable anchor, usually the feet/base/torso/lower body or the natural grounded part of the character, and let only the intended look mechanics change around it.
- Every look cell must be visually distinguishable from the neutral/resting frame at final pet size. A direction cell that reads as front-facing, idle, or neutral is failed even when it is non-empty, transparent, and in the correct row/column.
- Cardinal directions must be semantically unmistakable at final pet size, not only numerically or geometrically different. `000` must clearly read as looking up, `090` as looking right, `180` as looking down, and `270` as looking left using the pet's natural mechanism. If the pet has no pupils or physical eyeballs, the head, face surface, eyelids, antennae, ears, or body bend must carry the direction clearly enough that a viewer can identify the cardinal without labels.
- Diagonal and intermediate directions should broadly occupy the intended quadrant and advance naturally through the ordered loop. Minor pupil, nose, eyelid, or feature-placement deviations are not failures by themselves. Reject only gross wrong-quadrant poses, visible reversals, or intermediate cells that break the coherent motion family.
- For eyeless object pets, do not default to literal whole-object rotation just because the object is rigid. First identify whether the object has a natural front, display face, playable surface, readable silhouette, or iconic viewing angle. Preserve that primary readable face unless the user explicitly asks for turntable rotation. Express look direction through subtle object-specific body language: small lean, neck/tip aim, hinge, yaw, pitch, bend, vibration, squash, follow-through, or attached-part motion. The direction should read as attention or orientation, not as the object spinning through all clock angles.
- Preserve the pet's original eye design in look-direction cells. Do not paint new round "googly" eyes, replacement eye whites, floating pupils, detached eye dots, or a second eye layer on top of the source eyes. Eye motion must follow the look mechanics decision. If the pet has physical eyeballs, rotate or redraw the whole eyeball surface so the sclera/eye white, iris, pupil, eyelids, rim, and highlights change together as one physical eye; do not slide only the iris or pupil across a fixed eye white. If the pet has flat printed, sticker, or screen eyes, keep the surface fixed and move/redraw only the features that would physically change on that surface. Do not use procedural pupil/iris compositing unless it is clipped to the original eye aperture and visibly remains inside the head silhouette in every direction. If the original eye design cannot be preserved cleanly, regenerate the whole look cell with the original eye construction instead of compositing new eyes over it.
- Eyes may lead the gaze, but pupil-only motion is an exception, not the default. Use it only when the look mechanics decision explains why whole-eye rotation, eyelid reshaping, body, head, or feature movement would be unnatural for that specific design. Large-eye pets, cyclops pets, and round rigid-body pets with physical eyeballs usually should rotate the whole eye globes, not use pupil-only or googly-eye sliding. Screen-face pets and printed-eye pets may be body-locked with feature motion only. Separate head/body pets should usually combine eye movement with head turn, head tilt, ear/fur/upper-body follow-through, and a stable torso. Rigid object mascots may hinge, flex, slide, or shift attached features without rotating the whole sprite. Flexible wire or paperclip-like mascots should usually keep the feet/base anchored while the upper loop or face area bends toward the target and held props remain stable or lag subtly. Blob or organic pets should usually keep a base anchored while the face/head area stretches subtly toward the target. Other pet types should get their own similarly grounded mechanics.
- Human or humanoid pets need persona-preserving look mechanics. Do not use broad non-rigid raster warps that stretch the skull, brows, mouth, hoodie, hands, or held props just to make a direction read. The eyes should usually lead the gaze with visible eye, eyelid, and eyebrow participation, then the head/neck and upper body should follow subtly; a humanoid row where the head moves but the eyes stay locked in one expression is failed unless the mechanics decision gives a specific physical reason. Use small eye rotation, eyelid/eyebrow changes, head/neck turn, and restrained upper-body follow-through while preserving facial proportions and expression. Programmatic repairs must move anatomical parts with rigid or near-rigid part motion, not displacement fields that change facial feature spacing. For pets with held, worn, or attached props, infer each prop's physical constraints before generating look directions: where it is anchored, whether it is rigid or flexible, whether it leads or lags the body, and how it should occlude or be occluded as the character turns. Props near the face may become more side-on, partly hidden by the head, or reveal different contact points; hand-held tools may swing or lag subtly while staying attached; worn props should follow the body; flexible cords or straps should arc continuously. Do not keep the prop and character in the same front-facing relationship across all look directions. Before packaging a humanoid pet, inspect the normal-size neutral and cardinal cells together and reject identity or facial-proportion drift, or a `270` cardinal that does not unmistakably read as left.
- For every pet, use cardinal anchors instead of trusting a two-row sweep to preserve left/right semantics. Generate `000`, `090`, `180`, and `270` together as one strip, then extract and approve them. The final look rows use those four pose families for direction meaning and interpolate the intermediate directions as a coherent arc. Define directions in viewer/screen coordinates, never character-relative coordinates. Do not require exact pupil or nose placement on intermediate poses; use the ordered loop and overall quadrant motion as the primary evidence.
- Keep motion subtle and pet-safe: preserve volume, baseline, silhouette readability, identity, and material believability. The look pose may involve head, eyes, face, upper body, appendages, or body deformation only when those parts would naturally participate.
- Do not add labels, degree text, arrows, clocks, guide marks, shadows, glows, scenery, or detached effects.

Direction order is fixed:

```text
row 9:  000, 022.5, 045, 067.5, 090, 112.5, 135, 157.5
row 10: 180, 202.5, 225, 247.5, 270, 292.5, 315, 337.5
```

`000` means looking up / 12 o'clock. Neutral/front is the pointer deadzone and should fall back to idle unless the target renderer explicitly uses a neutral cell.

Look rows must have transparent backgrounds after assembly. Do not accept or install the pet if `qa/look-directions.png` or `qa/contact-sheet-extended.png` shows chroma-key panels behind any look cell. If generated look rows contain slight chroma-key lighting variation, rerun assembly with a wider `--chroma-threshold` instead of packaging the opaque key color. Validation must pass without opaque chroma-key-pixel errors.

Extended look cells must also keep the same practical scale and body registration as the neutral/default pet. Do not accept a direction set where neutral/default is noticeably larger than the look cells, where the look cells appear to float above the baseline, or where the pet slides left/right within its 192x208 cell while only changing gaze. Extended assembly recovers each pose group from the complete original-resolution row and computes one shared scale from height plus every pose's left and right extents around the shared lower-body anchor, so asymmetric poses remain inside the final cell after alignment. It resizes each original crop exactly once and never enlarges an already-resampled cell. The neutral frame supplies the target body height, lower-body anchor, and baseline. Pass `--neutral-cell` when an external neutral frame is available; otherwise the assembler falls back to the populated neutral/default slot or first visible idle frame in the base atlas. If the focused QA sheet still shows scale or placement drift, repair before packaging.

Assemble the extended atlas from two generated row strips:

Extended assembly reuses the approved registered row-9 cells and persisted scale exactly. It removes the chroma background from row 10, detects its eight separated pose groups, preserves their left-to-right order, crops each complete pose without fixed-slot slicing, and fits them against the same neutral-frame scale, lower-body anchor, and baseline. Only then does it apply the near-edge clipping check to row 10's normalized `192x208` cells. If pose-group recovery is ambiguous, or if row 10 cannot fit the approved row-9 transform without failing the post-registration edge check, resynthesize row 10; do not rescale row 9, patch an individual final cell, or relax the threshold for acceptance.

```bash
"$PYTHON" "$SKILL_DIR/scripts/assemble_extended_atlas.py" \
  --base-atlas "$RUN_DIR/final/spritesheet.webp" \
  --registered-row-9 "$RUN_DIR/qa/look-row-9-registered.png" \
  --row-9-registration "$RUN_DIR/qa/look-row-9-registration.json" \
  --look-row-10 "$RUN_DIR/decoded/look-row-10.png" \
  --neutral-cell "$RUN_DIR/frames/idle/00.png" \
  --chroma-key "$CHROMA_KEY" \
  --chroma-threshold 96 \
  --output "$RUN_DIR/final/spritesheet-extended.png" \
  --webp-output "$RUN_DIR/final/spritesheet-extended.webp" \
  --manifest-output "$RUN_DIR/final/spritesheet-extended.json"
```

For repair or upgrade of a user-provided 16-cell source that was already approved as one coherent set, individual-cell assembly remains available. Do not use this path for newly generated repair cells:

```bash
"$PYTHON" "$SKILL_DIR/scripts/assemble_extended_atlas.py" \
  --base-atlas "$RUN_DIR/final/spritesheet.webp" \
  --look-cells-dir /absolute/path/to/look-cells \
  --neutral-cell "$RUN_DIR/frames/idle/00.png" \
  --chroma-key "$CHROMA_KEY" \
  --chroma-threshold 96 \
  --output "$RUN_DIR/final/spritesheet-extended.png" \
  --webp-output "$RUN_DIR/final/spritesheet-extended.webp" \
  --manifest-output "$RUN_DIR/final/spritesheet-extended.json"
```


After coherent assembly, continue with [validation.md](validation.md).
