# Crux Games: design doc (branch feat/minigames, base 2396fe7)

Status: design only. crux.html is not touched by this doc. Audience: the shell builder and three game builders.
Sources behind the research notes are blog-grade; fairness and physiology points are inferred, not measured.

## 0. Principles (apply to every game)

- Games live in REST (30-90 s). Calm over frantic. One thumb. Tap anywhere or left/right halves. No lose state that wastes rest.
- Rounds are 30-60 s. Best score only. No XP, no streaks, no rewards, no "you lost X" copy.
- Teach by failing once: the failure shows the answer (the correct route, the missed beat), never a penalty.
- Ramp by item count and gentle speed, plateau inside one round. Hardest reaction window >= 400 ms.
- Every generated hazard/pattern is solvable by construction (seeded generator + property tests).
- Colour is never the sole signal (shape + label + position). Tap targets >= 56 px. Reduced motion has a variant.
- Time uses performance.now() deltas, never frame counts. Loop stops when hidden; the round pauses, never abandons.
- No "Play again" prompt appears in the last 10 s of rest. At rest end the round closes itself and hands back to the timer.

## 1. Lineup (4 games on the menu)

| # | Game | Replaces | Why (2 lines) |
|---|------|----------|---------------|
| 1 | Chalk Rhythm | Chalk Up (rework) | Slow 60-70 bpm tap-on-beat is the calmest rest game and the app already has the ring UI; we polish, add forgiving windows and sound. |
| 2 | Route Read | new | Memory of a hold route is on-theme (reading a problem before you pull) and is untimed per tap, so it never panics. |
| 3 | Summit Stack | new | One-tap drop with a visible payoff (climber on top, summit flag) gives the "one more block" pull without a fail state. |
| 4 | Reach Timer | Hold Hop | Keeps the left/right reach feel Hold Hop had but removes falling rocks: a single telegraphed target, always solvable. |

Phase 2: Daily Boulder (section 7). Not on the menu in v1.

Hold Hop is retired from the menu. Its saved `state.games.holdHop` is preserved by gamesNormalize (unknown ids are kept) and shown nowhere.
Known Hold Hop bugs that motivate the cut: rocks could be unavoidable (lane changed only by climbing), hit zone was 22% of the fall with no reaction floor, abandon at score 0 was not counted, hiding the tab abandoned the round.

## 2. Games

Common vocabulary. Frames come from `gmFrames()` (extended in the shell task). Existing frames only:
idle[0..n], blink, step, jump, land, climb-reach-left, climb-reach-right, climb-pull, climb-chalk-up, cheer-1..3, chalk-clap-1..3, ledge-sit, ledge-sit-look, summit-flag-1..2. Variant and outfit come from climberFrame() + outfitFollow(). New gmFrames keys: `step, jump, ledgeSit, ledgeLook, flag` (resolve through the same gmWall/gmMoves lookup `gmFrames` already uses; fall back to idle[0]).

Judgement labels (text + shape, never colour alone): "Perfect" (double ring), "Good" (single ring), "Close" (open dot).

### 2.1 Chalk Rhythm (id `chalkRhythm`)

Rules: a ring grows toward a fixed outline once per beat. Tap when it meets the outline. A missed beat just scores 0 for that beat and the next beat comes; there is no reset, no fail.
Controls: tap anywhere (also Space/Enter). Round: 45 s.
Scoring: Perfect 3, Good 2, Close 1, miss 0. Score = sum. Best = highest sum.

| Phase | Time | BPM | Beat length | Perfect | Good | Close |
|---|---|---|---|---|---|---|
| Warm | 0-15 s | 60 | 1000 ms | +-80 ms | +-160 ms | +-280 ms |
| Mid | 15-30 s | 64 | 937 ms | +-80 | +-160 | +-280 |
| Hold | 30-45 s | 70 | 857 ms | +-80 | +-160 | +-280 |

Reaction floor: the Close window total (560 ms) exceeds 400 ms at the fastest tempo. Max possible score about 3 x 48 = 144.
Fairness: beats are on a fixed grid from round start, one tap is attributed to the nearest unclaimed beat within the Close window; double-taps cannot claim two beats; the ring is always visible >= 60% of the beat. No hidden beats.
Feedback: ring pulse + label under the outline; chalk puff on Perfect (GAME_ART `cr.puff`). Miss: ring fades, no shake.
Frame map: idle[0] resting; `chalk` (climb-chalk-up) on Perfect for 300 ms; `clap` frames (chalk-clap-1..3) cycle every 8 consecutive non-miss beats; end: cheer-1 if new best else idle[0].
Reduced motion: ring does not scale; instead a bar fills left-to-right and the outline is a fixed line. No puff animation; label only.
Sound (optional, soft): a 200 Hz wood-click tick 60 ms at beat 0.15 volume (below timer beep volume, different pitch) on Perfect/Good only; none on miss. Silent when sound off. Haptic: buzz(8) on Perfect only, skipped on reduced motion.
End screen: "Nice breathing." big score, "Best N" or "New best." Buttons "Again" and "Games" (hidden if rest has <= 10 s left; see rest mode).
Rest mode: see section 4.6.
Schema: `games.chalkRhythm = { best, plays, perfectBest }`. Legacy `chalkUp` best is copied once on first load (`best` only, plays reset) so no score is lost; chalkUp key preserved.

### 2.2 Route Read (id `routeRead`)

Rules: a 3-column x 5-row hold wall shows. A route of N holds lights up with numbered badges (1..N) for the show time, then the numbers hide and the holds look identical. Tap the holds in order from memory. Completing the route: climber moves up, next route has N+1 (to max 8). Wrong tap: the route re-shows with numbers for 1.5 s ("That was close, here it is"), the tapped holds reset, same route again, then next route is N-1 (min 4).
Controls: tap a hold (hit area >= 64 px, snaps to nearest hold within 16 px of the target). Round: 60 s hard cap; round ends on time. No fail state.
Scoring: +N points per completed route (N = its length). Best = highest sum. Also track `longest` (longest route completed).

| Route length N | Show time | Between routes | Notes |
|---|---|---|---|
| 4 (floor) | 2.6 s | 0.8 s | only after a miss |
| 5 (start) | 3.0 s | 0.8 s | |
| 6 | 3.4 s | 0.8 s | |
| 7 | 3.8 s | 0.8 s | |
| 8 (cap) | 4.2 s | 0.8 s | plateau; stays at 8 |

There is no per-tap deadline; the only timer is the round clock (and the show time). Reaction window: n/a (untimed taps).
Generator (seeded, `routeGen(seed, N)`): pick one cell per row from the bottom, strictly ascending, column drift <= 1 per row, and for N > 5 allow two holds in a row only if in different columns; all holds distinct; no row empty gap > 1. Always solvable because the route is a subset of displayed holds.
Fairness property: the show time per hold >= 500 ms (min is 3.0 s / 5 = 600 ms); route holds never share a cell.
Feedback: correct tap = hold gets a ring + soft tick; wrong tap = hold wobbles, route re-shows. Final route completed with N=8: climber `flag` frame 1.2 s.
Frame map: idle while memorising; `reachL`/`reachR` (climb-reach-left/right) for the next hold by column (left col = reachL, right col = reachR, middle = pull); `pull` on route complete; `land` on re-show; end: cheer if new best else `ledgeSit`.
Reduced motion: no wobble; wrong hold shows an X badge; transitions are crossfades <= 120 ms.
Sound: soft rising 3-note chime on route complete (440/554/659 Hz, 80 ms each, 0.1 vol). Wrong: nothing (visual only).
End: "Good reading." score, "Longest route N". Buttons as above.
Schema: `games.routeRead = { best, plays, longest }`.

### 2.3 Summit Stack (id `summitStack`)

Rules: a ledge block slides left-right above a tower. Tap anywhere to drop it. The overlap with the block below stays; any overhang is trimmed off. A drop that misses entirely makes the block fall off, the tower is unchanged, and the next block comes (no fail, no height loss). The climber stands on the top block. At 20 blocks: summit flag frame, round continues (plateau) for the remaining time.
Controls: tap anywhere (Space/Enter). Round: 45 s timer shown as a thin bar.
Scoring: +1 per stacked block, +1 bonus for Perfect (overlap error <= 6 px; block regains +8% base width, capped at 100%). Best = highest total.

| Block # | Crossing time (edge to edge) | Block width (of 100% = 320 css px base) | Notes |
|---|---|---|---|
| 1-4 | 2.4 s | 100% | learn |
| 5-9 | 2.1 s | trimmed width, min 30% | |
| 10-14 | 1.8 s | min 30% | |
| 15+ | 1.5 s | min 30% (plateau) | |

Min reaction window: width 30% = 96 px; crossing speed at 1.5 s over a 320 px lane = 213 px/s; window 96/213 = 450 ms >= 400 ms. Floor enforced in code: `width = max(width, 0.30 * base)`; trimming never goes below it (block is "snapped" to floor and the extra is forgiven).
Fairness: the slider is deterministic (a sine/triangle on performance.now), never random; start side alternates; the next block is visible while sliding; seeded start phase only for variety.
Feedback: Perfect = ring + "Perfect" label + tiny settle bob; trimmed overhang drops as a chunk (static fade for reduced motion). Camera scrolls so the top block sits 60% down; scroll is a transform, no layout thrash.
Frame map: `step` on each stack; `jump` at block landing for 150 ms then `land`; `flag` (summit-flag-1..2 alternating every 600 ms) at 20+; idle between; end: cheer if new best else `ledgeSit`.
Reduced motion: no scroll animation (jump cut), no bob, fade overhang.
Sound: soft low thump (110 Hz, 70 ms, 0.12) on land; Perfect adds a 660 Hz 60 ms tick.
End: "Nice stack." score, "Tallest N". 
Schema: `games.summitStack = { best, plays, tallest, perfects }` (tallest = most blocks in one round).

### 2.4 Reach Timer (id `reachTimer`)

Rules: one target hold at a time appears on the left or right half of the wall, with the next target shown as a faint ghost so the player can anticipate. Tap the matching half before it times out to reach it; the climber climbs one step. Wrong half or timeout: the climber slips down 1 step (floor 0) and the same side is not repeated more than 3 times in a row. Score is the peak height reached in the round.
Controls: tap left half / right half (large halves, labelled L and R as well as shape). Round: 45 s.
Scoring: score = peak height (steps). Best = highest peak.

| Phase | Time | Target dwell | Gap before next | Ghost preview |
|---|---|---|---|---|
| Learn | 0-10 s | 1.8 s | 0.5 s | 1 ahead |
| Build | 10-25 s | 1.4 s | 0.4 s | 1 ahead |
| Hold | 25-45 s | 1.0 s | 0.35 s | 2 ahead |

Reaction floor: the dwell is never < 1.0 s (>= 400 ms with margin); the ghost makes the response predictable.
Fairness: only one live target; the sequence is seeded (`reachSeq(seed, n)`), max 3 identical sides in a row; no simultaneous targets; the dwell timer starts only when the target is fully visible (no pop-in).
Feedback: hit = climber reaches that side (`reachL`/`reachR`), pull, step up. Slip = `land` frame + soft fade, no shake.
Frame map: idle between targets; `reachL`/`reachR` for tap side; `pull` on success; `land` on slip; `jump` for each 5th step; end: cheer if best else idle.
Reduced motion: target fades in place; no slide of the wall; a fixed ladder of 10 marks fills.
Sound: 520 Hz 50 ms tick on hit, nothing on slip.
End: "Good reach." score is the peak height, "Best N".
Schema: `games.reachTimer = { best, plays, bestStreak }` (bestStreak = longest consecutive hits in a round, shown in end screen only).

## 3. Daily Boulder (phase 2, not built in v1)

One seeded 6-move puzzle per local calendar day: a 3x6 wall with 6 numbered hold slots hidden; each move shows 3 candidate holds, one is a valid next hold given reach rules (adjacent column, +1 row). The player has 3 tries for the whole day; one-and-done (a second attempt shows the result only). Result is shared as text: `Crux Daily 2026-10-11 5/6` with squares for each move (shape: filled vs hollow, not colour only). Seed = FNV-1a of the `YYYY-MM-DD` string. Storage: `games.dailyBoulder = { lastDay, result, plays }` and `games._meta.playDays` (an array of play dates, capped 400, used only for a no-guilt "You have played on N days" line; no streak). Needs Share button via navigator.share with clipboard fallback. Skipped in v1 to keep the first PR focused.

## 4. Shared systems

### 4.1 Game registry (replaces the id==="chalkUp" ternaries at ~7098, 7292, 7316, 7334)
```js
var GAMES = {};                       // id -> def
function gmRegister(def){ GAMES[def.id] = def; }
// def: { id, title, blurb, order, intro:{title,text}, start(ctx), stop(), pause(), resume(),
//        score(), state(), rest:{ closeScore() } , art:[slotIds], frames:[keys] }
```
renderGamesMenu builds cards from GAMES sorted by `order` (no static menu HTML per game). gmIntro, gmOver, gamesWatch, hud text all go through `GAMES[id]`. Each game's code and CSS prefix lives in its own block: `chalkRhythm*`/`.cr-`, `routeRead*`/`.rr-`, `summitStack*`/`.ss-`, `reachTimer*`/`.rt-`.

### 4.2 GAME_ART slot table
```js
var GAME_ART = {
  "ss.ledge":   { src:null, w:320, h:72 },   // src:null => drawn by gmDrawSlot(id, ctx/DOM) as chunky shape
  "ss.block":   { src:null, w:320, h:72 },
  "ss.flag":    { src:null, w:96,  h:144 },
  "rr.hold":    { src:null },                // null => reuse existing hold art
  "rr.ring":    { src:null },
  "cr.puff":    { src:null, frames:4 },
  "cr.ring":    { src:null },
  "rt.hold":    { src:null },
  "rt.ghost":   { src:null },
  "ui.perfect": { src:null }, "ui.good": { src:null }, "ui.best": { src:null }, "ui.summit": { src:null },
  "card.chalkRhythm":{src:null}, "card.routeRead":{src:null}, "card.summitStack":{src:null}, "card.reachTimer":{src:null}
};
function gmArt(slot){ return GAME_ART[slot].src ? IMG-resolved <img> : simple CSS/SVG shape; }
```
Rule: every slot works with `src:null` (plain rectangles, circles, rounded rects in the app palette; no emoji). Setting `src:"assets/games/<file>.png"` swaps it without touching game logic. New PNGs need an IMG entry via `asset(path, md5)`; the shell task adds a `gmArtRegister()` helper that does this.

### 4.3 Sound toggle
New settings flag `state.settings.gameSound` (default true), a switch on the Games menu. Sounds use ensureAudio()+beep(freq,dur,vol) with vol <= 0.12 and frequencies away from the timer beep band; no game sound plays in the last 3 s of a rest countdown (never masks the timer beeps). Haptics: dedupe the two buzz() definitions (guarded one at ~3786, unguarded at ~5176; keep the guarded one, delete the second); game haptics call buzz() only if `!prefersReducedMotion()` and sound/haptic flag on.

### 4.4 Pause on hidden
`visibilitychange` -> `gm.pause()`: stops rAF, records `pausedAt`; shows a small "Paused, tap to resume" overlay; on resume the round clock is shifted by the paused duration. A paused round that never resumes records nothing (not started). Also pauses when the rest watcher says rest ended (round closes instead).

### 4.5 Seeded RNG
`mulberry32(seed)`; per-round seed = `(Date.now() ^ gameIdHash) >>> 0` unless a daily seed is requested. The seed is stored on the `gm` object so a round can be replayed in tests.

### 4.6 Rest mode behaviour
- Enters from the rest strip as today (gmFromRest). Rest remaining shown in the strip.
- At rest end: the round closes itself (`gm.rest.closeScore()` score is recorded if started and >= 1 action), a 1.8 s "Back to work" panel with no buttons, then closeGames(). Never keeps playing past rest end.
- When rest remaining <= 10 s: end screens show no "Again" button, only "Games" label hidden too; the panel reads "Rest is almost over." The round that is running continues to end naturally or until rest end, whichever first.
- Game never starts a new round automatically.
- Sounds are muted in the last 3 s of rest.

### 4.7 Best-score recording rule
A round counts (plays++ and best candidate) only if it started and has >= 1 player action. Score >= 0 is accepted (best stays unchanged when score 0). Abandon-at-0 with no action does not count. Pausing counts nothing. Implementation: single `gamesRecordRound(id, {score, actions, extra})` in the shell; extra fields (longest, tallest, perfects, bestStreak, perfectBest) are merged with Math.max.

### 4.8 State schema
```js
state.games = {
  chalkUp:{best,plays},            // legacy, preserved
  holdHop:{best,plays},            // legacy, preserved
  chalkRhythm:{best,plays,perfectBest},
  routeRead:{best,plays,longest},
  summitStack:{best,plays,tallest,perfects},
  reachTimer:{best,plays,bestStreak},
  _meta:{playDays:[]}              // phase 2
};
state.settings.gameSound = true;
```
gamesNormalize: extend the id array to the 4 new ids, clamp every numeric field (0..9999 for best, 0..999999 for plays), keep unknown keys, ignore non-array playDays.

## 5. Test plan

Pure functions live between `/*GAMES-PURE-BEGIN*/` and `/*GAMES-PURE-END*/` and are exposed as `window.__cruxGames`:
`mulberry32, chalkWindow(deltaMs), chalkBpm(t), routeGen(seed,N), routeShowMs(N), stackWidth(n,prev,err), stackCross(n), reachSeq(seed,n), reachDwell(t), recordRound(games,id,res)`.
A node script (`tests/games.test.js`) extracts the block from crux.html and runs it with `vm` (no browser).

Unit tests: window thresholds; chalk BPM per phase; routeShowMs per N; stackWidth floor never < 0.30 base; recordRound rule (score 0 with no action not counted, score 0 with action counted, best monotone, extras Math.max).
Property tests (N = 500 seeds each):
- routeGen: N distinct cells in range, rows strictly ascending, column drift <= 1, every route hold exists in the wall (solvable).
- reachSeq: no side repeated > 3 in a row; dwell(t) >= 1000 ms for all t.
- stack: for all n in 1..40, min width/speed window >= 400 ms at max difficulty.
- chalk: window total at 70 bpm >= 400 ms and beat >= 800 ms.
Integration (browser, playwright or the existing dev harness):
- Start a game from the rest strip, advance fake clock to rest end: the round closes, score recorded once, returns to timer within 2 s.
- Rest <= 10 s: no "Again" button rendered.
- Hide the tab (dispatch visibilitychange): round pauses, clock does not advance, resume works.
- Timer safety: running timer is never paused/altered by a game; game sound muted in the last 3 s.
- Sound off: beep() never called by a game.
- Reload keeps state.games; legacy chalkUp best migrated.
Screenshots at 360 x 740 and 390 x 844: menu, each intro, mid-round, end screen; check no horizontal scroll and tap targets >= 56 px. Check reduced-motion emulation once per game.

## 6. Build split (one file, no conflicts)

T0 shell/registry/art-slot/sound (must land first; one builder):
- Registry, gmFrames extension, GAME_ART + gmArt + gmArtRegister, sound flag + switch, buzz dedupe, pause-on-hidden, seeded RNG, gamesRecordRound, schema + normalize, menu from registry, remove Hold Hop card + hop code, rest hand-off rules, window.__cruxGames skeleton, tests/ harness, and four empty region blocks:
  `/* ==== chalkRhythm BEGIN/END ==== */`, `routeRead`, `summitStack`, `reachTimer` inside the games block, each with an empty CSS block `/* .cr- */` etc.
Then in parallel (each edits only its region + its CSS prefix + its entries in `__cruxGames`):
- T1 chalkRhythm (rework of chalkUp; migrate best).
- T2 routeRead.
- T3 summitStack.
- T4 reachTimer.
Then T5 integration/tests/screenshots (tester) and reviewer pass; commit locally, do not push.
Order: T0 -> {T1,T2,T3,T4} -> T5 -> review. Conflict rules: no builder touches shell functions; any shell change request goes back to T0's owner; IDs/classes use the prefix; HTML for each game is generated in JS (no static HTML edits); `__cruxGames` is extended via `Object.assign(window.__cruxGames, {...})` in the owner's own region.

## 7. Open decisions for Hayden
- Daily Boulder in the first PR or phase 2? (Recommended: phase 2.)
- Sound default on (recommended) and whether to add a haptic toggle.
- Keep legacy Chalk Up code for one release? (Recommended: remove; best migrated.)
