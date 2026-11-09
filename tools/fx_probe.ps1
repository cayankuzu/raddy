# Shots of what the cars throw into the air, with and without the cloud in the same frozen frame, and how much of the road ahead it
# hides (tools\fx_probe.gd), into reports\screenshots\fx\<Tag>\.
#   tools\fx_probe.ps1 -At "24+30" [-Stage 0] [-Quality 1] [-Weather 0] [-Tag now] [-ExtraArgs "--follower=9,--follower-delay=2,--ride-follower"]
param(
    [string]$At = "20",
    [string]$Stage = "0",
    [int]$Quality = 1,
    [int]$Weather = 0,
    [string]$Tag = "now",
    [string[]]$ExtraArgs = @()
)
# From a command line only the first token after -ExtraArgs binds: callers pass one comma-joined string.
$ExtraArgs = @($ExtraArgs | ForEach-Object { $_ -split '[ ,]+' } | Where-Object { $_ })
. "$PSScriptRoot\godot.ps1"

$dir = Join-Path $ProjectDir "reports\screenshots\fx\$Tag"
$probeArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "1152x648", "--fixed-fps", "60",
    "-s", "res://tools/fx_probe.gd", "--", "--stage=$Stage", "--quality=$Quality", "--weather=$Weather", "--autodrive",
    "--at=$At", "--out=$dir") + $ExtraArgs
$out = & $GodotConsole @probeArgs 2>&1
$out | Select-String "SCRIPT ERROR|^ERROR:|^FXPROBE" | ForEach-Object { Write-Host "$_" }
Write-Host "Shots in $dir"
