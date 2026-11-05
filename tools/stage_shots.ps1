# Shots of every place worth a look on the stages (tools\list_stage_spots.gd) from the driver's seat, in
# one process per stage and weather (tools\stage_shots.gd: about a minute a stage), plus an overview per
# stage, into reports\screenshots\stages\<Tag>\<stage>\w<weather>\.
#   tools\stage_shots.ps1 [-Stage n] [-Quality 1] [-Weather 0 | -OwnWeathers] [-Tag now] [-Chase]
param(
    [int]$Stage = -1,
    [int]$Quality = 1,
    [int]$Weather = 0,
    [switch]$OwnWeathers,
    [string]$Tag = "now",
    [switch]$Chase
)
. "$PSScriptRoot\godot.ps1"

$dir = Join-Path $ProjectDir "reports\screenshots\stages\$Tag"
$listArgs = @("--headless", "--path", $ProjectDir, "-s", "res://tools/list_stage_spots.gd")
if ($Stage -ge 0) { $listArgs += @("--", "--stage=$Stage") }
$lines = & $GodotConsole @listArgs 2>&1 | ForEach-Object { "$_" }
$stages = @($lines | Select-String "^WEATHERS " | ForEach-Object { ($_.Line.Trim() -split '\s+')[1] })
foreach ($s in $stages) {
    $weathers = if ($OwnWeathers) {
        ($lines | Select-String "^WEATHERS $s " | Select-Object -First 1).Line.Trim() -split '\s+' | Select-Object -Skip 2
    } else { @($Weather) }
    $spots = @($lines | Select-String "^SPOT $s " | ForEach-Object {
        $p = $_.Line.Trim() -split '\s+'
        "--spot=$($p[2]):$($p[3])"
    })
    foreach ($w in $weathers) {
        $shotArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "1152x648", "--fixed-fps", "60",
            "-s", "res://tools/stage_shots.gd", "--", "--stage=$s", "--quality=$Quality", "--weather=$w",
            "--out=$(Join-Path $dir "$s\w$w")") + $spots
        if ($Chase) { $shotArgs += "--chase" }
        & $GodotConsole @shotArgs 2>&1 | Select-String "SCRIPT ERROR|^ERROR:" | ForEach-Object { Write-Host "$_" -ForegroundColor Red }
        Write-Host ("stage {0} weather {1}: {2} shots" -f $s, $w, $spots.Count)
    }
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot "screenshot.ps1") -Scene "res://scenes/dev/route_test.tscn" -Frames 60 `
        -Out (Join-Path $dir "$s\overview.png") -ExtraArgs "--stage=$s,--overview,--quality=$Quality" | Out-Null
    Write-Host ("stage {0} overview" -f $s)
}
Write-Host "Shots in $dir"
