# Character customization plan (accessories for the climber)

Status: PLAN ONLY. No app code was changed. Line refs are `crux.html` on `main` @ `a4efcc7` (6635 lines); the
`fix/data-preservation` branch has a different line count, so re-grep by the function names given.

## 0. Rules from AGENTS.md that constrain this feature

| Rule | What it means here |
|---|---|
| Hard rule 5: "`idle-01` is the locked master ... don't redesign the head or face. The owner prefers small pixel edits of idle-01 over freshly generated art for subtle motion." | Accessories are overlays on the existing frames. Never regenerate or repaint the body. Nothing may cover or alter the eyes/face; hats sit above the brow band. |
| Hard rule 4: "Only `mascot/climber/` images belong in the app"; no "Crimpet"; the climber is "your climber" | New art lives under `assets/mascot/climber/...` (e.g. `.../outfit/`). UI copy says "your climber". |
| Hard rule 3: key `crux-app-state-v2` never renamed; shape changes migrate in `normalizeState()`, old backups must still import; never drop attempts/notes/photos/grades/sessions | Selection goes in a new `state.character.outfit` key, additive only, defaults filled in `normalizeState()`. Unknown ids must be ignored, not deleted. |
| Hard rule 2: every image through `asset(file, blobId)`; new images need an uploaded blob id before publishing | Every accessory PNG = one upload. Count math in section 4 matters. Missing blob id is fine locally; say so in the handoff. |
| Hard rule 1: Artifact link fixed, three capabilities stay, contract 0.2.67 | No new capabilities needed. Do not publish unless asked. |
| Hard rule 7 + "mascot motion" | `recomputeProfile()`, XP and level maths untouched. Cosmetic unlocks must be derived from `state.level` / `wallInfo().holds`, never grant XP. Mascot motion clips are only extended (overlay follows the frame), not rewritten, unless Hayden okays it. |
| Hard rule 6 | Simple mode stays minimal: the wardrobe lives in Customize, one picker, no per-item options in Simple. |
| "A new pose goes through `normalize-wall-climber.ps1`, never straight from the generator" (The Wall section) | Same discipline for accessory art: a normalize/fit script, never raw generator output. |
| "Match the existing design ... CSS variables on `:root`" and "Check ... 375 px" | Picker uses `.picker-item` grid; test at 375 px, light and dark. |
| "Tests: all checks must pass; new behaviour the owner cares about gets a test" | Add `dev/tests.html` checks (section 3.8). |
| Rooms: "Backgrounds load only when their room is on screen" | Precedent for lazy-loading; accessory frames should load only for equipped items. |
| "One assistant at a time on `crux.html`" | Build on a branch, one agent at a time. |

## 1. How the climber works today

### 1.1 Rendering: raster PNG frame swapping, NOT SVG
- The climber is **pre-rendered 3D-style PNG sprites, 640x960 RGBA**, one full image per pose/frame. Art masters are 1024x1536 in `../art-source` (not present on this machine; treat as a dependency to locate).
- Home: `<img id="characterStage">` plus `<img id="characterFace" class="character-face">` inside `.character-body` inside `.character-wander` (L1087-1092). `.character-wander` is 50% of scene width, bottom 8.5% (L329-332); the scene is a 200x240 viewBox, 4:5 (`ROOM_VB_W/H`, `ROOM_FLOOR_Y = 192`, L4726). The img is `width:100%;height:auto` with a CSS `drop-shadow` filter (L353) and a separate CSS contact shadow `.character-shadow` (L338).
- **There is already an overlay layer precedent:** `characterFace` is a full-canvas (`inset:0;width:100%;height:100%`, L360) 640x960 PNG laid exactly over the idle frame, shown only on idle frames (`syncFace()`, `MASCOT_IDLE_SET`, ~L5440-5455), hidden during motion. Faces were "built by faces.py from idle-01: lids and highlights only". Accessories can reuse this exact pattern.
- Other places the climber is drawn (all must show the outfit, or deliberately not):
  1. Home scene `characterStage` (`renderCharacterCard()`, L5198; `selectedCharacterStage()` L4707 always returns `IMG.mascot.idle[0]`).
  2. Level-chip avatar `heroAvatarImg` (L1096, small).
  3. The Wall: `#wallClimberImg` (L1386) via `wallShow(src, wide)` (L5717); summit-flag frames are drawn at 141% width.
  4. Celebration cards `celebrateLevel()` (L2996) using `IMG.ui.cheer`.
  5. Share card canvas `drawShareCard()` (L6361) draws `IMG.ui.cheer[0|1]` onto a 1080x1350 canvas.
  6. Motion: `mascotClip()` (L5264) builds frame lists `[src, ms, lift, progress, shadow]` for tap/jump/step/land/blink; `MASCOT_CLIPS.idle` cycles 4 breathing frames (L5401).
  7. `px/` folders hold 60x90 pixel-art variants (dev/jump-lab); not the main runtime path.

### 1.2 Frame inventory (`assets/mascot/climber/default/`, git ls-tree of main)
idle 4, blink 2, step 3, jump 3, land 2, cheer 3, climb 4 (chalk-up, pull, reach-left, reach-right), sit 2, rest 1 (tea), move 14 (WALL_MOVES: chalk_clap, fist_pump, wave, dance), summit 2 (flag, wider canvas) = **40 body frames**, plus 6 face overlays. `assets/mascot` totals 19 MB; one idle frame is ~470 KB.

### 1.3 What the climber already wears (important)
From `idle-01.png` and `climb-reach-left.png`: round egg head with a dark vertical band (no hair, no ears, eyes are two dark ovals), cream t-shirt, dark brown belt with buckle, dark shorts, **orange climbing shoes, orange zig-zag chalk bag on the belt, olive backpack with a teal coiled rope**, shoulder straps. Climb/reach poses are a **back/three-quarter view**; idle is front three-quarter. So:
- "Chalk bag", "shoes", "pack" are not new slots, they are **re-skins of existing parts**: recolor (hue-shift mask) or replace.
- Genuinely new additive slots: head (band/beanie/cap/helmet), neck (bandana), face (glasses sit on a blank egg: tricky), wrists/hands (tape/gloves), aura/pet.
- The head is a smooth egg with a hard dark band: headwear must respect the band (it is the character's signature) and the skin texture/lighting is photoreal 3D, so flat vector overlays will look pasted on.

### 1.4 Customize screen, selection state, unlocks
- Customize modal: `renderCustomizeModal()` (L2197): gym picker (`pickerItemsHTML`, with "Auto" = newest) + decoration toggles (`decorateItemsHTML()`, L2186). Decorations are `ACCESSORIES` (L4918) = **room props**, not climber items. Naming collision: call the new thing "outfit"/"wardrobe", never "accessories" in code.
- State: `defaultState()` (L1889) `version:2`; `character:{ colorway:"accent", selectedStageId:null, selectedEnvironmentId:null, decorations:[...], decorPositionsByEnv:{}, roomLab:[] }` (L1915). `character.colorway` exists but is unused by the climber (verify with grep before reusing; do not repurpose). `normalizeState()` (L1974) does `Object.assign(base.character, migrated.character||{})`, so a new default key is picked up for old saves and backup import automatically, and unknown keys survive.
- Unlocks: `CHARACTER_STAGES` (L4692): levels 1/4/8/15/25 unlock Garage gear (pad, holds, plant, lights); they no longer change the climber's look. Rooms by level 8/15/24/40 (`ENVIRONMENTS`, `unlockedEnvironments()` L4891, `devPreviewGyms` bypasses it) and Wall holds (hold 21 = Home Wall). The Wall: 42 holds, "every hold unlocks something ... display-only for now" (AGENTS.md), so there are already ~42 reward slots with no real payload: the natural source of cosmetics.
- Dev tools: "Pretend level" (`devLevel`), "Pretend Wall streak" (`devWallDays`), "Preview every gym" (`devPreviewGyms`, L1590). Celebration cards `celebrate()` / `celebrateGear()` (L2971, ~L5214) show unlocks one at a time.
- Asset/offline: `asset()` L4443 (local path with `?v=hash`, or `/_blob/<id>`); `IMG` L4447. `preloadCharacterArt()` (~L5233) warms idle/blink/step/jump/land only. PWA: `dev/build-site.ps1` generates `sw.js`: "pictures and fonts cached after first use" (so an unseen outfit item is not available offline until first viewed; precache equipped set).

## 2. Why accessories are hard here

1. **Many frames, changing silhouettes.** 40 body frames, front and back views, a hop, a seated and a tea pose. A hat drawn for idle-01 is wrong on `climb-reach-left` (back view, head tilted).
2. **Breathing/bob.** The 4 idle frames shift the body a few px; a static overlay will "swim".
3. **Scale.** Same 640x960 canvas everywhere except summit (wider, 141%) and the 60x90 avatar/chip; fine detail disappears at chip size.
4. **Z-order.** Backpack/rope are behind the torso in front view but in front in back view; chalk bag swaps sides; hat vs the dark band; arms occlude chest items in reach/pull poses.
5. **Lighting baked into the sprite.** Warm key light from upper-left with soft ambient occlusion; the CSS drop-shadow adds a halo. Overlays need matching shading or they look like stickers. Dark mode and the 5 gym backgrounds change the surrounding contrast, not the sprite, but halos/fringes show on dark rooms. Premultiplied-alpha edges (white fringes) are the classic failure.
6. **Perf/size.** 470 KB per frame today; 40 frames x N items blows up size and the "blob id per image" upload (rule 2).
7. **Save-compat.** Items must be referenced by stable string ids; removing an item later must degrade to "none", never throw.
8. **Share card and Wall use different image sources** (`IMG.ui.cheer`, wall frames), so a single "draw the outfit" function is needed or cosmetics silently vanish on the share card.

## 3. Recommended architecture

### 3.1 Principle: "composite per frame family", not procedural skeleton rigging
The body art is photoreal raster; a true skeleton rig would need part-level cutouts that do not exist. The cheap, robust approach is **anchor-assisted overlay layers**:
- Each body frame gets a small data record (a "frame card") of named anchor points in the 640x960 canvas.
- Each accessory ships art per **pose family** (not per frame), and the renderer places it using the frame's anchors (translate/scale/rotate).
- Where the transform cannot cover a frame (extreme angle), the item has an explicit per-frame override image. Missing = item hidden on that frame (graceful, tested).

Pose families (proposed): `F` front/idle (idle x4, blink x2, step, cheer, jump, land), `B` back-climb (climb x4, move x14 if they are back view; verify), `S` seated (sit), `R` rest/tea, `T` summit/flag. About 5 families. Needs one contact-sheet review of all 40 frames to confirm the grouping (unknown, see risks).

### 3.2 Anchor table (data)
```json
{
  "idle-01": {
    "family": "F", "canvas": [640, 960],
    "anchors": {
      "head":   {"x": 320, "y": 345, "r": 160, "rot": 0},
      "brow":   {"x": 320, "y": 250, "rot": 0},
      "neck":   {"x": 330, "y": 470},
      "chest":  {"x": 340, "y": 560},
      "waist":  {"x": 340, "y": 628},
      "back":   {"x": 215, "y": 560},
      "handL":  {"x": 295, "y": 560}, "handR": {"x": 435, "y": 548},
      "footL":  {"x": 255, "y": 800}, "footR": {"x": 410, "y": 800}
    }
  }
}
```
(Numbers read off idle-01 by eye, illustrative only; real values come from the guide-sheet pass.) Idle breathing frames reuse idle-01's anchors plus a per-frame `dy`. Anchors live in a new `CLIMBER_FRAMES` const near `MASCOT_CLIPS`, generated and checked by a dev script, not hand-typed in prod.

### 3.3 Slots and z-order
Layer values are relative to the body (`0`). Negative = behind the body sprite, positive = in front. Because the body is ONE flattened image (backpack, chalk bag, shoes are baked in), "behind" can only be behind the whole sprite (back-of-head items, capes, aura, pet) and "in front" is anything on top; baked parts can be hidden only by painting over them (re-skin items carry full replacement art of that region).

| Slot | z (F family) | z (B family) | Notes |
|---|---|---|---|
| aura / ground FX | -20 | -20 | behind body, above room; also uses CSS shadow |
| pet / companion | -10 or +5 beside feet | same | Own small sprite, own motion; optional |
| back (pack/cape) | -5 (behind) / +10 re-skin | +15 (re-skin of baked pack) | baked pack exists: re-skin only |
| feet (shoe colorway) | +10 | +10 | replace baked orange shoes: mask + recolor |
| waist (chalk bag, belt) | +12 | +12 | baked bag exists: re-skin |
| torso (shirt colorway / vest) | +15 | +15 | |
| neck (bandana, scarf) | +20 | +20 | |
| hands (tape, gloves) | +25 | +25 | reach/pull poses move hands: per-frame art |
| head (headband, beanie, helmet) | +30 | +30 | above band, must not cover the eyes |
| face (glasses) | +35 | hidden | hide in B family (back view) |
| face expressions (`characterFace`) | +31 | n/a | existing; glasses go above it |

### 3.4 Conflict rules
- Single occupancy per slot. `head` helmet and `head` hat are the same slot, so they conflict by construction. Sub-slots `headTop` (hat/helmet) and `headBand` (headband) allowed together only if the item declares `allows:["headBand"]`.
- `requires`/`hides` arrays per item (e.g. helmet hides `headBand`; glasses `hidesWhen: ["B"]`).
- Unknown/removed id in saved outfit renders as empty slot.

### 3.5 Colorways
- **SVG not required.** Recolor raster with a **grayscale+mask master**: art is exported as a luminance layer plus an RGB tint mask; runtime tints via CSS `mix-blend-mode`/`filter` or a prebaked palette PNG per colorway. Cheapest: ship 3-4 prebaked colorways for the 3 shipped items only (static PNGs), CSS-variable-driven recolor later if Hayden wants many.
- Colorway ids are data (`"colorways":{"orange":..., "teal":...}`); theme is irrelevant to the sprite (no light/dark art), but the **picker thumbnail** background uses `--surface` tokens.
- Re-skin of baked parts (shoes, chalk bag): alpha-masked replacement per family.

### 3.6 Item definition (data schema)
```json
{
  "schema": 1,
  "id": "headband-teal",
  "name": "Teal headband",
  "slot": "head",
  "rarity": "common",
  "unlock": {"type": "level", "level": 3},
  "conflicts": ["head:*"],
  "colorways": {
    "teal":   {"swatch": "#2FA7A0"},
    "orange": {"swatch": "#E9822B"}
  },
  "families": {
    "F": {"img": "mascot/climber/outfit/headband-teal/F.png", "anchor": "brow", "scale": 1.0, "dx": 0, "dy": 0, "z": 30},
    "B": {"img": "mascot/climber/outfit/headband-teal/B.png", "anchor": "brow", "z": 30},
    "S": {"img": "mascot/climber/outfit/headband-teal/S.png", "anchor": "brow", "z": 30},
    "R": null, "T": null
  },
  "frameOverrides": {"climb-pull": {"img": "...", "dx": 4, "dy": -2}},
  "hideOnFrames": []
}
```
Unlock types: `level`, `wallHold`, `badge`, `room`, `default`. Blob ids go next to the img via `asset(file, blobId)` as today.

### 3.7 Rendering approach in `crux.html`
- One function `climberLayers(frameSrc) -> [{src,x,y,w,rot,z}]` consumed by: home scene (add sibling `<img class="character-outfit">` elements inside `.character-body`, same inset:0 box as `characterFace`), Wall (`wallShow`), celebrate cards, and `drawShareCard()` (canvas drawImage in z order).
- Because the overlay boxes are the same 640x960 canvas as the body, **CSS `transform` on `.character-body` (hop, wander, flip) moves everything together for free**; only `characterStage.src` swaps need a matching overlay src swap in `playMotion()` (one hook where the frame is set).
- Frames without an item entry: overlay hidden for that frame (never wrong art).

### 3.8 Unlocks and progression pacing
- Derive, don't store: `unlocked = f(state.level, wallInfo().holds, state.badges)`, same as `unlockedEnvironments()`. Nothing new is written to saves other than the selection.
- Rarity as a presentation + pacing tool: common (levels 2-10 / Wall holds), uncommon (15-25 / ledges every 7th hold), rare (gyms/badges), "legendary" only from long streaks (Wall hold 42 summit). Keeps the existing "every hold unlocks something" promise real without a new currency.
- Do not add a shop or currency unless Hayden decides to (decision list). Never gate XP or training features behind cosmetics.
- Show with existing `celebrate()` cards (one at a time), and "Pretend level"/"Pretend Wall streak" dev tools already preview them.

### 3.9 State and migration
- Add `character.outfit: { head:null, face:null, neck:null, back:null, waist:null, hands:null, feet:null, aura:null, colorways:{} }` to `defaultState()` and rely on `Object.assign(base.character, ...)`; additionally, in `normalizeState()` coerce `outfit` to an object, keep only string ids, ignore unknown slots (do not delete them, to allow forward import).
- `version` stays 2 (additive change), no key rename. Backup export/import already round-trips `character`; old backups get defaults. Test: import a pre-feature backup, assert attempts/notes/sessions identical and `outfit` defaulted.
- Never write outfit data into attempts/sessions.

### 3.10 Test strategy
- Existing `dev/tests.html` (Playwright harness at `/tmp/crux-pw`: `runtests.js`, `gyms.js`, `probe.js`): add (a) save/migration + backup-import tests; (b) "only climber art" guard extended to the `outfit/` folder; (c) every item's referenced frames exist and have the `canvas` size 640x960; (d) conflict rules; (e) unknown id ignored.
- **Visual regression:** a dev-only `dev/outfit-lab.html` (like `jump-lab.html`) renders every `frame x item` composite on a flat grey and on 2 gym backgrounds; Playwright screenshots each at 1x and chip size, diff against approved baselines (pixelmatch threshold 0.1). Matrix = 40 frames x items equipped one at a time.
- **Anchor sanity tests:** headless check that each anchor lies inside the frame's alpha bbox (head anchor inside head silhouette; foot anchors in lower 20%), and that item overlay alpha bbox stays within the body bbox +/- tolerance (no item floating off).
- Phone: 375 px width, no horizontal scroll, no console errors (AGENTS rule).

## 4. Asset production plan ("looks natural")

### 4.1 Spec
- Canvas **exactly 640x960**, RGBA PNG (non-premultiplied, transparent background, no halo/glow), same registration as the body frames: each item is delivered *as it sits on that frame*, so runtime needs no per-pixel alignment for the common case. Masters at 1024x1536 into `../art-source/mascot/climber/outfit/`, runtime export 640x960 via a script (mirrors `normalize-wall-climber.ps1`).
- Only the item's pixels are opaque; include a 1-2 px soft contact/occlusion shadow baked in at <=25% alpha on the body underneath (as a separate "shade" PNG if needed).
- Guide marker layer (never shipped): head anchor, brow line, eye holes, band edge, neckline, waist line, feet, per-frame.
- Optimize: palettized/quantized PNG or WebP where the hosting path supports it (Artifact images go through blob upload; confirm WebP accepted); target < 60 KB per overlay since coverage is small. Crop-to-bbox + store offsets in JSON instead of full canvas, giving ~5-10x smaller files (the renderer already needs x/y/w).

### 4.2 Count math
- Brute force (per frame): items x 40 frames. 3 items = 120 images.
- Family approach: items x ~5 families (+ overrides). 3 items = ~15 images plus a few overrides (~20). Per full wardrobe of 7 slots x 4 items = 28 items x 5 = 140 images, ~200 with overrides and colorways baked.
- Each image = one blob upload (rule 2): so crop-to-bbox + cropped sprite sheets per item (one sheet, N rects) cut uploads to 1 per item.

### 4.3 Guide sheet / template
Make a "fit sheet" per family: the body frame at 30% opacity + anchor crosshairs + head band + safe zones (no-cover: eyes; do-not-alter: band), in the exact 640x960 canvas, exported as PNG for the image model's reference and as a PSD-style layered file for hand work. Provide `idle-01` (F), `climb-reach-left` (B), a sit frame (S), the rest frame (R), a summit frame (T).

### 4.4 Briefing an image model
Prompt skeleton (use image-edit/inpainting with the body frame as input, never text-to-character):
> Edit this image. Keep the character, pose, lighting, texture and framing pixel-identical. Add only: [item] [placement]. Match the existing soft clay-like 3D render, warm key light from upper-left, same grain. Do not change the head, band, eyes or any body proportion. Output on a fully transparent background, no glow, no border, same 640x960 canvas.
Consistency tricks: (1) one item at a time, first on idle-01 then propagate with the *same item image* as a second reference; (2) generate the item **on a neutral grey** body-less sheet from front/back/3-4 views first and approve it, then fit per family; (3) get the model to output a "difference matte" (item only) by editing on idle-01 and subtracting idle-01 yourself: item = edited minus original (alpha from the diff), which guarantees body pixels are untouched (matches rule 5); (4) lock palette to 4-5 hexes sampled from the existing shirt/shoes/chalk bag.

### 4.5 What must be hand-fixed
Alpha edges and fringing; item penetrating the head egg (clipping at the silhouette); occlusion by arms/hands in reach, pull, wave, dance frames; contact shadows; consistent shading direction; any frame where the model drifted from on-model; the 141% summit frames; thumbnail legibility at the 60x90 level chip.

### 4.6 QA checklist (per item, per frame)
- [ ] 640x960 RGBA, no white/dark fringe on light AND dark background (flat #1a1a1a and #f5f5f5)
- [ ] Body pixels unchanged outside item mask (diff vs original frame is empty)
- [ ] Eyes/face untouched; works with each `characterFace` overlay
- [ ] Anchored correctly in all 4 idle frames (no swim), blink frames
- [ ] Reads at 375 px and at the level-chip size
- [ ] Looks right on all 5 gyms (Garage, Home Wall, The Local, Mountain Club, Dream Gym) and in dark mode
- [ ] Wall poses, celebrate card, share card all show it correctly
- [ ] Conflict rules behave; unequip returns exact original sprite
- [ ] Offline (PWA) after first view; blob id uploaded

### 4.7 Thin vertical slice (prove the pipeline)
3 items, 2 slots, all pose families:
1. **Teal headband** (head) - tests anchor on the egg, band interplay, back view, hide on face expression frames.
2. **Chalk bag colorway: teal** (waist re-skin of the baked orange bag) - tests re-skin + occlusion by arms + left/right swap in back view.
3. **Climbing shoes colorway: blue/white** (feet re-skin) - tests mask-replace on baked parts in jump, step, land and sit.
Across: F, B, S, R, T. Roughly 3 x 5 = 15 images + up to ~8 overrides. Deliver `dev/outfit-lab.html` showing all 40 frames x 3 items, Customize picker with an "Outfit" section, one save/migration test. Success = Hayden says "looks natural" on every frame without hand-waving, within a day of art fixes per item.

## 5. Roadmap

| Phase | Work | Effort |
|---|---|---|
| 0 | Contact sheet of all 40 frames, decide families, anchor table, check art-source masters are available; confirm WebP/size limits of blob upload | S |
| 1 | Data model + state + migration + renderer for the Home scene only (`characterStage` overlay) + outfit-lab + tests; ONE hand-drawn item | M |
| 2 | Vertical slice art (3 items, ~15-23 images) and QA loop; tune pipeline (normalize script, diff-matte workflow) | M |
| 3 | Propagate to Wall (`wallShow`), celebrate cards, share card, level-chip avatar | M |
| 4 | Customize UI (slot tabs, colorway swatches, unlock lock state, preview), unlock celebrate cards, hook to level/Wall holds | M |
| 5 | Content: 12-25 items, rarity pacing, seasonal items (Wall already has seasons) | L |
| 6 | Optional: pets/auras, per-gym interaction, animated accessories | L |

**Riskiest unknowns:** (1) whether the 14 `move` frames and sit/rest/summit are different enough that families fail and per-frame art balloons; (2) naturalness: photoreal clay-like render vs generator output on a locked head (rule 5), esp. headwear on the egg/band in back view; (3) blob-upload burden and 470 KB-class frames hurting load/PWA cache; (4) baked-in pack/chalk bag/shoes cannot be removed, only repainted over; (5) art-source repo (masters, normalize scripts, `LOCKED.md`) is outside this clone; (6) animated frames get out of sync with overlays if `mascotClip` is edited by another assistant.

## 6. Decisions for Hayden

- [ ] **Art source and style:** image-model edits of the locked frames + hand cleanup, commissioned artist, or 3D re-render of the character (cleanest overlays, biggest cost)?
- [ ] **Unlocks:** XP/level/Wall-hold only (recommended), or also purchasable / premium items? Any streak-only legendary items?
- [ ] **How many slots at launch** (suggest head + waist + feet for the slice; add neck/hands later)? Include pets/auras?
- [ ] **Re-skin or add:** allow recoloring the baked backpack/chalk bag/shoes, or additive-only items?
- [ ] **Scope of display:** outfit shown on Home only, or also Wall, celebration cards, share card, level chip?
- [ ] **Does customization affect the gym scenes** (e.g. matching items, outfit-reactive decorations), or stay purely on the climber?
- [ ] **Face accessories** (glasses) on a faceless egg head: allowed, or off-limits under the locked-head rule?
- [ ] **Naming:** "Outfit" / "Wardrobe" (since "Accessories" already means room decorations in code).
- [ ] **Is the unused `character.colorway` key** to be retired or reused?
