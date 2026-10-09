# Tao SpriteFrames (.tres) cho ban 64x64: character/hd/base_frames.tres va character/hd/frames/<ten>.tres cho moi lop trang phuc.
# Chi tao animation cho nhung huong (hang) co anh that trong sheet than. So khung = chieu rong sheet / 64.
# Chay sau import_body.ps1 va gen_fashion64.ps1. Dung: powershell -File tools\make_hd_frames.ps1
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path "$PSScriptRoot\..\character").Path
$hd = Join-Path $root "hd"
$utf8 = New-Object Text.UTF8Encoding($false)

# name, fps, loop, la animation chinh (luon co) hay animation ra chieu
$defs = @(
  @{ name="idle";        fps=4;  loop=$true  },
  @{ name="walk";        fps=9;  loop=$true  },
  @{ name="run";         fps=13; loop=$true  },
  @{ name="slash";       fps=12; loop=$false; pick=@(1,2,4,5) },   # chi dung 4 khung gon nhat: gio kiem -> dam ra -> vung -> thu ve
  @{ name="slash_heavy"; fps=12; loop=$false },
  @{ name="thrust";      fps=14; loop=$false },
  @{ name="cast";        fps=10; loop=$false },
  @{ name="ultimate";    fps=9;  loop=$false }
)
$views = @("front", "back", "side")

# Doc cac sheet than: so khung va hang nao co pixel
$info = @()
foreach ($d in $defs) {
  $p = Join-Path $hd "sheets\$($d.name).png"
  if (-not (Test-Path $p)) { continue }
  $bmp = [System.Drawing.Bitmap]::FromFile($p)
  $n = [int]($bmp.Width / 64); $rows = @()
  for ($r = 0; $r -lt 3; $r++) {
    $any = $false
    for ($y = 0; $y -lt 64 -and -not $any; $y += 2) { for ($x = 0; $x -lt $bmp.Width -and -not $any; $x += 2) { if ($bmp.GetPixel($x, $r * 64 + $y).A -gt 40) { $any = $true } } }
    $rows += $any
  }
  $bmp.Dispose()
  $idx = if ($d.pick) { $d.pick } else { 0..($n - 1) }; $info += @{ name = $d.name; fps = $d.fps; loop = $d.loop; n = $n; rows = $rows; idx = $idx }
  Write-Host ("{0}: {1} khung, hang co anh: {2}" -f $d.name, $n, (($rows | ForEach-Object { if ($_) { 'x' } else { '-' } }) -join ''))
}

# texPath: scriptblock nhan ten animation, tra ve duong dan res:// cua sheet
function Build-Frames([scriptblock]$texPath) {
  $ext = New-Object Collections.Generic.List[string]
  $sub = New-Object Collections.Generic.List[string]
  $anims = New-Object Collections.Generic.List[string]
  $ai = 0; $k = 0
  foreach ($a in $info) {
    $ai++
    $ext.Add("[ext_resource type=`"Texture2D`" path=`"$(& $texPath $a.name)`" id=`"$ai`"]")
    for ($r = 0; $r -lt 3; $r++) {
      if (-not $a.rows[$r]) { continue }
      $frames = New-Object Collections.Generic.List[string]
      foreach ($i in $a.idx) {
        $k++
        $sub.Add("[sub_resource type=`"AtlasTexture`" id=`"Atlas_$k`"]`natlas = ExtResource(`"$ai`")`nregion = Rect2($($i * 64), $($r * 64), 64, 64)`n")
        $frames.Add("{`"duration`": 1.0, `"texture`": SubResource(`"Atlas_$k`")}")
      }
      $loop = if ($a.loop) { "true" } else { "false" }
      $anims.Add("{`"frames`": [" + ($frames -join ", ") + "], `"loop`": $loop, `"name`": &`"$($a.name)_$($views[$r])`", `"speed`": $($a.fps).0}")
    }
  }
  $steps = $ext.Count + $sub.Count + 1
  return "[gd_resource type=`"SpriteFrames`" load_steps=$steps format=3]`n`n" + ($ext -join "`n") + "`n`n" + ($sub -join "`n") + "`n[resource]`nanimations = [" + ($anims -join ",`n") + "]`n"
}

[IO.File]::WriteAllText((Join-Path $hd "base_frames.tres"), (Build-Frames { param($n) "res://character/hd/sheets/$n.png" }), $utf8)

$out = Join-Path $hd "frames"
New-Item -ItemType Directory -Force $out | Out-Null
$prefixes = Get-ChildItem (Join-Path $hd "fashion") -Filter "*_idle.png" | ForEach-Object { $_.Name -replace '_idle\.png$', '' }
foreach ($pf in $prefixes) {
  $pfx = $pf
  $text = Build-Frames { param($n) "res://character/hd/fashion/${pfx}_$n.png" }
  [IO.File]::WriteAllText((Join-Path $out "$pf.tres"), $text, $utf8)
}
Write-Host "Xong: base_frames.tres + $(@($prefixes).Count) file frames"
