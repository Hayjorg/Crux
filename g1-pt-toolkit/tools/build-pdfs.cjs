#!/usr/bin/env node
/* Builds the PDFs in ../pdf/ (blank templates) and ../pdf/sample/ (fictional client).
 *
 *   macOS / Linux:  NODE_PATH=<folder containing playwright> node tools/build-pdfs.cjs
 *   Windows (PowerShell):  $env:NODE_PATH = "<folder containing playwright>"; node tools\build-pdfs.cjs
 *   Use your own Chrome or Edge:  set CHROMIUM_PATH to its executable first.
 *
 * Needs Node and Playwright (npm i playwright, then npx playwright install chromium). You do NOT need this to use the
 * toolkit: opening any page and choosing Print > Save as PDF gives the same result.
 *
 * Fails (exit 1) if any page: overflows its sheet; has under 0.2in spare above the footer; has a single-line field whose
 * text is cut off; does not render in the bundled Inter font; or if a PDF's page count differs from the sheet count; or
 * if a key in assets/sample-data.js matches no field.
 */
const path = require("node:path");
const fs = require("node:fs");
const { pathToFileURL } = require("node:url");

let chromium;
try { ({ chromium } = require("playwright")); }
catch (e) {
  console.error("Playwright was not found. Install it (npm i playwright) or set NODE_PATH to the folder that contains it.");
  process.exit(2);
}

const root = path.resolve(__dirname, "..");
const docs = [
  ["01-client-intake", "intake"],
  ["02-first-session-assessment", "assess"],
  ["03-goals-and-progress", "goals"],
  ["04-post-session-followup", "followup"],
];
const MIN_SPARE_IN = 0.2;

(async () => {
  let browser;
  try {
    browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
  } catch (e) {
    console.error("Could not start a browser. Run `npx playwright install chromium`, or set CHROMIUM_PATH to Chrome or Edge.\n" + String(e.message).split("\n")[0]);
    process.exit(2);
  }
  let problems = 0;
  const fail = (msg) => { problems++; console.error(msg); };

  for (const sample of [false, true]) {
    const outDir = path.join(root, "pdf", sample ? "sample" : "");
    fs.mkdirSync(outDir, { recursive: true });
    for (const [file, doc] of docs) {
      const label = file + (sample ? " (sample)" : "");
      const page = await browser.newPage();
      await page.goto(pathToFileURL(path.join(root, file + ".html")).href + (sample ? "?sample" : ""));
      await page.emulateMedia({ media: "print" });
      await page.evaluate(() => document.fonts.ready);

      const sheets = await page.evaluate(() => document.querySelectorAll(".sheet").length);
      const overflow = await page.evaluate(() =>
        Array.from(document.querySelectorAll(".sheet"))
          .map((s, i) => ({ sheet: i + 1, px: s.scrollHeight - s.clientHeight }))
          .filter((x) => x.px > 1));
      if (overflow.length) fail(`OVERFLOW ${label}: ${JSON.stringify(overflow)}`);

      const tight = await page.evaluate((min) =>
        Array.from(document.querySelectorAll(".sheet")).map((s, i) => {
          const f = s.querySelector(".foot");
          return { sheet: i + 1, inches: +((f.getBoundingClientRect().top - f.previousElementSibling.getBoundingClientRect().bottom) / 96).toFixed(2) };
        }).filter((x) => x.inches < min), MIN_SPARE_IN);
      if (tight.length) fail(`TIGHT (under ${MIN_SPARE_IN}in spare above the footer) ${label}: ${JSON.stringify(tight)}`);

      const cut = await page.evaluate(() =>
        Array.from(document.querySelectorAll("input:not([type=checkbox]):not([type=radio])"))
          .filter((i) => i.scrollWidth > i.clientWidth + 1).map((i) => i.getAttribute("data-k") || i.getAttribute("aria-label") || "?"));
      if (cut.length) fail(`TEXT CUT OFF in single-line fields of ${label}: ${cut.join(", ")}`);

      const client = await page.context().newCDPSession(page);
      await client.send("DOM.enable"); await client.send("CSS.enable");
      const { root: dom } = await client.send("DOM.getDocument");
      const { nodeId } = await client.send("DOM.querySelector", { nodeId: dom.nodeId, selector: ".sheet h1, .sheet .mini-title" });
      const { fonts } = await client.send("CSS.getPlatformFontsForNode", { nodeId });
      if (!fonts.some((f) => /^Inter/.test(f.familyName))) fail(`FONT: ${label} did not render in Inter (got ${fonts.map((f) => f.familyName).join(", ")})`);
      await client.detach();

      if (sample) {
        const missing = await page.evaluate((d) => {
          const data = (window.G1_SAMPLE || {})[d] || {};
          return Object.keys(data).filter((k) => !document.querySelector('[data-k="' + k + '"]'));
        }, doc);
        if (missing.length) fail(`SAMPLE KEYS WITH NO FIELD in ${file}: ${missing.join(", ")}`);
      }

      const pdf = path.join(outDir, file + ".pdf");
      await page.pdf({ path: pdf, preferCSSPageSize: true, printBackground: true, tagged: true });
      const pages = (fs.readFileSync(pdf).toString("latin1").match(/\/Type\s*\/Page[^s]/g) || []).length;
      if (pages !== sheets) fail(`PAGE COUNT ${label}: ${sheets} sheets but the PDF has ${pages} pages`);
      console.log("wrote", path.relative(root, pdf), "-", await page.title());
      await page.close();
    }
  }
  await browser.close();
  if (problems) { console.error(problems + " problem(s)."); process.exit(1); }
  console.log("OK: no overflow, 0.2in+ spare on every page, no cut-off fields, Inter rendered, page counts match, sample keys matched.");
})();
