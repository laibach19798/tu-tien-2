# Nhap trang phuc ve ca nguoi tu Pixellab: lay animation cua nhan vat mac do (cung template voi than tran), can khop
# theo hang chan (hang 60) va theo dau cua than tran de dung lop Clothes "full" (che luon than tran).
# Dung: powershell -File tools\import_fullbody.ps1 -Style tienbao -Dressed 622e182f-... [-Cached]
# Xuat: character\hd\fashion\clothes_<Style>_<idle|walk|run>.png (8 huong x n khung, o 64x64)
param(
  [string]$Style = "tienbao",
  [string]$Dressed = "622e182f-15c6-4121-aeb1-f03a5838fb77",
  [string]$Bare = "8bb8061e-6b59-4948-aaec-19ddd7e33b79",
  [string]$DressedSuffix = "tienbao",
  [switch]$Cached
)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$fashion = Join-Path $root "character\hd\fashion"
$tmp = Join-Path $env:TEMP "fullbody_import"; New-Item -ItemType Directory -Force $tmp | Out-Null
$dirs = @("south","south-east","east","north-east","north","north-west","west","south-west")

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing;
public static class FullBody {
  static int A(int c) { return (c >> 24) & 255; }
  public static int[,] Crop(Bitmap sh, int cell, int row, int col, int left, int top) {
    int[,] r = new int[64,64];
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) {
      int sx = col*cell + left + x, sy = row*cell + top + y;
      if (sx < col*cell || sx >= (col+1)*cell || sy < row*cell || sy >= (row+1)*cell) r[x,y] = 0;
      else r[x,y] = sh.GetPixel(sx, sy).ToArgb();
    }
    return r;
  }
  // hang day nhat co pixel (toa do trong cell) qua n khung cua mot hang
  public static int Bottom(Bitmap sh, int cell, int row, int n) {
    int best = -1;
    for (int c=0;c<n;c++) for (int y=cell-1;y>=0;y--) { bool hit=false; for (int x=0;x<cell;x++) if (A(sh.GetPixel(c*cell+x,row*cell+y).ToArgb())>40) { hit=true; break; } if (hit) { if (y>best) best=y; break; } }
    return best;
  }
  static int Top(int[,] a) { for (int y=0;y<64;y++) for (int x=0;x<64;x++) if (A(a[x,y])>40) return y; return 0; }
  // dich ban mac (D) de khop dau cua than tran (B): thu dx,dy trong [-4,4] tren 22 hang dau
  public static int[,] Align(int[,] B, int[,] D) {
    int top = Top(B), best = int.MaxValue, bx = 0, by = 0;
    for (int dy=-4;dy<=4;dy++) for (int dx=-4;dx<=4;dx++) {
      int s = 0;
      for (int y=top; y<top+22 && y<64; y++) for (int x=0;x<64;x++) {
        int sx = x-dx, sy = y-dy; bool d = (sx>=0&&sy>=0&&sx<64&&sy<64) && A(D[sx,sy])>40; bool b = A(B[x,y])>40;
        if (d != b) s++;
      }
      if (s < best || (s == best && Math.Abs(dx)+Math.Abs(dy) < Math.Abs(bx)+Math.Abs(by))) { best = s; bx = dx; by = dy; }
    }
    int[,] R = new int[64,64];
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) { int sx=x-bx, sy=y-by; R[x,y] = (sx>=0&&sy>=0&&sx<64&&sy<64) ? D[sx,sy] : 0; }
    return R;
  }
  public static void Put(Bitmap dst, int ox, int oy, int[,] a) {
    for (int y=0;y<64;y++) for (int x=0;x<64;x++) dst.SetPixel(ox+x, oy+y, Color.FromArgb(a[x,y]));
  }
}
"@

function Get-Sheet([string]$id, [string]$tag) {
  $zip = Join-Path $tmp "$tag.zip"; $dir = Join-Path $tmp $tag
  if (-not $Cached -or -not (Test-Path $zip)) { Invoke-WebRequest "https://api.pixellab.ai/mcp/characters/$id/spritesheet" -OutFile $zip -UseBasicParsing }
  if (Test-Path $dir) { [IO.Directory]::Delete($dir, $true) }
  Expand-Archive $zip $dir -Force
  $json = Get-Content (Get-ChildItem $dir -Filter *.json | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
  return @{ json = $json; bmp = [System.Drawing.Bitmap]::FromFile((Get-ChildItem $dir -Filter *.png | Select-Object -First 1).FullName); cell = [int]$json.spritesheet.cell_size.width }
}
function Find-Row($sheet, [string]$anim, [string]$dir) {
  return $sheet.json.spritesheet.rows | Where-Object { $_.type -eq "animation" -and ([string]$_.animation) -eq $anim -and $_.direction -eq $dir } | Select-Object -First 1
}

$SB = Get-Sheet $Bare "bare"; $SD = Get-Sheet $Dressed "dress"
$anims = @(@("idle", "idle_bare_ref", "idle_$DressedSuffix"), @("walk", "walk_bare_ref", "walk_$DressedSuffix"), @("run", "run_bare_ref", "run_$DressedSuffix"))
foreach ($a in $anims) {
  $n = 99; $rb = @{}; $rd = @{}
  foreach ($d in $dirs) {
    $b = Find-Row $SB $a[1] $d; $dd = Find-Row $SD $a[2] $d
    if (-not $b -or -not $dd) { throw "thieu $($a[0]) huong $d (bare=$([bool]$b) dressed=$([bool]$dd))" }
    $rb[$d] = $b; $rd[$d] = $dd; $n = [Math]::Min($n, [Math]::Min([int]$b.frame_count, [int]$dd.frame_count))
  }
  $sheet = New-Object System.Drawing.Bitmap ($n * 64), 512, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  for ($r = 0; $r -lt 8; $r++) {
    $d = $dirs[$r]
    $yb = [FullBody]::Bottom($SB.bmp, $SB.cell, $rb[$d].row, $n)
    $topB = $yb - 60; $leftB = [int](($SB.cell - 64) / 2)
    $topD = $topB - [int]($SB.cell / 2) + [int]($SD.cell / 2); $leftD = [int](($SD.cell - 64) / 2)
    for ($i = 0; $i -lt $n; $i++) {
      $cb = [FullBody]::Crop($SB.bmp, $SB.cell, $rb[$d].row, $i, $leftB, $topB)
      $cd = [FullBody]::Crop($SD.bmp, $SD.cell, $rd[$d].row, $i, $leftD, $topD)
      [FullBody]::Put($sheet, ($i * 64), ($r * 64), [FullBody]::Align($cb, $cd))
    }
  }
  $out = Join-Path $fashion "clothes_$($Style)_$($a[0]).png"
  $sheet.Save($out); $sheet.Dispose()
  Write-Host ("{0}: {1} khung x 8 huong -> {2}" -f $a[0], $n, (Split-Path $out -Leaf))
}
# chem (slash) dung lai sheet ao trang (bachvan) vi chua co animation chem rieng
Copy-Item (Join-Path $fashion "clothes_bachvan_slash.png") (Join-Path $fashion "clothes_$($Style)_slash.png") -Force
Write-Host "Xong."
