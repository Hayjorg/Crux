/* G1 Personal Training onboarding toolkit: tiny shared script.
   Nothing here saves or sends anything: no localStorage, no cookies, no network calls.
   What you type is gone when the page reloads (print or save a PDF first). */
(function () {
  "use strict";
  var $$ = function (sel) { return Array.prototype.slice.call(document.querySelectorAll(sel)); };
  var isSample = /[?&]sample(=|&|$)/.test(location.search);
  document.body.classList.toggle("is-sample", isSample);

  // Plain inputs: no browser autofill (these pages should never remember a person).
  $$("input").forEach(function (el) { el.setAttribute("autocomplete", "off"); });

  // Multi-line boxes (.ta) are editable divs so they print as ruled lines with no scrollbars.
  $$(".ta").forEach(function (el) {
    el.setAttribute("contenteditable", "true");
    el.setAttribute("role", "textbox");
    el.setAttribute("aria-multiline", "true");
    var box = el.closest(".f"), cap = box && box.querySelector(".lbl");
    if (cap && !el.getAttribute("aria-label")) el.setAttribute("aria-label", cap.textContent.trim());
    el.addEventListener("paste", function (e) {          // paste as plain text only
      e.preventDefault();
      var t = (e.clipboardData || window.clipboardData).getData("text");
      document.execCommand("insertText", false, t);
    });
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
  if (isSample) $$(".dh .tag b").forEach(function (b) { b.textContent = "Sample \u00b7 " + b.textContent; });
  if (isSample) fill((window.G1_SAMPLE || {})[document.body.getAttribute("data-doc")] || {});

  // Running-header client name on later pages mirrors the first page.
  $$("[data-mirror]").forEach(function (m) {
    var src = document.querySelector('[data-k="' + m.getAttribute("data-mirror") + '"]');
    if (!src) return;
    m.readOnly = true;
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
    b.addEventListener("click", function () {
      var src = document.querySelector(b.getAttribute("data-copy"));
      var done = function () { b.textContent = "Copied"; setTimeout(function () { b.textContent = label; }, 1600); };
      var fallback = function () {
        var r = document.createRange(), s = window.getSelection();
        r.selectNodeContents(src); s.removeAllRanges(); s.addRange(r);
        try { document.execCommand("copy"); done(); } catch (e) { b.textContent = "Select and copy"; }
        s.removeAllRanges();
      };
      if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(src.innerText).then(done, fallback);
      else fallback();
    });
  });
})();
