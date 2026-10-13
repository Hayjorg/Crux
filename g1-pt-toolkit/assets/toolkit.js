/* G1 Personal Training onboarding toolkit: tiny shared script.
   Nothing here saves or sends anything: no localStorage, no cookies, no network calls.
   What you type is gone when the page reloads (print or save a PDF first). */
(function () {
  "use strict";
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
  var isSample = /[?&]sample(=|&|$)/.test(location.search);
  document.body.classList.toggle("is-sample", isSample);

  // Plain inputs: no browser autofill (these pages should never remember a person).
  $$("input").forEach(function (el) { el.setAttribute("autocomplete", "off"); });

  // Multi-line boxes (.ta) are editable divs so they print as ruled lines with no scrollbars.
  // "plaintext-only" keeps Enter as a plain newline and blocks rich paste; older browsers fall back to "true"
  // plus a paste handler that inserts text only.
  var probe = document.createElement("div");
  probe.setAttribute("contenteditable", "plaintext-only");
  var plainOnly = probe.contentEditable === "plaintext-only";
  $$(".ta").forEach(function (el) {
    el.setAttribute("contenteditable", plainOnly ? "plaintext-only" : "true");
    el.setAttribute("role", "textbox");
    el.setAttribute("aria-multiline", "true");
    var box = el.closest(".f"), cap = box && box.querySelector(".lbl");
    if (cap && !el.getAttribute("aria-label")) el.setAttribute("aria-label", cap.textContent.trim());
    if (!plainOnly) el.addEventListener("paste", function (e) {
      e.preventDefault();
      var t = (e.clipboardData || window.clipboardData).getData("text");
      document.execCommand("insertText", false, t);
    });
  });

  // Name each tick-box group after its caption (screen readers announce "Decision, group").
  var gid = 0;
  $$(".opts").forEach(function (g) {
    if (g.getAttribute("role") || g.getAttribute("aria-label")) return;
    var cap = g.previousElementSibling;
    if (!cap || !(cap.classList.contains("lbl") || cap.classList.contains("k"))) return;
    if (!cap.id) cap.id = "grp" + (++gid);
    g.setAttribute("role", "group");
    g.setAttribute("aria-labelledby", cap.id);
  });
  // Yes / No / Prefer to discuss rows: every radio is described by its question.
  $$(".qtbl tbody tr").forEach(function (tr, i) {
    var q = tr.cells[0];
    if (!q.id) q.id = "qtext" + i;
    $$("input", tr).forEach(function (inp) { inp.setAttribute("aria-describedby", q.id); });
  });

  // Sample client: any field with data-k="key" is filled from assets/sample-data.js (?sample).
  function fill(data) {
    Object.keys(data).forEach(function (k) {
      $$('[data-k="' + k + '"]').forEach(function (el) {
        if (el.type === "checkbox") el.checked = !!data[k];
        else if (el.type === "radio") el.checked = el.value === data[k];
        else if (el.classList.contains("ta")) el.textContent = data[k];
        else el.value = data[k];
      });
    });
  }
  if (isSample) $$(".dh .tag b").forEach(function (b) { b.textContent = "Sample · " + b.textContent; });
  if (isSample) fill((window.G1_SAMPLE || {})[document.body.getAttribute("data-doc")] || {});

  // Tap a chosen radio again to clear it (a mis-tap, or "no answer").
  var radios = $$("input[type=radio]");
  radios.forEach(function (r) { r.setAttribute("data-was", r.checked ? "1" : ""); });
  radios.forEach(function (r) {
    r.addEventListener("click", function () {
      if (r.getAttribute("data-was") === "1") { r.checked = false; r.setAttribute("data-was", ""); return; }
      radios.forEach(function (x) { if (x.name === r.name) x.setAttribute("data-was", ""); });
      r.setAttribute("data-was", "1");
    });
  });

  // Running-header client name on later pages mirrors the first page (read-only, not a tab stop).
  $$("[data-mirror]").forEach(function (m) {
    var src = document.querySelector('[data-k="' + m.getAttribute("data-mirror") + '"]');
    if (!src) return;
    m.readOnly = true;
    m.tabIndex = -1;
    var sync = function () { m.value = src.value; };
    src.addEventListener("input", sync);
    sync();
  });

  // Toolbar buttons.
  $$("[data-print]").forEach(function (b) { b.addEventListener("click", function () { window.print(); }); });
  $$("[data-sample-toggle]").forEach(function (a) {
    a.textContent = isSample ? "Show blank" : "View sample";
    a.setAttribute("href", isSample ? location.pathname : location.pathname + "?sample");
  });
  $$("[data-copy]").forEach(function (b) {
    var label = b.textContent;
    b.setAttribute("aria-live", "polite");
    var say = function (text, ms) { b.textContent = text; setTimeout(function () { b.textContent = label; }, ms); };
    b.addEventListener("click", function () {
      var src = document.querySelector(b.getAttribute("data-copy"));
      var fallback = function () {
        var r = document.createRange(), s = window.getSelection(), ok = false;
        r.selectNodeContents(src); s.removeAllRanges(); s.addRange(r);
        try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
        if (ok) s.removeAllRanges();            // on failure leave the text selected so it can be copied by hand
        say(ok ? "Copied" : "Select and copy", ok ? 1600 : 4000);
      };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(src.innerText).then(function () { say("Copied", 1600); }, fallback);
      } else fallback();
    });
  });
})();
