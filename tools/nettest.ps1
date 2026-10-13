# Automated multiplayer check on one PC: a headless host plus N headless clients run
# scenes/dev/net_test.tscn with scripted actions, then the "NET ..." log lines are checked.
#   tools\nettest.ps1 [-Clients 3] [-Seconds 40]
# Exit 0 when every check passes, 1 otherwise. Logs: logs\instance_<n>.log.
param(
    [ValidateRange(2, 6)][int]$Clients = 3,
    [int]$Seconds = 40
)
. "$PSScriptRoot\godot.ps1"

$launch = Join-Path $PSScriptRoot "launch.ps1"
& $launch -Server -Clients $Clients -Headless -Scene "res://scenes/dev/net_test.tscn" `
    -ExtraArgs "--players=$Clients,--autodrive,--local,--test-script,--quit-after-seconds=$Seconds"
# Four instances compiling their scripts at once can take 20-30 s to boot on this laptop (see
# CLAUDE.md gotchas); the scripted actions are timed from race start, so only the total must be generous.
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
# Voice: instance 1 sends a 3 s fake tone; its teammate (2) and the other car (3, a few metres
# away) must receive it with a clear level; the host relays and never plays (dedicated).
$sent = LastValue 1 "VOICE t=\d+ tx packets=(\d+)"
if ($sent -lt 100) { $failures.Add("instance 1: sent only $sent voice packets (expected ~150 for 3 s)") }
foreach ($i in 2, 3) {
    if ($i -gt $Clients) { continue }
    $rx = LastValue $i "VOICE t=\d+ rx from \d+ packets=(\d+)"
    if ($rx -lt 100) { $failures.Add("instance ${i}: received only $rx voice packets") }
    Expect $i "VOICE t=\d+ rx from \d+ packets=\d+ level=0\.[1-9]" "voice level clearly above zero on instance $i"
}
Expect 0 "VOICE t=\d+ tx packets=0 relayed near=[1-9]\d* far=0" "host relayed to near peers only"
foreach ($i in 0..$Clients) { ExpectNot $i "VOICE problem" "no mic problem reported" }
if ($Clients -ge 3) {
    $other = LastValue 1 "car team 2 simulated=false packets=(\d+)"
    if ($other -lt 50) { $failures.Add("instance 1: only $other snapshots of team 2's car") }
    Expect 0 "NET roster \[(?!.*3:)" "host roster drops instance 3 after it leaves"
    Expect 1 "NET car team 2 removed" "team 2 car removed on instance 1 after its driver left"
    Expect 2 "NET car team 2 removed" "team 2 car removed on instance 2 after its driver left"
}

# Recovery (spec 16): instance 1 rolls its car at 13 s; the host must offer after 3 s stuck, both
# team-1 seats confirm (2/2), the host places the car back on the road and everyone applies it.
Expect 0 "NET recovery team 1 offered 0/2" "host offered the recovery to team 1"
Expect 0 "NET recovery team 1 offered 1/2" "first confirmation counted"
foreach ($i in 1, 2) { Expect $i "NET confirming recovery" "seat on instance $i confirmed" }
foreach ($i in 0..$Clients) { if ($i -ne 3) { Expect $i "NET recovered car team 1 to .* \(recovery 1\)" "recovery applied on instance $i" } }
Expect 1 "NET recovery team 1 closed" "offer closed after the recovery"
# Damage (spec 8): the rollover lands hard enough for the host to judge it from the snapshots.
Expect 0 "NET damage team 1 (light|medium|critical)" "host judged damage from the driver's impact report"
# Cabin glass (spec 9): the navigator kicks the windshield out at 24 s and every peer sees it.
Expect 2 "NET kicking the windshield out" "navigator kicked"
foreach ($i in 0..$Clients) { if ($i -ne 3) { Expect $i "NET windshield removed team 1" "windshield state reached instance $i" } }

if ($failures.Count -eq 0) {
    Write-Host "NET TEST PASSED ($Clients clients, $Seconds s)" -ForegroundColor Green
    exit 0
}
Write-Host "NET TEST FAILED:" -ForegroundColor Red
$failures | ForEach-Object { Write-Host "  - $_" }
exit 1
