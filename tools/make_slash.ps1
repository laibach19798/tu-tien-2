# Ghep animation vung kiem cho bo trang phuc ve ca nguoi (plb_navy) tu cac job transfer_outfit cua Pixellab.
#  - 5 huong (south, south-east, east, north-east, north) tu Pixellab; 3 huong tay lat guong tu huong dong tuong ung.
#  - 6 khung: goc 2,4,5,6,7,8 (khung 6,7 co vet chem). Moi khung dat vao o 96x96, chan khung dung (khung 0 cua than tran) o hang 76.
#  - Ket qua: character\hd\fashion\plb_navy_slash.png, cap nhat clothes_plb_navy.tres va base_frames.tres (Body dung chung anh de dong bo khung).
# Dung: powershell -File tools\make_slash.ps1
param([string]$Out = "$PSScriptRoot\..\character\hd")
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$out = [IO.Path]::GetFullPath($Out)
$tmp = Join-Path $env:TEMP "plb_slash"; New-Item -ItemType Directory -Force $tmp | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$urls = Get-Content "$PSScriptRoot\..\backup\bare_slash_urls.json" -Raw | ConvertFrom-Json
# job A = goc 2,5,6 ; job B = goc 4,7,8
$jobs = [ordered]@{
  "south"      = @{ a = "d76a563b-c358-4809-9587-c7fbe75a5ef4"; b = "17263dca-80a4-4d1a-afe4-5839489d94cf"; key = "south" }
  "south-east" = @{ a = "b8b426cf-e27a-4f3e-bba6-58edef0d101a"; b = "0da7e2b9-a6a6-4f08-a2b9-4ac5811aaa6e"; key = "south-east" }
  "east"       = @{ a = "3a45e6de-6eb4-43db-99cb-d5bde65ca05c"; b = "23993287-fee8-4d2f-aa50-a603580f39dc"; key = "east" }
  "north-east" = @{ a = "345ecc62-c5c5-41b9-8bbf-522c1899a735"; b = "66241106-43be-46f7-a891-078801c536b6"; key = "north-east" }
  "north"      = @{ a = "83f2fc74-b2e9-4909-a8fa-aea3e364d421"; b = "856e8770-634c-4f0c-8008-5585d2cb91cb"; key = "north_2" }
}
$order = @("south","south-east","east","north-east","north","north-west","west","south-west")
$mirror = @{ "north-west" = "north-east"; "west" = "east"; "south-west" = "south-east" }
$N = 6; $C = 96; $FOOT = 76

function Get-Img([string]$name, [string]$url) { $p = Join-Path $tmp $name; if (-not (Test-Path $p)) { Invoke-WebRequest $url -OutFile $p -UseBasicParsing }; return [System.Drawing.Bitmap]::FromFile($p) }
function Bottom($b) { for ($y = $b.Height - 1; $y -ge 0; $y--) { for ($x = 0; $x -lt $b.Width; $x++) { if ($b.GetPixel($x, $y).A -gt 40) { return $y } } }; return $b.Height - 1 }

$sheet = New-Object System.Drawing.Bitmap ($N * $C), (8 * $C)
$g = [System.Drawing.Graphics]::FromImage($sheet); $g.CompositingMode = 'SourceCopy'
$cells = @{}
foreach ($d in $jobs.Keys) {
  $j = $jobs[$d]
  $f0 = Get-Img "bare-$d-0.png" $urls.($j.key)[0]; $yb = Bottom $f0; $f0.Dispose()
  $seq = @(@($j.a, 0), @($j.b, 0), @($j.a, 1), @($j.a, 2), @($j.b, 1), @($j.b, 2))
  $row = New-Object System.Drawing.Bitmap ($N * $C), $C
  $gr = [System.Drawing.Graphics]::FromImage($row); $gr.CompositingMode = 'SourceCopy'
  for ($i = 0; $i -lt $N; $i++) {
    $fr = Get-Img ("{0}-{1}.png" -f $seq[$i][0], $seq[$i][1]) ("https://api.pixellab.ai/mcp/images/{0}/download?index={1}" -f $seq[$i][0], $seq[$i][1])
    $ox = [int](($C - $fr.Width) / 2); $oy = $FOOT - $yb
    $gr.DrawImage($fr, (New-Object System.Drawing.Rectangle ($i * $C + $ox), $oy, $fr.Width, $fr.Height)); $fr.Dispose()
  }
  $gr.Dispose(); $cells[$d] = $row
  Write-Host "${d}: chan khung 0 o hang $yb"
}
for ($r = 0; $r -lt 8; $r++) {
  $d = $order[$r]
  if ($cells.ContainsKey($d)) { $src = $cells[$d]; $flip = $false } else { $src = $cells[$mirror[$d]]; $flip = $true }
  if ($flip) { $tmpb = New-Object System.Drawing.Bitmap $src; for ($i = 0; $i -lt $N; $i++) { } ; $tmpb.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)
    # lat theo tung o: lat ca hang roi dao thu tu o
    $row = New-Object System.Drawing.Bitmap ($N * $C), $C; $gr = [System.Drawing.Graphics]::FromImage($row); $gr.CompositingMode = 'SourceCopy'
    for ($i = 0; $i -lt $N; $i++) { $gr.DrawImage($tmpb, (New-Object System.Drawing.Rectangle ($i * $C), 0, $C, $C), (New-Object System.Drawing.Rectangle (($N - 1 - $i) * $C), 0, $C, $C), [System.Drawing.GraphicsUnit]::Pixel) }
    $gr.Dispose(); $tmpb.Dispose(); $src = $row }
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, ($r * $C), ($N * $C), $C), (New-Object System.Drawing.Rectangle 0, 0, ($N * $C), $C), [System.Drawing.GraphicsUnit]::Pixel)
}
$g.Dispose()
$sheet.Save((Join-Path $out "fashion\plb_navy_slash.png")); $sheet.Dispose()
Write-Host "Da luu plb_navy_slash.png"

# ---- cap nhat tres ----
function New-Anim([string]$name, [int]$sheetId, [int]$n, [int]$cell, [int]$fps, [bool]$loop, [ref]$k, [ref]$sub) {
  $res = @()
  for ($r = 0; $r -lt 8; $r++) { $fr = @()
    for ($i = 0; $i -lt $n; $i++) { $k.Value++; $sub.Value += "[sub_resource type=`"AtlasTexture`" id=`"Atlas_$($k.Value)`"]`natlas = ExtResource(`"$sheetId`")`nregion = Rect2($($i * $cell), $($r * $cell), $cell, $cell)`n"; $fr += "{`"duration`": 1.0, `"texture`": SubResource(`"Atlas_$($k.Value)`")}" }
    $lp = if ($loop) { "true" } else { "false" }
    $res += "{`"frames`": [" + ($fr -join ", ") + "], `"loop`": $lp, `"name`": &`"$($name)_$($order[$r])`", `"speed`": $($fps).0}" }
  return $res
}
# 1) clothes_plb_navy.tres: viet lai day du (idle, walk, run co san + slash)
$sub = @(); $an = @(); $k = 0
$ext = @('[ext_resource type="Texture2D" path="res://character/hd/fashion/plb_navy_idle.png" id="1"]', '[ext_resource type="Texture2D" path="res://character/hd/fashion/plb_navy_walk.png" id="2"]', '[ext_resource type="Texture2D" path="res://character/hd/fashion/plb_navy_run.png" id="3"]', '[ext_resource type="Texture2D" path="res://character/hd/fashion/plb_navy_slash.png" id="4"]')
$an += New-Anim "idle" 1 4 64 4 $true ([ref]$k) ([ref]$sub)
$an += New-Anim "walk" 2 8 64 10 $true ([ref]$k) ([ref]$sub)
$an += New-Anim "run" 3 8 64 14 $true ([ref]$k) ([ref]$sub)
$an += New-Anim "slash" 4 $N $C 14 $false ([ref]$k) ([ref]$sub)
$text = "[gd_resource type=`"SpriteFrames`" load_steps=$($k + 6) format=3]`n`n" + ($ext -join "`n") + "`n`n" + ($sub -join "`n") + "`n[resource]`nanimations = [" + ($an -join ",`n") + "]`n"
[IO.File]::WriteAllText((Join-Path $out "frames\clothes_plb_navy.tres"), $text, $utf8)
Write-Host "Da ghi clothes_plb_navy.tres"

# 2) base_frames.tres: them slash (Body dung chung anh, chi de dong bo khung)
$bf = Join-Path $out "base_frames.tres"; $t = [IO.File]::ReadAllText($bf)
$t = [regex]::Replace($t, '(?s)\[ext_resource type="Texture2D" path="res://character/hd/fashion/plb_navy_slash.png".*?\]\r?\n', '')
$t = [regex]::Replace($t, '(?s)\[sub_resource type="AtlasTexture" id="Slash_\d+"\].*?\r?\n\r?\n', '')
$t = [regex]::Replace($t, '(?s),\s*\{"frames": \[[^\]]*Slash_[^\]]*\], "loop": false, "name": &"slash_[a-z-]+", "speed": [0-9.]+\}', '')
$k2 = 0; $sub2 = @(); $an2 = @()
for ($r = 0; $r -lt 8; $r++) { $fr = @()
  for ($i = 0; $i -lt $N; $i++) { $k2++; $sub2 += "[sub_resource type=`"AtlasTexture`" id=`"Slash_$k2`"]`natlas = ExtResource(`"slashsheet`")`nregion = Rect2($($i * $C), $($r * $C), $C, $C)`n"; $fr += "{`"duration`": 1.0, `"texture`": SubResource(`"Slash_$k2`")}" }
  $an2 += "{`"frames`": [" + ($fr -join ", ") + "], `"loop`": false, `"name`": &`"slash_$($order[$r])`", `"speed`": 14.0}" }
$t = $t.Replace('[resource]', ($sub2 -join "`n") + "`n[resource]")
$rx = New-Object System.Text.RegularExpressions.Regex('(?m)^\[sub_resource')
$t = $rx.Replace($t, '[ext_resource type="Texture2D" path="res://character/hd/fashion/plb_navy_slash.png" id="slashsheet"]' + "`n`n" + '[sub_resource', 1)
$idx = $t.LastIndexOf(']')
$t = $t.Substring(0, $idx) + ",`n" + ($an2 -join ",`n") + $t.Substring($idx)
[IO.File]::WriteAllText($bf, $t, $utf8)
Write-Host "Da them slash vao base_frames.tres"
