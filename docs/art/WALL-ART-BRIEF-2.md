# The Wall: art brief, round 2

Written 2026-10-04 for ChatGPT image generation, after round 1 (`WALL-ART-BRIEF.md`) went into the
app. Round 1 worked: the wall, ledges, summit, holds, chalk, flames and climber poses are all live.
This round fixes the pieces that look broken and adds the finishing touches that make the Wall feel
like a finished game.

## Paste this to ChatGPT

> Please read `Desktop/Crux/app/docs/art/WALL-ART-BRIEF-2.md` and make every image in it, in order.
> Save them to `Desktop/Crux/art-source/wall/incoming-2/` with exactly the file names given. Use the
> style block before every prompt, and follow the "Rules that matter" section, especially the one
> about margins. When you're done, write `HANDOFF.md` in that folder listing each file, its size,
> and anything you weren't happy with. Don't edit `crux.html` or anything in `app/`; Claude wires
> the art in.

## Rules that matter (round 1 problems to avoid)

1. **Nothing touches the edge of the canvas.** Leave at least **10% empty, transparent margin on
   every side**. Several older pieces were cut off (the shoes lost their heel and toe, the string
   lights ended in half a bulb), and a cut-off object can't be repaired afterwards.
2. **No glow, halo, haze or soft shadow around the outline.** The object ends in a crisp edge on
   fully transparent pixels. Two round-1 climber frames had an orange glow that had to be removed.
3. **Solid objects are fully opaque inside.** Only the outermost 1–2 px of the edge are partially
   transparent.
4. **No text, letters, numbers or logos** except the Crux mountain mark where an item already has it.
5. **One object per file,** centred, on a fully transparent background, with no floor and no scene.

## Style: paste this before every prompt

> Soft, painted 3D illustration style, like a cosy mobile game. Warm and friendly, with gentle
> rounded shapes, subtle texture and soft top-left lighting. Rich but not neon colours. A clean
> single object on a fully transparent background, with at least 10% empty margin on every side.
> Nothing touches the edge of the image. No glow, no halo, no drop shadow, no floor, no background.
> No text. It must match these existing Crux pieces: the textured climbing holds with a bolt hole
> in the middle, the chalk bag with the mountain logo, and the wooden wall shelf.

Attach two or three round-1 pieces from `art-source/wall/incoming/` as style references (for example
`hold-jug.png`, `ledge.png` and `golden-shoes.png`).

## 1. Replacements for broken pieces (most important)

These replace older art that was cut off at the edges. The app shows stopgaps until these arrive.

| File | Size | What |
|---|---|---|
| `climbing-shoes.png` | 1024×1024 | A pair of climbing shoes side by side, three-quarter view, the whole pair visible including heels and toes. Charcoal rubber soles and rand, bright orange uppers (the climber's own shoes are orange and charcoal), two velcro straps each. |
| `string-lights.png` | 1536×1024 | A short draped string of **four** warm Edison bulbs on a dark twisted cable. Each end finishes in a small screw hook, so the string has two clean ends. All four bulbs whole. |
| `gear-bag.png` | 1024×1024 | An olive-green duffel bag with orange straps and the Crux mountain logo, the whole bag including both strap ends visible. |
| `wall-shelf.png` | 1024×1024 | A small wooden wall shelf with iron brackets: a few books, a little potted plant and a water bottle on top; carabiners, a small chalk bag and a coiled rope hanging from hooks underneath. Nothing else beside it. |
| `hold-purple-pinch.png` | 1024×1024 | A tall purple pinch hold, slightly curved, with a bolt hole. |
| `hold-grey-pocket.png` | 1024×1024 | A round speckled grey hold with one deep two-finger pocket and a bolt hole. |
| `hold-blue-volume.png` | 1024×1024 | A blue triangular wall volume (a big three-sided wooden-looking pyramid shape painted blue) with a few T-nut holes. |

## 2. More holds, for variety up the wall

The wall now rotates through 12 holds. Six more make it feel hand-set. Each is **1024×1024**, a
single hold seen from the front, with a bolt hole.

| File | What |
|---|---|
| `hold-mint-edge.png` | A thin mint-green crimp edge, wide and shallow |
| `hold-sand-sloper.png` | A big round sand-coloured sloper with a rough grippy texture |
| `hold-red-jug.png` | A chunky red jug with a deep lip |
| `hold-navy-pinch.png` | A navy blue pinch shaped like a small fin |
| `hold-yellow-pocket.png` | A yellow hold with a single deep finger pocket |
| `hold-wood-edge.png` | A wooden edge hold with visible grain and a darker oiled finish |

## 3. Finishing touches

| File | Size | What | Where it goes |
|---|---|---|---|
| `topout-ceiling.png` | 1024×1024 | The **gym ceiling above the top of the wall**: dark wooden rafters running across, warm shadows, a little dust in the air, softly lit from the middle. **Not transparent:** this one fills the whole square. Its left and right edges must tile seamlessly. No lamp (the app hangs its own bulb). | Behind the summit at the top of the Wall, replacing a plain CSS gradient. |
| `reveal-plinth.png` | 1024×768 | A small round wooden display plinth (like a museum stand made of plywood with a brass trim ring), seen slightly from above, empty on top. | The prize stands on it in the unlock card. |
| `icon-climb.png` | 512×512 | A small painted icon: a little mountain with a teal Crux pennant on top. | The Climb button. |
| `icon-workout.png` | 512×512 | A small painted icon: a stopwatch with a chalky handprint on the glass. | The Workout button. |
| `icon-rest.png` | 512×512 | A small painted icon: a crescent moon resting on a steaming mug of tea. | The Rest day button. |
| `icon-unlocks.png` | 512×512 | A small painted icon: a chalk bag tied with a gold ribbon like a present, with a few sparkles. | The unlocks counter. |

Icons must read clearly at 24 px: bold, simple shapes, no fine detail.

## 4. Climber poses for the Wall (optional, if there's time)

Same rules as round 1: canvas **1024×1536**, feet on the line at **y = 1344**, centred at
**x = 512**, head width about **515 px**, at least 32 px empty border, and no glow. Attach
`mascot/climber/default/idle/idle-01.png` every time and say "same character, same proportions,
only the pose changes". **Don't redesign the head or face**; only the eyes may change, and only
where the pose says so.

| File | Pose | Where it goes |
|---|---|---|
| `summit-flag-1.png`, `summit-flag-2.png` | Standing tall, holding the teal Crux pennant up high and waving it (two frames: flag left, flag right), happy eyes | Hold 42, the top of the wall |
| `climb-chalk-up.png` | On the wall, facing it (back to us), one hand on a hold, the other dipped in the chalk bag behind them | While waiting on a hold |
| `ledge-sit-look.png` | Sitting on a ledge with legs dangling, turned slightly to look at something beside them, curious | On a ledge, looking at the prize |

## Notes for Claude when this arrives

- **Holds and objects:** add them to `dev/build-wall-art.ps1` and export. Then drop the stopgaps
  (`r_shoes2`, `r_lights2`, `r_shelf2`) and put the original reward names back (Blue sloper,
  Purple pinch, Grey pocket).
- **Climber frames:** run them through `art-source/tools/normalize-wall-climber.ps1` (head lock
  plus glow removal) and never use them straight from the generator.
- **Then:** upload, fill in the blob ids, run `dev/tests.html`, and check on a phone width.
