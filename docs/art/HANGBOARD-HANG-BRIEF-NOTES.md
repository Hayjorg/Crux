# Hangboard hang: the frame we do not have (notes, 2026-10-17)

Status: **missing art.** The Home climber can be dropped on the Hangboard decoration (`hangboard` in `ACCESSORIES`, a `perch:"hang"` target),
but it uses a stand-in frame, behind the flag `HANGBOARD_FALLBACK` in `crux.html` (true today). This note says what the real frame has to be.

## Why nothing existing works

Every climber frame that has a raised arm is a **one-fist reach seen from behind, on a wall**: `climb/climb-reach-left`, `climb-reach-right`,
`climb-mid-reach-*-v2`, `climb-chalk-up`, `climb-pull`. One hand is on the hold, the other arm is bent at the chest, the legs are in a climbing
stance with one foot high, and the body leans. None has **both hands on one bar with the arms straight and the legs hanging**. `jump/jump-0x` have
the arms out to the side; `sit/*` and `idle/*` have the hands down. A two-hand hang cannot be made by mirroring or rotating one of them (the second
hand would be in the wrong place and the legs would still be in a stance), so we do not fake it.

## What the fallback is

`climb-reach-left` / `climb-reach-right` (one fist on the top edge of the board, body hanging below it, feet off the floor), drawn at 0.44 of the
floor climber. Honest look: he reads as "hanging from the board by one hand", not as a hangboard hang. The fist is on the board's top edge (`PERCH_HANG_Y.hangboard`),
the feet hang about a third of the sprite above the floor feet line.

## The frame to make (one image, `climb/climb-hang-two.png`)

- **Pose:** a dead hang / active hang. Both arms straight (a slight shrug is fine), **both fists on the same horizontal line at the very top of the
  frame**, wrist width about shoulder width. Legs hang straight down together, knees slightly bent, toes pointing down, **no foot touching anything**.
  Backpack and chalk bag as in the other climb frames. Relaxed, not a crank.
- **Camera:** from behind and slightly above eye level, like the other climb frames (he faces the wall / board). No yaw: the hang should be left-right symmetric
  (a few degrees of head turn is fine so the head still reads as the locked idle-01 head).
- **Canvas:** 1024 x 1536 RGBA master (runtime copy 640 x 960), same head size as `idle-01` (it goes through `normalize-wall-climber.ps1` and `HeadFit.cs` like the
  other poses), transparent background, no glow.
- **Layout in the canvas:** the fist line at about **y = 0.06 of the height**, the two fists at about **x = 0.30 and x = 0.70** (so the gap is about 0.40 of the width),
  the soles at about **y = 0.90**. The opaque figure must not touch the canvas edge.
- **Size against the hangboard:** the Home Wall hangboard is 26% of the scene wide (97 px at a 375 px wide scene). The climber is drawn at 0.44 of the floor box (225 px at 375),
  so the fist gap (0.40 x 225 x 0.44 = about 40 px) is a little under half the board's width, which is how a person's hands sit on a real board.
- **Variants and outfits:** needs the same recolours (`variants/<id>/climb/climb-hang-two.png`) and outfit layers as the other climb frames, or an entry in the
  skip lists (`BEANIE_SKIP` and the shirt/shorts skips) so the original shows.

## How to wire it when it exists

1. Add the file to `assets/mascot/climber/default/climb/` and an `IMG.wall.cl_hang_two` row (`asset()`, blob id empty until uploaded: rule 2).
2. Measure the two fists (`hand`) and the opaque box in `PERCH_FRAME` (a new `hangTwo` entry), as the comment above it describes.
3. In `perchPlacement`, for `target.id === "hangboard"` and `!HANGBOARD_FALLBACK`, use the new frame (hand = the midpoint of the two fists) and `perchFrameAddr`.
4. Set `HANGBOARD_FALLBACK = false`. The "Home polish: hangboard" test then needs its frame check updated (it expects the reach frame while the flag is true).

## Where the hangboard appears

The Hangboard is a global decoration (no `from`): it can be switched on in **every** room (Garage, Home Wall, The Local, The Mountain Club, The Dream Gym).
No room painting has a hangboard in it. The Home Wall has **Campus Rungs**, the Dream Gym **Gym Rings** and the Mountain Club **Ice Axes**, which are also hang targets.
