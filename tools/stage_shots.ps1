# Screenshots of every interesting spot of the stages (tools\list_stage_spots.gd) from the driver's
# seat, plus an overview per stage, into reports\screenshots\stages\<Tag>\.
#   tools\stage_shots.ps1 [-Stage n] [-Quality 1] [-Weather 0] [-Tag now] [-Chase]
param(
    [int]$Stage = -1,
    [int]$Quality = 1,
    [int]$Weather = 0,
    [string]$Tag = "now",
    [switch]$Chase
)
. "$PSScriptRoot\godot.ps1"

$dir = Join-Path $ProjectDir "reports\screenshots\stages\$Tag"
New-Item -ItemType Directory -Force $dir | Out-Null
$listArgs = @("--headless", "--path", $ProjectDir, "-s", "res://tools/list_stage_spots.gd")
if ($Stage -ge 0) { $listArgs += @("--", "--stage=$Stage") }
$spots = & $GodotConsole @listArgs 2>&1 | Select-String "^SPOT "
$shot = Join-Path $PSScriptRoot "screenshot.ps1"
$stages = @{}
foreach ($line in $spots) {
    $p = "$line".Trim() -split '\s+'
    $s = $p[1]; $m = $p[2]; $kind = $p[3]
    $stages[$s] = $true
    $extra = "--stage=$s,--start=$m,--quality=$Quality,--weather=$Weather"
    if ($Chase) { $extra += ",--chase" }
    & pwsh -NoProfile -File $shot -Scene "res://scenes/dev/route_test.tscn" -Frames 90 `
        -Out (Join-Path $dir ("{0}_{1}_{2}.png" -f $s, $kind, $m)) -ExtraArgs $extra | Out-Null
    Write-Host ("stage {0} {1} at {2} m" -f $s, $kind, $m)
}
foreach ($s in $stages.Keys) {
    & pwsh -NoProfile -File $shot -Scene "res://scenes/dev/route_test.tscn" -Frames 60 `
        -Out (Join-Path $dir ("{0}_overview.png" -f $s)) -ExtraArgs "--stage=$s,--overview,--quality=$Quality" | Out-Null
    Write-Host ("stage {0} overview" -f $s)
}
Write-Host "Shots in $dir"
