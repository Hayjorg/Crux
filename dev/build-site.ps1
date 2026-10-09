# Builds the installable app: a folder of plain files (site/) that any static web host can serve.
#   powershell -NoProfile -File dev\build-site.ps1
# It is NOT the Artifact: crux.html is untouched. The build copies it to index.html with a few extra tags
# (install manifest, icons, "I am the installed app" flag, file versions, service worker) and copies only the
# images the app really uses, so the phone can install it, run it full screen and keep working offline.
# The installed app keeps its own saved data (a different address from the Artifact), so move your data with
# Settings -> Export backup in one and Import backup in the other.
param([string]$Out = (Join-Path (Split-Path -Parent $PSScriptRoot) "site"))
Add-Type -AssemblyName System.Drawing
$app = Split-Path -Parent $PSScriptRoot
$html = [IO.File]::ReadAllText((Join-Path $app "crux.html"))

# every image the app can ask for
$used = [regex]::Matches($html, 'asset\("([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $Out "assets"), (Join-Path $Out "icons") | Out-Null
$hash = [ordered]@{}; $bytes = 0
foreach ($f in $used) {
  $src = Join-Path $app ("assets\" + $f.Replace("/", "\"))
  if (-not (Test-Path $src)) { throw "missing image: $f" }
  $dst = Join-Path $Out ("assets\" + $f.Replace("/", "\"))
  New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
  Copy-Item $src $dst
  $hash[$f] = (Get-FileHash $src -Algorithm SHA256).Hash.Substring(0, 10).ToLower()
  $bytes += (Get-Item $src).Length
}

# icons, from the artwork in pwa/app-icon-source.png (the head sits inside the middle 70%, so it is safe as a maskable icon too)
$iconSrc = [System.Drawing.Image]::FromFile((Join-Path $app "pwa\app-icon-source.png"))
foreach ($n in @(@("icon-192.png", 192), @("icon-512.png", 512), @("apple-touch-icon.png", 180), @("favicon-64.png", 64))) {
  $bmp = New-Object System.Drawing.Bitmap $n[1], $n[1], ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($iconSrc, 0, 0, $n[1], $n[1]); $g.Dispose()
  $bmp.Save((Join-Path $Out ("icons\" + $n[0])), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
$iconSrc.Dispose()

# the install manifest
$manifest = [ordered]@{
  name = "Crux"; short_name = "Crux"
  description = "A climbing session timer and send log with a little climber who levels up with you."
  start_url = "./"; scope = "./"; display = "standalone"; orientation = "portrait"
  background_color = "#F3EEE2"; theme_color = "#F2ECE1"
  icons = @(
    [ordered]@{ src = "icons/icon-192.png"; sizes = "192x192"; type = "image/png"; purpose = "any" },
    [ordered]@{ src = "icons/icon-512.png"; sizes = "512x512"; type = "image/png"; purpose = "any" },
    [ordered]@{ src = "icons/icon-512.png"; sizes = "512x512"; type = "image/png"; purpose = "maskable" }
  )
  # Long-press menu on the home-screen icon (Android shows the first three). Each opens the app and
  # logs one attempt: see quickLogFromLaunch() in crux.html. Two icons each, so JSON keeps it a list.
  shortcuts = @(
    [ordered]@{ name = "Log a Send"; short_name = "Send"; description = "Log a send"; url = "./?log=send"
      icons = @(
        [ordered]@{ src = "icons/icon-192.png"; sizes = "192x192"; type = "image/png" },
        [ordered]@{ src = "icons/icon-512.png"; sizes = "512x512"; type = "image/png" }
      ) },
    [ordered]@{ name = "Log a Flash"; short_name = "Flash"; description = "Log a flash"; url = "./?log=flash"
      icons = @(
        [ordered]@{ src = "icons/icon-192.png"; sizes = "192x192"; type = "image/png" },
        [ordered]@{ src = "icons/icon-512.png"; sizes = "512x512"; type = "image/png" }
      ) },
    [ordered]@{ name = "Log a Fall"; short_name = "Fall"; description = "Log a fall"; url = "./?log=fall"
      icons = @(
        [ordered]@{ src = "icons/icon-192.png"; sizes = "192x192"; type = "image/png" },
        [ordered]@{ src = "icons/icon-512.png"; sizes = "512x512"; type = "image/png" }
      ) }
  )
}
[IO.File]::WriteAllText((Join-Path $Out "manifest.webmanifest"), ($manifest | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $false))

# index.html: crux.html plus the install tags and the standalone flag, and the service worker hook at the end
$vjson = ($hash | ConvertTo-Json -Compress)
$head = @"

<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/png" sizes="64x64" href="icons/favicon-64.png">
<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Crux">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<script>window.__CRUX_STANDALONE = true; window.__CRUX_V = $vjson;</script>
"@
$anchor = "<title>Crux</title>"
if ($html.IndexOf($anchor) -lt 0) { throw "no <title> to anchor on" }
$index = $html.Replace($anchor, $anchor + $head)
$index += "`n<script>if (`"serviceWorker`" in navigator && location.protocol !== `"file:`") { window.addEventListener(`"load`", function () { navigator.serviceWorker.register(`"sw.js`").catch(function () {}); }); }</script>`n"
[IO.File]::WriteAllText((Join-Path $Out "index.html"), $index, (New-Object System.Text.UTF8Encoding $false))

# the service worker: keeps the app and every picture it has shown, so it opens offline (at the crag)
$files = ($hash.Keys | ForEach-Object { '"assets/' + $_ + '?v=' + $hash[$_] + '"' }) -join ",`n  "
$build = (Get-FileHash (Join-Path $Out "index.html") -Algorithm SHA256).Hash.Substring(0, 10).ToLower()
$sw = @"
// Generated by dev/build-site.ps1 (build $build). Do not edit by hand.
var FILES = [
  $files
];
var CACHE = "crux-files", FONTS = "crux-fonts", SCOPE = self.registration.scope;
var CORE = ["index.html", "manifest.webmanifest", "icons/icon-192.png", "icons/icon-512.png", "icons/apple-touch-icon.png", "icons/favicon-64.png"];
self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) {
    return Promise.all(CORE.map(function (u) { return c.add(new Request(u, { cache: "reload" })).catch(function () {}); }));
  }).then(function () { return self.skipWaiting(); }));
});
self.addEventListener("activate", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) {
    // forget pictures that no longer exist or changed (their address carries the file's version)
    var keep = {}; FILES.forEach(function (f) { keep[new URL(f, SCOPE).href] = 1; });
    return c.keys().then(function (reqs) { return Promise.all(reqs.filter(function (r) { return r.url.indexOf("/assets/") > -1 && !keep[r.url]; }).map(function (r) { return c.delete(r); })); });
  }).then(function () { return self.clients.claim(); }));
});
function putCopy(name, req, res) { var copy = res.clone(); caches.open(name).then(function (c) { c.put(req, copy); }); }
self.addEventListener("fetch", function (e) {
  var req = e.request; if (req.method !== "GET") return;
  var url = new URL(req.url);
  if (url.origin === location.origin) {
    if (req.mode === "navigate") { // the page itself: fresh when online, the saved copy when not
      e.respondWith(fetch(req).then(function (res) { if (res.ok) putCopy(CACHE, new URL("index.html", SCOPE).href, res); return res; })
        .catch(function () { return caches.match(new URL("index.html", SCOPE).href); }));
      return;
    }
    if (url.pathname.indexOf("/assets/") > -1 || url.pathname.indexOf("/icons/") > -1) { // pictures: kept after the first time
      e.respondWith(caches.match(req).then(function (hit) {
        return hit || fetch(req).then(function (res) { if (res.ok) putCopy(CACHE, req, res); return res; });
      }));
    }
    return;
  }
  if (/(^|\.)fonts\.(googleapis|gstatic)\.com$/.test(url.hostname)) { // fonts: show the saved copy, refresh in the background
    e.respondWith(caches.open(FONTS).then(function (c) {
      return c.match(req).then(function (hit) {
        var net = fetch(req).then(function (res) { if (res.ok || res.type === "opaque") c.put(req, res.clone()); return res; }).catch(function () { return hit; });
        return hit || net;
      });
    }));
  }
});
"@
[IO.File]::WriteAllText((Join-Path $Out "sw.js"), $sw, (New-Object System.Text.UTF8Encoding $false))

"site: {0}" -f $Out
"{0} pictures, {1:N1} MB, build {2}" -f $used.Count, ($bytes / 1MB), $build
