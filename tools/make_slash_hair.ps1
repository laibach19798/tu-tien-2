# Tao lop toc cho animation vung kiem cua bo trang phuc ve ca nguoi (than dung ban dau troc nen toc bi mat khi chem).
#  - Lay khung dung dau tien cua toc (hairf_/hairb_<kieu>_idle.png), do vi tri dau trong khung chem (da bi mat troc) so voi khung dung cua cung huong, dich toc theo do lech do.
#  - Ket qua: hair{f,b}_<kieu>_slash.png (o 96x96, 6 khung) va them animation slash vao hair{f,b}_<kieu>.tres
# Chay SAU gen_fashion8.ps1 (gen_fashion8 viet lai cac file .tres). Dung: powershell -File tools\make_slash_hair.ps1
param([string]$Out = "$PSScriptRoot\..\character\hd", [string]$Outfit = "plb_navy")
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$out = [IO.Path]::GetFullPath($Out)
$utf8 = New-Object Text.UTF8Encoding($false)
$order = @("south","south-east","east","north-east","north","north-west","west","south-west")
$N = 6; $C = 96

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing;
public static class Head {
  static bool Skin(Color c) { return c.A > 40 && c.R > c.G + 30 && c.G > c.B && c.R > 150; }
  // tra ve (cx, top) cua dinh dau: dinh = hang da dau tien; tam = giua nhip da o hang top+4..top+6
  public static int[] Find(Bitmap b, int cx0, int cy0, int w, int h) {
    int top = -1;
    for (int y = 0; y < h && top < 0; y++) for (int x = 0; x < w; x++) if (Skin(b.GetPixel(cx0 + x, cy0 + y))) { top = y; break; }
    if (top < 0) return new int[] { -1, -1 };
    double sum = 0; int n = 0;
    for (int y = top + 4; y <= top + 6 && y < h; y++) { int mn = 999, mx = -1; for (int x = 0; x < w; x++) if (Skin(b.GetPixel(cx0 + x, cy0 + y))) { if (x < mn) mn = x; if (x > mx) mx = x; } if (mx >= 0) { sum += (mn + mx) / 2.0; n++; } }
    if (n == 0) return new int[] { -1, -1 };
    return new int[] { (int)Math.Round(sum / n), top };
  }
}
"@

$slash = [System.Drawing.Bitmap]::FromFile((Join-Path $out "fashion\${Outfit}_slash.png"))
$idle  = [System.Drawing.Bitmap]::FromFile((Join-Path $out "fashion\${Outfit}_idle.png"))

# vi tri dau cua khung dung dau tien tung huong (toa do o 64x64), va cua tung khung chem (toa do o 96x96)
$idleHead = @(); $slashHead = @{}
for ($r = 0; $r -lt 8; $r++) { $idleHead += , [Head]::Find($idle, 0, $r * 64, 64, 64) }
for ($r = 0; $r -lt 8; $r++) { for ($i = 0; $i -lt $N; $i++) { $slashHead["$r,$i"] = [Head]::Find($slash, $i * $C, $r * $C, $C, $C) } }
$d0 = $slashHead["0,0"]; Write-Host ("dau hang 0 khung 0: slash cx={0} top={1}; idle cx={2} top={3}" -f $d0[0], $d0[1], $idleHead[0][0], $idleHead[0][1])

function Append-Slash([string]$tres, [string]$sheetRes) {
  $t = [IO.File]::ReadAllText($tres)
  if ($t.Contains('id="slashsheet"')) { return }
  $rx = New-Object System.Text.RegularExpressions.Regex('(?m)^\[sub_resource')
  $t = $rx.Replace($t, ('[ext_resource type="Texture2D" path="' + $sheetRes + '" id="slashsheet"]' + "`n`n" + '[sub_resource'), 1)
  $sub = @(); $an = @(); $k = 0
  for ($r = 0; $r -lt 8; $r++) { $fr = @()
    for ($i = 0; $i -lt $N; $i++) { $k++; $sub += "[sub_resource type=`"AtlasTexture`" id=`"Slash_$k`"]`natlas = ExtResource(`"slashsheet`")`nregion = Rect2($($i * $C), $($r * $C), $C, $C)`n"; $fr += "{`"duration`": 1.0, `"texture`": SubResource(`"Slash_$k`")}" }
    $an += "{`"frames`": [" + ($fr -join ", ") + "], `"loop`": false, `"name`": &`"slash_$($order[$r])`", `"speed`": 14.0}" }
  $t = $t.Replace('[resource]', ($sub -join "`n") + "`n[resource]")
  $idx = $t.LastIndexOf(']')
  $t = $t.Substring(0, $idx) + ",`n" + ($an -join ",`n") + $t.Substring($idx)
  [IO.File]::WriteAllText($tres, $t, $utf8)
}

foreach ($part in "hairf", "hairb") {
  foreach ($style in "topknot", "long", "ponytail") {
    $src = Join-Path $out "fashion\${part}_${style}_idle.png"
    if (-not (Test-Path $src)) { continue }
    $hair = [System.Drawing.Bitmap]::FromFile($src)
    $sheet = New-Object System.Drawing.Bitmap ($N * $C), (8 * $C); $g = [System.Drawing.Graphics]::FromImage($sheet); $g.CompositingMode = 'SourceCopy'
    for ($r = 0; $r -lt 8; $r++) {
      $ih = $idleHead[$r]
      for ($i = 0; $i -lt $N; $i++) {
        $sh = $slashHead["$r,$i"]
        if ($sh[0] -lt 0 -or $ih[0] -lt 0) { $dx = 16; $dy = 16 } else { $dx = $sh[0] - $ih[0]; $dy = $sh[1] - $ih[1] }
        $dest = New-Object System.Drawing.Rectangle ($i * $C + $dx), ($r * $C + $dy), 64, 64
        $g.DrawImage($hair, $dest, (New-Object System.Drawing.Rectangle 0, ($r * 64), 64, 64), [System.Drawing.GraphicsUnit]::Pixel)
      }
    }
    $g.Dispose(); $hair.Dispose()
    $dst = Join-Path $out "fashion\${part}_${style}_slash.png"; $sheet.Save($dst); $sheet.Dispose()
    Append-Slash (Join-Path $out "frames\${part}_${style}.tres") "res://character/hd/fashion/${part}_${style}_slash.png"
    Write-Host "${part}_${style}: xong"
  }
}
