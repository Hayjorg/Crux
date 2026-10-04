# Crux coaching: design for v1

Status: **proposal, not built.** Written 2026-10-04. The draft database schema is in
[`schema.sql`](schema.sql).

## What v1 is (and isn't)

An athlete links a real coach to their Crux account. The coach sees only the training data the
athlete chose to share, builds structured workouts, and assigns them. The athlete runs those
workouts with Crux's existing timer, logging and session flow. The result flows back to the coach.

```
Athlete account <-> Coach connection <-> Coach account

Workout template -> Workout assignment -> Athlete runs it in a Crux session -> Workout result
```

**Not in v1, by design:**
- DMs, chat, comments, feeds, followers, video, or any general messaging. The only free text is a
  coach note on a template or assignment, and one athlete note on a result.
- Discovery, payments, ratings or verification.

## 1. Why the current setup can't do this

| Today | Problem for coaching |
|---|---|
| Hosted as a Claude Artifact | The page's network is blocked, so it can't reach any server. |
| The Artifact's own database (`db` capability) | Only signed-in Claude users the page is shared with can use it. Every coach and athlete would need a claude.ai account and access to the page. Its rules are by access level, so they can't say "this coach sees this athlete's sessions but not their notes". |
| All data in `localStorage` | Per browser. A coach can't see it, and it doesn't follow you between devices. |
| Photos in the Artifact's asset store | Only reachable from the Artifact page. |

**Conclusion:** coaching needs (a) ordinary web hosting and (b) a small backend with real accounts
and server-enforced permissions.

## 2. Proposed architecture: the smallest clean option

| Piece | Choice | Why |
|---|---|---|
| Hosting | **Cloudflare Pages or Netlify**, auto-deploying from `Hayjorg/Crux` | Free, static, and works from a private repo. (GitHub Pages from a private repo needs a paid plan.) Same single HTML file, no build step. |
| Backend | **Supabase** (Postgres + Auth + Row Level Security) | No server code to write or run. Permissions are enforced in the database itself (RLS), so a buggy page can't leak data. The JS client loads from jsDelivr into a plain HTML page. Free tier: 50k monthly users, 500 MB database. |
| Sign-in | Supabase **email one-time code** | No passwords to manage. Works on phones. |
| Coach app | A second page, **`coach.html`**, in the same repo and site | Keeps the athlete app small. Coaches get a dashboard-shaped tool. Shares the same backend and workout format. |

**Things that stay the same:**
- **Crux stays local-first.** It works fully without an account, exactly as today. Signing in
  only *adds* backup, sync and coaching.
- **localStorage stays the on-device copy.** Changes upload in the background, and offline
  results are queued.

Rejected alternatives:
- **Firebase.** Its security rules and document model make "relationship plus share scopes" and
  the relational parts (connections, assignments) harder to express.
- **A custom Node server.** More to build, run and secure for no v1 gain.
- **Claude Artifact `db`.** See section 1.

## 3. Data model

All tables have Row Level Security on. Full SQL, policies and functions are in `schema.sql`.

| Table | Holds | Who can read |
|---|---|---|
| `profiles` | display name, `is_coach`, coach's gym | yourself, plus the other person in an active connection (name only) |
| `coach_connections` | athlete, coach, status (`pending`/`active`/`ended`), **share scopes**, hashed invite code | the two people in it |
| `training_sessions` | your Crux sessions, stored as the same JSON Crux keeps today (attempts included) | **only you**. Coaches never read this table directly. |
| `training_projects` | your projects (name, gym) | only you |
| `workout_templates` | a coach's library: single workouts and blocks | that coach |
| `workout_assignments` | a workout sent to an athlete: a **frozen copy** of its steps, coach note, date, group | that athlete, plus the coach while connected |
| `workout_results` | how it went: per-step outcome, RPE, one athlete note, the Crux session it was done in | that athlete, plus the coach while connected |

### Share scopes (permission categories)

The athlete ticks these. Defaults are the first three, as decided 2026-10-04.

| Scope | What the coach sees |
|---|---|
| `sessions` (default on) | dates, gyms, duration, flash/send/fall per attempt, timer used, how it felt |
| `projects` (default on) | climb names, projects, grades, grade type |
| `effort` (default on) | RPE and fall reasons |
| `notes` (default **off**) | session and attempt notes |

**Never shared:**
- photos and videos
- AI coach debriefs
- device settings
- the Garage
- XP

### How the coach sees data

- **Coaches read through one database function,** `coach_view_sessions(athlete)`. It checks for an
  active connection, then builds each session from an **allow-list** of fields for the granted
  scopes.
  - A field Crux adds in future is **not** shared until someone adds it to that list on purpose.
  - Changing scopes or disconnecting takes effect on the coach's next read.
- **Workout results** for a coach's own assignments are always visible to that coach while
  connected. The athlete attaches the RPE and note specifically for them.

## 4. Linking a coach (consent first)

1. **Athlete:** opens Settings → Coach → **Invite a coach**, ticks the scopes, and gets a code like
   `7F3K-92QD-XW4M`. It's single-use, expires in 7 days, and only a hash is stored. They give it
   to the coach in person, or by text or email.
2. **Coach:** signs in to `coach.html`, confirms "I coach climbers" and that they're 18+, and
   enters the code.
3. **Both sides:**
   - The athlete sees "Connected to **Sam Lee** (Movement)" with the scopes listed, plus
     **Change what's shared** and **Disconnect**.
   - The coach sees the athlete in their list.
4. **Disconnect** (either side) ends the connection immediately. Then:
   - The coach loses access to everything, including past results (privacy first).
   - The athlete keeps every assigned workout and result.

Under-18 athletes:
- See a "get a parent or guardian's OK first" notice before creating an invite.
- Coaches must confirm they're 18+.
- The legal sheet gets a section on coaching.

## 5. Workouts: one format everywhere

Templates, assignments and the local runner all use the same JSON. Every step is one of four types.

```json
{
  "title": "Power day",
  "coachNote": "Full rests. Stop if fingers tweak.",
  "steps": [
    { "type": "timed",     "title": "Warm-up",       "minutes": 15, "note": "V0-V2, getting harder" },
    { "type": "intervals", "title": "Limit Boulder", "work": 60, "rest": 180, "rounds": 6, "note": "Blue Arete" },
    { "type": "climbs",    "title": "Flash attempts", "goal": 5, "note": "new problems, V3-V4" },
    { "type": "task",      "title": "Stretch",        "note": "forearms + shoulders, 5 min" }
  ]
}
```

| Step type | Runs on (existing system) | Recorded in the result |
|---|---|---|
| `intervals` | **the existing timer**, loaded with work/rest, plus a **rounds target** that stops it when reached | rounds completed |
| `timed` | the existing timer as a single countdown (`work = minutes×60`, 1 round) | done / skipped |
| `climbs` | **the existing Flash/Send/Fall logging**. It counts attempts logged during the step, and the project chip is picked if the note names a project. | attempts and results |
| `task` | a checkbox | done / skipped |

**Sending one, several, or a block:**
- A coach can send **one workout**, **several workouts at once** (they share a `group_id` and
  group title), or a **block**.
- A block is a template of the form `{workouts:[{day:1,…},{day:3,…}]}`. When it's assigned with a
  start date, it becomes one dated assignment per workout.
- Assignments are frozen copies, so editing a template later never changes what was already sent.

## 6. Running an assigned workout (reusing Crux)

1. **Assigned workouts show on Home:** "From Sam: Power day (Tue)", with its coach note. They
   replace **Today's plan** when one is due. Today's plan stays as the fallback when nothing is
   assigned.
2. **Tap Start:** this runs the normal `startSession()`. The session gets
   `workout: {assignmentId, steps, progress}`.
3. **A Workout card steps through the plan,** styled like Today's plan:
   - It highlights the current step.
   - It loads the timer for timed and interval steps.
   - It counts logged attempts for climbs steps.
   - **Next** and **Skip** buttons move between steps.
4. **Finish Session** shows the usual summary plus a **Workout** section:
   - each step marked done or skipped (filled in automatically),
   - **RPE 1–10** (the existing effort chips),
   - an optional one-line note for the coach (500 characters max).
5. **The result saves locally and uploads.** If you're offline, it's queued and sent later.

**Smallest change to existing code:**
- The timer gains one optional field, `targetRounds`, which stops the timer when reached.
- `startSession(opts)` already takes options, from Continue-a-project.
- Logging, XP, badges and the mascot are untouched.

## 7. Sync

**Push:**
- On sign-in, local sessions upload (upsert by their existing ids).
- After that, each `saveState()` marks the session as changed, and a debounced background push
  sends it.

**Pull:**
- Assignments download on app open and when the app comes back to the foreground.
- Your own sessions also pull, so a second phone gets your history (v1.1).

**Conflicts:** in practice only the athlete writes their own sessions, so the newest `updated_at`
wins per session.

**Offline:** everything works. Uploads wait in a queue.

**Privacy copy:** signing in means your log is stored on Crux's server (Supabase), not only in
your browser. The sign-in screen and the legal sheet have to say this plainly. Whoever runs the
Supabase project can technically read stored data, so keep the project owner-only.

## 8. Moving off the Claude Artifact

- **Data:** each browser's data is tied to the site it was saved on. Moving to the new site uses
  the **existing backup export/import** (Settings → Export on the old page, Import on the new
  one). We should add a clear "We've moved" banner to the Artifact page.
- **Images:** `asset()` gains a "self-hosted" mode that loads `assets/` from the site, with no
  blob ids needed.
- **Photos already uploaded:** these live in the Artifact's store. v1 keeps them viewable only
  on the old page. Proper photo storage (Supabase Storage) can come later.
- **The AI coach** (`sample`): it isn't available off-Artifact. It already hides itself there, so
  nothing breaks. Plan to remove it.
- **Downloads:** backup export falls back to a normal browser download (to add: a plain `<a
  download>`).

## 9. Build order

| Phase | What | Needs a backend? | Who |
|---|---|---|---|
| **0** | Workout format, the **Workout card and runner** with `targetRounds`, the result capture screen, and local "My workouts" (athletes can build their own). Tests. | No | Claude, in `crux.html` |
| **1** | Hosting move (Cloudflare Pages or Netlify), self-hosted asset mode, "We've moved" banner, normal downloads | No | either |
| **2** | Supabase project, `schema.sql` applied, email-code sign-in, upload and pull of own sessions | Yes | Claude (schema) + owner (account) |
| **3** | Invite codes, connect/disconnect, scopes UI (athlete). `coach.html`: sign in, enter code, athlete list, read-only athlete view. | Yes | split: athlete side vs `coach.html` |
| **4** | Coach templates (workout + block editor), assign (one / several / block), assignments into Crux, results back | Yes | split |
| later | discovery, verification, payments, photo storage | | |

Phase 0 is useful on its own (custom workouts with real timers), and it's the foundation
everything else plugs into.

## 10. Open decisions (owner)

1. **Move hosting off the Claude Artifact.** Required for accounts. Pick Cloudflare Pages or
   Netlify; both are free. A custom domain is optional.
2. **Create the Supabase project** (free). This has to be the owner's account. Claude then
   writes and checks the setup.
3. **Should the coach keep past results after a disconnect?** This proposal says **no** (privacy
   first).
4. **Can one athlete have more than one coach?** The schema allows it, and the UI could start
   with one.
5. **Can anyone switch on "I coach climbers"?** This proposal says yes for v1: there's no
   verification, but a coach only sees athletes who invited them.
