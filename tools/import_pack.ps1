# Nhap goi nhan vat 8 huong (xuat tu cong cu tao sprite) thanh sheet 64x64 + SpriteFrames cho Godot.
#  - Moi huong trong khung 96x96 bi dat lech khac nhau, nen can lai: so bbox cua khung idle dau tien voi anh "rotations" (64x64, chan o hang 60)
#    de tim do lech (ox, oy) cho tung huong, roi cat khung 64x64 tai do lech do. Khong thu phong (giu nguyen pixel).
#  - Sheet: character\hd\sheets\<anim>.png, rong = so khung * 64, cao = 8 huong * 64.
#    Thu tu hang: south, south-east, east, north-east, north, north-west, west, south-west
#  - Tao character\hd\base_frames.tres va character\hd\base_character.tscn
# Dung: powershell -File tools\import_pack.ps1 [-Pack <thu muc co Idle\rotations va Idle\animations>]
param([string]$Pack = "$PSScriptRoot\..\source\character_pack",
      [string]$Out  = "$PSScriptRoot\..\character\hd")
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$pack = (Resolve-Path $Pack).Path
$out = [IO.Path]::GetFullPath($Out)
$sheets = Join-Path $out "sheets"
New-Item -ItemType Directory -Force $sheets | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)

$dirs = @("south","south-east","east","north-east","north","north-west","west","south-west")
$anims = @(
  @{ src="Breathing_Idle"; name="idle"; fps=4;  loop=$true  },
  @{ src="Walking";        name="walk"; fps=10; loop=$true  },
  @{ src="Running";        name="run";  fps=14; loop=$true  },
  @{ src="Jumping";        name="jump"; fps=12; loop=$false }
)
$FOOT_ROW = 60     # hang cuoi cung co pixel o chan trong anh rotations

function Get-BBox([string]$path) {
  $b = [System.Drawing.Bitmap]::FromFile($path)
  $x0 = 9999; $y0 = 9999; $x1 = -1; $y1 = -1
  for ($y = 0; $y -lt $b.Height; $y++) { for ($x = 0; $x -lt $b.Width; $x++) { if ($b.GetPixel($x, $y).A -gt 40) { if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } } } }
  $b.Dispose()
  return @{ x0 = $x0; y0 = $y0; x1 = $x1; y1 = $y1 }
}

# Do lech (ox, oy) cua tung huong
$off = @{}
foreach ($d in $dirs) {
  $rot = Get-BBox (Join-Path $pack "Idle\rotations\$d.png")
  $idl = Get-BBox (Join-Path $pack "Idle\animations\Breathing_Idle\$d\frame_000.png")
  $ox = [int][math]::Round((($idl.x0 + $idl.x1) / 2.0) - (($rot.x0 + $rot.x1) / 2.0))
  $oy = $idl.y1 - $FOOT_ROW      # chan tat ca cac huong ve cung mot hang
  $off[$d] = @{ ox = $ox; oy = $oy }
  Write-Host ("{0,-11} lech ({1},{2})  chan hang {3}" -f $d, $ox, $oy, $rot.y1)
}

$info = @()
foreach ($a in $anims) {
  $adir = Join-Path $pack "Idle\animations\$($a.src)"
  if (-not (Test-Path $adir)) { continue }
  $n = (Get-ChildItem (Join-Path $adir "south") -Filter "frame_*.png").Count
  $sheet = New-Object System.Drawing.Bitmap ($n * 64), (8 * 64)
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.CompositingMode = 'SourceCopy'; $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
  for ($r = 0; $r -lt 8; $r++) {
    $d = $dirs[$r]; $o = $off[$d]
    for ($i = 0; $i -lt $n; $i++) {
      $f = [System.Drawing.Bitmap]::FromFile((Join-Path $adir ("{0}\frame_{1:D3}.png" -f $d, $i)))
      $dest = New-Object System.Drawing.Rectangle ($i * 64), ($r * 64), 64, 64
      $src = New-Object System.Drawing.Rectangle $o.ox, $o.oy, 64, 64
      $g.DrawImage($f, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
      $f.Dispose()
    }
  }
  $g.Dispose(); $sheet.Save((Join-Path $sheets "$($a.name).png")); $sheet.Dispose()
  $info += @{ name = $a.name; n = $n; fps = $a.fps; loop = $a.loop }
  Write-Host ("{0}: {1} khung x 8 huong" -f $a.name, $n)
}

# base_frames.tres
$ext = New-Object Collections.Generic.List[string]; $sub = New-Object Collections.Generic.List[string]; $an = New-Object Collections.Generic.List[string]
$ai = 0; $k = 0
foreach ($a in $info) {
  $ai++
  $ext.Add("[ext_resource type=`"Texture2D`" path=`"res://character/hd/sheets/$($a.name).png`" id=`"$ai`"]")
  for ($r = 0; $r -lt 8; $r++) {
    $frames = New-Object Collections.Generic.List[string]
    for ($i = 0; $i -lt $a.n; $i++) {
      $k++
      $sub.Add("[sub_resource type=`"AtlasTexture`" id=`"Atlas_$k`"]`natlas = ExtResource(`"$ai`")`nregion = Rect2($($i * 64), $($r * 64), 64, 64)`n")
      $frames.Add("{`"duration`": 1.0, `"texture`": SubResource(`"Atlas_$k`")}")
    }
    $loop = if ($a.loop) { "true" } else { "false" }
    $an.Add("{`"frames`": [" + ($frames -join ", ") + "], `"loop`": $loop, `"name`": &`"$($a.name)_$($dirs[$r])`", `"speed`": $($a.fps).0}")
  }
}
$steps = $ext.Count + $sub.Count + 1
$text = "[gd_resource type=`"SpriteFrames`" load_steps=$steps format=3]`n`n" + ($ext -join "`n") + "`n`n" + ($sub -join "`n") + "`n[resource]`nanimations = [" + ($an -join ",`n") + "]`n"
[IO.File]::WriteAllText((Join-Path $out "base_frames.tres"), $text, $utf8)

# base_character.tscn: chan o hang 60 (canh duoi hang 61) -> tam khung (hang 32) cach chan 29 pixel
$scene = @"
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://character/character.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://character/hd/base_frames.tres" id="2"]

[node name="BaseCharacter" type="Node2D"]
texture_filter = 1
script = ExtResource("1")

[node name="HairBack" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -29)

[node name="Body" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -29)
sprite_frames = ExtResource("2")
animation = &"idle_south"

[node name="Clothes" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -29)

[node name="Shoes" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -29)

[node name="HairFront" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -29)
"@
[IO.File]::WriteAllText((Join-Path $out "base_character.tscn"), $scene, $utf8)
Write-Host "Xong: sheets + base_frames.tres + base_character.tscn"
