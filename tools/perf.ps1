# Frame times on one stage, windowed, the bot driving: one summary line (build time, average fps,
# p95/p99 frame time, draw calls, primitives, physics ms) from tools\perf_probe.gd.
#   tools\perf.ps1 [-Stage 0] [-Quality 1] [-Seconds 30] [-Start 0]
param(
    [string]$Stage = "0",
    [int]$Quality = 1,
    [int]$Seconds = 30,
    [int]$Start = 0
)
. "$PSScriptRoot\godot.ps1"

$args = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "1920x1080", "-s", "res://tools/perf_probe.gd", "--",
    "--stage=$Stage", "--quality=$Quality", "--start=$Start", "--autodrive", "--perf-seconds=$Seconds")
$out = & $GodotConsole @args 2>&1
$built = ($out | Select-String "ROUTE built in (\d+) ms" | Select-Object -Last 1)
$perf = @($out | Select-String "^PERF ")
if (-not $perf) {
    $out | Select-Object -Last 30 | ForEach-Object { "$_" }
    Write-Host "No PERF lines." -ForegroundColor Red
    exit 1
}
$builtMs = if ($built) { $built.Matches[0].Groups[1].Value } else { "?" }
Write-Host ("stage {0} quality {1}: built {2} ms" -f $Stage, $Quality, $builtMs)
$perf | ForEach-Object { Write-Host "  $($_.Line)" }
exit 0
