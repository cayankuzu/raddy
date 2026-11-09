# How many runs of a lone bot end with a bullseye or a crack in the windshield, per stage (tools\chip_odds.gd, headless, faster than the
# bot really drives; about a minute a stage).
#   tools\chip_odds.ps1 [-Stage n] [-Weather 0]
param(
    [int]$Stage = -1,
    [int]$Weather = 0
)
. "$PSScriptRoot\godot.ps1"

$stages = if ($Stage -ge 0) { @($Stage) } else { 0..5 }
foreach ($s in $stages) {
    $line = & $GodotConsole --headless --path $ProjectDir --fixed-fps 120 -s res://tools/chip_odds.gd -- "--stage=$s" "--weather=$Weather" --autodrive 2>&1 |
        Select-String "^CHIPS |SCRIPT ERROR"
    $line | ForEach-Object { Write-Host "$_" }
}
