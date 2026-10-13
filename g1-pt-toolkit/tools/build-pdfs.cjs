#!/usr/bin/env node
/* Builds the PDFs in ../pdf/ (blank templates) and ../pdf/sample/ (fictional client).
 *
 *   NODE_PATH=<folder containing playwright> node tools/build-pdfs.cjs
 *
 * Needs Node and Playwright with a Chromium. You do NOT need this to use the toolkit: opening any page and choosing
 * Print > Save as PDF gives the same result. It also checks that no sheet overflows its page and that every
 * data-k key in assets/sample-data.js matches a field, and exits non-zero if either check fails.
 */
const path = require("node:path");
const fs = require("node:fs");
const { pathToFileURL } = require("node:url");
const { chromium } = require("playwright");

const root = path.resolve(__dirname, "..");
const docs = [
  ["01-client-intake", "intake"],
  ["02-first-session-assessment", "assess"],
  ["03-goals-and-progress", "goals"],
  ["04-post-session-followup", "followup"],
];

(async () => {
  const launch = process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {};
  const browser = await chromium.launch(launch);
  let problems = 0;
  for (const sample of [false, true]) {
    const outDir = path.join(root, "pdf", sample ? "sample" : "");
    fs.mkdirSync(outDir, { recursive: true });
    for (const [file, doc] of docs) {
      const page = await browser.newPage();
      await page.goto(pathToFileURL(path.join(root, file + ".html")).href + (sample ? "?sample" : ""));
      await page.emulateMedia({ media: "print" });
      await page.evaluate(() => document.fonts.ready);

      const overflow = await page.evaluate(() =>
        Array.from(document.querySelectorAll(".sheet"))
          .map((s, i) => ({ sheet: i + 1, px: s.scrollHeight - s.clientHeight }))
          .filter((x) => x.px > 1));
      if (overflow.length) {
        problems++;
        console.error(`OVERFLOW ${file}${sample ? " (sample)" : ""}:`, JSON.stringify(overflow));
      }
      const tight = await page.evaluate(() =>
        Array.from(document.querySelectorAll(".sheet")).map((s, i) => {
          const f = s.querySelector(".foot");
          return { sheet: i + 1, inches: +((f.getBoundingClientRect().top - f.previousElementSibling.getBoundingClientRect().bottom) / 96).toFixed(2) };
        }).filter((x) => x.inches < 0.2));
      if (tight.length) {
        problems++;
        console.error(`TIGHT (under 0.2in spare above the footer; other fonts could push it over) ${file}${sample ? " (sample)" : ""}:`, JSON.stringify(tight));
      }
      if (sample) {
        const missing = await page.evaluate((d) => {
          const data = (window.G1_SAMPLE || {})[d] || {};
          return Object.keys(data).filter((k) => !document.querySelector('[data-k="' + k + '"]'));
        }, doc);
        if (missing.length) {
          problems++;
          console.error(`SAMPLE KEYS WITH NO FIELD in ${file}:`, missing.join(", "));
        }
      }

      const title = await page.title();
      const pdf = path.join(outDir, file + ".pdf");
      await page.pdf({ path: pdf, preferCSSPageSize: true, printBackground: true });
      console.log("wrote", path.relative(root, pdf), "-", title);
      await page.close();
    }
  }
  await browser.close();
  if (problems) { console.error(problems + " problem(s)."); process.exit(1); }
  console.log("OK: no overflow, at least 0.2in spare on every page, all sample keys matched.");
})();
