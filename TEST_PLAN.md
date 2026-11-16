# Test plan

Status as of 2026-11-16 (build 0.2.0). Automated checks run on the dev PC (i7-13650HX, RTX 5070
Laptop, Windows 11); manual checks need people and are listed with their state.

## Automated

| Check | How | Covers | Last result |
|---|---|---|---|
| Unit and physics tests (GUT, 555 tests) | `tools\test.ps1` | driving (grip, brakes, handbrake, rollover, recovery offer, damage effects), gearbox, water drag, stage recipes (valid, deterministic, features shaped into the road), terrain (flat under the road, cliffs drop, banks rise), track furniture (pools, rails with one gap, walls never across another stretch, gates), a bot driving a whole stage through every gate, pace notes, paper map, roadside dressing, race progress/results/settings, recovery anchors (never past the next gate or ahead of where the car got), stage events (tree across half the road, boulders reach it, a bot drives around the tree), visible damage parts, records/medals, cabin, voice codec/capture, room codes, roster rules, snapshot buffer, settings, project settings, times of day (settings, light, moon and stars, the headlights' pattern and strength), the plants in the weather, the forest floor's shade | pass |
| Multiplayer | `tools\nettest.ps1` (host + 3 clients, headless) | race start barrier, car sync, windows and cans on every peer, voice relay near/far, a client leaving mid-race, team recovery confirmation, host-judged damage, windscreen kick-out, a navigator's gesture and look on every other peer | pass |
| End to end | `tools\flowtest.ps1` | main menu → create room → join by code → seats/ready → start → bots drive the whole stage (both falling trees come down in front of them) → results → back to the room → quit | pass (2 crews: 2:11.1 / 2:17.5 on Kara Çam Geçidi, 2026-11-16) |
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
| The light pod at night: the road readable far down a straight and into a corner's sides, the night still hard; its black back along the bottom of the windshield never more in the way than a real one; a bonnet that flaps or flies off with it | to do (contact sheets before and after: `stage_shots.ps1 -Time 3 -Compare`) |
| The windshield's dirt: its colour on every road (dust, mud, slush), driving into a low sun with it (a glowing haze: hard, never hopeless with the wipers), the dome lamp's veil on it at night | to do |
| Following a car in its dust at night (the cloud glows in your own beams and hides everything) and a follower's beams in the mirrors | to do |
| A car close behind at night lights the trees round the car ahead (never its road through it): fair to the leader, or a help nobody should get | to do |
| The dome lamp: the map readable by it at night and hard to read without, and how much it blinds the driver | to do |
| The new seat and view (lower, closer, a vertical 62 degrees): the road readable and the speed felt at the wheel, the mirrors a glance away (the driver's interior mirror is 60 % in the frame at rest, 77 % at 60 km/h, 88 % at 100 km/h); whether the settings need a seat and FOV option before A7 | to do |
| Looking round (100 degrees either way, no further than between the bucket seat's wings): enough to see out of the side window; the seat's mesh fabric credible up close | to do |
| The crew from the other seat and through the windows: a real rally crew, not a mannequin in costume: race suits (the mannequin rounded by one Loop step since A5b; its shoulder still a rounded lump, seen from the partner's seat), race gloves (dark fingers, the coloured back: no jointed doll's fingers), the harness and the open-face helmet (the eyes in the balaclava's slot, the boom microphone), by day, at night under the dome lamp | to do |
| The partner's name on the chest (12 mm letters, seen at a slant) and on the helmet, the flag patch on the sleeve: legible from the other seat, or too small to matter | to do |
| Heads that stop at the seat (since A5b: up 12 degrees looking ahead, not at all from 60 degrees aside, the swing 9 degrees to a side): natural, never stiff | to do |
| The roll cage from both seats and in the interior mirror (drawn only since A5's review: it hides 0.1 % of the windshield's view from the driver's seat, 0.9 % from the navigator's): a rally car's, never more in the way than a real one | to do |
| Hand signals in a real race: each sign (the finger across, the thumb for the side away, a chop for straight on, a pat for slow down) read from the other seat at a glance and in motion (the thumb rests 58 degrees up and jerks to 32: a way, or a thumbs-up?), by day and at night without the dome lamp (the dials light the hands: the driver reads the navigator's well, the navigator sees the driver's as dim shapes against the beams), and whether a silent crew can run a stage on them | to do |
| The crew's hands and heads in a real race: on the wheel through quick corrections and at full lock (the rim slides through them past the arms' reach), the gear and handbrake hand, the map's grip from both seats, heads that follow their players smoothly over the network | to do |
| One-handed steering while signalling, winding the window, flicking the wipers or pressing the horn: a fair price, never annoying | to do |
| The partner's head swinging with the car (out of a corner, nodding under braking, a jolt on a hit): alive, never restless or sickening beside you, on every screen (the navigator's own sees the car played back from the driver's snapshots), in the rivals' cars too | to do |
| The livery: the number and the names read from the car behind, at the start and in the results' team colours, clean and filthy, in every team colour | to do |
| The crowd: people worth having by the road from the grid and at speed (the crew's mannequin dressed: shirts and trousers that hang, hems, short or long sleeves, shaped and painted faces; close up a short sleeve stands like a cap over the shoulder), their cheer as a car goes by, at dusk, at night and in snow | to do |
| Flags, guard rails, straw bales, concrete blocks and boards in the beams at night: a flag red with its crescent and star, a rail a grey rail, a bale straw, a block concrete, never a white flare that hides the road behind it; a rival's car in your beams in its colour | to do |
| A car's own lamps from outside at night (the chrome reflector, the flutes, the headlight's hot core, dimmer from the side): real lamps, never flat white plates | to do |
| What three crews cost on a mid-range PC (dev laptop, Medium: 0.6-1.2 ms a frame since A5b's suits and helmets, `tools\perf.ps1 -ExtraArgs "--follower=14+28,--flip-crew=0.5"`) | to do |
| Windows SmartScreen first run on a clean PC | to do |

## Known issues and gaps
- No relay for players behind carrier-grade NAT (Radmin VPN workaround); no reconnect; host loss ends the room.
- The crew's short motions (winding a window, the wipers' stalk, a throw, the kick) are placed by eye: the model has no door winders or stalks to
  aim at.
- The crew and the crowd are Quaternius's mannequin, rounded (one Loop step), the crew in race suits cut over it and the crowd dressed:
  the shoulder's ball joint still shows (a rounded shoulder on the crew's suit, its stretch panel only behind it since the review; a
  spectator's short sleeve standing like a cap),
  and a face is shaped and painted (the crew's under a balaclava), not modelled. Character models wait for a free source the owner
  approves; the helmet is built in code (`CrewHelmet.mesh()` is the one place a model would replace).
- The trip meter is a black box against the black A pillar until A7 lights its display with numbers.
- The dev laptop has a ~8 ms per-frame floor even for an empty scene (hybrid graphics); frame
  rates measured there understate other PCs.
- Vulkan is not usable on the dev laptop (17 fps on an empty scene); the project pins D3D12.
