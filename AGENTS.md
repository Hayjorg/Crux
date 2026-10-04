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
   file storage. The page declares the `assets` (photos) and `downloads` (backup export) capabilities,
   and both must stay.
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
4. **The mascot is the climber.** The old pebble mascot "Crimpet" is retired, and the owner was
   unhappy when a test brought it back. Don't show it, restore it, or switch the app back to it,
   unless the owner explicitly asks for Crimpet work.
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
