# Frame times on one stage, windowed at 1920x1080, vsync off, the bot driving (tools\perf_probe.gd: what its ADAPTER, PERF, GPUPASS,
# VIEWPORT and FLIP lines say is written there). Godot runs with --gpu-profile, so that the renderer stamps its passes.
#   tools\perf.ps1 [-Stage 0] [-Quality 1] [-Seconds 30] [-Start 0] [-ExtraArgs "--a,--b"] [-GodotArgs "--render-thread,separate"]
# -GodotArgs go to Godot itself (before the script), -ExtraArgs to the probe and the scene (--flip-<what>=S, --work-top=S, --window=..,
# --scene=look_test, the route_test args).
param(
    [string]$Stage = "0",
    [int]$Quality = 1,
    [int]$Seconds = 30,
    [int]$Start = 0,
    [string[]]$ExtraArgs = @(),
    [string[]]$GodotArgs = @()
)
# From a command line only the first token after -ExtraArgs binds: callers pass one comma-joined string.
$ExtraArgs = @($ExtraArgs | ForEach-Object { $_ -split '[ ,]+' } | Where-Object { $_ })
$GodotArgs = @($GodotArgs | ForEach-Object { $_ -split '[ ,]+' } | Where-Object { $_ })
. "$PSScriptRoot\godot.ps1"

$args = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "1920x1080", "--gpu-profile") + $GodotArgs + @("-s", "res://tools/perf_probe.gd", "--",
    "--stage=$Stage", "--quality=$Quality", "--start=$Start", "--autodrive", "--perf-seconds=$Seconds") + $ExtraArgs
$out = & $GodotConsole @args 2>&1
$built = ($out | Select-String "ROUTE built in (\d+) ms" | Select-Object -Last 1)
$perf = @($out | Select-String "^ADAPTER |^PERF |^GPUPASS |^VIEWPORT |^FLIP ")
if (-not $perf) {
    $out | Select-Object -Last 30 | ForEach-Object { "$_" }
    Write-Host "No PERF lines." -ForegroundColor Red
    exit 1
}
$builtMs = if ($built) { $built.Matches[0].Groups[1].Value } else { "?" }
Write-Host ("stage {0} quality {1}: built {2} ms" -f $Stage, $Quality, $builtMs)
$perf | ForEach-Object { Write-Host "  $($_.Line)" }
$out | Select-String "SCRIPT ERROR|^ERROR:" | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
exit 0
