# Crux: rules for AI coding assistants

Read this before changing anything. It applies to every assistant (Claude, ChatGPT/Codex, others).
More than one assistant works on this project, so leave things the way you'd want to find them.

## What this is

Crux is a climbing training timer and send log. It has XP, levels and badges, a climber mascot,
and decoratable gym rooms (the Garage, plus Home Wall, The Local, The Mountain Club and The Dream Gym).

- **The whole app is one file:** `crux.html`, which is vanilla JS with no build step and no dependencies.
- **`assets/`** holds the runtime images.
- **`dev/`** holds dev-only pages, such as `jump-lab.html`. They are never published.
- **Art masters** live in a separate git repo, `../art-source`. They are 1024×1536 sources; the runtime
  copies in `assets/` are 640×960.

## Hard rules

1. **Publishing.** The app is published as a Claude Artifact at
   https://claude.ai/code/artifact/1dd25e22-1714-4393-964c-6ec37735a770. Only publish when the
   owner asks, and only to that same link: every image on the live page points at that Artifact's
   file storage. The page declares three capabilities, and all of them must stay:
   - `assets` for photos,
   - `downloads` for backup export,
   - `sample` for the coach (asking Claude), live since version 43.

   The page runs on runtime contract 0.2.67 (version 44). Don't change the contract unless the
   owner asks.
2. **Images.** Every image goes through `asset(file, blobId)` in `crux.html`. Locally it loads
   `assets/<file>`; when published it loads `/_blob/<blobId>`. A new or changed image must be
   uploaded to the Artifact and its blob id filled in before publishing, or it will be broken live.
   Uploading happens from Claude, so an image whose blob id is still missing is fine locally.
   Say so in your handoff notes.
3. **Saved data.** The localStorage key is `crux-app-state-v2`. Never rename it. Any change to
   the saved data's shape must:
   - migrate older saves in `normalizeState()`, which both loading and backup import run, and
   - keep older backup files importing correctly (Settings → Import backup).
   - Never drop or rewrite attempts, notes, photos, grades or session history.
4. **The app is called Crux, and the mascot is the climber.**
   - **The name:** never call the app or the climber "Crimpet". The owner confirmed this on
     2026-10-03, after a rename slipped in. The climber is simply "your climber".
   - **The art:** the old pebble mascot art is retired too (the `mascot/chalkling`,
     `boulderbud`, `crimper` and `summitfriend` folders). The owner was unhappy when a test
     brought it back. Only `mascot/climber/` images belong in the app.
5. **Keep the climber on-model.** `idle-01` is the locked master (see
   `../art-source/mascot/climber/default/LOCKED.md`), so don't redesign the head or face. The owner
   prefers small pixel edits of idle-01 over freshly generated art for subtle motion.
6. **Simple vs Advanced mode.** Simple mode stays fast and minimal. Detailed controls (grades,
   project controls, extra logging fields) only show in Advanced.
7. **Don't touch what you weren't asked to touch.** In particular, leave alone the timer, XP and level
   maths (everything is replayed from attempts in `recomputeProfile()`), session handling and
   mascot motion, unless the task is about them.

## The installable app (built 2026-10-06)

Besides the Artifact, Crux can be hosted as plain files and installed to a phone's home screen (full screen, its
own icon, works offline). `dev/build-site.ps1` builds it into `site/` (git-ignored, regenerate it any time):
`index.html` is `crux.html` plus install tags and `window.__CRUX_STANDALONE`, with the images the app uses
(each loaded as `assets/...?v=<hash>`), `manifest.webmanifest`, `icons/` (from `pwa/app-icon-source.png`) and a
generated `sw.js` (service worker: page network-first, pictures and fonts cached after first use).
- **`crux.html` stays the one source.** Never edit `site/`. The Artifact and the installed app run the same code;
  the standalone flag only changes where images load from and how files are saved (`saveFileLocal()` shares or
  downloads, since the Artifact `downloads` capability isn't there).
- **Hosting is the owner's call** (Netlify Drop, Cloudflare Pages or GitHub Pages: any static host). Don't put the app on
  a public site without the owner saying so; hard rule 1 about publishing still covers the Artifact.
- **Its saved data is separate** from the Artifact's (a different address), so people move data with Export /
  Import backup. Photos and videos aren't available in the installed app yet (no `assets` capability).
- **Quick log from the home-screen icon (2026-10-08):** the manifest has `shortcuts` (Send, Flash, Fall; Chrome on Android
  shows the first three) that open `./?log=send|flash|fall`. `quickLogFromLaunch()` in `crux.html` logs one attempt through
  `logAttempt()`, starting a session if none is running, then cleans the address so a reload can't log twice. It logs nothing
  until the first-run safety notice is acknowledged. A real home-screen widget isn't possible for an installed web app
  (that needs a native Android wrapper), so this is the one-tap route. The test hook is `window.__cruxLaunch`, set only by `dev/tests.html`.
- **After changing `crux.html` or any image,** rebuild `site/` and re-host it for the installed app to update.
- **GitHub Pages (set up 2026-10-08, at the owner's request):** `.github/workflows/pages.yml` runs `dev/build-site.ps1` on a Windows runner and deploys `site/` to https://hayjorg.github.io/Crux/ on every push to `main`. So pushing `crux.html` or image changes to `main` updates the public installed app.

## Climber variants (palette recolours, 2026-10-10)

`state.character.variant` ("default" | "slate" | "sandstone" | "moss") picks a full recolour of every body frame, art in
`assets/mascot/climber/variants/<id>/<folder>/<name>.png` (same 40 frames as `default/`, minus `face/` and `px/`; web-weight 256-colour PNGs).
- **One resolver:** `climberFrame(src)` / `climberFrameFor(src, id)` maps a default body-frame address to the variant's. Every place that
  draws the climber goes through it (Home stage and clips, avatar chip, Wall via `wallShow()`, celebration, share card, pickers). Never
  put a raw `IMG.mascot.*` / `IMG.wall.cl_*` / `IMG.ui.cheer` address on screen.
- **Face overlays are per-variant (v3, 2026-10-11):** `assets/mascot/climber/variants/<id>/face/face-{neutral,stoked,focused,tired,sheepish,surprised}.png`.
  `mascotFace(mood)` / `mascotFaceFor(mood, id)` is the resolver (Home idle overlay and the session/summary buddy go through it);
  default / locked / unknown variant falls back to `default/face/`. Outfit layers stack on variants (frame key is the same).
- **v3 recolour method:** OKLab frequency separation on the default frames (hue/chroma remapped on the low-frequency layer, the
  luminance detail kept), so shading, line art and texture survive. Source in `dev/outfit/out/variants3_assets/`; `dev/build-site.ps1`
  picks up `variants/**` recursively, so `face/` ships too.
- **Unlocks** are derived from `state.level` (`CLIMBER_VARIANTS[id].unlock`), never stored; a saved-but-locked choice draws as default.
- **Blob ids** for the variant art go in `CLIMBER_VARIANT_BLOB` ("<id>/<folder>/<name>"); empty until Claude uploads them (rule 2).
  `night` exists in dev/outfit but is off-model and held back.

## Parked hats (2026-10-11)

Caps, bandanas, bucket hats and berets were taken out of the app (3D-rendered hats looked off to Hayden/Max). Their rows are
**removed from `OUTFIT_ITEMS`** and their chips from `OUTFIT_HEAD_KINDS`. Their ids (`cap-*`, `bandana-*`, `bucket-*`, `beret-*`, and
`beanie-navy`) are reserved: a saved selection of one is kept in the save but inert (draws nothing, picker shows Plain; same path as any
unknown id) and never throws. **Art is kept** in `assets/outfit/{beanie,cap,bandana,bucket,beret}/` and `dev/outfit/`; **the build excludes nothing**
(`build-site.ps1` ships `assets/outfit/**`, so the parked art is in the installed app, ~unused weight). To revive: restore the rows from git history (c1d530e) and the chips.
**The 3D beanie is replaced by the painted beanie below** (the old `assets/outfit/beanie/` art is no longer referenced).

## Painted beanie (2026-10-11, live: Headwear > Hats)

One ChatGPT-painted hat, fitted to the climber by script. Source: `Desktop/Crux-previews/ChatGPT-work/hat-objects/hat-beanie-q3left-simple-v2.png`
(1254px, 3/4 left view, pom, chunky cuff). Pipeline: `dev/outfit/painted_beanie_v5.py` (v4 = `painted_beanie_v4.py`, v3 = `painted_beanie_v3.py`, v2 = `painted_beanie_pilot.py`; `dev/outfit/` is local and untracked), outputs `dev/outfit/out/painted_v5/`. v5 reshapes the hat before fitting, gently: the source crown dome is kept (parabola apex fill, so the original pom can be removed), the pom is re-pasted at 0.88x, crown x0.97 / cuff x0.94 vertically (total about -7%), ribs converge only slightly (CONV 0.10). v4 cut much harder (pom 0.62, crown 0.90) and lost the beanie shape (flat tam, nub pom): do not go there. Calmer mottle from a mostly-vertical rib blur, stray specks dropped, blink frames shadow-masked by their own eye pixels (no light patch).
- **Cleaning:** alpha eroded 1px, edge colour replaced by the nearest interior colour (no light/dark fringe), grey luminance only, cuff re-cut along a hand-read contour (everything below is the opening).
- **Tone:** form (blur 24) and rib/groove structure (blur 6) are kept, **grooves (valleys) amplified x1.9** so the cuff stays chunky; the hat's own fine grain is damped to 0.35.
  Normalised by gain only (soft knee above 158, never lift the darks) to **mean 148 (`OUTFIT_GREY`), peak <= 170** (shipped 164).
- **Texture blend:** the climber's own mosaic (high-pass of the idle-01 cheek, blur 5, std 0.07) is multiplied on at **high frequency only**, so ribs are not washed out.
- **Fit:** head ellipse + roll from `lib/headmodel.py`; hat rotated by the roll, scaled by head radius, cuff lower edge re-contoured to a bowl that wraps the dome (sag 46).
  Rolled heads (|roll| > 1.5) get a small per-frame search (angle +-3, shift) minimising exposed skin above the cuff; horns at the cuff ends are shaved by a 5px alpha opening;
  the hat is erased where something is held in front of the head (flag pole, fists). Eye pixels are never covered or shadowed (shadow masked 3px around them).
- **Export:** a DELTA layer = hat over its own contact shadow (neutral grey 34, alpha), 128-colour RGBA palette PNG, palette rescaled so the mean stays 148. 36 frames, ~0.4 MB.
  `assets/outfit/painted-beanie/<folder>/<name>.png`.
- **Skip list** (`BEANIE_SKIP`, no file shipped; the original art shows): `climb/climb-pull` (turned, yaw 100), `climb/climb-chalk-up`, `climb/climb-reach-left`,
  `climb/climb-reach-right` (back-facing). QA: `dev/outfit/tools/outfit_check.py --item headband --dir dev/outfit/out/painted_v3/check --naming folder-name`
  (hard gates pass: canvas, alpha, outside; the box-based `zone`/`eyes` flags are expected for a hat that rises above the head).
- **App:** 9 rows in `OUTFIT_ITEMS`, slot `headband`, `kind:"hats"` (chip "Hats"), `art:"painted-beanie"`, `tint:{color}` colourways (Plain grey = untinted, red, mustard, orange, forest, purple, pink, charcoal, cream),
  unlocks by level (and holds for the last two) like the knit headbands. **Ids reuse the old parked `beanie-*` ids**, so an old save wearing `beanie-red` now wears the painted red one.
- **Blob ids:** `OUTFIT_BLOB["painted-beanie/..."]` is empty until Claude uploads the folder (rule 2).

## Head items: 3D beanies, caps, bandanas (2026-10-10, PARKED; method reference)

They live in the existing `headband` slot (one head item at a time), as 24 rows in `OUTFIT_ITEMS` (`beanie-red`, `cap-navy`, ...).
- **Art** is three neutral-grey delta-layer folders, `assets/outfit/<beanie|cap|bandana>/<folder>/<name>.png` (40 frames each, 128-colour
  palette PNGs made by `dev/outfit/compress_hats.py` from `dev/outfit/export/headwear-*`). Rows share a folder via `art:`.
- **Colour** comes from `tint:{ color:"#rrggbb" }`: each pixel is multiplied per channel by `color / OUTFIT_GREY` (148, the art's mean grey).
  DOM layers use an inline SVG `feColorMatrix` filter (`outfitFilterCSS()`), the share card the same numbers in `outfitTintCanvas()`.
  Hue-rotate alone cannot colour a grey, so never use `{hue,sat,bri}` on this art.
- **Two tint kinds, one path** (`outfitFilterCSS` / `outfitTintMatrix` / `outfitTintCanvas`, merged 2026-10-10 with the colourways): `{hue,sat,bri}` re-hues coloured art (the 23 knit/bag/shoe colourways); `{color}` colourises grey art (hats).
- **Picker**: Customize > Outfit > Headwear shows chips by `kind` (Headbands / Beanies / Caps / Bandanas), earliest unlock first.
- **Blob ids** (`OUTFIT_BLOB["beanie/idle/idle-01"]` etc.) are empty until Claude uploads the three folders (rule 2).

## Accessories: buckets, headlamps, berets, shirts, shorts (2026-10-11; buckets and berets PARKED, headlamps/shirts/shorts live)

Same neutral-grey delta-layer + `tint:{color}` method as the hats above (`OUTFIT_GREY` 148).
- **Headwear** (slot `headband`): new `kind`s `bucket`, `headlamp`, `beret` (6 colours each, `art:` = the kind). The picker chips scroll sideways. `visor` is held back.
- **New slots `shirt` and `shorts`** (`state.character.outfit` gains both, old saves/backups -> `null` in `normalizeState()`). `OUTFIT_SLOTS` draw order is
  shoes, chalkbag, shirt, shorts, headband. A layer REPLACES the cream tee / dark shorts by alpha-over (masks come from the default frames; variant frames
  have the same alpha, so it works on variants too). Picker order is `OUTFIT_PICKER_ORDER`.
- **Skips:** shirt skips `move/move-chalk-clap-1..3` (dust patches); shorts skips `rest/rest-day` and `climb/climb-reach-left`, `climb/climb-pull`
  (mask misses the far leg's shorts, looked two-tone). Skipped frames show the original art and the file is not shipped.
- **Art** in `assets/outfit/{bucket,headlamp,beret,shirt,shorts}/` (web copies from `dev/outfit/out/{hats_more,shirt_shorts}_assets`); `build-site.ps1` covers `assets/outfit/**`.
- **Blob ids** for all five folders are empty in `OUTFIT_BLOB` until Claude uploads them (rule 2).

## Games: Play (2026-10-11)

A small, optional play area for rest times, using the player's own climber. Removable: delete the `GAMES` blocks in `crux.html`
(CSS, `#gamesOverlay`, the dock's `#openGamesBtn`, the timer card's `#playRestBtn`, the JS block, the `// GAMES hook` line in `renderTimer`,
`gamesNormalize`/`state.games`) and the "Games:" tests. Design and research notes: `docs/GAMES-DESIGN.md`.
- **Entry points:** "Play" on the Home dock (next to Customize), and "Play while you rest" in the session's timer card, shown only while
  `timer.phase==="rest"`. The bottom bar stays Home / Train / The Wall.
- **It is a sheet, not a view:** `#gamesOverlay` sits over whatever is on screen, so the session timer, its beeps and the wake lock keep
  running untouched. Opened from the rest button, it shows the rest clock; when rest ends the round closes itself (the score still counts
  if it had an action), says "Back to work" with no buttons and closes after 1.8 s. In the last 10 s of a rest an end screen has no "Play again" / "Games"
  ("Rest is almost over."), and buttons already on screen are removed when the clock crosses 10 s. A hidden page pauses the round ("Paused. Tap to resume"); a paused round never resumed records nothing.
- **Shell conveniences:** `gmHud` leaves the clock alone while a round runs; `gmSetSrc` does a 100 ms opacity settle on pose swaps (skipped for reduced motion and rapid cycling; its animationend never bubbles to a host); a game may set `gmSheetTap` to make the whole sheet (minus header/HUD/rest strip/buttons) a tap target (Summit Stack does); in a game the sheet hugs its content (`:has(.gm-play:not([hidden]))`).
- **The four games** (menu order; all calm, best score only, no XP/streaks/rewards, hardest reaction window >= 400 ms):
  1. **Dyno** `dyno`, 45 s (replaced Chalk Rhythm, cut: "not a climbing action"). Hold anywhere (finger or Space) to charge; a meter
     rises and falls; release with the bar inside the band shown for the target hold to latch it (+1 height, next hold farther, band narrower,
     never under 400 ms of release time). Short/over drops one ledge and retries the same hold (peak kept; no fail state). Score = peak height.
     Reduced motion: flat bar, no wobble or scroll. `games.dyno = {best, plays, cleanBest}`. Bot: `node dev/dyno-bot.js`.
  2. **Route Read** `routeRead`, 60 s, a spray wall. 5 x 5 irregular wall (holds only where the generator puts them), two interleaved routes in
     different colour + shape; one is called, tap its holds in order from memory (N 4 to 10, start 5; N+1 on a clean route, N-1 after a loss).
     A wrong tap loses that route (it is re-shown for 1.8 s, then the next route). +N per route. `{best, plays, longest}`.
     Bot: `node dev/route-bot-run.js` (`dev/route-bot.js` is its model).
  3. **Summit Stack** `summitStack`, 45 s (v2). A block slides over the tower; tap to drop; overhang is trimmed (never below 30 % width);
     Perfect (<= 6 px) gives +1 and regains width. Topple rule: a drop whose centre is more than half a width off the tower topples and costs the
     top tier (score is the round peak). Crossing time ramps in 50 ms steps, 2400 -> 1350 ms over 22 blocks (405 ms window at the floor);
     the first 3 blocks are learn blocks. Flag at 30 blocks (re-plants if the tower drops under it). `{best, plays, tallest, perfects}`.
     Bot: `node dev/stack-bot.js`.
  4. **Wall Run** `wallRun`, 45 s (replaced Reach Timer on the menu). Holds come down a three-lane wall in a seeded sequence; tap a hold's lane
     as it reaches the climber's hands. Window is early-heavy: 350/250 ms early/late at the start -> 260/140 ms at top (400 ms total, reached by
     25 s then a plateau); a hold is on the wall 2.0 -> 0.9 s (>= 600 ms of sight before its window), mean gap 950 -> 400 ms with doubles and
     short runs (2-4 holds), floors by lane distance (280/340/420 ms), same lane <= 3 in a row. A hit climbs one move; a miss, a late tap or a
     stray tap slips one move (floor 0, one stray slip per 350 ms, round goes on). Score = peak height. Reduced motion: next three holds in fixed
     rows with a fuse bar. `{best, plays, longestRun}`. Bot: `node dev/wallrun-bot.js`.
  Retired: Reach Timer is off the menu (unregistered; its pure rules, `GAME_ART` slots and saved `reachTimer` data are kept). Hold Hop is
  retired (saved `holdHop` kept). Chalk Rhythm is cut (code, `.cr-` CSS, art slots, tests); its saved `chalkRhythm` data and the legacy
  `chalkUp` key are kept (gamesNormalize keeps unknown ids; the one-time `_meta.chalkMigrated` copy is unchanged).
  The `dev/*-bot.js` scripts are dev-only (they pull the pure rules out of `crux.html` or model them), never shipped in `crux.html`.
- **Registry:** `GAMES` / `gmRegister(def)`; the menu (`renderGamesMenu`) is built from it, sorted by `order`. A def is
  `{ id, title, blurb, order, icon, intro:{title,text}, start(), stop?, pause?, resume?, state(), rest:{closeScore()}, hud0? }`.
  A game ends with `gmOver(id, score, {title, note, actions, extra})`, which records through `recordRound` and draws the end screen.
- **Shell:** `gmBegin` (seeded RNG, `gm.seed`), `gamesRecordRound`/`recordRound` (a round counts only with >= 1 action; extras merge with
  Math.max), `gmBeep`/`gmBuzz` (setting `settings.gameSound`, silent in the last 3 s of a rest), `gmPause`/`gmResume`, `gamesWatch` (rest
  hand-off), `GAME_ART` slots with `gmArt`/`gmArtRegister`.
- **GAME_ART slots** (each draws as a plain shape with `src:null`; set `src` through `gmArtRegister(slot, file, blobId)` to swap in a PNG
  without touching game logic): `ss.ledge ss.block ss.flag`, `rr.hold rr.ring`, `dy.ledge dy.hold`, `wr.hold`, `rt.hold rt.ghost` (retired),
  `ui.perfect ui.good ui.best ui.summit`, `card.dyno card.routeRead card.summitStack card.wallRun` (`card.reachTimer` kept).
- **Adding a game:** (1) add a region `/* ==== myGame BEGIN/END ==== */` after the last one inside the GAMES block, with its pure rules
  between `/*MYGAME-PURE-BEGIN*/` and `-END*/`; (2) CSS under its own prefix after `.gm-art-img`; (3) `gmRegister({...})` with a fresh
  `order`; (4) extend the hook with `if(window.__cruxTest) Object.assign(window.__cruxGames, {...})` (the object is created before the
  regions); (5) add its slots to `GAME_ART` and its id to `gamesNormalize` and the default `state.games`; (6) always end through
  `gmOver`, make the intro/end screens obey the last-10-s rule, honour `prefers-reduced-motion`, keep every target >= 56 px; (7) tests below.
- **Art:** existing frames only, always through `climberFrame()` and `outfitFollow()` (variant, outfit layers and skip lists work);
  no shipped game art. Holds, blocks and rings are drawn defaults that a `GAME_ART` file can override.
- **Saved data:** only `state.games` (`chalkUp`, `holdHop`, `chalkRhythm` legacy; the four ids; `_meta`) and `settings.gameSound`, normalised by
  `gamesNormalize()` in `normalizeState()`. Games never write XP, levels, streaks, holds, sessions or attempts.
- **Tests** (`dev/tests.html`, "Games:" and per-game blocks `// ---- dyno tests ----` etc.): pure rules through
  `window.__cruxGames` (only with `window.__cruxTest`; `dyno*`, `route*`, `stack*`, `wall*`, `reach*`, `mulberry32`, `recordRound`, `normalize`),
  each with a 500-seed property test (routes solvable, no side repeated > 3, stack window >= 400 ms, dyno band >= 400 ms and a human-like bot that misses), plus browser runs
  for the rest hand-off, hidden-page pause, sound off, reduced motion and the registry/menu.
- **Shell polish (2026-10-12):** the sheet is a bottom sheet <= 520 px wide (centered above) that slides up and fades down (~110 ms close, then `hidden`;
  `__cruxGames.close()` and reduced motion hide at once); body scroll is locked while it is open. Cards show best / plays and have a spoken aria-label;
  the intro is one line (`GM_HOWTO`, falls back to `intro.text`) and a 56 px Start; Escape steps back (round or intro -> menu -> closed), Back returns
  focus to the game's card, Tab is trapped inside the sheet; the whole sound row toggles and states On/Off in words. The end screen puts Play again first.
- **Reduced motion:** every game has a still variant (Dyno: flat bar, no wobble; Wall Run: fixed rows and fuse bar; bar instead of ring scale elsewhere, no scroll, crossfades <= 120 ms).

## Home perch (2026-10-16)

Press and hold the Home climber, drag to a decoration, let go: he travels there and perches. All in the `HOME PERCH` block in `crux.html`.
- **Targets:** ACCESSORIES rows with `perch:"hang"|"sit"|"stand"` plus the two level-8 gear holds (`gearHoldA/B`, hang). `perchTargets(envId, sceneBox)` returns
  them with `valid` / `why` (`top` head above the visible stage, `floor` feet lower than the floor line, `side` cropped) and `geo` (sprite box, resting spot, floor limit `maxX`);
  invalid ones are returned flagged, not dropped. `perchPlacement(target, kind, boxW, boxH)` is pure (frame anchors and the measured hand points are in the comment above `PERCH_FRAME`).
- **How to add a perch to a new decoration:** add `perch:"hang"|"sit"|"stand"` to its ACCESSORIES row. For `sit` / `stand` also measure the first picture row that is
  the seat or rim (first row whose opaque width is >= half the widest row, as a fraction of the picture height) and add it to `PERCH_SURFACE`; without an entry it uses `PERCH_SINK`.
  A `ar` (picture height / width) on the row, or the loaded picture, gives its height. Nothing else: the gesture, fallbacks and tests pick it up (the "Home perch:" tests loop over every target).
- **Fallbacks (a drop is almost never refused):** `perchResolve(target)` returns `{kind, frame, left, top, dx, dy, facing}`. Order: the target's own kind if it fits (`hang` / `sit` / `stand`);
  else for a `hang` the floor `reach` (feet on the floor, fist at the hold, if the hand anchor lands within 3% of the scene of the hold); else `beside` (standing on the floor next to it, facing it,
  clamped to the floor range). `beside` is always valid and leaves no perch (`homePerch` stays null); `reach` is a perch with `dy` 0. A drop that is not near any target is just a tap.
  Most targets are `beside` at 375 px because the climber is big; that is expected.
- **Gesture** (pointer events on `#characterStage`, beside the click): idle, pressed, armed, aiming, travelling, perched. Armed after 350 ms hold, or 8 px of mouse movement. A touch that moves more than 10 px
  before 350 ms is a scroll: the gesture is dropped and the page scrolls (nothing is blocked by default: `touch-action:manipulation`). Once armed, a non-passive `touchmove` calls `preventDefault`. While aiming,
  `#perchRing` (the Arrange dashed look) marks the nearest target within 12% of the scene width. Release over it travels; release elsewhere answers like a tap. A short tap still runs `playHop` (or dismounts);
  an armed gesture swallows the click that follows (250 ms, cleared by the next press); armed but released over nothing still plays the tap's step (or hops down off a perch); Escape / pointercancel / blur / a hidden tab abort. Off in Arrange (the climber is `pointer-events:none` there).
- **Travel** (point-and-travel, not following the finger): the jump clip with sideways progress and a rise to the target (`PERCH_JUMP_PROG`), then by kind: hang = chalk (`cl_chalk`), reach, pull (`cl_pull`) tween
  to the hold (the `wallHop` pattern, rAF plus a timer fallback); sit = the arc lands in `ledge-sit`; stand = lands on the object; reach / beside = lands alongside. Frames are preloaded first.
  Every wait is in `perchRun.timers`. Reduced motion = `perchTo`, instant, no timers. Interruptions always end valid: a hidden tab or a second press finish the final pose at once (`perchFinishRun`);
  leaving Home, a room change, Arrange and level-up put him on the floor where he is (`perchCancelRun`, called from `dismountHome` and `perchSync`).
- **Frames:** existing art only, through `climberFrame()`: hang = `climb-reach-left/right`, sit = `ledge-sit` / `ledge-sit-look`, stand = `idle-01`. Without `IMG.wall` hang/sit fall back to stand.
- **State is memory only** (`homePerch`, `wanderOffsetY`, `perchRun`): never saved, no state-shape change. A reload shows the floor. The climber's transform is `translate(x,y) scaleX(f)`; `playMotion` keeps Y.
- **Dismounts:** tap while perched, Arrange on, any view away from Home, a room change, a removed or no-longer-fitting target (`perchSync` at the end of `renderSceneEnvironment`), level-up jump.
  While perched `mascotTick` plays the perch idle and `autoHopOnce` skips.
- **Resize:** `homeRelayout` calls `perchSync` first, so a perch is re-seated even when the visible-window key is unchanged. **Tests:** "Home perch:" in `dev/tests.html`, through `window.__cruxPerch` (only with `window.__cruxTest`). `dev/tests.html?only=Home%20perch` runs just those. Not verified on a real phone: long-press and scroll behaviour on iOS.

## Home climb (2026-10-17)

In the Home Wall room, press and hold the climber, drag onto the painted leaning board and let go: he jumps on and climbs hold to hold as you drag him up or down
(one hold per 48 px). All in the `HOME CLIMB` block in `crux.html`, ported from the dev prototype `dev/climb-lab.html` (frames in `dev/climb-frames/`).
- **Entry:** the Home perch gesture (`perchAim` / `perchRelease`). A drop that is within 4% of the scene width of a decoration or gear hold still perches there (hooks marked `// HOME CLIMB hook`);
  a drop on the board (`climbHit`, polygon `climbBoard` on the `homewall` row of `ENVIRONMENTS`, in painting px) mounts. Off the board it is a tap, as before. The ring while aiming is the board's visible box.
- **Frames** (all through `climberFrame()`, drawn on `#characterStage`, so variants and outfit layers follow): stances `climb/climb-reach-left` (RL) and `climb-reach-right` (RR) alternating; `climb-chalk-up` for the chalk rest
  (3 s idle; mirrored when the high hand is the left, so gear can flip sides there); `jump/jump-01..03` to mount, `jump-02` then `land/land-01..02` to fall; `idle-01` once back on the floor.
  **Two in-between frames, runtime assets** `assets/mascot/climber/default/climb/climb-mid-reach-right-v2.png` and `climb-mid-reach-left-v2.png` (640x960 RGBA; `IMG.wall.cl_mid_r2` / `cl_mid_l2`, blob ids empty until Claude uploads them, rule 2;
  the build ships every `asset()` address, so they are in the installed app's file list). **Default colours with no outfit only** (`climbMidOn()`): any other variant or any equipped outfit takes the no-mid path (the stance frame of the next hold,
  pinned about the same fist and swung to put the torso where it was: a visible pose swap at the start of each move, then smooth). Never mirrored (except the chalk frame).
- **Scale:** `CLIMB_REL = 0.09` (px per 1024-frame unit on a 375 px wide scene; the lab was 0.11; 0.095-0.10 left only 3-4 holds on a small phone). He is about 40% of the floor climber's size.
- **Placement:** one CSS transform on `#characterWander` (`translate rotate scale`, `transform-origin` = the pinned frame point) pins a frame point to a scene point (`climbDraw`); the measured frame points are in `CLIMB_A` (1024 units).
  The route (`climbBuildRoute`) is built per scene size in scene px: as many holds as fit (3-8), every hold, sole and the head at least 7 px inside the board and the visible window below the top chips; the start hold and footholds are drawn
  as `.climb-holds` images. Resize / re-render re-fits it (`climbRelayout`, via `perchSync`) and keeps him on the same hold.
- **Moves:** `climbPreviewSpec` (mid frame or swung next stance) tweens 120 ms; the pinned fist stays on its hold (drift < 0.6 px in the tests). A fling down (> 1.2 px/ms over >= 16 ms) or dragging 40 px off the board is a fall
  (`climbFall`: gravity arc, scale up to the floor climber, land frames). A tap on the board does nothing. Hidden tab, leaving Home, Arrange, a room change and a level-up all end it on the floor at once (`dismountHome` -> `climbEnd`).
- **Reduced motion:** no mount / fall animation, no swing or mid frames, no chalk rest, no timers: stances are placed directly.
- **In memory only:** `homeClimb`; no saved field, no new localStorage key (the "Home climb:" tests check the save and a backup round trip are untouched). Test hook `window.__cruxClimb`, only under `__cruxTest`.
- **Honest looks (phone 375x740):** the mid-move pose swings far (up to about 60-70 degrees, near horizontal at the end of a move) and the legs can swing past the board's right edge for a moment; the no-mid swap pops the head by about
  a quarter of the body width; the figure is a little wider than the board at its lowest stance. Not verified on a real phone (touch drag, `touch-action:none` while on the board).
- **To remove:** delete the `HOME CLIMB` block, the `climbBoard` row of the `homewall` environment, the `.climb-holds` / `.character-wander.climbing` CSS, the `cl_mid_r2` / `cl_mid_l2` rows and the two `climb-mid-reach-*-v2.png` files,
  every `// HOME CLIMB hook` line (`playHop`, `dismountHome`, `perchSync`, `perchAim`, `perchRelease`, the perch `pointerdown`, `perchTravel`, `perchTo`, `PERCH_NEAR_BOARD`), and the "Home climb:" tests. `dev/climb-lab.html` can stay.

## Projects (climb tracking)

A project is **one named climb at one gym or crag**, and attempts link to it by `projectId`.
- **Same name at different gyms means separate projects.**
- **A typed name only auto-joins a project with the same name and the same gym.**
- **When either gym is unknown,** the app asks ("Use …" / "Keep separate") instead of linking.
- **Older entries with no location** get their own "Location not set" project and are never merged
  automatically.

See `linkProjects()` and `projectChoicesFor()` in `crux.html`.

## Today's plan

At the top of each session, `planFor()` in `crux.html` picks a warm-up, a main workout from
the timer drills, and a finish.
- **It runs on plain rules,** with no Claude involved: days since the last session, sessions
  this week, the hardest boulder send, and recent fall reasons.
- **Never auto-suggest the hangboard protocols** (Max Hangs, Repeaters) because of their
  finger-injury risk.
- **Keep the advice conservative** and the copy short.
- **Its tests** are the "Today's plan" checks in `dev/tests.html`.

## Workouts (Phase 0, built 2026-10-04)

There's a local workout library (`state.workouts`), built-in examples, an editor (Advanced
only), and a runner that steps through a workout inside a normal session. The code is in
`/* ---- workouts (Phase 0: local) ---- */` in `crux.html`.
- **The format** is Workout document v1 (`docs/coaching/DESIGN.md` section 5), checked by
  `validateWorkout()`.
- **Timed parts** run on the existing timer through `loadTimerProgram()`, a list of phases.
  With no program loaded, the timer must behave exactly as it always has, and the tests check
  this.
- **A climbing step** counts the normal Flash/Send/Fall logs. **Undo and deleting an attempt**
  call `workoutOnRemove()`.
- **The result** is saved on the session as `session.workout`: per-step status, plus
  `result: {rpe, note}`.
- **No hangboard protocols** among the built-in examples.
- **Per-set log (optional):** Advanced + `settings.timerSetLog` (default off). After a program's WORK phase a small strip (kg, RPE 6-10) can append `{ts,label,tag,load,rpe}` to `session.setLog` (separate from `session.workout`, so the v1 format is unchanged; migrated in `normalizeState()`). Never read by `recomputeProfile()`/XP.

## Workout timer (2026-10-16)

Built on the timestamp engine and `loadTimerProgram()`; free mode (no program) is unchanged apart from the small "Next:" line.
- **Builder:** `compileTimerConfig(cfg)` turns `{work,reps,repRest,sets,setRest,leadIn}` into a phase list (GET READY lead-in is phase 0, set rest replaces rep rest, no trailing rest, tags "REP r/R · SET s/S"). Loaded with `meta {kind:"custom"}`; `timerProgramDoneHook` ignores custom. Only the Reset *button* keeps a custom program (`resetTimer({keepCustom:true})`); every other caller clears it.
- **Controls:** `timerSkip(dir)` and `timerAddMs(15000)` work on programs only (custom and workout steps); `timer.extraMs` tracks +15s so Back and the progress bar stay right. Skipping past the end uses the same `finishTimerProgram()` as a natural end.
- **Sound:** `settings.timerVolume` (70 = original loudness), `timerVibrate`, `timerVoice`. Timer-only: games use `gmBeep`/`gmBuzz` and are not affected. Beeps stay the source of truth; speech is additive.
- **Full screen:** `timer-full` CSS overlay on `#timerCard` (no Fullscreen API). Escape/Exit leaves; it also leaves when the session view hides.
- **Saved timers:** `state.customTimers` (cap 30, normalised by `normCustomTimers()`); pinned ones are chips at the start of `#presets` in Simple and Advanced, the builder and save/rename/delete are Advanced only. Reset progress keeps them; Reset all data clears them. `planFor()` never reads them.
- **Per-set log:** see the Workouts section above. Off by default, Advanced only.
- **Tests:** `dev/tests.html`, sections "timer builder", "skip", "sound", "full screen", "saved custom timers", "Set log".

## The Wall (beta, removable)

The Wall is a streak ladder, added 2026-10-04. Each day you log something, your climber moves
up one hold:
- **What counts:** a session with climbs, a finished workout step, or a rest day.
- **Unlocks:** every hold unlocks something, and every 7th hold is a ledge with a bigger prize.
- **Where it lives:** a card on Home, and its own view (`view-wall`).

**How it works:**
- **Holds aren't stored.** `wallDayMap()` works them out from sessions plus `state.restDays`.
- **Saved data** is only `state.restDays` (local day numbers from `planDayNum`) and
  `state.wallSeen` (how far the climber animation has played).
- **Unlocks are display-only for now,** except the four climber moves and the Home Wall gym
  (hold 21). Other unlocks don't give Garage items yet, and the copy says so. Moves are real: your climber does the newest one after
  each unlock card closes, and tapping your climber cycles through the ones you have
  (`WALL_MOVES`, `wallPlayMove()`).
- **The climber on the Wall** chalks up, reaches, pulls up and catches the next hold (`wallHop()`),
  sits on a ledge (now and then glancing at the prize), stands on the summit lip waving the flag at
  hold 42 (`wallIdleTick()`), and a rest day's unlock card shows the tea pose. The two summit-flag
  frames are wider than the standard canvas (`PadX` in `HeadFit.cs`), so `wallShow()` draws them at
  141% width.
- **The art** is in `assets/wall/`, made by `dev/build-wall-art.ps1` from ChatGPT's sources
  (the originals are in `../art-source/wall/incoming/` for round 1 and `incoming-2/` for round 2,
  which uses the `r2_` names). The ceiling texture comes from `dev/build-room-art.ps1`. It's
  uploaded, with blob ids in `IMG.wall`. The prototype page is `dev/wall-prototype.html`.
- **The climber poses** are in `assets/mascot/climber/default/{climb,sit,rest,move}/`. They're
  made by `../art-source/tools/normalize-wall-climber.ps1`, which locks each head to idle-01
  (`HeadFit.cs`) and removes the soft glow ChatGPT left around some frames. A new pose goes
  through that script, never straight from the generator. The snow summit and autumn ledge
  sources are unused, kept for seasons.
- **Some round-1 cutouts were clipped at their edges** (shoes, string lights, shelf, gear bag and the
  purple, grey, blue and red holds). Round 2 redrew them cleanly, and the old versions are out of
  use. The hold rotation is `WALL_HOLD_ART`: 21 whole pieces, picked with a stride of 5.
- **Seasons:** autumn leaves on the shelves (Sep-Nov) and snow on the summit (Dec-Feb), from the real date
  (`wallSeason()`; Developer tools can force one). The seasonal pictures are cropped to overhang the plain ones by
  known amounts (numbers in `dev/build-wall-art.ps1`); do not re-export one without the other.
- **Streak rescue:** if yesterday is missing but the day before was logged, Home offers "Log it as a rest day"
  (`wallRescueBtn`, in `renderWallCard()`).
- **Hold sizes** come from each picture's proportions (`WALL_HOLD_SHAPE`, `wallHoldSize()`), so every hold
  has about the same visual weight; thin holds stay nearly level. A new hold picture needs its proportion
  added there (short side over long side), and the Garage decoration holds in `ACCESSORIES` are sized the same way.
- **The Wall** also has Me / Top jump buttons, and the end-of-session summary offers "Climb a hold on the
  Wall" when the session earned a hold you haven't watched (`wallEndSummary()`, the sixth `// THE WALL hook`).
- **Painted icons** (`r2_icon_*`) are on the Climb / Workout / Rest day buttons and the unlocks
  pill. Prizes stand on `r2_plinth` in the unlock card (a gym shows as a tilted photo instead).
  Above the top-out is a CSS ceiling using `r2_ceiling.jpg`.
- **The summit's lip is the last ledge** (hold 42), with a CSS ceiling above it. The next-unlock
  tag is placed beside or above the next hold, away from your climber (`wallPlaceTag()`).

## Rooms (the gyms)

Five painted rooms: The Garage, Home Wall (level 8), The Local (15), The Mountain Club (24) and
The Dream Gym (40). Home Wall also unlocks at Wall hold 21.
- **Each room** is an entry in `ENVIRONMENTS` in `crux.html`: `bg` (the painting and its `floor`
  line), `thumb`, and `fx` (lamp glows and drifting motes). `paintedRoomSVG()` scales every painting
  so its floor line lands on `ROOM_FLOOR_Y`, the same line the Garage uses, so the climber, gear and
  decorations stand on the floor in every room. To add a room, add an entry, its images in
  `IMG.rooms`, and its five decorations in `ACCESSORIES` (with `from`).
- **Decorations** work in any room; the ones that belong to a room (`from`) appear in Customize once
  that room is unlocked. They're placed with `foot` (the bottom edge) or `y`, and `ar` (height over
  width of the trimmed picture). Arrange mode lets people move any of them.
- **The art** is made by `dev/build-room-art.ps1` from ChatGPT's sources in
  `../art-source/rooms/incoming/` (backgrounds and thumbnails are JPEGs, decorations are trimmed
  PNGs). Backgrounds load only when their room is on screen.
- **Developer tools** are hidden until you tap the Settings title five times (or open the page with `?dev=1`).
  They hold "Pretend level" (raises the level that gates rooms, gear and badges; it never changes XP or
  history, see `recomputeProfile()`), "Pretend Wall streak" (fake days for the Wall, never saved as
  history, see `wallDayMap()`) and "Preview every gym".
- **The celebration card** (`celebrate()`) shows when a new gym or new gear unlocks, one at a time,
  and on every 5th level that unlocks nothing else (`celebrateLevel()`, with the level badge and the
  cheering climber). A pretend level shows them too, which is how to test them.
- **A room's painting rules** (floor line, empty middle, calm bottom-right corner) are in
  `docs/art/ROOMS-BRIEF.md`.

## Art briefs for ChatGPT

- **`docs/art/WALL-ART-BRIEF.md`** is round 1 and **`WALL-ART-BRIEF-2.md`** is round 2: both done and
  in the app (round 2 skipped the optional extra climber poses).
- **`docs/art/ROOMS-BRIEF.md`**: done and in the app (four rooms, 28 images).
- **`docs/art/ART-BRIEF-3.md`**: made and mostly in the app (originals in `../art-source/round3/`).
  In use: the seven painted Home icons, level badge, empty-logbook picture, the clean hangboard and
  mountain print, and the climber poses (summit flag, cheer, chalk-up, ledge look). Not used yet: the
  app icon (a home-screen icon needs the page installed as an app), the mono app icon (rough edges, needs
  a redraw) and the streak banner. Home art lives in `assets/ui/` so it survives removing the Wall.

ChatGPT makes the images in its own folder; Claude copies them to `../art-source/.../incoming*/`,
exports them, uploads them and wires them in.

**Rooms use the Wall in one place:** a gym can have `wallHold`, and `unlockedEnvironments()` then also
unlocks it at that Wall hold. That is the fourth `// THE WALL hook` line.

**The owner may remove it if the art doesn't come together. To remove it:**
1. Delete every block between `THE WALL` and `END THE WALL` markers in `crux.html` (CSS, Home
   card markup, the view markup, `IMG.wall`, and the JS block).
2. Delete the six `// THE WALL hook` lines (in `switchView`, `renderHome`, `unlockedEnvironments`,
   `renderSettingsModal` and `showEndSummary`), the summary's Wall button, the "THE WALL dev tools" block in the Developer settings, and the
   `devWallDays` and `devSeason` settings.
   Keep `assets/wall/` files `rays`, `sparkle`, `r2_plinth`, `r2_lights`, `r2_hold_*`, `r2_shelf`,
   `r2_shoes` and `r2_gearbag`: the celebration card and Garage decorations also use them.
3. Delete the Wall tests in `dev/tests.html`, the `assets/wall/` folder, and the climber's
   `climb`, `sit`, `rest` and `move` folders. **Home perch uses `IMG.wall.cl_reach_l/r`, `cl_pull`, `cl_chalk`, `cl_sit` and `cl_sit_look`**
   (the climb and sit frames). If any of those six is missing, `perchWallArt()` is false and the perch falls back to `stand` / `beside`;
   that clean fallback only holds for a partial removal of the climb / sit frames. Removing the whole `IMG.wall` breaks the existing ACCESSORIES lines
   that use `IMG.wall.*` pictures (the Garage decorations), so keep those regardless.
4. `restDays` and `wallSeen` can stay in saves: they're harmless. Or remove them from
   `defaultState`/`normalizeState`.

To switch it off without deleting anything, set `WALL_ENABLED = false`.

## Real coaches (planned, not built)

The design for linking athletes to real coaches is in `docs/coaching/DESIGN.md`, with a draft
database schema in `docs/coaching/schema.sql`.
- **Hard limits:** no messaging, chat, comments, feeds or followers. The only text allowed is a
  coach note on a workout and an athlete note on a result.
- **Don't start a phase without the owner's go-ahead,** and say which phase you're working on
  in commit messages.
- **The workout format** in DESIGN.md section 5 is the shared contract. Don't change it in one
  place only.
  - It has six primitives: instruction, timed, intervals, climbing, setsReps and rest.
  - Templates are frozen into assignments.
  - Training blocks are real objects.
- **The model was approved on 2026-10-04,** with all three open questions answered as proposed.
  Phase 0 is built (see Workouts above). Phases 1+ need the owner's go-ahead.

## Log sheet and sharing

- **Recent climb names:** the log sheet's climb-name box shows up to three recent names as chips (this gym's
  first), filtered as you type (`recentClimbNames()`), instead of the browser's long dropdown. The attempt editor
  still uses the old dropdown.
- **Share a send:** the end summary ("Share your best send") and the attempt editor ("Share this send") draw a
  1080x1350 picture on a canvas (`drawShareCard()`): the current room, your cheering climber, the climb, grade,
  gym, date. Nothing is uploaded: it is saved with the `downloads` capability (the iPhone Claude app opens its
  share sheet; elsewhere it downloads). If a picture fails to load, the card is still made without it.

## Coach (AI, being phased out)

The AI coach writes a short debrief of a finished session, and a "what to try next" tip for a
project. It uses the published page's `sample` capability (see `/* ---- coach ---- */` in
`crux.html`).
- **Only on a tap, never automatically.** Each answer uses the viewer's own Claude usage, and the
  first asks permission.
- **Fully hidden where Claude isn't available,** including local testing. Use the fake Claude in
  `dev/tests.html` to see it locally.
- **Session debriefs are saved** on the session as `coach: {text, ts}`.
- **Keep the privacy note** in the Safety, privacy & terms sheet accurate if what's sent changes.

## Tests: run them before every commit that touches `crux.html`

Open http://localhost:8765/dev/tests.html (any static server pointed at this folder works). It
loads the real `crux.html` with its own private, in-memory save, so it never touches real data.
It runs about 40 checks in roughly 2 minutes:
- logging, Undo, sessions and reloads
- the save key
- old-save migration and backup import/export
- every project rule
- Today's plan, and every workout step type on the real timer
- that only the climber art is used
- publish readiness

- **All checks must pass before you commit.** A FAIL means you broke something the owner relies
  on. Fix the app, not the test. Change a test only when the owner has explicitly changed the
  behaviour it checks, and say so in the commit message.
- **A WARN isn't a blocker for local work,** but it must be cleared before publishing. Right now
  it lists images with no uploaded copy.
- **New behaviour the owner cares about gets a test** in `dev/tests.html`.
- **Results** are on the page, in `document.title` ("Crux tests: PASS …" or "FAIL …"), and in
  `window.cruxTestResults` for scripts.

## Working practice

- **Git is the safety net.**
  - Commit before you start and when you finish, with a clear message.
  - Don't leave work uncommitted, and don't make `*.before-x.html` backup copies; use a commit instead.
  - The `art-source` repo is separate and needs its own commits.
- **One assistant at a time on `crux.html`.** It's one large file, and parallel edits clobber each
  other. Check `git status` and `git log` first, so you know what changed since you last looked.
- **Testing locally.**
  - On this machine (Windows), Python and Node are not installed. The local server is a
    PowerShell HttpListener defined in `.claude/launch.json` and served at
    http://localhost:8765/crux.html. Any static file server works too.
  - Before testing, back up the save (`localStorage["crux-app-state-v2"]`), and restore it when done.
  - Fake test climbs are fine.
  - Check both desktop and phone widths (375 px), with no horizontal scroll and no console errors.
- **Match the existing design.** Use the CSS variables on `:root` (they already handle dark mode),
  the existing `.btn`, `.chip`, `.link-btn` and `.composer` styles, and plain-English UI copy.
- **Report back plainly:** what changed, how to try it, what you tested, and anything you skipped
  or weren't sure about.
