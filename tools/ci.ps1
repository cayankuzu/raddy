# Every automated check in one run, in the order a release needs them: unit and physics tests,
# the multiplayer test, the end-to-end flow test (optionally on every stage), a headless bot run
# through every stage event, and the Windows export. Stops at the first failing step.
#   tools\ci.ps1 [-AllStages] [-SkipExport] [-SkipFlow]
# Exit 0 when everything passed; otherwise the exit code of the failing step (or 1).
param(
    [switch]$AllStages,
    [switch]$SkipExport,
    [switch]$SkipFlow
)
. "$PSScriptRoot\godot.ps1"

$results = [System.Collections.Generic.List[string]]::new()
$started = Get-Date

function Step([string]$name, [scriptblock]$body) {
    $t = Get-Date
    Write-Host "== $name" -ForegroundColor Cyan
    & $body
    $code = $LASTEXITCODE
    $seconds = [int]((Get-Date) - $t).TotalSeconds
    if ($code -ne 0) {
        $results.Add("FAIL  $name ($seconds s, exit $code)")
        $results | ForEach-Object { Write-Host $_ }
        Write-Host "CI FAILED at: $name" -ForegroundColor Red
        exit $(if ($code) { $code } else { 1 })
    }
    $results.Add("pass  $name ($seconds s)")
}

Step "unit and physics tests" { & pwsh -NoProfile -File (Join-Path $PSScriptRoot "test.ps1") }
Step "multiplayer (nettest)" { & pwsh -NoProfile -File (Join-Path $PSScriptRoot "nettest.ps1") }
if (-not $SkipFlow) {
    $stages = if ($AllStages) { 0..5 } else { @(0) }
    foreach ($s in $stages) {
        Step "flow test stage $s" { & pwsh -NoProfile -File (Join-Path $PSScriptRoot "flowtest.ps1") -Clients 1 -Stage $s }
    }
}
Step "bot through every stage event" {
    # The bot starts 80 m before each event and must get past it without a recovery.
    $events = & $GodotConsole --headless --path $ProjectDir -s "res://tools/list_stage_events.gd" 2>&1 | Select-String "^EVENT "
    if (-not $events) { Write-Host "   no stage events found" -ForegroundColor Red; $global:LASTEXITCODE = 1; return }
    $failed = 0
    foreach ($line in $events) {
        $parts = "$line".Trim() -split '\s+'
        $parts = @($parts[1], [string][Math]::Max(0, [int]$parts[2] - 80), $parts[3])
        $out = & $GodotConsole --headless --path $ProjectDir "res://scenes/dev/route_test.tscn" -- "--stage=$($parts[0])" "--start=$($parts[1])" --autodrive --quit-after-seconds=22 2>&1
        $bot = $out | Select-String "ROUTE bot at" | Select-Object -Last 1
        $errors = $out | Select-String "SCRIPT ERROR|^ERROR:"
        Write-Host "   stage $($parts[0]) $($parts[2]) from $($parts[1]) m: $bot"
        if ($null -eq $bot -or $bot -notmatch ", 0 recoveries" -or $errors) {
            $failed++
            $errors | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
        }
    }
    $global:LASTEXITCODE = [int]($failed -gt 0)
}
if (-not $SkipExport) {
    Step "Windows export" { & pwsh -NoProfile -File (Join-Path $PSScriptRoot "export_windows.ps1") }
}

$results | ForEach-Object { Write-Host $_ }
Write-Host ("CI PASSED in {0:N0} min" -f ((Get-Date) - $started).TotalMinutes) -ForegroundColor Green
exit 0
