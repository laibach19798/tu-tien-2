# Ghep thu than + toc/ao/giay (co mau) cho 8 huong. Moi hang = mot bo do, moi cot = mot huong.
# Dung: powershell -File tools\preview_fashion8.ps1 -Anim walk -Frame 2 -OutFile preview.png [-Zoom 3]
param([string]$Anim = "idle", [int]$Frame = 0, [int]$Zoom = 3, [string]$OutFile = "$PSScriptRoot\..\fashion_preview.png")
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path "$PSScriptRoot\..\character\hd").Path
function Tint([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Layer($path, $col, $row, $tint) {
  if (-not (Test-Path $path)) { return $null }
  $b = [System.Drawing.Bitmap]::FromFile($path); $o = New-Object System.Drawing.Bitmap 64, 64
  for ($y = 0; $y -lt 64; $y++) { for ($x = 0; $x -lt 64; $x++) { $p = $b.GetPixel($col * 64 + $x, $row * 64 + $y); if ($p.A -gt 40) {
    $o.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, [int]($p.R * $tint.R / 255), [int]($p.G * $tint.G / 255), [int]($p.B * $tint.B / 255))) } } }
  $b.Dispose(); return $o }
$outfits = @(
  @{ hair="topknot";  hc="#2a2733"; cl="tunic"; cc="#c8c8cc"; sh="cloth"; sc="#80583a" },
  @{ hair="long";     hc="#d9dcec"; cl="wide";  cc="#f4f4ff"; sh="boot";  sc="#2b2b33" },
  @{ hair="ponytail"; hc="#6b4630"; cl="robe";  cc="#4a78c8"; sh="boot";  sc="#8a6a2a" },
  @{ hair="long";     hc="#1e1c25"; cl="wide";  cc="#8c2b2f"; sh="cloth"; sc="#e8e0d0" }
)
$cell = 64 * $Zoom
$img = New-Object System.Drawing.Bitmap ($cell * 8), ($cell * $outfits.Count)
$g = [System.Drawing.Graphics]::FromImage($img); $g.Clear([System.Drawing.Color]::FromArgb(107, 167, 107)); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
for ($oi = 0; $oi -lt $outfits.Count; $oi++) { $o = $outfits[$oi]
  for ($d = 0; $d -lt 8; $d++) {
    $parts = @(
      @{ p = "$root\fashion\hairb_$($o.hair)_$Anim.png"; t = (Tint $o.hc) },
      @{ p = "$root\sheets\$Anim.png"; t = [System.Drawing.Color]::White },
      @{ p = "$root\fashion\clothes_$($o.cl)_$Anim.png"; t = (Tint $o.cc) },
      @{ p = "$root\fashion\shoes_$($o.sh)_$Anim.png"; t = (Tint $o.sc) },
      @{ p = "$root\fashion\hairf_$($o.hair)_$Anim.png"; t = (Tint $o.hc) })
    foreach ($pt in $parts) { $bm = Layer $pt.p $Frame $d $pt.t; if ($bm) { $g.DrawImage($bm, $d * $cell, $oi * $cell, $cell, $cell); $bm.Dispose() } } } }
$img.Save([IO.Path]::GetFullPath($OutFile)); $g.Dispose(); $img.Dispose()
