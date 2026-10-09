# Kiem tra sheet skin co khop than tran (character/hd/sheets) khong: kich thuoc anh va hang pixel chan thap nhat.
# Dung: powershell -File tools\check_skin_align.ps1 [-Skin plb_navy] [-Tolerance 1]
# Chi so lech > Tolerance thi in CANH BAO (nhan vat se "nhay" khi doi skin, hoac toc de len mat).
param([string]$Skin = "", [int]$Tolerance = 1)
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$fashion = Join-Path $root "character\hd\fashion"
$sheets = Join-Path $root "character\hd\sheets"
$dirs = "south","south-east","east","north-east","north","north-west","west","south-west"

function Get-Bottoms($path, $cell) {
    $bmp = New-Object System.Drawing.Bitmap $path
    $cols = [int]($bmp.Width / $cell); $rows = [int]($bmp.Height / $cell)
    $res = @{}
    for ($r = 0; $r -lt $rows; $r++) { for ($c = 0; $c -lt $cols; $c++) {
        $low = -1
        for ($y = $cell - 1; $y -ge 0 -and $low -lt 0; $y--) {
            for ($x = 0; $x -lt $cell; $x++) {
                if ($bmp.GetPixel($c * $cell + $x, $r * $cell + $y).A -gt 16) { $low = $y; break }
            }
        }
        $res["$r,$c"] = $low
    } }
    $info = @{W = $bmp.Width; H = $bmp.Height; Cols = $cols; Rows = $rows}
    $bmp.Dispose()
    return @{Info = $info; Bottoms = $res}
}

$warn = 0
foreach ($anim in "idle","walk","run") {
    $body = Get-Bottoms (Join-Path $sheets "$anim.png") 64
    $files = Get-ChildItem $fashion -Filter "*_$anim.png" | Where-Object { $Skin -eq "" -or $_.Name -like "*$Skin*" }
    foreach ($f in $files) {
        if ($f.Name -match '^(hair|shoes)') { continue }   # chi kiem tra ao/bo do dai (hair/shoes khong che het than)
        $s = Get-Bottoms $f.FullName 64
        if ($s.Info.W -ne $body.Info.W -or $s.Info.H -ne $body.Info.H) {
            Write-Host "SAI KICH THUOC $($f.Name): $($s.Info.W)x$($s.Info.H), than la $($body.Info.W)x$($body.Info.H)"; $warn++; continue
        }
        $maxd = 0; $worst = ""
        foreach ($k in $body.Bottoms.Keys) {
            if ($body.Bottoms[$k] -lt 0 -or $s.Bottoms[$k] -lt 0) { continue }
            $d = [math]::Abs($body.Bottoms[$k] - $s.Bottoms[$k])
            if ($d -gt $maxd) { $maxd = $d; $r, $c = $k.Split(","); $worst = "huong $($dirs[[int]$r]) frame $c" }
        }
        if ($maxd -gt $Tolerance) { Write-Host "LECH $($f.Name): toi da $maxd px ($worst)"; $warn++ }
        else { Write-Host "ok   $($f.Name) (lech toi da $maxd px)" }
    }
}
Write-Host "Canh bao: $warn"
