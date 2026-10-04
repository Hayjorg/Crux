# Crux coaching: design for v1

Status: **proposal, revision 2 (2026-10-04). Not built.** It's waiting for the owner's review
before Phase 0. The draft database schema is in [`schema.sql`](schema.sql).

**What changed in revision 2:**
- Hosting and Supabase are confirmed.
- Connections are many-to-many.
- A disconnect revokes all coach access, including past results.
- Training blocks are now real objects.
- There are six workout primitives.
- Share scopes are persistent and more fine-grained.
- The no-messaging rule is now enforced in the schema.
- Coach access is tied to a specific connection, so a reconnect never re-exposes old results.

## What v1 is (and isn't)

An athlete links one or more real coaches to their Crux account. Each coach sees only the
training data the athlete chose to share with *that* coach. A coach builds structured workouts
and multi-week training blocks and assigns them. The athlete runs them with Crux's existing
timer, logging and session flow, and results flow back to the assigning coach.

```
Athlete account <-> Coach connection (many-to-many) <-> Coach account

Workout template --assign--> Workout assignment (frozen snapshot) --run in Crux--> Workout result

Block template --assign--> Training block (a real object, start-end dates)
                              +-- Workout assignment (Mon wk 1)
                              +-- Workout assignment (Thu wk 1)
                              +-- ... (each a frozen snapshot, each with its own result)
```

**Not in v1, by design:**
- DMs, chat, replies, threads, an inbox, comments, feeds, followers or video.
- Discovery, payments, ratings or verification.

## 1. Why the current setup can't do this

| Today | Problem for coaching |
|---|---|
| Hosted as a Claude Artifact | The page's network is blocked, so it can't reach any server. |
| The Artifact's own database (`db` capability) | Only signed-in Claude users the page is shared with can use it. Its rules are by access level, so they can't express "this coach sees these categories of this athlete's data". |
| All data in `localStorage` | Per browser. A coach can't see it, and it doesn't follow you between devices. |
| Photos in the Artifact's asset store | Only reachable from the Artifact page. |

**Decided:** move to normal hosting, and use Supabase as the backend.

## 2. Architecture

| Piece | Choice | Why |
|---|---|---|
| Hosting | **Cloudflare Pages or Netlify**, auto-deploying from `Hayjorg/Crux` | Free, static, works from a private repo, no build step |
| Backend | **Supabase**: Postgres + Auth + Row Level Security | No server code. Permissions are enforced inside the database. The JS client loads from jsDelivr. |
| Sign-in | Email one-time code | No passwords. Works on phones. |
| Coach app | **`coach.html`**, same repo and site | Keeps the athlete app small, and shares the backend and workout format |

**Things that stay the same:**
- **Crux stays local-first.** It works fully without an account. Signing in adds sync and coaching.
- **localStorage stays the on-device copy.** Changes upload in the background.

## 3. Data model

There are no message, comment or thread tables, and adding one breaks the design.

| Object | Table | Owned by | Notes |
|---|---|---|---|
| Profile | `profiles` | the user | name, `is_coach`, coach's gym, adult confirmation |
| Coach connection | `coach_connections` | the athlete | athlete ↔ coach, status, **persistent share scopes**, how far back history is shared |
| Athlete's sessions | `training_sessions` | the athlete | Crux's session JSON, unchanged. Coaches never read this table directly. |
| Athlete's projects | `training_projects` | the athlete | name, gym |
| Workout template | `workout_templates` | the coach | reusable workout in the coach's library |
| Block template | `block_templates` and `block_template_items` | the coach | reusable plan: "Red River Prep: 4 weeks" with workouts placed on day offsets |
| Training block | `training_blocks` | coach + athlete | **an assigned block**: title, coach note, start and end dates, source template |
| Workout assignment | `workout_assignments` | coach + athlete | **a frozen snapshot** of a workout, a date, an optional `block_id`, one coach note |
| Workout result | `workout_results` | the athlete | per-step outcomes, RPE, one reflection note, the Crux session it was done in |

### Many-to-many coaching

- **Any number of coaches per athlete,** and any number of athletes per coach.
- **One active connection per pair.**
- **Scopes are per connection,** so a strength coach and a technique coach can see different things.
- **Each connection is its own row.**
  - Assignments and blocks belong to the connection they were created under.
  - Disconnecting ends that row.
  - Reconnecting later creates a **new** row. The coach doesn't regain anything from the old one.
- **The first UI can still be simple:** one "Coaches" list with **Invite a coach**.

### Share scopes

Scopes are stored on the connection and enforced on every read. They're persistent, not a report.

| Scope | Default | What that coach sees |
|---|---|---|
| `sessions` | **on** | session summaries: date, gym, duration, flash/send/fall counts, timer used, how it felt |
| `projects` | **on** | projects and grades: names, gyms, grades and grade type, attempts and sends per project |
| `attempts` | **on** | each attempt: result (flash/send/fall) and time |
| `effort` | **on** | RPE per attempt |
| `fall_reasons` | **on** | why each fall happened |
| `notes` | off | session and attempt notes |
| `photos` | off | photos and videos (reserved: served only once photo storage exists) |

**What's never shared:**
- XP and levels
- the Garage
- settings
- AI coach text

**History window.** The connection also stores `history_from`:
- `null` means all history.
- A date means "only from here on".
- The default is an open decision (section 9).

**How enforcement works:** coaches read only through `coach_view_sessions` and
`coach_view_projects`.
- They check that the calling coach has an **active** connection with this athlete.
- They build each row from an **allow-list** of fields for that connection's scopes.
- A field Crux adds later stays private until someone deliberately adds it to the list.
- Changing scopes or disconnecting takes effect on the coach's next read.

### Workout results and scopes

A result is something the athlete sends to the assigning coach. So the coach can see the result
itself (step outcomes, workout RPE and reflection note) while that assignment's connection is
active, whatever the scopes say. The UI labels the note **"Note for your coach"**. The Crux
session the workout ran in is still filtered by the scopes.

### Disconnect

Either side can disconnect, and it takes effect immediately.
- **The coach** loses access to everything from that connection: sessions, projects, blocks,
  assignments and results, past ones included. Every coach policy checks that *the specific
  connection* is active.
- **The athlete** keeps all of it.
- **The coach's own templates** stay in their library, because they're the coach's work.
- **The athlete can still see the former coach's name** on the workouts they keep. The coach can
  no longer see the athlete at all.

## 4. Linking (consent first)

1. **Athlete:** opens Settings → Coaches → **Invite a coach**, chooses scopes (the five defaults
   are pre-ticked) and the history window, and gets a code like `7F3K-92QD-XW4M`. It's single-use,
   expires in 7 days, and only a hash is stored.
2. **Coach:** signs in to `coach.html`, turns on their coach profile (name, gym, "I'm 18 or
   older"), and enters the code.
3. **Athlete:** sees exactly who is connected: name, gym, connected since, what's shared,
   **Change what's shared** and **Disconnect**.

**Under-18 athletes** see a "get a parent or guardian's OK first" notice before making an invite.

## 5. The workout model

### Lifecycle

| Stage | What it is | Can change? |
|---|---|---|
| Workout template | the coach's reusable definition | yes. It never affects anything already assigned. |
| Workout assignment | a **frozen snapshot** of the template, plus date, coach note and optional block | **Until it's done**, the coach can change its date or note, or withdraw it. The steps stay frozen; to change steps, withdraw it and assign again. |
| Workout result | the athlete's outcome for one assignment | the athlete can redo it (replaces it). Only one result per assignment. |
| Block template | a reusable multi-week plan: title, length in days, and items of (day offset, workout template) | yes. It never affects assigned blocks. |
| Training block | an assigned block: title, coach note, start and end dates, and its assignments (each a snapshot) | the coach can add, re-date or withdraw unfinished assignments inside it, or withdraw the whole block |

**Ways to send work:**
- **One workout:** a single assignment, not in a block.
- **Several workouts:** several assignments, each with its own date.
- **A block:** one training block with all its assignments, created in one step from a block
  template and a start date.

Every assignment carries **one** optional `coach_note`. A block and a template each carry one too.
Every result carries **one** optional `athlete_note`. There are no replies.

### Workout document

Templates and assignments store the same JSON, with format version 1. All durations are in
seconds. Every step has a stable `id`, so results can refer to it.

```json
{
  "v": 1,
  "title": "Power day",
  "steps": [
    { "id": "s1", "type": "timed",     "title": "Warm-up", "duration": 900, "text": "V0-V2, getting harder" },
    { "id": "s2", "type": "climbing",  "title": "Limit attempts", "target": "attempts", "count": 6,
      "restBetween": 180, "grade": { "type": "boulder", "min": "V5", "max": "V6" }, "text": "your project" },
    { "id": "s3", "type": "rest",      "duration": 300 },
    { "id": "s4", "type": "intervals", "title": "4x4s", "work": 240, "rest": 240, "rounds": 4,
      "text": "4 problems back to back, 2-3 grades below max" },
    { "id": "s5", "type": "setsReps",  "title": "Pull-ups", "sets": 3, "reps": 8, "restBetween": 120 },
    { "id": "s6", "type": "instruction", "title": "Stretch", "text": "forearms and shoulders, 5 min" }
  ]
}
```

### The six primitives

| Type | Fields | Runs on (existing Crux systems) | Result records |
|---|---|---|---|
| `instruction` | title, text | a **Done** tick | done / skipped |
| `timed` | title, `duration`, text | **the Crux timer** as one countdown | done / partial (seconds done) / skipped |
| `intervals` | title, `work`, `rest`, `rounds`, optional `sets` + `setRest`, text | **the Crux timer** (work/rest phases, auto-stops at the target) | rounds and sets completed |
| `climbing` | title, `target` (`attempts` or `sends` or `problems`), `count`, optional `grade` range, optional `restBetween`, text | **the Crux Flash/Send/Fall logging**. It counts logs made during the step. With `restBetween`, the timer starts a rest countdown after each log. | the ids of the attempts logged, counts by result, target met? |
| `setsReps` | title, `sets`, `reps`, optional `restBetween`, text (load or variation) | a set counter. **The Crux timer** runs the rest between sets. | sets done (and reps per set if edited) |
| `rest` | `duration`, optional text | **the Crux timer** as a rest countdown | done / skipped |

**How common workouts compose:**

| Workout | Built from |
|---|---|
| **4x4s** | `intervals` 240/240 × 4 |
| **Repeaters** | `intervals` 7/3 × 6, `sets` 6, `setRest` 180 |
| **ARC** | `timed` 1200 s, or `intervals` 1200/600 × 3 |
| **Limit attempts** | `climbing` attempts × 6 with `restBetween` 180 |
| **Movement drills** | `instruction` steps, or `climbing` problems × N with a drill in `text` |
| **Conditioning** | `setsReps` steps with `rest` between |
| **Projecting** | `climbing` sends × 1 on a named project |

The steps are a flat list, with no nesting or loops in v1. Intervals and sets already cover
repetition, and a flat list keeps the runner, the editor and the results simple. Nested
"repeat this group" could be added later as `v: 2`.

### Timer reuse

Today the Crux timer alternates work and rest forever, counting rounds, and it's driven by
timestamps so it survives screen locks and reloads. Phase 0 extends that **same engine** with an
optional **timer program**: a list of phases, each with a label and a duration in milliseconds.

- **Building the phases:** `timed`, `rest`, `intervals` and the rests inside `climbing` and
  `setsReps` all compile to a phase list. For example, `intervals` 240/240 × 4 becomes
  Work, Rest, Work, Rest, Work, Rest, Work.
- **No program means no change:** when there's no program, the timer behaves exactly as it does
  today.
- **What's reused unchanged:** beeps, the wake lock, reload-safe saving
  (`session.timerState`) and the countdown display.

## 6. Running an assigned workout

1. **Home shows what's due:** "From Sam Lee · Red River Prep (week 2): Power day", with the coach
   note. A due workout takes the place of **Today's plan**, which stays as the fallback.
2. **Start** runs the normal `startSession()`. The session gets
   `workout: {assignmentId, snapshot, stepIndex, stepResults}`.
3. **The Workout card** highlights the current step:
   - Timed steps load the timer program.
   - Climbing steps count Flash/Send/Fall logs.
   - **Next** and **Skip** buttons move between steps.
   - XP, badges, projects and the mascot work as usual.
4. **Finish Session** shows the usual summary plus a **Workout** section:
   - each step's outcome (filled in automatically and editable),
   - **workout RPE 1–10**, using the existing effort chips,
   - **Note for your coach**, one optional line of up to 500 characters.
5. **The result saves locally and uploads.** If you're offline, it's queued. The coach sees it on
   their next load.

**Phase 0 runs all of this locally, with no account.** Athletes can build their own workouts
(no blocks yet) in the same format. Later, coach assignments plug into the same runner.

## 7. Sync

**Push:**
- On sign-in, local sessions and projects upload, keyed by their existing ids.
- After that, changed sessions push in the background after `saveState()`.

**Pull:**
- Assignments and blocks download on app open and when the app comes back to the foreground.
- Your own sessions pull too (for a second device, v1.1).

**Conflicts:** only the athlete writes their own sessions, so the newest `updated_at` wins.

**Offline:** everything works, and uploads queue.

**Privacy copy:**
- Signing in stores your log on Crux's server (Supabase), and the sign-in screen and legal sheet
  must say so.
- Whoever runs the Supabase project can technically read stored data, so the project stays
  owner-only.

## 8. Moving off the Claude Artifact

- **Data:** moves with the existing backup export/import. The Artifact gets a "We've moved"
  banner.
- **Images:** `asset()` gains a self-hosted mode that loads `assets/` directly.
- **Photos already uploaded:** they stay viewable on the old page. Proper photo storage
  (Supabase Storage) is later, and so is the `photos` scope.
- **The AI coach:** it's unavailable off-Artifact. It already hides itself there; remove it later.
- **Backup export:** falls back to a plain browser download.

## 9. Build order

| Phase | What | Backend? |
|---|---|---|
| **0** | Workout document v1, the timer program, the Workout card and runner, result capture, local "My workouts" (single workouts). Tests. | no |
| **1** | Hosting move, self-hosted assets, "We've moved" banner, plain downloads | no |
| **2** | Supabase project, `schema.sql`, email-code sign-in, upload and pull of own sessions | yes |
| **3** | Coaches list, invite, scopes and history window, disconnect (athlete). `coach.html`: coach profile, enter code, athletes, read-only athlete view. | yes |
| **4** | Workout and block template editors, assign (one / several / block), due workouts in Crux, results back, block progress | yes |
| later | discovery, verification, payments, photo storage and the `photos` scope | |

## 10. Decisions

**Decided (2026-10-04):**
- **Hosting:** normal hosting plus Supabase.
- **Disconnect:** it revokes everything, past results included.
- **Connections:** many-to-many.
- **Assignments:** frozen snapshots.
- **Training blocks:** real objects.
- **Scopes:** persistent on the connection. Defaults are sessions, projects, attempts, effort and
  fall reasons. Notes and photos stay off unless deliberately enabled.
- **Notes:** one coach note per assignment (and per block or template), one athlete note per
  result, and no messaging of any kind.
- **Phase 0:** waits until this model has been reviewed.

**Still open:**
1. **History window default:** all history, or only from the connection date? The proposal says
   **all**, because coaches need context, but the athlete can choose "from today" when inviting.
2. **Workout RPE:** should it be shared even when the `effort` scope is off? The proposal says
   **yes**, since it's on a result the athlete deliberately submits. Per-attempt RPE still follows
   the scope.
3. **Editing an assignment:** can the coach edit the note or date after the athlete has started
   the workout? The proposal says **no**: they're locked once a result exists.
