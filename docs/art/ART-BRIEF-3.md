# Crux art brief, round 3

Written 2026-10-05 for ChatGPT image generation. Rounds 1 and 2 and the four rooms are in the app and
look great. This round finishes the Home screen: painted icons for its buttons (the same treatment
the Wall got), clean redraws of two Garage decorations that are still cut off, an app icon, a few
more climber poses, and some small illustrations.

## Paste this to ChatGPT

> Please read `Desktop/Crux/app/docs/art/ART-BRIEF-3.md` and make every image in it, in order. Work in
> your own output folder as before, in a folder called `round3`, with exactly the file names given.
> Use the style block before every prompt and follow "Rules that matter", especially the margins.
> When you're done, write `HANDOFF.md` listing each file, its size, and anything you weren't happy
> with. Don't edit `crux.html` or anything in `app/`; Claude wires the art in.

## Rules that matter (same as before)

1. **Nothing touches the edge of the canvas.** At least **10% empty, transparent margin on every
   side** for cutouts.
2. **No glow, halo, haze or soft shadow around the outline.** Crisp edge on fully transparent pixels.
3. **Solid objects are fully opaque inside.** Only the outer 1–2 px of the edge is partly transparent.
4. **No text, letters or numbers** anywhere. The app writes any words itself.
5. **One object per file,** centred, on a fully transparent background, no floor and no scene.
6. **The climber** is the Crux mascot. **Never redesign the head or face.** Attach
   `mascot/climber/default/idle/idle-01.png` every time and say "same character, same proportions,
   only the pose changes". Canvas 1024×1536, feet on y = 1344, centred at x = 512, head width about
   515 px, 32 px empty border, and no glow.

## Style: paste this before every prompt

> Soft, painted 3D illustration style, like a cosy mobile game. Warm and friendly, with gentle
> rounded shapes, subtle texture and soft top-left lighting. Rich but not neon colours. A clean
> single object on a fully transparent background, with at least 10% empty margin on every side.
> Nothing touches the edge of the image. No glow, no halo, no drop shadow, no floor, no background.
> No text. It must match the attached Crux pieces.

Attach two or three finished pieces as references each time, such as `icon-rest.png`,
`icon-workout.png` and `hold-red-jug.png` from round 2.

## 1. Clean redraws of two Garage decorations (still cut off at the edges)

| File | Size | What |
|---|---|---|
| `hangboard.png` | 1536×1024 | A wooden hangboard with a row of finger rails and pockets, seen from the front, whole board visible with its screw holes. Warm birch wood, slightly chalky. |
| `mountain-print.png` | 1024×1024 | A framed painting of a mountain at sunset in a dark wooden frame (a snowy peak, pines, an orange sky with a small sun). Whole frame visible, hanging straight. No text. |

## 2. Painted icons for the Home screen

Bold, simple, readable at **28 px**. Each **512×512**, one object, same look as the round-2 icons
(`icon-climb`, `icon-workout`, `icon-rest`, `icon-unlocks`).

| File | Icon | Used for |
|---|---|---|
| `icon-start.png` | A rounded teal-and-gold mountain with a small flag at the summit and a little rope loop | The big **Start session** button |
| `icon-workouts.png` | A clipboard with a checklist, a stopwatch clipped on the corner | The **Workouts** button |
| `icon-progress.png` | Three chunky wooden bars rising left to right, the tallest with a small flag | The **Progress** button |
| `icon-drills.png` | An open training book with a hold sketched on one page and a pencil | The **Drills** button |
| `icon-settings.png` | Three wooden slider bars with round brass knobs at different positions | The **Settings** button |
| `icon-customize.png` | A paintbrush with an orange tip leaning on a small paint pot | The **Customize** button |
| `icon-arrange.png` | Four chunky arrows pointing outward from a small wooden square | The **Arrange** button |

## 3. App icon

| File | Size | What |
|---|---|---|
| `app-icon.png` | 1024×1024 | The climber's head and shoulders only, facing us (same face, never redesigned), centred on a warm teal circle-free full-bleed background with a soft sunrise glow, and a small cream mountain shape behind the head. **Fully opaque**, no transparent pixels, square corners (the phone rounds them). Keep the head inside the middle 70% so no crop cuts it. |
| `app-icon-mono.png` | 1024×1024 | The same idea as a single flat cream silhouette (the head and a mountain) on a transparent background. For dark and tinted icon styles. |

## 4. Small illustrations (transparent, 1024×768)

| File | What | Where |
|---|---|---|
| `empty-history.png` | The climber sitting on the floor leaning on a wooden crate, flipping through an empty logbook, curious. Same character, never redesigned. | The empty session history box |
| `level-badge.png` | A **blank** golden shield or rosette with a laurel edge and a wooden-textured inner disc, nothing written on it (the app writes the level number). 1024×1024. | The level-up card |
| `streak-banner.png` | A blank cream ribbon banner with swallowtail ends, slightly curved. Nothing written. | Behind the streak count |

## 5. More climber poses (1024×1536, climber rules above)

| File | Pose | Where |
|---|---|---|
| `summit-flag-1.png`, `summit-flag-2.png` | Standing tall at the top, holding the teal Crux pennant up high and waving it (flag left, then flag right), happy eyes | The summit, hold 42 |
| `cheer-1.png`, `cheer-2.png`, `cheer-3.png` | Both arms thrown up, then a small hop with a big grin, then landing with a fist pump. Eyes and mouth may change as in the fist pump; the rest of the face stays | The level-up card |
| `climb-chalk-up.png` | On the wall, facing it (back to us), one hand on a hold, the other dipped in the chalk bag behind them | While waiting on a hold |
| `ledge-sit-look.png` | Sitting on a ledge, legs dangling, turned slightly to look curiously at something beside them | A ledge with a prize |

## Notes for Claude when this arrives

- **Icons and illustrations:** add them to `dev/build-wall-art.ps1` or `dev/build-room-art.ps1`
  (trim, scale, snap alpha), upload, fill in the blob ids, run `dev/tests.html`, check on a phone width.
- **Climber frames:** run them through `art-source/tools/normalize-wall-climber.ps1`.
- **Wiring:** the Home buttons take the icons the way the Wall's buttons do; the level-up card reuses
  the celebration card (`celebrate()` in `crux.html`) with `level-badge.png`.
- **App icon:** the Artifact page can set a tab icon, but a home-screen icon needs the page installed as
  an app. Ask the owner how they open it on their phone before doing anything with it.
