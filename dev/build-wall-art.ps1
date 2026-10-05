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
  public static void Export(string src, string dst, int boxW, int boxH, int cropL, int cropT, int cropR, int cropB, bool trim, bool hard, int pad) {
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
$dst = Join-Path $app "assets\wall"
New-Item -ItemType Directory -Force $dst | Out-Null
# out-name = source, boxW, boxH, crop L,T,R,B, trim, hard alpha, padding
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
}
foreach ($k in $jobs.Keys) {
  $j = $jobs[$k]
  [WallExport]::Export((Join-Path $src $j[0]), (Join-Path $dst $k), $j[1], $j[2], $j[3], $j[4], $j[5], $j[6], $j[7], $j[8], $j[9])
}
Get-ChildItem $dst | Where-Object { $jobs.Contains($_.Name) } | ForEach-Object {
  $i = [System.Drawing.Image]::FromFile($_.FullName); "{0,-18} {1,4}x{2,-4} {3,8:N0} B" -f $_.Name, $i.Width, $i.Height, $_.Length; $i.Dispose()
}
