# Crux Games: design doc (branch feat/minigames, base 2396fe7; sections 1 and 2 updated for games-v2 on 2026-10-12)

Status: design doc, kept in step with the built games (section 8 has the tuning tables). Audience: the shell builder and three game builders.
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
| 1 | Dyno | Chalk Rhythm (cut 2026-10-12) | Charge-and-release timing with a real climbing action: hold, let go in the band, latch the next hold or drop a ledge. |
| 2 | Route Read | new (reworked 2026-10-12 as a spray wall) | Reading a problem before you pull; two interleaved routes make it a real read, and a wrong tap loses the route. |
| 3 | Summit Stack | new (v2 2026-10-12) | One-tap drop with a visible payoff; v2 adds a topple rule and a real speed ramp so it can be failed. |
| 4 | Wall Run | Reach Timer (retired 2026-10-12) | Three lanes, seeded holds rushing down; tap the lane as a hold reaches the hands. Replaces the left/right reach game that was too easy. |

Phase 2: Daily Boulder (section 7). Not on the menu in v1.

Hold Hop is retired from the menu. Its saved `state.games.holdHop` is preserved by gamesNormalize (unknown ids are kept) and shown nowhere.
Known Hold Hop bugs that motivate the cut: rocks could be unavoidable (lane changed only by climbing), hit zone was 22% of the fall with no reaction floor, abandon at score 0 was not counted, hiding the tab abandoned the round.

## 2. Games

Common vocabulary. Frames come from `gmFrames()` (extended in the shell task). Existing frames only:
idle[0..n], blink, step, jump, land, climb-reach-left, climb-reach-right, climb-pull, climb-chalk-up, cheer-1..3, chalk-clap-1..3, ledge-sit, ledge-sit-look, summit-flag-1..2. Variant and outfit come from climberFrame() + outfitFollow(). New gmFrames keys: `step, jump, ledgeSit, ledgeLook, flag` (resolve through the same gmWall/gmMoves lookup `gmFrames` already uses; fall back to idle[0]).

Judgement labels (text + shape, never colour alone): "Perfect" (double ring), "Good" (single ring), "Close" (open dot).

### 2.1 Dyno (id `dyno`; replaces the cut Chalk Rhythm, 2026-10-12)

Why: the owner found the ring-on-a-beat game "weird", not a climbing action. Dyno is the dyno itself: charge, release, latch or fall.
Rules: hold anywhere to charge; the power meter rises and falls (triangle wave, one cycle 2.2-4.0 s, speed differs per hold). The target hold is
drawn at the height the meter must reach, with a band on the meter (and a dashed line from the hold to the meter). Release with the bar in the band:
the climber latches (+1 height, camera moves up, next hold farther and its band narrower). Short or over: the climber falls one ledge to the
previous hold and the round goes on (no fail state; a fall costs ~1.1 s and the peak is kept). A fall retries the same hold (seeded per hold).
Controls: press and hold with a finger, or hold Space/Enter; a second finger cannot release the first; presses during flight/landing are ignored.
Round: 45 s. Score = peak height. Extra: `cleanBest` (catches in the central 40 % of the band).
Ramp (by hold number, plateau at hold 15): band window 900 -> 420 ms of release time, cycle 3.3 s -> 2.8 s (x0.8-1.2 per hold), target level 0.28 -> 0.68 of the meter.
Hardest window is never below 400 ms (test asserts `w*T >= 400` for 500 seeds x 40 holds). The ideal release is also reachable on the falling pass.
Failability: the meter speed changes every hold, so a human reacts to the bar instead of timing a known interval. Bot pass rate at the hardest hold:
beginner ~42 %, average ~69 %, strong ~92 %; perfect player ~28 holds, strong ~21, average ~16, beginner ~9 (`dev/dyno-bot.js`).
Feedback: label "Latched" / "Latched, clean" / "Short" / "Over"; a bar mark stays at the release level. Frames: pull while charging, jump in flight,
reachL/R on a latch, hit on a fall, cheer on a new best. Sound: soft rising tick on a latch, low tick on a fall; silent when sound is off.
Reduced motion: the meter is a flat horizontal bar, no wobble, no flight or scroll animation (positions snap), same rules.
Art slots: `dy.ledge` (ground), `dy.hold` (hold), `card.dyno`.
Schema: `games.dyno = { best, plays, cleanBest }`. Saved `chalkRhythm` and `chalkUp` data are kept untouched (unknown ids are preserved by gamesNormalize).

### 2.2 Route Read (id `routeRead`; spray wall, reworked 2026-10-12)

Rules: a 5 x 5 irregular spray wall (holds only where `routeWall(seed, n)` puts them; empty cells are blank). Two routes are interleaved on it,
each with its own colour AND shape (`RR_CODES`); one is called ("the blue triangles"). The called route lights with numbered badges for the show
time, then the numbers hide; tap its holds in order from memory. Route length N is 4 to 10, start 5; N+1 after a clean route, N-1 after a loss.
A wrong tap LOSES the route (it is re-shown for 1.8 s, then the next route; no points). Round: 60 s hard cap, ends on time.
Scoring: +N per completed route. Best = highest sum. Also `longest` (longest route completed).
Show time `routeShowMs(N) = 900 + 560 N` ms (3.1 s at N=4, 6.5 s at N=10; always >= 560 ms per hold). No per-tap deadline; the only timers are the show time and the round clock.
Generator properties (500 seeds, tests): the called route is N distinct cells in rows ascending-or-flat with drift <= 1, the decoy route has
`routeDecoyLen(N)` (3 to 7) holds, no cell is shared, the wall has clutter holds that are neither, and the called route is always readable by colour + shape (never colour alone).
Feedback: correct tap = ring + tick; wrong tap = wobble and re-show. Reduced motion: no wobble, X badge on a wrong hold, crossfades <= 120 ms.
Schema: `games.routeRead = { best, plays, longest }` (unchanged keys; old bests preserved).

### 2.3 Summit Stack (id `summitStack`; v2 2026-10-12)

Rules: a ledge block slides left-right above a tower. Tap anywhere to drop. The overlap with the block below stays; overhang is trimmed (width never
below 30 % of 320 px = 96 px). Topple rule: if the dropped block's centre is more than half a width off the tower below, the block topples and
the tower loses its top tier (score is the round's peak, so a topple never lowers best). Perfect (centre within 6 px) gives +1 and the block regains 8 % base width.
Ramp: crossing time 2400 ms falling in 50 ms steps to 1350 ms over 22 blocks (a 405 ms window at the 96 px floor); the first 3 blocks are learn blocks
(no topple, wide). The next block is visible while sliding; the slider is deterministic, only the start phase is seeded.
Flag at 30 blocks (summit frame, re-plants if the tower drops under it); play continues to the end of the 45 s round.
Feedback: Perfect = ring + label + settle bob; trimmed chunk falls (fade for reduced motion). Reduced motion: no scroll animation, no bob.
Schema: `games.summitStack = { best, plays, tallest, perfects }`.

### 2.4 Wall Run (id `wallRun`; replaces Reach Timer, 2026-10-12)

Rules: holds come down a three-lane wall in a seeded sequence (`wallNotes(seed)`); tap a hold's lane as it reaches the climber's hands. Each hold has an
early-heavy window: 350 ms early / 250 ms late at the start, tightening to 260 / 140 ms (400 ms total, reached at 25 s, then a plateau). A hold is on the wall
2.0 s falling to 0.9 s (always >= 600 ms of sight before its window). Mean gap 950 -> 400 ms with 22 % chance of a short run of 2 to 4 holds at the fastest
fair spacing; floors by lane distance 280 / 340 / 420 ms; the same lane at most 3 in a row. A hit climbs one move; a miss, a late tap or a stray tap slips one move
(floor 0; one stray slip per 350 ms; the round goes on). Round: 45 s. Score = peak height.
Controls: three full-height lane buttons (>= 56 px), keys 1/2/3 or arrow keys. Reduced motion: the next three holds sit in fixed rows with a fuse bar, no scroll.
Art slots: `wr.hold`, `card.wallRun`. Schema: `games.wallRun = { best, plays, longestRun }`.
Bot: `node dev/wallrun-bot.js` pulls the pure rules out of crux.html and plays with noisy timing per band.

### 2.5 Reach Timer (retired 2026-10-12)

Off the menu and unregistered: the owner called it "all sorts of wack" in the 2026-10-12 playtest and asked for a climb-the-wall tile game (Wall Run). Its pure rules (`reach*`), `rt.*` art slots and CSS stay in
crux.html behind `RT_RETIRED_DEF`, and saved `games.reachTimer` data is kept by gamesNormalize. Chalk Rhythm was cut earlier (Dyno replaced it).

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
renderGamesMenu builds cards from GAMES sorted by `order` (no static menu HTML per game). gmIntro, gmOver, gamesWatch, hud text all go through `GAMES[id]`. Each game's code and CSS prefix lives in its own block: `dyno*`/`.dy-`, `routeRead*`/`.rr-`, `summitStack*`/`.ss-`, `wallRun*`/`.wr-` (and retired `reachTimer*`/`.rt-`).

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
- dyno: band window w*T >= 400 ms for every hold; ideal hold latches; a fall retries the same hold; human-like bot misses some (dev/dyno-bot.js).
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

## 8. Tuning tables (2026-10-12, games-v2 integration)

Generated by the human-like noisy bots in `dev/` (noise on reaction time and position per skill band; see the crux-game-bot notes). Pass rate is the share of
items (a hold, a route, a drop) the bot gets right, so a game is "fair" when beginner is passable, average mostly passes and strong passes but can still miss.

**Dyno** (`node dev/dyno-bot.js`): item pass rate by hold number (ramp tops out at hold 15).

| band | hold 1 | hold 4 | hold 8 | hold 12 | hold 15 | mean height | max |
|---|---|---|---|---|---|---|---|
| beginner | 85 % | 76 % | 61 % | 45 % | 42 % | 9.3 | 16 |
| average | 98 % | 97 % | 94 % | 82 % | 69 % | 16.2 | 23 |
| strong | 99 % | 98 % | 98 % | 97 % | 92 % | 20.9 | 24 |

Perfect player 28 (26 to 30); a player who never releases scores 0.

**Route Read** (`node dev/route-bot-run.js`): pass rate by route length N (sample size in brackets).

| N | beginner | average | strong |
|---|---|---|---|
| 4 | 78 % (269) | 92 % (121) | 94 % (62) |
| 5 | 72 % (826) | 84 % (718) | 89 % (564) |
| 6 | 56 % (714) | 68 % (773) | 83 % (627) |
| 7 | 42 % (375) | 54 % (506) | 73 % (598) |
| 8 | 18 % (82) | 40 % (214) | 66 % (450) |
| 9 | 0 % (10) | 28 % (47) | 46 % (148) |
| 10 | - | - | 17 % (36) |

Mean round score: beginner 18.6 (max 26), average 23.3 (35), strong 30.0 (45).

**Summit Stack** (`node dev/stack-bot.js`, 500 seeds per band): keep % = drop not toppled.

| band | blocks 1-6 | 7-14 | 15-21 | 22+ (top speed) | mean peak | reach flag (30) | rounds with a miss |
|---|---|---|---|---|---|---|---|
| beginner | 99.8 | 95.5 | 85.9 | 82.2 | 30.2 | 16.6 % | 96.4 % |
| average | 100.0 | 98.8 | 97.4 | 94.7 | 41.2 | 76.0 % | 66.8 % |
| strong | 100.0 | 99.8 | 99.6 | 99.4 | 54.0 | 98.0 % | 13.0 % |

**Wall Run** (`node dev/wallrun-bot.js`, 300 seeds): hold pass rate by quarter of the round (Q4 = hardest, 33.75 to 45 s). About 105 holds per round.

| band | Q1 | Q2 | Q3 | Q4 | all | mean height | p10 | p90 | max |
|---|---|---|---|---|---|---|---|---|---|
| beginner | 80 % | 74 % | 70 % | 69 % | 72 % | 42.9 | 32 | 54 | 67 |
| average | 93 % | 89 % | 84 % | 84 % | 87 % | 76.6 | 67 | 86 | 97 |
| strong | 97 % | 97 % | 96 % | 96 % | 96 % | 98.2 | 92 | 104 | 111 |
| beginner, tempo stress | 75 % | 65 % | 60 % | 59 % | 63 % | 23.1 | 14 | 33 | 51 |
| average, tempo stress | 90 % | 82 % | 76 % | 75 % | 79 % | 57.1 | 46 | 68 | 85 |
| strong, tempo stress | 97 % | 95 % | 92 % | 91 % | 93 % | 89.5 | 81 | 98 | 106 |

Null bot (no taps) max 0; spam bot (cycles lanes at 6.7 Hz) mean 4.1, max 10.
