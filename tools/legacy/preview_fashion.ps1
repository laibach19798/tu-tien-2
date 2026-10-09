# Ghép thử các lớp trang phục lên thân nhân vật và lưu ảnh xem trước.
# Dùng: powershell -File tools\preview_fashion.ps1 -OutFile preview.png [-Sub "\hd" -Px 64 -Zoom 3]
param([string]$OutFile = "$PSScriptRoot\..\fashion_preview.png", [string]$Sub = "", [int]$Px = 32, [int]$Zoom = 5)
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path "$PSScriptRoot\..\character$Sub").Path
function Tint([string]$hex) { $c = [System.Drawing.ColorTranslator]::FromHtml($hex); return $c }
function Layer($path, $col, $row, $tint) {
  if (-not (Test-Path $path)) { return $null }
  $b = [System.Drawing.Bitmap]::FromFile($path); $o = New-Object System.Drawing.Bitmap $Px,$Px
  for ($y=0;$y -lt $Px;$y++){ for($x=0;$x -lt $Px;$x++){ $p=$b.GetPixel($col*$Px+$x,$row*$Px+$y); if($p.A -gt 40){
     $r=[int]($p.R*$tint.R/255); $g=[int]($p.G*$tint.G/255); $bl=[int]($p.B*$tint.B/255); $o.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(255,$r,$g,$bl)) } } }
  $b.Dispose(); return $o }
$outfits = @(
  @{ hair="topknot"; hc="#2a2733"; cl="tunic";  cc="#9a9a9a"; sh="cloth"; sc="#7a5538" },
  @{ hair="long";    hc="#d9dcec"; cl="wide";   cc="#f4f4ff"; sh="boot";  sc="#2b2b33" },
  @{ hair="ponytail";hc="#6b4630"; cl="robe";   cc="#4a78c8"; sh="cloth"; sc="#e8e0d0" },
  @{ hair="long";    hc="#1e1c25"; cl="wide";   cc="#33333d"; sh="boot";  sc="#8a6a2a" }
)
$frames = @( @("idle",0,0), @("idle",0,1), @("idle",0,2), @("walk",2,2), @("run",3,0), @("run",3,1) )
$S = $Zoom; $cell = $Px*$S
$img = New-Object System.Drawing.Bitmap ($cell*$frames.Count), ($cell*$outfits.Count)
$g = [System.Drawing.Graphics]::FromImage($img); $g.Clear([System.Drawing.Color]::FromArgb(107,167,107)); $g.InterpolationMode='NearestNeighbor'; $g.PixelOffsetMode='Half'
for ($oi=0;$oi -lt $outfits.Count;$oi++){ $o=$outfits[$oi]
  for ($fi=0;$fi -lt $frames.Count;$fi++){ $a=$frames[$fi][0]; $col=$frames[$fi][1]; $row=$frames[$fi][2]
    $parts = @(
      @{ p="$root\fashion\hairb_$($o.hair)_$a.png"; t=(Tint $o.hc) },
      @{ p="$root\sheets\$a.png"; t=[System.Drawing.Color]::White },
      @{ p="$root\fashion\clothes_$($o.cl)_$a.png"; t=(Tint $o.cc) },
      @{ p="$root\fashion\shoes_$($o.sh)_$a.png"; t=(Tint $o.sc) },
      @{ p="$root\fashion\hairf_$($o.hair)_$a.png"; t=(Tint $o.hc) } )
    foreach($pt in $parts){ $bm = Layer $pt.p $col $row $pt.t; if($bm){ $g.DrawImage($bm, $fi*$cell, $oi*$cell, $cell, $cell); $bm.Dispose() } } } }
$img.Save([IO.Path]::GetFullPath($OutFile)); $g.Dispose(); $img.Dispose()

