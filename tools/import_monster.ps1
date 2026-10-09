# Nhap quai vat tu Pixellab: tai bang sprite, can chan ve cung mot hang, tao sheet + SpriteFrames cho Godot.
#  - Moi khung duoc cat ve o vuong -Canvas (mac dinh 64); chan o hang (Canvas/2 + 28) nen node sprite de o (0,-28).
#  - Ket qua: character\monsters\<Name>\<anim>.png (so khung x 8 huong) va character\monsters\<Name>\frames.tres
# Dung: powershell -File tools\import_monster.ps1 -Id <uuid> -Name wolf -Canvas 80 -Anims "walk:walk:10,attack:bark:12"
#   (Anims: ten_trong_game:ten_trong_pixellab:fps)
param(
  [Parameter(Mandatory = $true)][string]$Id,
  [Parameter(Mandatory = $true)][string]$Name,
  [int]$Canvas = 64,
  [string]$Anims = "walk:walk:10",
  [string]$Out = ""
)
if ($Out -eq "") { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) "character\monsters" }
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$out = Join-Path ([IO.Path]::GetFullPath($Out)) $Name
New-Item -ItemType Directory -Force $out | Out-Null
$tmp = Join-Path $env:TEMP "pl_monster_$Name"; New-Item -ItemType Directory -Force $tmp | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$dirs = @("south","south-east","east","north-east","north","north-west","west","south-west")
$FOOT = [int]($Canvas / 2) + 28

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing;
public static class Mon {
  public static int Bottom(Bitmap sh, int cell, int row, int n) {
    int best = -1;
    for (int c = 0; c < n; c++) for (int y = cell - 1; y >= 0; y--) { bool hit = false; for (int x = 0; x < cell; x++) if (sh.GetPixel(c * cell + x, row * cell + y).A > 40) { hit = true; break; } if (hit) { if (y > best) best = y; break; } }
    return best;
  }
  public static void Put(Bitmap sh, int cell, int row, int col, int left, int top, Bitmap dst, int dx, int dy, int canvas) {
    for (int y = 0; y < canvas; y++) for (int x = 0; x < canvas; x++) {
      int sx = left + x, sy = top + y;
      if (sx < 0 || sx >= cell || sy < 0 || sy >= cell) continue;
      dst.SetPixel(dx + x, dy + y, sh.GetPixel(col * cell + sx, row * cell + sy));
    }
  }
}
"@

$zip = Join-Path $tmp "sheet.zip"; $dir = Join-Path $tmp "sheet"
Invoke-WebRequest "https://api.pixellab.ai/mcp/characters/$Id/spritesheet" -OutFile $zip -UseBasicParsing
if (Test-Path $dir) { [IO.Directory]::Delete($dir, $true) }
Expand-Archive $zip $dir -Force
$j = Get-Content (Get-ChildItem $dir -Filter *.json | Select-Object -First 1).FullName -Raw | ConvertFrom-Json
$cell = [int]$j.spritesheet.cell_size.width
$sheet = [System.Drawing.Bitmap]::FromFile((Get-ChildItem $dir -Filter *.png | Select-Object -First 1).FullName)
Write-Host "cell $cell, canvas $Canvas"

$info = @()
foreach ($spec in ($Anims -split ",")) {
  $p = $spec -split ":"; $game = $p[0]; $src = $p[1]; $fps = [int]$p[2]
  $rows = @{}; $n = 99
  foreach ($d in $dirs) {
    $r = $j.spritesheet.rows | Where-Object { $_.type -eq "animation" -and ([string]$_.animation) -eq $src -and $_.direction -eq $d } | Select-Object -First 1
    if (-not $r) { Write-Host "  thieu $src/$d"; $rows = $null; break }
    $rows[$d] = $r; $n = [Math]::Min($n, [int]$r.frame_count)
  }
  if ($null -eq $rows) { continue }
  $img = New-Object System.Drawing.Bitmap ($n * $Canvas), (8 * $Canvas)
  for ($ri = 0; $ri -lt 8; $ri++) {
    $d = $dirs[$ri]; $row = $rows[$d].row
    $yb = [Mon]::Bottom($sheet, $cell, $row, $n)
    $left = [int](($cell - $Canvas) / 2); $top = $yb - $FOOT
    for ($i = 0; $i -lt $n; $i++) { [Mon]::Put($sheet, $cell, $row, $i, $left, $top, $img, ($i * $Canvas), ($ri * $Canvas), $Canvas) }
  }
  $img.Save((Join-Path $out "$game.png")); $img.Dispose()
  $info += @{ name = $game; n = $n; fps = $fps }
  Write-Host ("{0}: {1} khung x 8 huong" -f $game, $n)
}

$ext = @(); $sub = @(); $an = @(); $k = 0; $ai = 0
foreach ($a in $info) {
  $ai++
  $ext += "[ext_resource type=`"Texture2D`" path=`"res://character/monsters/$Name/$($a.name).png`" id=`"$ai`"]"
  for ($r = 0; $r -lt 8; $r++) {
    $fr = @()
    for ($i = 0; $i -lt $a.n; $i++) { $k++; $sub += "[sub_resource type=`"AtlasTexture`" id=`"Atlas_$k`"]`natlas = ExtResource(`"$ai`")`nregion = Rect2($($i * $Canvas), $($r * $Canvas), $Canvas, $Canvas)`n"; $fr += "{`"duration`": 1.0, `"texture`": SubResource(`"Atlas_$k`")}" }
    $an += "{`"frames`": [" + ($fr -join ", ") + "], `"loop`": true, `"name`": &`"$($a.name)_$($dirs[$r])`", `"speed`": $($a.fps).0}"
  }
}
$text = "[gd_resource type=`"SpriteFrames`" load_steps=$($ext.Count + $sub.Count + 1) format=3]`n`n" + ($ext -join "`n") + "`n`n" + ($sub -join "`n") + "`n[resource]`nanimations = [" + ($an -join ",`n") + "]`n"
[IO.File]::WriteAllText((Join-Path $out "frames.tres"), $text, $utf8)
Write-Host "Xong: $out"
