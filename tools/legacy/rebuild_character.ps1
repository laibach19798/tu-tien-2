# Dung lai toan bo nhan vat sau khi them/doi anh trong character\sheets_new:
#   1. import_body.ps1     : cat/thu nho cac hang anh raw_*.png thanh sheet 64x64 (idle, walk, run, slash, ...)
#   2. copy sheet vao character\hd\sheets
#   3. gen_fashion64.ps1   : sinh toc / ao / giay cho moi animation
#   4. make_hd_frames.ps1  : tao SpriteFrames (.tres) cho than va tung lop trang phuc
#   5. Godot --import      : nap lai tai nguyen (bo qua bang -SkipGodot)
# Dung: powershell -File tools\rebuild_character.ps1
param([switch]$SkipGodot)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..").Path
$new = Join-Path $root "character\sheets_new"
$hdSheets = Join-Path $root "character\hd\sheets"

Write-Host "== 1/5 import_body"; & powershell -NoProfile -File "$PSScriptRoot\import_body.ps1" | Select-Object -Last 25
if ($LASTEXITCODE -ne 0) { throw "import_body loi" }

Write-Host "== 2/5 copy sheets"
New-Item -ItemType Directory -Force $hdSheets | Out-Null
$names = @("idle","walk","run","slash","slash_heavy","thrust","cast","ultimate")
foreach ($n in $names) {
  foreach ($f in @("$n.png", "${n}_weapon.png")) {
    $s = Join-Path $new $f
    if (Test-Path $s) { Copy-Item $s $hdSheets -Force; Write-Host "  $f" }
  }
}

Write-Host "== 3/5 gen_fashion64";  & powershell -NoProfile -File "$PSScriptRoot\gen_fashion64.ps1" | Select-Object -Last 3
Write-Host "== 4/5 make_hd_frames"; & powershell -NoProfile -File "$PSScriptRoot\make_hd_frames.ps1" | Select-Object -Last 12

if (-not $SkipGodot) {
  $g = Get-ChildItem (Join-Path $root "tools") -Recurse -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($g) { Write-Host "== 5/5 Godot import"; & $g.FullName --headless --path $root --import | Out-Null; Write-Host "  xong" }
  else { Write-Host "== 5/5 khong thay Godot console, bo qua (mo editor la tu nap lai)" }
}
Write-Host "HOAN TAT"
