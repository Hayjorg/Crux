# New rooms: art brief

Written 2026-10-04 for ChatGPT image generation. This is a big job: four new rooms for your
climber, each with a background painting, a thumbnail and its own set of decorations.

**Why:** the app already plans four more rooms after The Garage: **Home Wall** (level 8),
**The Local** (level 15), **The Mountain Club** (level 24) and **The Dream Gym** (level 40). They
were taken out because a room that unlocks as a flat-colour placeholder feels like a broken
promise. Finished art brings them back, and Claude wires each one in as it arrives.

## Paste this to ChatGPT

> Please read `Desktop/Crux/app/docs/art/ROOMS-BRIEF.md` and make the rooms in it, one room at a
> time, in the order given. For each room, save the files to
> `Desktop/Crux/art-source/rooms/incoming/<room-id>/` with exactly the file names given. Attach
> `Desktop/Crux/app/assets/garage/background.png` as the style reference for every background,
> and follow "How a room is built" closely, especially the floor line and the empty areas. After
> each room, write `HANDOFF.md` in that room's folder listing the files and anything you're unsure
> about. Don't edit `crux.html` or anything in `app/`; Claude wires the rooms in.

## How a room is built (read this first)

The Garage is the model. Look at `app/assets/garage/background.png` before starting: a warm
painted garage with a leaning plywood climbing wall, timber rafters and a sunset through the door.
In the app, the room is a **background painting**. Your climber stands in front of it, and the
decorations you unlock (holds, a hangboard, a crash pad, a plant…) are placed on top. Those
decorations are separate images, so **the background must be an empty room**.

**The background painting:**
- **Canvas: 1024×1536, portrait.** Not transparent: it fills the whole image.
- **The app shows only the middle part.** The visible window is the full width from **y = 154**
  to **y = 1383**. Keep everything important inside it. The strips above and below can be
  ceiling and floor that simply continue.
- **The floor line,** where the back wall meets the floor, sits at about **y = 1135** (74% of the
  way down). Your climber stands on the floor just in front of it, centred.
- **The left half is a big climbing surface:** a plywood or panel wall, often leaning towards us
  like the Garage wall. It shows **bolt holes (T-nuts) only, with no holds on it**, because the
  unlocked holds are bolted on by the app. Keep its colour mid-tone so colourful holds stand out.
- **The back wall on the right** has some open space where a shelf, a print or a hangboard can go.
- **The middle of the floor stays clear:** that's where your climber stands.
- **The bottom-right corner stays calm** (from x = 680, y = 1050 down to the bottom of the
  visible window): just floor and wall, nothing busy, because two buttons sit on top of it.
- **No people, no climber, no holds on the main wall, and no loose objects** (bags, pads, shoes,
  chalk buckets). Fixtures that belong to the room are fine: windows, lamps, beams, a fireplace,
  a front desk far away.
- **The same camera as the Garage:** eye level about 1.2 m, looking slightly up, the climbing
  wall on the left and the room going back to the right.
- **No text, signs with letters, logos or numbers** anywhere.

**The thumbnail:** `<room-id>-thumb.png` at **1536×1024** is the same room seen a little wider, as
a postcard. It's used in the room picker and as a Wall unlock picture, and it's not transparent.

**The decorations:** each room has its own set of **five objects** at **1024×1024** each:
- a single object on a **fully transparent** background
- at least **10% empty margin on every side**, with nothing touching the edge
- no glow, no halo, no shadow and no floor under it
- painted in the same style as the Garage decorations (attach `app/assets/decor/chalk-bag.png` and
  `app/assets/decor/hay-bale.png` as references)

## Style: paste this before every background prompt

> A warm, painted illustration of an empty indoor room, in the same style, camera angle, lighting
> quality and level of detail as the attached Garage image: soft painterly textures, rich but not
> neon colours, cosy and inviting, like a background in a high-quality mobile game. Portrait
> 1024×1536. Eye-level camera looking slightly up. The left half of the image is a large climbing
> wall surface with bolt holes only and no climbing holds on it. The middle of the floor is
> empty. The bottom-right corner is plain floor. No people, no characters, no loose objects on the
> floor, no text, no signs, no logos.

## The four rooms

### 1. Home Wall (`homewall`, level 8)

A cosy home climbing wall in a spare room or basement: someone built their own board.

**The background, `homewall-background.png`.** Paste the style block, then:

> A small home climbing room in a basement. On the left, a homemade 40-degree plywood board
> (light birch plywood with a grid of dark T-nut bolt holes, no holds) leans out from the wall on
> chunky 2x6 timber framing. The back wall is painted a soft warm grey, with exposed pipes along
> the ceiling, a small high basement window showing evening blue light, and a warm clamp lamp
> fixed to a beam. A worn rug covers part of a concrete floor. Cosy evening lamplight, warm
> yellow against cool blue from the window.

**The thumbnail:** `homewall-thumb.png`, the same room as a wider postcard.

**The decorations:**

| File | Object |
|---|---|
| `homewall-step-stool.png` | A small wooden step stool, a bit paint-splattered |
| `homewall-desk-fan.png` | A retro metal desk fan in mint green |
| `homewall-toolbox.png` | An open red toolbox with a drill and a bag of T-nut bolts |
| `homewall-campus-rungs.png` | A short wooden campus board with four rounded rungs, mounted on a small plywood panel |
| `homewall-beanbag.png` | A slouchy mustard-yellow beanbag |

### 2. The Local (`local`, level 15)

A friendly neighbourhood bouldering gym: small, busy, a bit scruffy, and much loved.

**The background, `local-background.png`.** Paste the style block, then:

> A small neighbourhood bouldering gym. On the left, a big grey-blue textured bouldering wall
> with a steep overhang (bolt holes only, no holds on this wall). Far in the background on the
> right, a second wall covered in colourful holds, a little out of focus, and a small wooden
> front desk with a plant and a coffee machine. Thick dark-grey padded matting covers the whole
> floor, with chalk dust on it. Big industrial windows with afternoon daylight, and string lights
> along a steel beam. Bright, friendly and lived-in.

**The thumbnail:** `local-thumb.png`.

**The decorations:**

| File | Object |
|---|---|
| `local-chalk-bucket.png` | A big communal chalk bucket, white chalk spilling over the rim |
| `local-brush-stick.png` | A long bouldering brush on a telescopic pole |
| `local-bench.png` | A short wooden bench with a folded towel on it |
| `local-tape-roll.png` | A fat roll of white finger tape, half unrolled |
| `local-volume-stack.png` | Three colourful wooden volumes stacked on each other (orange, teal, white) |

### 3. The Mountain Club (`club`, level 24)

An old alpine climbing club hut: stone, timber, history, and a view of the peaks.

**The background, `club-background.png`.** Paste the style block, then:

> The inside of an old alpine climbing club hut. On the left, a traditional timber climbing wall
> made of dark varnished wooden boards with bolt holes (no holds), built against a rough stone
> wall. On the right, a stone fireplace with a crackling fire, a heavy wooden beam ceiling, and a
> big window looking out at snowy mountain peaks at blue hour. Wide old floorboards with a
> woollen rug. Warm firelight inside, cool blue light outside.

**The thumbnail:** `club-thumb.png`.

**The decorations:**

| File | Object |
|---|---|
| `club-ice-axes.png` | Two vintage wooden-shafted ice axes crossed, as if mounted on a wall |
| `club-rucksack.png` | An old leather and canvas rucksack with a rope coil strapped to it |
| `club-boots.png` | A pair of heavy leather mountaineering boots with red laces |
| `club-lantern.png` | A brass hurricane lantern, glowing softly from inside (the light stays inside the glass) |
| `club-map.png` | A framed old topographic map of a mountain (contour lines only, no words) |

### 4. The Dream Gym (`dream`, level 40)

The biggest, brightest climbing gym you can imagine: the reward for sticking with it.

**The background, `dream-background.png`.** Paste the style block, then:

> A huge, beautiful modern climbing gym. On the left, a tall sweeping white-and-sand coloured
> climbing wall with a dramatic overhang and curved panels (bolt holes only, no holds on it). High
> above, a glass roof with morning sunlight streaming in in soft rays. In the background on the
> right, a second level with a balcony, big green plants and a distant competition wall with
> colourful holds, gently out of focus. A smooth, soft, light-blue padded floor. Airy, bright and
> inspiring, but still warm and cosy, not cold.

**The thumbnail:** `dream-thumb.png`.

**The decorations:**

| File | Object |
|---|---|
| `dream-monstera.png` | A big monstera plant in a woven basket |
| `dream-rings.png` | A pair of wooden gymnastic rings hanging from straps |
| `dream-trophy.png` | A small golden trophy shaped like a climbing hold on a wooden base |
| `dream-foam-roller.png` | A teal foam roller lying on its side |
| `dream-smoothie.png` | A tall smoothie cup with a straw and a slice of fruit on the rim |

## Before you hand over each room, check

1. **The window:** crop the background from y = 154 to y = 1383. Does it still look like a whole
   room, with the floor line about four-fifths of the way down?
2. **The climbing wall:** is the left half of the room clearly a climbing surface, with bolt
   holes only and no holds?
3. **The clear areas:** are the middle of the floor and the bottom-right corner clear?
4. **The style:** placed next to the Garage, does it look like the same game?
5. **The decorations:** is each one whole, with margin all around and no glow?

## Notes for Claude when this arrives

- **Each room** becomes an entry in `ENVIRONMENTS` in `crux.html`, with its background drawn like
  the Garage (see `garageSceneSVG`). Work out its own width, height and y offset so the floor line
  lands on `ROOM_FLOOR_Y`.
- **Set `artReady: true`** only once the room looks right on a phone.
- **The decorations** become `ACCESSORIES`. Trim, size and upload them like the Wall art.
- **The thumbnails** can replace the Wall's Home Wall unlock picture, and give later Wall unlocks
  their rooms.
