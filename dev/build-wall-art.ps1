# Production export for The Wall's art: turns the generated sources in
# ../art-source/wall/incoming/ into small runtime copies in assets/wall/ (pass A: everything except
# the climber frames, which go through the mascot head-lock tools instead).
#   powershell -NoProfile -File dev\build-wall-art.ps1
# Per file: crop N px off chosen edges (seam repair for tiles), trim transparent margins, scale to
# fit a box with premultiplied alpha (no colour fringes from hidden RGB), and for hard objects
# snap near-opaque interiors to fully opaque. Sources are never modified.
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class WallExport {
  public static void Export(string src, string dst, int boxW, int boxH, int cropL, int cropT, int cropR, int cropB, bool trim, bool hard, int pad,
                            double fL, double fT, double fR, double fB, double hue) {
    using (var raw = new Bitmap(src))
    using (var pre = new Bitmap(raw.Width, raw.Height, PixelFormat.Format32bppPArgb)) {
      using (var g0 = Graphics.FromImage(pre)) g0.DrawImage(raw, new Rectangle(0, 0, raw.Width, raw.Height));
      Rectangle r = new Rectangle(cropL, cropT, raw.Width - cropL - cropR, raw.Height - cropT - cropB);
      if (trim) r = Bounds(pre, r);
      double s = Math.Min(1.0, Math.Min((double)(boxW - 2 * pad) / r.Width, (double)(boxH - 2 * pad) / r.Height));
      int tw = Math.Max(1, (int)Math.Round(r.Width * s)), th = Math.Max(1, (int)Math.Round(r.Height * s));
      using (var outp = new Bitmap(tw + 2 * pad, th + 2 * pad, PixelFormat.Format32bppPArgb)) {
        using (var g = Graphics.FromImage(outp)) {
          g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
          g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
          g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
          g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
          using (var wrap = new System.Drawing.Imaging.ImageAttributes()) {
            wrap.SetWrapMode(System.Drawing.Drawing2D.WrapMode.TileFlipXY); // no dark edge from sampling outside
            g.DrawImage(pre, new Rectangle(pad, pad, tw, th), r.X, r.Y, r.Width, r.Height, GraphicsUnit.Pixel, wrap);
          }
        }
        using (var fin = new Bitmap(outp.Width, outp.Height, PixelFormat.Format32bppArgb)) {
          using (var g2 = Graphics.FromImage(fin)) g2.DrawImage(outp, 0, 0, outp.Width, outp.Height);
          if (hard) SnapAlpha(fin);
          if (hue != 0) Recolor(fin, hue);
          if (fL + fT + fR + fB > 0) Feather(fin, fL, fT, fR, fB);
          fin.Save(dst, ImageFormat.Png);
        }
      }
    }
  }
  // Near-opaque interiors of solid objects come out of the generator at alpha 230-254, which reads
  // as slightly see-through on the wall; snap those up. Soft edges (alpha < 200) are left alone.
  static void SnapAlpha(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n);
    for (int i = 3; i < n; i += 4) if (px[i] >= 225) px[i] = 255;
    Marshal.Copy(px, 0, d.Scan0, n); b.UnlockBits(d);
  }
  // Fades alpha to zero across the given fraction of each edge: a stopgap for art the generator
  // cut off at the canvas edge (a wire running off reads fine; a hard cut does not).
  static void Feather(Bitmap b, double fL, double fT, double fR, double fB) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n);
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
      double k = 1, u = (x + 0.5) / b.Width, v = (y + 0.5) / b.Height;
      if (fL > 0 && u < fL) k = Math.Min(k, u / fL);
      if (fR > 0 && 1 - u < fR) k = Math.Min(k, (1 - u) / fR);
      if (fT > 0 && v < fT) k = Math.Min(k, v / fT);
      if (fB > 0 && 1 - v < fB) k = Math.Min(k, (1 - v) / fB);
      if (k < 1) { k = k * k * (3 - 2 * k); int i = y * d.Stride + x * 4 + 3; px[i] = (byte)(px[i] * k); }
    }
    Marshal.Copy(px, 0, d.Scan0, n); b.UnlockBits(d);
  }
  // Rotates hue (degrees) of saturated pixels only, so dark soles and highlights keep their look.
  static void Recolor(Bitmap b, double hue) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n);
    for (int i = 0; i < n; i += 4) {
      if (px[i + 3] == 0) continue;
      double r = px[i + 2] / 255.0, g = px[i + 1] / 255.0, bl = px[i] / 255.0;
      double mx = Math.Max(r, Math.Max(g, bl)), mn = Math.Min(r, Math.Min(g, bl)), l = (mx + mn) / 2, s = 0, h = 0, c = mx - mn;
      if (c < 1e-6) continue;
      s = c / (1 - Math.Abs(2 * l - 1));
      if (mx == r) h = 60 * (((g - bl) / c) % 6); else if (mx == g) h = 60 * ((bl - r) / c + 2); else h = 60 * ((r - g) / c + 4);
      double w = Math.Min(1, s * 1.6); // weight by saturation
      h = (h + hue * w + 360) % 360;
      double C = (1 - Math.Abs(2 * l - 1)) * s, X = C * (1 - Math.Abs((h / 60) % 2 - 1)), m = l - C / 2, R = 0, G = 0, B = 0;
      if (h < 60) { R = C; G = X; } else if (h < 120) { R = X; G = C; } else if (h < 180) { G = C; B = X; } else if (h < 240) { G = X; B = C; } else if (h < 300) { R = X; B = C; } else { R = C; B = X; }
      px[i + 2] = (byte)Math.Round(Math.Max(0, Math.Min(1, R + m)) * 255); px[i + 1] = (byte)Math.Round(Math.Max(0, Math.Min(1, G + m)) * 255); px[i] = (byte)Math.Round(Math.Max(0, Math.Min(1, B + m)) * 255);
    }
    Marshal.Copy(px, 0, d.Scan0, n); b.UnlockBits(d);
  }
  static Rectangle Bounds(Bitmap b, Rectangle within) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n); b.UnlockBits(d);
    int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1;
    for (int y = within.Top; y < within.Bottom; y++) for (int x = within.Left; x < within.Right; x++)
      if (px[y * d.Stride + x * 4 + 3] > 10) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
    if (maxX < 0) return within;
    return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
  }
}
"@
$app = Split-Path -Parent $PSScriptRoot
$src = Join-Path (Split-Path -Parent $app) "art-source\wall\incoming"
$assets = Join-Path $app "assets"
$src2 = Join-Path (Split-Path -Parent $app) "art-source\wall\incoming-2"
$src3 = Join-Path (Split-Path -Parent $app) "art-source\round3"
$dst = Join-Path $app "assets\wall"
New-Item -ItemType Directory -Force $dst | Out-Null
# out-name = source, boxW, boxH, crop L,T,R,B, trim, hard alpha, padding[, feather L,T,R,B (fraction of the edge), hue shift]
# A source starting with "app:" is read from this app's assets/ folder, and "r2:" from art-source/wall/incoming-2, "r3:" from art-source/round3.
# (The Wall's ceiling texture is exported by dev/build-room-art.ps1, because it is a JPEG.)
$jobs = [ordered]@{
  "wall2.png"        = @("wall-tile.png", 300, 300, 6,6,6,6, $false, $false, 0)
  "stud2.png"        = @("wall-stud.png", 40, 2000, 0,6,0,6, $true, $true, 0)
  "ground2.png"      = @("ground.png", 600, 300, 4,0,4,0, $true, $true, 0)
  "ledge2.png"       = @("ledge.png", 560, 200, 0,0,0,0, $true, $true, 0)
  "summit.png"       = @("summit.png", 560, 440, 0,0,0,0, $true, $true, 0)
  "h2_crimp.png"     = @("hold-crimp.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_pinch.png"     = @("hold-pinch.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_jug.png"       = @("hold-jug.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_sloper.png"    = @("hold-sloper.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_tufa.png"      = @("hold-tufa.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_dual.png"      = @("hold-dual-texture.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_macro.png"     = @("hold-macro.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "h2_chip.png"      = @("hold-foot-chip.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "c_mint.png"       = @("chalk-mint.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "c_sunset.png"     = @("chalk-sunset.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "c_lilac.png"      = @("chalk-lilac.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "c_glacier.png"    = @("chalk-glacier.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "c_neon.png"       = @("chalk-neon-green.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "c_gold.png"       = @("chalk-gold.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "c_midnight.png"   = @("chalk-midnight.png", 170, 170, 0,0,0,0, $true, $false, 2)
  "title_plate.png"  = @("title-plate.png", 520, 200, 0,0,0,0, $true, $true, 0)
  "golden_shoes.png" = @("golden-shoes.png", 190, 170, 0,0,0,0, $true, $true, 2)
  "mystery.png"      = @("mystery.png", 170, 170, 0,0,0,0, $true, $true, 2)
  "home_wall.png"    = @("home-wall-gym.png", 300, 200, 0,0,0,0, $false, $false, 0)
  "rays.png"         = @("reveal-rays.png", 340, 340, 0,0,0,0, $false, $false, 0)
  "sparkle.png"      = @("reveal-sparkle.png", 360, 360, 0,0,0,0, $true, $false, 0)
  "flame_s.png"      = @("streak-flame-small.png", 110, 110, 0,0,0,0, $true, $false, 2)
  "flame_l.png"      = @("streak-flame-large.png", 110, 110, 0,0,0,0, $true, $false, 2)
  "flame_b.png"      = @("streak-flame-blue.png", 110, 110, 0,0,0,0, $true, $false, 2)
  # round 2 (art-source/wall/incoming-2): clean redraws of pieces round 1 clipped, more holds, icons, plinth
  "r2_shoes.png"       = @("r2:climbing-shoes.png", 130, 120, 0,0,0,0, $true, $true, 2)
  "r2_gearbag.png"     = @("r2:gear-bag.png", 150, 120, 0,0,0,0, $true, $true, 2)
  "r2_shelf.png"       = @("r2:wall-shelf.png", 150, 140, 0,0,0,0, $true, $true, 2)
  "r2_lights.png"      = @("r2:string-lights.png", 160, 100, 0,0,0,0, $true, $false, 2)
  "r2_hold_purple.png" = @("r2:hold-purple-pinch.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_grey.png"   = @("r2:hold-grey-pocket.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_blue.png"   = @("r2:hold-blue-volume.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_mint.png"   = @("r2:hold-mint-edge.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_navy.png"   = @("r2:hold-navy-pinch.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_red.png"    = @("r2:hold-red-jug.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_sand.png"   = @("r2:hold-sand-sloper.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_wood.png"   = @("r2:hold-wood-edge.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_hold_yellow.png" = @("r2:hold-yellow-pocket.png", 130, 130, 0,0,0,0, $true, $true, 4)
  "r2_icon_climb.png"  = @("r2:icon-climb.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "r2_icon_workout.png"= @("r2:icon-workout.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "r2_icon_rest.png"   = @("r2:icon-rest.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "r2_icon_unlocks.png"= @("r2:icon-unlocks.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "r2_plinth.png"      = @("r2:reveal-plinth.png", 400, 300, 0,0,0,0, $true, $true, 2)
  # seasons (round 1 sources): cropped to the union of the plain and seasonal artwork so the leaves and snow
  # overhang the plain piece by known amounts (see wall season code in crux.html; numbers measured in source px:
  # ledge base 34,196-1948,631 vs autumn 32,109-1950,632; summit base 1,201-1445,1085 vs snow 1,173-1446,1085)
  "ledge_autumn.png"   = @("ledge-autumn.png", 562, 200, 32,109,32,160, $false, $true, 0)
  "summit_snow.png"    = @("summit-snow.png", 560, 440, 1,173,1,0, $false, $true, 0)
  # round 3 (art-source/round3): Home screen icons, level badge, empty-logbook picture (to assets/ui/) and two Garage redraws (to assets/decor/):
  # the "../" keys put these outside assets/wall/ so they stay if the Wall is removed
  "../ui/start.png"    = @("r3:icon-start.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/workouts.png" = @("r3:icon-workouts.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/progress.png" = @("r3:icon-progress.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/drills.png"   = @("r3:icon-drills.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/settings.png" = @("r3:icon-settings.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/customize.png"= @("r3:icon-customize.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/arrange.png"  = @("r3:icon-arrange.png", 120, 120, 0,0,0,0, $true, $true, 2)
  "../ui/badge.png"         = @("r3:level-badge.png", 320, 320, 0,0,0,0, $true, $true, 2)
  "../ui/empty.png"         = @("r3:empty-history.png", 380, 300, 0,0,0,0, $true, $true, 2)
  "../decor/hangboard-clean.png"     = @("r3:hangboard.png", 340, 240, 0,0,0,0, $true, $true, 2)
  "../decor/mountain-print-clean.png"         = @("r3:mountain-print.png", 240, 240, 0,0,0,0, $true, $true, 2)
}
foreach ($k in $jobs.Keys) {
  $j = $jobs[$k]
  $from = if ($j[0] -like "app:*") { Join-Path $assets $j[0].Substring(4) } elseif ($j[0] -like "r2:*") { Join-Path $src2 $j[0].Substring(3) } elseif ($j[0] -like "r3:*") { Join-Path $src3 $j[0].Substring(3) } else { Join-Path $src $j[0] }
  $fe = if ($j.Count -ge 15) { $j[10..14] } else { @(0,0,0,0,0) }
  [WallExport]::Export($from, (Join-Path $dst $k), $j[1], $j[2], $j[3], $j[4], $j[5], $j[6], $j[7], $j[8], $j[9], $fe[0], $fe[1], $fe[2], $fe[3], $fe[4])
}
Get-ChildItem $dst | Where-Object { $jobs.Contains($_.Name) } | ForEach-Object {
  $i = [System.Drawing.Image]::FromFile($_.FullName); "{0,-18} {1,4}x{2,-4} {3,8:N0} B" -f $_.Name, $i.Width, $i.Height, $_.Length; $i.Dispose()
}
