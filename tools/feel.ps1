# The feel probe and its plots in one go (docs/phases/f_feel_hud.md, Part 1 item 1): route_test windowed with --feel (tools/feel_probe.gd,
# its header says every arg and FEEL line) drives the car through the scripts on its pad and writes reports\feel\<Tag>\<script>.csv (a row a
# physics tick) and <script>.frames.csv (a row a camera frame); tools/plot_feel.gd draws a sheet per script into <Tag>\plots\, or with
# -Compare an earlier tag's runs under these on one sheet per script into <Tag>\vs_<Compare>\.
#   tools\feel.ps1 [-Scripts "step,slalom" | all] [-Tag now] [-Compare <tag>] [-Device key|pad|wheel] [-Assist 1] [-Stage 0] [-Quality 1]
#                  [-ExtraArgs "--a,--b"]
# Prints the FEEL lines (peaks per script, the driver's camera jerk, the flicks). The flick needs the window to keep the mouse: leave it be
# while it runs (about 75 s for every script).
param(
    [string]$Scripts = "all",
    [string]$Tag = "",
    [string]$Compare = "",
    [string]$Device = "",
    [int]$Assist = 1,
    [string]$Stage = "0",
    [int]$Quality = 1,
    [string[]]$ExtraArgs = @()
)
# From a command line only the first token after -ExtraArgs binds: callers pass one comma-joined string.
$ExtraArgs = @($ExtraArgs | ForEach-Object { $_ -split '[ ,]+' } | Where-Object { $_ })
. "$PSScriptRoot\godot.ps1"
if (-not $Tag) { $Tag = Get-Date -Format "yyyyMMdd-HHmm" }
$feel = (($Scripts -split '[ ,+]+') | Where-Object { $_ }) -join "+"
$folder = Join-Path $ProjectDir "reports\feel\$Tag"

$probeArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "1280x720", "res://scenes/dev/route_test.tscn", "--",
    "--stage=$Stage", "--quality=$Quality", "--feel=$feel", "--feel-tag=$Tag", "--feel-assist=$Assist")
if ($Device) { $probeArgs += "--feel-device=$Device" }
$out = & $GodotConsole @($probeArgs + $ExtraArgs) 2>&1
$out | Select-String "^FEEL " | ForEach-Object { Write-Host "  $($_.Line)" }
$errors = @($out | Select-String "SCRIPT ERROR|^ERROR:")
$errors | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
if (-not ($out | Select-String "^FEEL done")) {
    $out | Select-Object -Last 20 | ForEach-Object { "$_" }
    Write-Host "The probe did not finish." -ForegroundColor Red
    exit 1
}

$plotArgs = @("--path", $ProjectDir, "--headless", "-s", "res://tools/plot_feel.gd", "--", "--run=$folder")
if ($Compare) {
    $before = Join-Path $ProjectDir "reports\feel\$Compare"
    if (-not (Test-Path $before)) { Write-Host "No such tag: $before" -ForegroundColor Red; exit 1 }
    $plotArgs += "--compare=$before"
}
if ($Scripts -ne "all") { $plotArgs += "--scripts=$feel" }
$plots = & $GodotConsole @plotArgs 2>&1
$sheets = @($plots | Select-String "^PLOT ")
$sheets | ForEach-Object { Write-Host "  $($_.Line)" }
if (-not $sheets -or $errors) { exit 1 }
exit 0
