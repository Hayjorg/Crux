# Production export for the rooms' art: turns ChatGPT's sources in ../art-source/rooms/incoming/
# into app-sized copies in assets/rooms/<room>/. Sources are never modified.
#   powershell -NoProfile -File dev\build-room-art.ps1
# Per room:   background.jpg   the painted room (opaque, 1024x1536, JPEG)
#             thumb.jpg        picker / unlock picture (opaque, 600x400, JPEG)
#             <item>.png       each decoration: trimmed to its pixels, scaled to fit 320 px, with
#                              near-opaque interiors snapped fully opaque (premultiplied scaling,
#                              so no colour fringe from hidden RGB)
# The Garage has no thumbnail source, so its thumb is cropped from assets/garage/background.png.
# The final line of each decoration's output is its size: copy its height/width ratio into the
# room's ACCESSORIES entry (ar) in crux.html.
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices; using System.Linq;
public static class RoomExport {
  public static void Photo(string src, string dst, int outW, int outH, int cx, int cy, int cw, int ch, long quality) {
    using (var raw = new Bitmap(src))
    using (var o = new Bitmap(outW, outH, PixelFormat.Format24bppRgb)) {
      using (var g = Graphics.FromImage(o)) {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
        if (cw <= 0) { cx = 0; cy = 0; cw = raw.Width; ch = raw.Height; }
        g.DrawImage(raw, new Rectangle(0, 0, outW, outH), cx, cy, cw, ch, GraphicsUnit.Pixel);
      }
      var enc = ImageCodecInfo.GetImageEncoders().First(e => e.MimeType == "image/jpeg");
      var ps = new EncoderParameters(1); ps.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
      o.Save(dst, enc, ps);
    }
  }
  public static string Decor(string src, string dst, int box, int pad) {
    using (var raw = new Bitmap(src))
    using (var pre = new Bitmap(raw.Width, raw.Height, PixelFormat.Format32bppPArgb)) {
      using (var g0 = Graphics.FromImage(pre)) g0.DrawImage(raw, new Rectangle(0, 0, raw.Width, raw.Height));
      Rectangle r = Bounds(pre);
      double s = Math.Min(1.0, (double)(box - 2 * pad) / Math.Max(r.Width, r.Height));
      int tw = Math.Max(1, (int)Math.Round(r.Width * s)), th = Math.Max(1, (int)Math.Round(r.Height * s));
      using (var outp = new Bitmap(tw + 2 * pad, th + 2 * pad, PixelFormat.Format32bppPArgb)) {
        using (var g = Graphics.FromImage(outp)) {
          g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
          g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
          g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
          g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
          using (var wrap = new ImageAttributes()) {
            wrap.SetWrapMode(System.Drawing.Drawing2D.WrapMode.TileFlipXY);
            g.DrawImage(pre, new Rectangle(pad, pad, tw, th), r.X, r.Y, r.Width, r.Height, GraphicsUnit.Pixel, wrap);
          }
        }
        using (var fin = new Bitmap(outp.Width, outp.Height, PixelFormat.Format32bppArgb)) {
          using (var g2 = Graphics.FromImage(fin)) g2.DrawImage(outp, 0, 0, outp.Width, outp.Height);
          SnapAlpha(fin);
          fin.Save(dst, ImageFormat.Png);
          return fin.Width + "x" + fin.Height;
        }
      }
    }
  }
  static void SnapAlpha(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n);
    for (int i = 3; i < n; i += 4) if (px[i] >= 225) px[i] = 255;
    Marshal.Copy(px, 0, d.Scan0, n); b.UnlockBits(d);
  }
  static Rectangle Bounds(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppPArgb);
    int n = d.Stride * b.Height; byte[] px = new byte[n]; Marshal.Copy(d.Scan0, px, 0, n); b.UnlockBits(d);
    int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1;
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++)
      if (px[y * d.Stride + x * 4 + 3] > 10) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
    if (maxX < 0) return new Rectangle(0, 0, b.Width, b.Height);
    return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
  }
}
"@
$app = Split-Path -Parent $PSScriptRoot
$src = Join-Path (Split-Path -Parent $app) "art-source\rooms\incoming"
$out = Join-Path $app "assets\rooms"
$rooms = @{
  homewall = @("step-stool", "desk-fan", "toolbox", "campus-rungs", "beanbag")
  local    = @("chalk-bucket", "brush-stick", "bench", "tape-roll", "volume-stack")
  club     = @("ice-axes", "rucksack", "boots", "lantern", "map")
  dream    = @("monstera", "rings", "trophy", "foam-roller", "smoothie")
}
foreach ($room in $rooms.Keys) {
  $d = Join-Path $out $room; New-Item -ItemType Directory -Force $d | Out-Null
  [RoomExport]::Photo((Join-Path $src "$room\$room-background.png"), (Join-Path $d "background.jpg"), 1024, 1536, 0, 0, 0, 0, 86)
  [RoomExport]::Photo((Join-Path $src "$room\$room-thumb.png"), (Join-Path $d "thumb.jpg"), 600, 400, 0, 0, 0, 0, 86)
  foreach ($item in $rooms[$room]) {
    $size = [RoomExport]::Decor((Join-Path $src "$room\$room-$item.png"), (Join-Path $d "$item.png"), 320, 4)
    "{0,-10} {1,-14} {2}" -f $room, $item, $size
  }
}
# the Wall's gym-ceiling texture (tiles in both directions; a JPEG, so it lives here)
[RoomExport]::Photo((Join-Path (Split-Path -Parent $app) "art-source\wall\incoming-2\topout-ceiling.png"), (Join-Path $app "assets\wall\r2_ceiling.jpg"), 512, 512, 0, 0, 0, 0, 84)
# the Garage's picker picture: the wall, lamp and shutter window from its own painting
$g = Join-Path $out "garage"; New-Item -ItemType Directory -Force $g | Out-Null
[RoomExport]::Photo((Join-Path $app "assets\garage\background.png"), (Join-Path $g "thumb.jpg"), 600, 400, 0, 250, 941, 627, 86)
Get-ChildItem $out -Recurse -File | Where-Object { $_.Extension -eq ".jpg" } | ForEach-Object { "{0,-40} {1,8:N0} B" -f $_.FullName.Replace($out, ""), $_.Length }
