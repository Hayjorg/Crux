# G1 Personal Training Onboarding Toolkit

Four short, printable documents for a new personal-training client at G1 Climbing + Fitness, plus a fictional
sample client. **Draft v0.1, pending G1 management approval.**

This folder is **separate from the Crux app.** `crux.html`, the tests, the saved data (`crux-app-state-v2`),
the Artifact and the GitHub Pages build don't use it and it doesn't use them. The Pages build copies only named
app files, so nothing here is published.

## What's here

| # | Document | Who fills it in, and when | Pages |
|---|----------|---------------------------|-------|
| 1 | `01-client-intake.html` | Client, before session one | 2 |
| 2 | `02-first-session-assessment.html` | Trainer, during session one | 3 |
| 3 | `03-goals-and-progress.html` | Trainer and client, end of session one, then about every 4 weeks | 2 |
| 4 | `04-post-session-followup.html` | Trainer, after every session | 2 |

- `index.html` is the landing page (open this first).
- `SOURCES.md` lists where each NASM-informed claim comes from (links), how well it is supported, and what could not be verified.
- `pdf/` has the blank templates as Letter PDFs. `pdf/sample/` has the same four filled in for **Casey Sample**.
- Add `?sample` to any page's address (or use its **View sample** button) to see the fictional client in it.

## Using it

- **Print or save as PDF:** open a page and use **Print / Save PDF**. Each page is already laid out as Letter sheets,
  and in Chrome and Edge the browser adds no headers or footers. In other browsers, turn off "Headers and footers"
  and turn on "Background graphics" if the print dialog offers them.
- **Phone or tablet:** the PDFs open anywhere and can be marked up with the device's PDF tools. The HTML pages are
  responsive (checked at 375 px), but to open them on a device they need to be hosted. That is not set up and
  is your call. Nothing in the pages stores or sends data, so any static host would do.
- **Typing into the pages:** fields are fillable on screen, but **nothing is saved or sent**. It all clears on reload,
  so print or save the PDF first. There is no database, no `localStorage`, no cookies and no network call.
  Don't enter real client personal or health information until G1 approves how it is stored.

## Editing

- **Wording:** edit the HTML directly. `03` and `04` were produced by a one-off script, but they are plain HTML now.
- **Colours and sizes:** the tokens at the top of `assets/toolkit.css` (`--accent`, `--line-h`). There is no G1 brand
  colour in here yet.
- **Paper size:** Letter. For A4, change the two lines marked `[PAGE SIZE]` in `assets/toolkit.css`.
- **Sample data:** `assets/sample-data.js`. A field shows sample content only if it has a `data-k="key"` attribute
  that matches a key there.
- **Single-line fields don't wrap.** Use a multi-line box (`.ta`) where an answer could be long. Table cells already grow.
- **Re-export the PDFs:** browser Print, or, with Node and Playwright installed,
  `NODE_PATH=<folder containing playwright> node g1-pt-toolkit/tools/build-pdfs.cjs`. The script also fails if any
  sheet overflows its page or a sample key matches no field.
- **Never commit a filled-in form.** `.gitignore` here skips `private/` and anything with `filled` in its name.

## Placeholders pending G1 management approval

Shown as yellow dashed "PLACEHOLDER" boxes. Replace them (and delete the box styling) once approved:

| Placeholder | Where |
|-------------|-------|
| Waiver and liability release | Intake p2 |
| Client acknowledgment and signature block | Intake p2 (don't add a signature line until the waiver is approved) |
| Pricing and packages; payment terms | Intake p2; Follow-up p2 note (no prices in client messages) |
| Cancellation and late policy | Intake p2; Follow-up p2 and its message template |
| Privacy and health-information handling (who sees answers, where kept, for how long) | Intake p2 (twice); Follow-up p1 note |
| Pre-activity screening form, medical-clearance rules, under-18s, guardian consent | Intake p2 (if G1 adopts the PAR-Q+ it must be the official form, unaltered; see `SOURCES.md`) |
| Emergency action plan (first aid, AED), incident process, waiver on file, clearance requirements | Assessment p1 |
| Resting heart rate, blood pressure and body-measurement policy | Assessment p1 |

## How the movement screening is framed

- It is **observation for exercise programming**, never diagnosis. Every page that records observations says so,
  includes a stop-and-refer reminder, and the wording asks trainers to describe ("left shoulder sits higher"),
  not label.
- The screens (overhead squat, single-leg squat, push and pull, static posture) and the OPT phase list follow
  published NASM material, checked online on 2026-10-13. `SOURCES.md` gives the links claim by claim and says where NASM's own
  pages differ or where a line is a G1 addition and not an NASM protocol (the climbing add-ons, baseline tests).
  The quick-reference table gives starting *ideas*, not rules or muscle diagnoses.
- It is **NASM-informed, not an NASM product**, and the pages say so. NASM and OPT are NASM's trademarks.
- No max-effort finger or hangboard testing is suggested in session one, in line with the rest of this repo's
  conservative approach to finger loading.

## Please check before real use

- **NASM check, and its limits.** Claims were checked against NASM's own pages through a search tool restricted to NASM's domains,
  because this environment could not open nasm.org directly. Several NASM blog articles are old and differ in detail from one
  another, and the single-leg squat has no NASM checklist I could find for every line on the sheet. A certified trainer should
  still read `SOURCES.md` against the current NASM textbook. To have me re-check the full pages, allow `nasm.org` and `blog.nasm.org`
  under the environment's network settings.
- **Health questions and privacy** (intake section 5, the pregnancy question, "prefer to discuss" options) should be
  reviewed by G1 management, and by legal counsel if G1 has one, before the form is used. NASM's own guide presents the
  PAR-Q+ as the trainer's pre-participation screen, and the PAR-Q+ Collaboration requires it to be used whole and unaltered, so
  G1 may prefer to attach the official form in place of section 5 (it is not reproduced here).
- **Safety wording.** The stop-and-refer box and the client message tell people to call emergency services or see a healthcare
  professional for red-flag symptoms. G1 should confirm that wording and supply its emergency action plan.
- **Browsers:** layout, printing and the PDFs were tested in Chromium only. Safari (including iPhone and iPad) and Firefox
  printing are untested.
- **Accessibility:** tick boxes and fields are sized for touch and labelled for screen readers, but this hasn't been
  tested with a screen reader.

## Checked

- Print layout: every sheet fits its Letter page with at least 0.2 in spare above the footer (the build script fails otherwise).
- A read-only wording, scope and privacy review was run and its findings applied (stronger emergency wording, no overpromising, print-visible privacy placeholder, consistent status labels).
- Phone: no horizontal scroll at 375 px on any page; no console errors or failed requests.
- Behaviour: typing, mirrored client name, one-choice radios, copy-message button, sample toggle,
  nothing written to storage, no network requests.
