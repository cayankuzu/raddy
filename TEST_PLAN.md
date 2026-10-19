# Test plan

Status as of 2026-10-19 (build 0.2.0). Automated checks run on the dev PC (i7-13650HX, RTX 5070
Laptop, Windows 11); manual checks need people and are listed with their state.

## Automated

| Check | How | Covers | Last result |
|---|---|---|---|
| Unit and physics tests (GUT, ~165 tests) | `tools\test.ps1` | driving (grip, brakes, handbrake, rollover, recovery offer, damage effects), gearbox, water drag, stage recipes (valid, deterministic, features shaped into the road), terrain (flat under the road, cliffs drop, banks rise), track furniture (pools, rails with one gap, walls never across another stretch, gates), a bot driving a whole stage through every gate, pace notes, paper map, roadside dressing, race progress/results/settings, recovery anchors (never past the next gate or ahead of where the car got), stage events, records/medals, cabin, voice codec/capture, room codes, roster rules, snapshot buffer, settings, project settings | pass |
| Multiplayer | `tools\nettest.ps1` (host + 3 clients, headless) | race start barrier, car sync, windows and cans on every peer, voice relay near/far, a client leaving mid-race, team recovery confirmation, host-judged damage, windscreen kick-out | pass |
| End to end | `tools\flowtest.ps1` | main menu → create room → join by code → seats/ready → start → bots drive the whole stage → results → back to the room → quit | pass (2 crews: 2:08.4 / 2:18.6 on Kara Çam Geçidi) |
| Export | `tools\export_windows.ps1`, run the exe | release build packs and starts | pass |
| Screenshots | `tools\screenshot.ps1` | every stage, cockpit, HUD, glass states, weather | reviewed by eye |
| Code review | multi-agent review with adversarial verification of every finding | stages, race/network, car/audio/cameras, UI/map/notes, rendering/tools, tests | findings fixed (see git log) |

## Manual (needs people)

| Check | State |
|---|---|
| Real microphones between two PCs; voice fades with distance; push-to-talk; device choice | to do (only the tone test and one local mic level check so far) |
| Internet play from really different networks (UPnP code, CGNAT + Radmin VPN fallback) | to do |
| Six players / three crews at once over the internet; latency feel | to do |
| Driving feel with keyboard and with a gamepad on every stage | to do |
| Navigator flow: reading the notes, map in hand, guiding a blind driver (bonnet up, mud) | to do |
| Frame rate on a mid-range desktop GPU and on integrated graphics (Auto → Low) | to do (dev laptop: 59-77 fps at 1080p High, GPU ~5.6 ms/frame) |
| Every weather on every compatible stage | to do (screenshots of several) |
| Windows SmartScreen first run on a clean PC | to do |

## Known issues and gaps
- No relay for players behind carrier-grade NAT (Radmin VPN workaround); no reconnect; host loss ends the room.
- Crew bodies and hands are not modelled yet.
- The dev laptop has a ~8 ms per-frame floor even for an empty scene (hybrid graphics); frame
  rates measured there understate other PCs.
- Vulkan is not usable on the dev laptop (17 fps on an empty scene); the project pins D3D12.
