# Nhap animation tu Pixellab: than tran (bare) + ban mac do (dressed), tach lop trang phuc bang cach tru hai ban cung mau animation.
#  - Hai nhan vat phai animate bang CUNG template, nen tung khung khit nhau tung pixel.
#  - Than tran -> character\hd\sheets\<anim>.png (+ base_frames.tres neu -WriteBody)
#  - Lop do   -> character\hd\fashion\<style>_<anim>.png + character\hd\frames\<prefix>_<style>.tres
# Dung: powershell -File tools\import_pixellab.ps1 -Style pl_navy -Dressed c4fe7d7e-... -Bare 8bb8061e-... -WriteBody
param(
  [string]$Style = "pl_navy",
  [string]$Prefix = "clothes",
  [string]$Dressed = "c4fe7d7e-4786-45ed-ba02-382669df7183",
  [string]$Bare = "8bb8061e-6b59-4948-aaec-19ddd7e33b79",
  [string]$Anims = "idle:idle_bare_ref:idle_navy:4:true,walk:walk_bare_ref:walk_navy:10:true,run:run_bare_ref:run_navy:14:true",
  [switch]$WriteBody,
  [switch]$Cached,
  [int]$HeadCut = 18,
  [string]$Out = "$PSScriptRoot\..\character\hd"
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$out = [IO.Path]::GetFullPath($Out)
$tmp = Join-Path $env:TEMP "pl_import"; New-Item -ItemType Directory -Force $tmp | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$dirs = @("south","south-east","east","north-east","north","north-west","west","south-west")

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing;
public static class Lay {
  public static int HeadCut = 18;
  static int Dist(Color a, Color b) { return Math.Abs(a.R-b.R)+Math.Abs(a.G-b.G)+Math.Abs(a.B-b.B); }
  // frame 64x64 cat tu sheet (cell, hang, cot) voi goc (left, top) trong cell; tra ve ARGB
  public static Color[,] Crop(Bitmap sh, int cell, int row, int col, int left, int top) {
    Color[,] r = new Color[64,64];
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) {
      int sx = col*cell + left + x, sy = row*cell + top + y;
      if (sx < col*cell || sx >= (col+1)*cell || sy < row*cell || sy >= (row+1)*cell) r[x,y] = Color.FromArgb(0,0,0,0);
      else r[x,y] = sh.GetPixel(sx, sy);
    }
    return r;
  }
  public static void Put(Bitmap dst, int ox, int oy, Color[,] a) {
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) dst.SetPixel(ox+x, oy+y, a[x,y]);
  }
  // do cao chan: hang day nhat co pixel trong o hang row cua sheet (toa do trong cell)
  public static int Bottom(Bitmap sh, int cell, int row, int n) {
    int best = -1;
    for (int c=0;c<n;c++) for (int y=cell-1;y>=0;y--) { bool hit=false; for (int x=0;x<cell;x++) if (sh.GetPixel(c*cell+x,row*cell+y).A>40) { hit=true; break; } if (hit) { if (y>best) best=y; break; } }
    return best;
  }
  static int Top(Color[,] a) { for (int y=0;y<64;y++) for (int x=0;x<64;x++) if (a[x,y].A>40) return y; return 0; }
  // dich D de khop dau cua B (dau khong doi): thu dx,dy trong [-4,4], so mat na alpha o 22 hang tren cung
  public static Color[,] Align(Color[,] B, Color[,] D) {
    int top = Top(B), best = int.MaxValue, bx = 0, by = 0;
    for (int dy=-4;dy<=4;dy++) for (int dx=-4;dx<=4;dx++) {
      int s = 0;
      for (int y=top; y<top+22 && y<64; y++) for (int x=0;x<64;x++) {
        int sx = x-dx, sy = y-dy; bool d = (sx>=0&&sy>=0&&sx<64&&sy<64) && D[sx,sy].A>40; bool b = B[x,y].A>40;
        if (d != b) s++;
      }
      if (s < best || (s == best && Math.Abs(dx)+Math.Abs(dy) < Math.Abs(bx)+Math.Abs(by))) { best = s; bx = dx; by = dy; }
    }
    Color[,] R = new Color[64,64];
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) { int sx=x-bx, sy=y-by; R[x,y] = (sx>=0&&sy>=0&&sx<64&&sy<64) ? D[sx,sy] : Color.FromArgb(0,0,0,0); }
    return R;
  }
  public static Color[,] Layer(Color[,] B, Color[,] D0) {
    Color[,] D = Align(B, D0);
    int cutY = Top(B) + HeadCut;
    int T = 40, T2 = 30;
    System.Collections.Generic.List<Color> pal = new System.Collections.Generic.List<Color>();
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) if (B[x,y].A>40) { bool f=false; foreach (Color c in pal) if (Dist(c,B[x,y])<=6) { f=true; break; } if (!f) pal.Add(B[x,y]); }
    Color[,] L = new Color[64,64]; bool[,] k = new bool[64,64];
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) {
      Color pd = D[x,y], pb = B[x,y];
      if (pd.A <= 40 || y < cutY) continue;
      if (pb.A <= 40) { k[x,y] = true; continue; }
      if (Dist(pd,pb) <= T) continue;
      bool pm = false; foreach (Color c in pal) if (Dist(pd,c) <= 24) { pm = true; break; }
      if (pm) continue;
      bool near = false;
      for (int dy=-1;dy<=1 && !near;dy++) for (int dx=-1;dx<=1;dx++) { int xx=x+dx, yy=y+dy; if (xx<0||yy<0||xx>=64||yy>=64) continue; Color q = B[xx,yy]; if (q.A>40 && Dist(pd,q) <= T2) { near = true; break; } }
      if (!near) k[x,y] = true;
    }
    // bo pixel le loi (it hon 2 lang gieng)
    bool[,] k2 = new bool[64,64];
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) { if (!k[x,y]) continue; int c=0; for (int dy=-1;dy<=1;dy++) for (int dx=-1;dx<=1;dx++) { if (dx==0&&dy==0) continue; int xx=x+dx, yy=y+dy; if (xx>=0&&yy>=0&&xx<64&&yy<64&&k[xx,yy]) c++; } if (c>=2) k2[x,y]=true; }
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) L[x,y] = k2[x,y] ? Color.FromArgb(255, D[x,y].R, D[x,y].G, D[x,y].B) : Color.FromArgb(0,0,0,0);
    return L;
  }
}
"@

function Get-Sheet([string]$id, [string]$tag) {
  $zip = Join-Path $tmp "$tag.zip"; $dir = Join-Path $tmp $tag
  if (-not $Cached -or -not (Test-Path $zip)) { Invoke-WebRequest "https://api.pixellab.ai/mcp/characters/$id/spritesheet" -OutFile $zip -UseBasicParsing }
  if (Test-Path $dir) { [IO.Directory]::Delete($dir, $true) }
  Expand-Archive $zip $dir -Force
  $json = Get-Content (Get-ChildItem $dir -Filter *.json | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  $png = [System.Drawing.Bitmap]::FromFile((Get-ChildItem $dir -Filter *.png | Select-Object -First 1).FullName)
  return @{ json = $json; bmp = $png; cell = [int]$json.spritesheet.cell_size.width }
}
function Find-Row($sheet, [string]$anim, [string]$dir) {
  $r = $sheet.json.spritesheet.rows | Where-Object { $_.type -eq "animation" -and ([string]$_.animation) -eq $anim -and $_.direction -eq $dir } | Select-Object -First 1
  return $r
}

[Lay]::HeadCut = $HeadCut
Write-Host "Tai sheet..."
$SB = Get-Sheet $Bare "bare"; $SD = Get-Sheet $Dressed "dress"
New-Item -ItemType Directory -Force (Join-Path $out "sheets"), (Join-Path $out "fashion"), (Join-Path $out "frames") | Out-Null

$info = @()
foreach ($spec in ($Anims -split ",")) {
  $p = $spec -split ":"; $name = $p[0]; $bn = $p[1]; $dn = $p[2]; $fps = [int]$p[3]; $loop = ($p[4] -eq "true")
  $n = 99; $rowsB = @{}; $rowsD = @{}; $ok = $true
  foreach ($d in $dirs) { $rb = Find-Row $SB $bn $d; $rd = Find-Row $SD $dn $d; if (-not $rb -or -not $rd) { $ok = $false; Write-Host "  thieu $name/$d (bare=$([bool]$rb) dressed=$([bool]$rd))"; break }; $rowsB[$d] = $rb; $rowsD[$d] = $rd; $n = [Math]::Min($n, [Math]::Min([int]$rb.frame_count, [int]$rd.frame_count)) }
  if (-not $ok) { Write-Host "Bo qua $name"; continue }
  $sheetBody = New-Object System.Drawing.Bitmap ($n * 64), (8 * 64); $sheetLay = New-Object System.Drawing.Bitmap ($n * 64), (8 * 64)
  for ($r = 0; $r -lt 8; $r++) {
    $d = $dirs[$r]
    $yb = [Lay]::Bottom($SB.bmp, $SB.cell, $rowsB[$d].row, $n)
    $topB = $yb - 60; $leftB = [int](($SB.cell - 64) / 2)
    $topD = $topB - [int]($SB.cell / 2) + [int]($SD.cell / 2); $leftD = [int](($SD.cell - 64) / 2)
    for ($i = 0; $i -lt $n; $i++) {
      $cb = [Lay]::Crop($SB.bmp, $SB.cell, $rowsB[$d].row, $i, $leftB, $topB)
      $cd = [Lay]::Crop($SD.bmp, $SD.cell, $rowsD[$d].row, $i, $leftD, $topD)
      $ly = [Lay]::Layer($cb, $cd)
      [Lay]::Put($sheetBody, ($i * 64), ($r * 64), $cb)
      [Lay]::Put($sheetLay, ($i * 64), ($r * 64), $ly)
    }
  }
  if ($WriteBody) { $sheetBody.Save((Join-Path $out "sheets\$name.png")) }
  $sheetLay.Save((Join-Path $out "fashion\${Style}_$name.png"))
  $sheetBody.Dispose(); $sheetLay.Dispose()
  $info += @{ name = $name; n = $n; fps = $fps; loop = $loop }
  Write-Host ("{0}: {1} khung x 8 huong" -f $name, $n)
}

function Write-Frames([string]$path, [string]$sheetFmt, $list) {
  $ext = New-Object Collections.Generic.List[string]; $sub = New-Object Collections.Generic.List[string]; $an = New-Object Collections.Generic.List[string]
  $ai = 0; $k = 0
  foreach ($a in $list) {
    $ai++
    $ext.Add("[ext_resource type=`"Texture2D`" path=`"$($sheetFmt -f $a.name)`" id=`"$ai`"]")
    for ($r = 0; $r -lt 8; $r++) {
      $frames = New-Object Collections.Generic.List[string]
      for ($i = 0; $i -lt $a.n; $i++) {
        $k++
        $sub.Add("[sub_resource type=`"AtlasTexture`" id=`"Atlas_$k`"]`natlas = ExtResource(`"$ai`")`nregion = Rect2($($i * 64), $($r * 64), 64, 64)`n")
        $frames.Add("{`"duration`": 1.0, `"texture`": SubResource(`"Atlas_$k`")}")
      }
      $lp = if ($a.loop) { "true" } else { "false" }
      $an.Add("{`"frames`": [" + ($frames -join ", ") + "], `"loop`": $lp, `"name`": &`"$($a.name)_$($dirs[$r])`", `"speed`": $($a.fps).0}")
    }
  }
  $steps = $ext.Count + $sub.Count + 1
  $text = "[gd_resource type=`"SpriteFrames`" load_steps=$steps format=3]`n`n" + ($ext -join "`n") + "`n`n" + ($sub -join "`n") + "`n[resource]`nanimations = [" + ($an -join ",`n") + "]`n"
  [IO.File]::WriteAllText($path, $text, $utf8)
}
Write-Frames (Join-Path $out "frames\${Prefix}_$Style.tres") "res://character/hd/fashion/${Style}_{0}.png" $info
if ($WriteBody) { Write-Frames (Join-Path $out "base_frames_pl.tres") "res://character/hd/sheets/{0}.png" $info }
Write-Host "Xong."
