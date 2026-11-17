# End-to-end check of the real game flow on one PC: a headless host and N headless clients start
# at the main menu (the exported game's first screen), the host creates a room on 127.0.0.1, the
# clients join it with the room code, everyone takes a seat and gets ready, the host starts, bots
# drive the whole stage, the results come in, the host returns everyone to the room, and all quit.
#   tools\flowtest.ps1 [-Clients 1] [-Seconds 300] [-Stage 0] [-Time 0]
# Exit 0 when every check passes, 1 otherwise. Logs: logs\instance_<n>.log.
param(
    [ValidateRange(1, 5)][int]$Clients = 1,
    [int]$Seconds = 300,
    [int]$Stage = 0,
    [int]$Time = 0
)
. "$PSScriptRoot\godot.ps1"

$launch = Join-Path $PSScriptRoot "launch.ps1"
$players = $Clients + 1
$teams = [Math]::Min($players, 3)  # RosterRules.MAX_TEAMS: extra players sit as navigators
& $launch -Server -Clients $Clients -Headless -Scene "res://scenes/ui/main_menu.tscn" `
    -ExtraArgs "--flow-test,--players=$players,--stage=$Stage,--weather=0,--time=$Time,--autodrive,--bot-roll=19,--quit-after-seconds=$Seconds"

$logs = 0..$Clients | ForEach-Object { Join-Path $ProjectDir "logs\instance_$_.log" }
$deadline = (Get-Date).AddSeconds($Seconds + 15)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    $done = @($logs | Where-Object { (Test-Path $_) -and (Select-String -Path $_ -Pattern "FLOW done|FLOW timeout" -Quiet) })
    if ($done.Count -eq $logs.Count) { break }
}
Start-Sleep -Seconds 3
& $launch -Stop | Out-Null

$failures = [System.Collections.Generic.List[string]]::new()
function Expect([int]$instance, [string]$pattern, [string]$what) {
    $log = Join-Path $ProjectDir "logs\instance_$instance.log"
    if (-not (Test-Path $log) -or -not (Select-String -Path $log -Pattern $pattern -Quiet)) {
        $failures.Add("instance ${instance}: $what (expected /$pattern/)")
    }
}
function ExpectNot([int]$instance, [string]$pattern, [string]$what) {
    $log = Join-Path $ProjectDir "logs\instance_$instance.log"
    if ((Test-Path $log) -and (Select-String -Path $log -Pattern $pattern -Quiet)) {
        $first = (Select-String -Path $log -Pattern $pattern | Select-Object -First 1).Line
        $failures.Add("instance ${instance}: $what (found: $first)")
    }
}

Expect 0 "FLOW starting race" "host started the race from the room"
for ($i = 1; $i -le $Clients; $i++) { Expect $i "FLOW joining with code" "client joined with a room code" }
foreach ($i in 0..$Clients) {
    ExpectNot $i "SCRIPT ERROR|^ERROR:" "no engine errors"
    ExpectNot $i "FLOW timeout" "finished before the time limit"
    Expect $i "FLOW screen menu" "started at the main menu"
    Expect $i "FLOW screen lobby" "reached the room"
    Expect $i "FLOW screen race" "reached the race"
    Expect $i "NET countdown 3 s" "countdown on every peer"
    Expect $i "NET go" "cars released"
    for ($team = 1; $team -le $teams; $team++) {
        Expect $i "NET team $team finished in" "team $team finish reached instance $i"
    }
    Expect $i "NET race finished, order" "results published"
    Expect $i "FLOW results" "results screen shown"
    Expect $i "FLOW done" "back in the room after the race"
}
# --bot-roll=19 (tests/unit/procedural/test_bypasses.gd): on a stage with bypasses (Black Pine) the host's crew keeps to
# the stage and the first client's takes every bypass, so the race follows two roads at once.
$taken = Select-String -Path (Join-Path $ProjectDir "logs\instance_1.log") -Pattern "BOT team 2 takes bypasses \[(.*)\] of (\d+)" | Select-Object -First 1
if ($taken -and [int]$taken.Matches[0].Groups[2].Value -gt 0) {
    Expect 0 "BOT team 1 takes bypasses \[\]" "the host's crew keeps to the stage"
    if ($taken.Matches[0].Groups[1].Value -eq "") { $failures.Add("instance 1: the client's crew takes no bypass") }
    Write-Host ($taken.Line)
}

if ($failures.Count -eq 0) {
    $host_log = Join-Path $ProjectDir "logs\instance_0.log"
    (Select-String -Path $host_log -Pattern "NET team \d+ finished in|FLOW results" | ForEach-Object { $_.Line }) | Write-Host
    # The bots' average over the stage's length, what StageRecords.MEDAL_SPEEDS is judged against.
    $length = [double](Select-String -Path $host_log -Pattern "NET stage \S+ (\d+) m" | Select-Object -First 1).Matches[0].Groups[1].Value
    Select-String -Path $host_log -Pattern "NET team (\d+) finished in (\d+):(\d+\.\d)" | ForEach-Object {
        $g = $_.Matches[0].Groups
        [string]::Format([cultureinfo]::InvariantCulture, "team {0}: {1:F1} m/s over {2} m", $g[1].Value, ($length / ([int]$g[2].Value * 60 + [double]$g[3].Value)), $length)
    } | Write-Host
    Write-Host "FLOW TEST PASSED ($players players)" -ForegroundColor Green
    exit 0
}
Write-Host "FLOW TEST FAILED:" -ForegroundColor Red
$failures | ForEach-Object { Write-Host "  - $_" }
exit 1
