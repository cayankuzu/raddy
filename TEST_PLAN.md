# Test plan

Status as of 2026-11-10 (build 0.2.0). Automated checks run on the dev PC (i7-13650HX, RTX 5070
Laptop, Windows 11); manual checks need people and are listed with their state.

## Automated

| Check | How | Covers | Last result |
|---|---|---|---|
| Unit and physics tests (GUT, 439 tests) | `tools\test.ps1` | driving (grip, brakes, handbrake, rollover, recovery offer, damage effects), gearbox, water drag, stage recipes (valid, deterministic, features shaped into the road), terrain (flat under the road, cliffs drop, banks rise), track furniture (pools, rails with one gap, walls never across another stretch, gates), a bot driving a whole stage through every gate, pace notes, paper map, roadside dressing, race progress/results/settings, recovery anchors (never past the next gate or ahead of where the car got), stage events (tree across half the road, boulders reach it, a bot drives around the tree), visible damage parts, records/medals, cabin, voice codec/capture, room codes, roster rules, snapshot buffer, settings, project settings, times of day (settings, light, moon and stars, the headlights' pattern and strength), the plants in the weather, the forest floor's shade | pass |
| Multiplayer | `tools\nettest.ps1` (host + 3 clients, headless) | race start barrier, car sync, windows and cans on every peer, voice relay near/far, a client leaving mid-race, team recovery confirmation, host-judged damage, windscreen kick-out | pass |
| End to end | `tools\flowtest.ps1` | main menu → create room → join by code → seats/ready → start → bots drive the whole stage (both falling trees come down in front of them) → results → back to the room → quit | pass (2 crews: 2:05.2 / 2:15.3 on Kızıl Kanyon, no damage) |
| Stage events by bot | `route_test.tscn --stage=N --start=M --autodrive --quit-after-seconds=22` (headless) | every falling tree and rockfall on every stage; prints the bot's progress, recoveries and hardest impact | pass (0 recoveries; boulders graze the car at most 5 m/s) |
| Export | `tools\export_windows.ps1`, run the exe | release build packs and starts | pass |
| Screenshots | `tools\screenshot.ps1`, `tools\stage_shots.ps1 -OwnWeathers -AllTimes -Sheet` | every stage, cockpit, HUD, glass states, weather; every stage at every time of day in its own weathers (18 contact sheets) | reviewed by eye |
| Code review | multi-agent review with adversarial verification of every finding | stages, race/network, car/audio/cameras, UI/map/notes, rendering/tools, tests | findings fixed (see git log) |

## Manual (needs people)

| Check | State |
|---|---|
| Real microphones between two PCs; voice fades with distance; push-to-talk; device choice | to do (only the tone test and one local mic level check so far) |
| Internet play from really different networks (UPnP code, CGNAT + Radmin VPN fallback) | to do |
| Six players / three crews at once over the internet; latency feel | to do |
| Driving feel with keyboard and with a gamepad on every stage | to do |
| Navigator flow: reading the notes, map in hand, guiding a blind driver (bonnet up, mud) | to do |
| Frame rate on a mid-range desktop GPU and on integrated graphics (Auto → Low) | to do (dev laptop at 1080p with a bot on Kara Çam: Medium 32-35 fps, High 26-34 fps; down to 19-23 and 20-28 fps when other programs load the CPU) |
| Every weather on every compatible stage | screenshots of all reviewed; to do by people at the wheel |
| Medal times (`StageRecords.MEDAL_SPEEDS`: bots average 15.3-18.5 m/s, gold is 20.5) are hard but reachable for a good crew | to do |
| Mirrors, dome lamp and sliding windows in a real two-player race, from both seats | to do |
| How often a stone should mark the windshield with people at the wheel (`StoneChipRules`: a lone bot cracks about one run in ten, following close it is the price of the dust) | to do |
| Stones pinging under the floor and a stone on the windshield: heard by a person, loud enough and not annoying over the engine | to do |
| How long a crew can stand the dust behind another car (a follower 2 s behind sees none of the road 30-90 m ahead) | to do |
| Dirt on the car: filthy by the finish, the team colours still told apart in the room's results and on the road | to do |
| Tyre marks: whether a crew reads the line of the car ahead from its marks, and whether they ever look painted on | to do |
| The windshield crack from the seat by day, into a low sun and at night: real, and never in the way more than a real one | to do |
| Crashes: the sparks, leaves, splinters and glass read as what was hit, at speed and from the car behind | to do |
| The exhaust pops: heard by a person, not too loud against the engine | to do |
| Night with people at the wheel: hard but fair (the road readable in the beams, a corner beyond them dark), and beautiful; dusk and the golden hour worth choosing | to do (contact sheets of every stage, weather and time reviewed by eye: `stage_shots.ps1 -OwnWeathers -AllTimes -Sheet`) |
| Night in snow and in fog: the snow's glare in the beams and the fog's glowing veil still let a crew drive | to do |
| Following a car in its dust at night (the cloud glows in your own beams and hides everything) and a follower's beams in the mirrors | to do |
| The dome lamp: the map readable by it at night and hard to read without, and how much it blinds the driver | to do |
| Windows SmartScreen first run on a clean PC | to do |

## Known issues and gaps
- No relay for players behind carrier-grade NAT (Radmin VPN workaround); no reconnect; host loss ends the room.
- Crew bodies and hands are not modelled yet.
- The dev laptop has a ~8 ms per-frame floor even for an empty scene (hybrid graphics); frame
  rates measured there understate other PCs.
- Vulkan is not usable on the dev laptop (17 fps on an empty scene); the project pins D3D12.
