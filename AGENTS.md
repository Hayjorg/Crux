# Crux: rules for AI coding assistants

Read this before changing anything. It applies to every assistant (Claude, ChatGPT/Codex, others).
More than one assistant works on this project, so leave things the way you'd want to find them.

## What this is

Crux is a climbing training timer and send log. It has XP, levels and badges, a climber mascot,
and a decoratable gym scene ("the Garage").

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

## Projects (climb tracking)

A project is **one named climb at one gym or crag**, and attempts link to it by `projectId`.
- **Same name at different gyms means separate projects.**
- **A typed name only auto-joins a project with the same name and the same gym.**
- **When either gym is unknown,** the app asks ("Use …" / "Keep separate") instead of linking.
- **Older entries with no location** get their own "Location not set" project and are never merged
  automatically.

See `linkProjects()` and `projectChoicesFor()` in `crux.html`.

## Coach

The coach writes a short debrief of a finished session, and a "what to try next" tip for a
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
It checks about 20 things in roughly 30 seconds:
- logging, Undo, sessions and reloads
- the save key
- old-save migration and backup import/export
- every project rule
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
