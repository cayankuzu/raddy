# Automated multiplayer check on one PC: a headless host plus N headless clients run
# scenes/dev/net_test.tscn with scripted actions, then the "NET ..." log lines are checked.
#   tools\nettest.ps1 [-Clients 3] [-Seconds 22]
# Exit 0 when every check passes, 1 otherwise. Logs: logs\instance_<n>.log.
param(
    [ValidateRange(2, 6)][int]$Clients = 3,
    [int]$Seconds = 22
)
. "$PSScriptRoot\godot.ps1"

$launch = Join-Path $PSScriptRoot "launch.ps1"
& $launch -Server -Clients $Clients -Headless -Scene "res://scenes/dev/net_test.tscn" `
    -ExtraArgs "--players=$Clients,--autodrive,--local,--test-script,--quit-after-seconds=$Seconds"
Start-Sleep -Seconds ($Seconds + 8)
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
        $failures.Add("instance ${instance}: $what (found /$pattern/)")
    }
}
function LastValue([int]$instance, [string]$pattern) {
    $log = Join-Path $ProjectDir "logs\instance_$instance.log"
    $m = Select-String -Path $log -Pattern $pattern | Select-Object -Last 1
    if ($m) { return [double]::Parse($m.Matches[0].Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) }
    return -1
}

foreach ($i in 0..$Clients) {
    ExpectNot $i "SCRIPT ERROR|^ERROR:" "no engine errors"
    Expect $i "NET race started" "race started"
    Expect $i "NET spawned car team 1" "team 1 car spawned"
    Expect $i "NET window 1 open team 1" "navigator's window change reached everyone"
    Expect $i "NET can 1 spawned" "thrown can reached everyone"
}
Expect 0 "NET can 1 despawned" "host despawns the can"
# The navigator (instance 2) only plays back team 1's car: it must receive packets and see it move.
$packets = LastValue 2 "car team 1 simulated=false packets=(\d+)"
if ($packets -lt 100) { $failures.Add("instance 2: only $packets snapshots of the driver's car (expected > 100)") }
$distance = LastValue 2 "car team 1 simulated=false packets=\d+ distance=([\d.]+)"
if ($distance -lt 10) { $failures.Add("instance 2: driver's car moved only $distance m as seen by the navigator") }
Expect 1 "car team 1 simulated=true" "driver simulates its own car"
if ($Clients -ge 3) {
    $other = LastValue 1 "car team 2 simulated=false packets=(\d+)"
    if ($other -lt 50) { $failures.Add("instance 1: only $other snapshots of team 2's car") }
    Expect 0 "NET roster \[(?!.*3:)" "host roster drops instance 3 after it leaves"
    Expect 1 "NET car team 2 removed" "team 2 car removed on instance 1 after its driver left"
    Expect 2 "NET car team 2 removed" "team 2 car removed on instance 2 after its driver left"
}

if ($failures.Count -eq 0) {
    Write-Host "NET TEST PASSED ($Clients clients, $Seconds s)" -ForegroundColor Green
    exit 0
}
Write-Host "NET TEST FAILED:" -ForegroundColor Red
$failures | ForEach-Object { Write-Host "  - $_" }
exit 1
