# The Wall: art brief

Written 2026-10-04 for whoever makes the art, such as ChatGPT image generation. The Wall works
today with existing Crux art, but it needs much more to look finished. Generate in the order
below: the first five change the look most.

**How to deliver:**
1. Save PNGs to `Desktop/Crux/art-source/wall/incoming/`, using the file names below.
2. Tell Claude. It trims, resizes, uploads and wires each piece in, and checks it against the
   existing art.
3. Nothing gets deleted. If a piece doesn't look right, the current art stays.

## Style: match what's already in Crux

Paste this before every prompt:

> Soft, painted 3D illustration style, like a cosy mobile game. Warm and friendly, with gentle
> rounded shapes, subtle texture and soft top-left lighting. Rich but not neon colours. A clean
> single object on a fully transparent background. No drop shadow, no floor and no background
> scene unless asked for. No text, no logos, no watermark. It must match these existing Crux
> pieces: the textured climbing holds (bolt hole in the middle), the chalk bag with the mountain
> logo, and the wooden wall shelf.

- **Format:** PNG with real transparency, on a square canvas unless a size is given. The object
  should fill about 80% of the canvas.
- **The climber** is the Crux mascot: the rounded little climber with the vertical face stripe.
  Their look is locked, so **never redesign the head or face**. Every climber image must use the
  same canvas as the existing frames: **1024×1536**, feet on the line at **y = 1344**, centred
  at **x = 512**, head width about **515 px**, and a 32 px empty border. Attach `idle-01.png` as
  the reference every time, and say "same character, same proportions, only the pose changes".

## Priority 1: the wall itself

| # | File | Size | What |
|---|---|---|---|
| 1 | `wall-tile.png` | 1024×1024 | **Seamless, tileable** plywood climbing-wall panel with a grid of dark T-nut holes (bolt sockets), warm birch colour and faint grain. It must tile with no visible seam on all four sides, with no frame or border around the panel. |
| 2 | `wall-stud.png` | 128×1024 | **Seamless vertical** wooden support beam (2x6 stud) running down the side of the wall, to tile vertically. Slightly darker wood than the panels. |
| 3 | `ledge.png` | 1024×256 | A chunky wooden ledge or shelf bolted across the wall, seen from the front: a thick front edge with a little top surface for a prize to sit on. It's empty, so the prize is added separately. |
| 4 | `summit.png` | 1024×768 | The top of the wall (the top-out): the wall ends at a wooden lip, with a small pennant flag in Crux teal (#0FB8A6) and a little rope coil. It's the finish line at hold 42. Transparent above the top edge. |
| 5 | `ground.png` | 1024×384 | The floor at the bottom of the wall: a big blue crash pad with a little chalk dust, seen from the front. Seamless left to right. |

## Priority 2: the climber climbing (the biggest upgrade)

Today the climber jumps between holds. Real climbing frames make it feel alive. Each is a
1024×1536 frame on the climber canvas, with the feet line respected wherever the climber
stands on something.

| # | File | Pose |
|---|---|---|
| 6 | `climb-reach-left.png` | On the wall facing it (back mostly to us), left arm reaching up to a hold, right foot high on a hold |
| 7 | `climb-reach-right.png` | The mirror pose: right arm reaching up, left foot high |
| 8 | `climb-pull.png` | Pulling up: both hands on a hold at chest height, knees bent, about to step up |
| 9 | `ledge-sit.png` | Sitting on a ledge, legs dangling, relaxed and happy, holding a water bottle |
| 10 | `rest-day.png` | Rest-day pose: sitting cross-legged on a crash pad with a mug of tea, eyes calm and half-closed (an **eye-only** change from idle; the face otherwise stays the same) |

## Priority 3: holds and unlock art

| # | File | Size | What |
|---|---|---|---|
| 11 | `hold-crimp.png` … | 512×512 each | **8 more textured holds** in the same style as the existing ones: crimp rail, pinch, big jug, round sloper, a tufa-style pinch, a two-tone dual-texture hold, a small macro volume, and a foot chip. Each in a different colour (teal, coral, lime, purple, orange, pink, white speckled, black). |
| 12 | `chalk-<name>.png` | 512×512 each | A puff or cloud of chalk dust in **each unlock colour**: mint, sunset orange, lilac, glacier blue, neon green, gold, midnight. It's a soft round cloud with tiny particles. |
| 13 | `title-plate.png` | 1024×384 | An empty gold nameplate or badge (a wooden board with a brass plate) for climber titles like "Crimper". There's no text, because the app writes the title on top. |
| 14 | `golden-shoes.png` | 512×512 | A pair of climbing shoes in shiny **gold** with a little sparkle, the prize at hold 42 |
| 15 | `home-wall-gym.png` | 768×512 | A small thumbnail of a cosy garage home wall (the "Home Wall" gym unlock): plywood board, a few holds, a lamp |
| 16 | `mystery.png` | 512×512 | A locked mystery box: a wooden crate with a question mark carved in, used for unlocks you can't see yet |

## Priority 4: climber moves (unlockable)

Each is a short animation of 3–4 frames on the climber canvas. These are the moves the Wall
unlocks.

| # | Files | Move |
|---|---|---|
| 17 | `move-chalk-clap-1..3.png` | Clapping chalky hands, with a white puff of chalk between the hands on the middle frame |
| 18 | `move-fist-pump-1..3.png` | Crouch, fist up in the air, back down, with a big grin (a **mouth/eye-only** change) |
| 19 | `move-wave-1..4.png` | A friendly wave with one arm, back and forth |
| 20 | `move-dance-1..4.png` | A small happy shuffle-dance, side to side |

## Priority 5: nice to have

- **Reveal effects:** a sparkle burst and soft golden light rays as transparent PNGs (1024×1024),
  for the unlock card.
- **Streak flame:** three flame icons (small orange, bigger red-orange, blue-white), 256×256,
  for 1–6, 7–13 and 14+ day streaks.
- **Season themes,** for later: snow on the top-out, autumn leaves on the ledge.

## Notes for Claude when the art arrives

- **Climber frames:** normalize against `idle-01` with the existing frame tools in
  `art-source/tools` (head lock, feet line). Then make runtime copies (640×960) in
  `assets/mascot/climber/default/<set>/`.
- **Wall pieces:** run `dev/build-wall-prototype.ps1 -AppAssets` after adding them to its list.
- **Then:** upload, fill in the blob ids, run `dev/tests.html`, and check on a phone width.
