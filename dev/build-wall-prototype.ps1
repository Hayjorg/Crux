# Builds dev/wall-prototype.html from dev/wall-prototype.src.html by embedding trimmed, shrunk
# copies of Crux's own art as data: URIs (an Artifact page can't load images from anywhere else).
# Run from anywhere:  powershell -NoProfile -File dev\build-wall-prototype.ps1
# With -AppAssets it instead writes the same trimmed images to assets/wall/<key>.png for the real
# app's Wall (climber frames excluded: the app already has them).
param([switch]$AppAssets)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class WallArt {
  // Crops fully transparent margins, then scales to fit a w x h box (never upscales).
  public static string Prep(string path, int w, int h, bool trim) {
    using (var src = new Bitmap(path)) {
      Rectangle r = new Rectangle(0, 0, src.Width, src.Height);
      if (trim) r = Bounds(src);
      double s = Math.Min(1.0, Math.Min((double)w / r.Width, (double)h / r.Height));
      int tw = Math.Max(1, (int)Math.Round(r.Width * s)), th = Math.Max(1, (int)Math.Round(r.Height * s));
      using (var dst = new Bitmap(tw, th, PixelFormat.Format32bppArgb))
      using (var g = Graphics.FromImage(dst)) {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
        g.DrawImage(src, new Rectangle(0, 0, tw, th), r, GraphicsUnit.Pixel);
        using (var ms = new System.IO.MemoryStream()) { dst.Save(ms, ImageFormat.Png); return Convert.ToBase64String(ms.ToArray()); }
      }
    }
  }
  static Rectangle Bounds(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n); b.UnlockBits(d);
    int minX = b.Width, minY = b.Height, maxX = -1, maxY = -1;
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
      if (px[y * d.Stride + x * 4 + 3] > 12) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
    }
    if (maxX < 0) return new Rectangle(0, 0, b.Width, b.Height);
    return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
  }
}
"@

$app = Split-Path -Parent $PSScriptRoot
$a = Join-Path $app "assets"
# key = [file, width, height, trim]
$art = [ordered]@{
  tile        = @("homewall\plywood-panel.png", 320, 320, $false)
  bulb        = @("homewall\bare-bulb.png", 120, 170, $true)
  h_jug       = @("decor\jug-hold.png", 120, 120, $true)
  h_slot      = @("decor\slotted-hold.png", 120, 120, $true)
  h_foot      = @("decor\foothold.png", 110, 110, $true)
  h_red       = @("decor\hold-red.png", 110, 120, $true)
  h_purple    = @("decor\hold-purple.png", 80, 120, $true)
  h_gray      = @("decor\hold-gray.png", 100, 110, $true)
  h_yellow    = @("decor\hold-yellow-tri.png", 120, 110, $true)
  h_volume    = @("decor\wall-volume.png", 90, 130, $true)
  h_green     = @("gear\hold-green.png", 110, 100, $true)
  h_yellow2   = @("gear\hold-yellow.png", 100, 100, $true)
  r_chalkbag  = @("decor\chalk-bag.png", 120, 120, $true)
  r_shoes     = @("decor\climbing-shoes.png", 120, 120, $true)
  r_pad       = @("decor\crash-pad.png", 140, 120, $true)
  r_notes     = @("homewall\route-notes.png", 110, 120, $true)
  r_hangboard = @("decor\hangboard.png", 150, 90, $true)
  r_lamp      = @("homewall\clamp-lamp.png", 120, 120, $true)
  r_gearbag   = @("decor\gear-bag.png", 140, 120, $true)
  r_rolled    = @("homewall\rolled-pad.png", 150, 110, $true)
  r_shelf     = @("decor\wall-shelf.png", 140, 120, $true)
  r_print     = @("decor\mountain-print.png", 100, 120, $true)
  r_lights    = @("gear\string-lights.png", 150, 90, $true)
  r_plant     = @("gear\potted-plant.png", 110, 120, $true)
  r_hay       = @("decor\hay-bale.png", 140, 120, $true)
  r_basket    = @("homewall\laundry-basket.png", 120, 120, $true)
  r_fridge    = @("homewall\mini-fridge.png", 110, 130, $true)
  c_idle1     = @("mascot\climber\default\idle\idle-01.png", 132, 198, $false)
  c_idle2     = @("mascot\climber\default\idle\idle-02.png", 132, 198, $false)
  c_idle3     = @("mascot\climber\default\idle\idle-03.png", 132, 198, $false)
  c_idle4     = @("mascot\climber\default\idle\idle-04.png", 132, 198, $false)
  c_blink1    = @("mascot\climber\default\blink\blink-01.png", 132, 198, $false)
  c_blink2    = @("mascot\climber\default\blink\blink-02.png", 132, 198, $false)
  c_jump1     = @("mascot\climber\default\jump\jump-01.png", 132, 198, $false)
  c_jump2     = @("mascot\climber\default\jump\jump-02.png", 132, 198, $false)
  c_jump3     = @("mascot\climber\default\jump\jump-03.png", 132, 198, $false)
  c_land1     = @("mascot\climber\default\land\land-01.png", 132, 198, $false)
  c_land2     = @("mascot\climber\default\land\land-02.png", 132, 198, $false)
}
if ($AppAssets) {
  $dir = Join-Path $a "wall"
  New-Item -ItemType Directory -Force $dir | Out-Null
  foreach ($k in $art.Keys) {
    if ($k -like "c_*") { continue }
    $v = $art[$k]
    $bytes = [Convert]::FromBase64String([WallArt]::Prep((Join-Path $a $v[0]), $v[1], $v[2], $v[3]))
    [IO.File]::WriteAllBytes((Join-Path $dir ($k + ".png")), $bytes)
  }
  "{0} files in {1}" -f (Get-ChildItem $dir).Count, $dir
  return
}
$parts = @()
foreach ($k in $art.Keys) {
  $v = $art[$k]
  $b64 = [WallArt]::Prep((Join-Path $a $v[0]), $v[1], $v[2], $v[3])
  $parts += ('"' + $k + '":"data:image/png;base64,' + $b64 + '"')
}
$js = "var ART = {" + ($parts -join ",`n") + "};"
$src = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "wall-prototype.src.html"))
$out = $src.Replace("/*__ART__*/", $js)
$dest = Join-Path $PSScriptRoot "wall-prototype.html"
[IO.File]::WriteAllText($dest, $out, (New-Object System.Text.UTF8Encoding($false)))
"{0}: {1:N0} bytes, {2} images" -f $dest, (Get-Item $dest).Length, $art.Count
