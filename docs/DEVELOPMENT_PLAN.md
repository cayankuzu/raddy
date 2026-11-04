# RADDY — Development plan, requirements and risks

Sources: `RADDY_MEGA_MASTER_PROMPT_FINAL.md` (main spec), `RADDY_SUPPLEMENT_ART_ENGINEERING.md`,
`RADDY_SUPPLEMENT_MCP_TOOLCHAIN.md`. This file merges them into one ordered list and tracks status.
Status keys: DONE (verified by a test or a real run), WIP, TODO.

## 1. Repo audit (2026-10-12)
- Godot 4.7.2-stable (official, signed) at `C:\Tools\Godot\4.7.2\`; export templates 4.7.2 installed. No upgrade planned.
- Project: `project.godot` (Jolt, 120 Hz, D3D12, mic input on), GUT 9.7.1, Beckett Lite 1.16.0 MCP, tool scripts
  in `tools/`, Windows export preset. No game scenes or gameplay code yet.
- Verified so far: headless import, GUT suite (6 settings tests), 2-3 client ENet localhost run with RPCs,
  Movie Maker screenshots, Windows release export runs, Beckett MCP over HTTP (56 tools, token auth).
- Machine constraints: Smart App Control ON (unsigned console wrapper blocked); Windows global atom table full
  (IObit/iTop Delphi apps leak atoms) which crashes Godot windows unless `--accessibility disabled`; laptop mic
  muted and the default input is the iTop virtual mic.

## 2. Unified requirement list (grouped by phase)
P0 Tooling and audit — DONE
- Godot + templates, GUT, MCP verified end to end, multi-instance launcher, screenshots, export, CLAUDE.md.

P1 Technical prototypes (highest risk first)
1. Vehicle: forward/reverse, throttle/brake, speed-sensitive steering, handbrake slide, surface grip
   (gravel/dirt/mud/wet), bumps, rollover + upright, chase camera, impact events. Each behaviour has its own test.
2. Network: host + client join, player id / team / role, driver + navigator in one car, car state sync with
   interpolation, disconnect without freeze. Host validates checkpoints, damage, recovery.
3. Proximity voice: real mic on client A heard on client B, distance attenuation + pan, push-to-talk, mute,
   device select, mic-denied message, no crash on disconnect. Fake-mic mode for automated tests.
4. Route graph: seeded deterministic graph, one road segment + one 3-way junction generated from the graph;
   the same data drives road mesh, collision, map and pace notes. — DONE (road mesh + collision + gates)
5. Physics object + cabin state: one thrown can and one window state synced over the network. — DONE (P1.2)
6. Debug and release Windows builds start (done for an empty project; redo with gameplay).

P2 Playable core
- Role input contexts (driver/navigator), cockpit camera, paper map (M, zoom/pan, fold animation, wind/flight,
  6 s replacement), pace notes from the graph, alternative routes/shortcuts/loops with validation,
  windshield/side windows (open/close/crack/break/kick out), wipers + dirt, wind/dust/gravel exposure and 6 s faint,
  light/medium/critical damage, joint R recovery (3 s trigger, 1/2 or 2/2 confirm, safe anchors), glovebox cans.

P3 Six-player MVP
- Main menu, room create/join with code, max 6 players / 3 teams / 2 per team, one driver per team enforced on
  the host, host settings (difficulty, laps 1-3, biome, weather, Random, Surprise Rally), race state, checkpoints
  with anti-skip, results, rematch/new seed, disconnect/timeout/host-loss handling, NAT path (netfox/noray or
  direct/UPnP; Tailscale/Radmin for friend tests), network simulation and 6-client load test.

P4 Art and content (stylized realism, Half Grip used only as a mood reference)
- Forest/desert/rocky mountain biomes with own palettes and silhouettes, weather (clear/rain/fog/snow/dust storm)
  with grip effects, licensed real assets + `ASSET_LICENSES.md`, materials/lighting/fog, particles, SFX layers,
  UI (no neon sci-fi), TR/EN localisation, settings (audio, voice, rebinding, camera shake, effects intensity).

P5 QA and release
- Performance measurements (FPS, memory, network, voice latency), crash/network logs, README, TEST_PLAN,
  CHANGELOG, ITCH_IO_RELEASE_CHECKLIST, clean-folder build check, friend test, unsigned-build instructions for
  players (zero-cost rule: no paid code signing).

## 2b. AAA release plan (2026-10-19, owner's go-ahead: "all phases")
Rules and quality bar: `GAME_DESIGN.md` (pillars, stage rules, shock gun, characters, HUD, 9.8 gate).
Downloadable Windows build on itch.io only; no browser build at launch (reasons in GAME_DESIGN §1).

| Phase | Goal | Exit gate |
|---|---|---|
| A0 Solid ground | review findings fixed, dev leftovers out of the player build, `tools\ci.ps1` runs everything | CI green |
| A1 Design bible | `GAME_DESIGN.md`: pillars, rules, rubric, web/demo decision | written (done) |
| A2 Driving feel 2.0 | steering/input layers, tyre and weight tuning, gamepad + vibration, wheel, assists | handling benchmarks hit targets |
| A3 Stages 2.0 | narrow roads, ditches, dense forest, sightline budget, junction decoys, rally dressing | validator rules + per-stage screenshots + bots |
| A4 Effects | lingering dust, stones, mud on the body, ruts and skid marks, night lights | per-surface checklist, frame budget |
| A5 Crew characters | driver + navigator bodies, hands, gestures, states, network sync | screenshots from both seats + nettest |
| A6 Chaos mechanics | shock gun, doors, intercom, hands system, more events, awards, room modes | unit + network tests per mechanic |
| A7 AAA HUD / UI / UX | design system, role HUDs, menus, onboarding, gamepad navigation, accessibility | UX audit, new-player test |
| A8 Network + security | relay for CGNAT, reconnect, RPC audit, rate limits, anti-teleport, streamer mode, Opus | soak test, security review |
| A9 Performance + QA | budgets met on mid and low PCs, no shader stutter, full test matrix, clean-PC run | all gates |
| A10 Launch | itch page, trailer/GIFs, press kit, demo build, update pipeline | launch checklist |

## 3. Technical risks
| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| 1 | Stock Godot 4.7.2 cannot step physics manually: no rollback/re-simulation of RigidBody cars | Laggy or jittery remote cars, unfair collisions | Owner simulates its car, host validates race-critical events; snapshot interpolation at 20-30 Hz; car-to-car contact resolved by the host |
| 2 | Mic API is experimental (4.6+); no echo cancellation; raw PCM is heavy | Voice may drift, echo, or flood bandwidth | 16 kHz mono int16/µ-law + host forwards only in range; Opus via TwoVoIP 6.5 later; headphones; fake-mic test mode |
| 3 | NAT: friends at home cannot reach an ENet host without port forwarding | Online play fails | Player-hosted ENet; netfox.noray punch-through/relay on the free public instance; UPnP; Radmin VPN (free) fallback. No paid servers (zero-cost rule) |
| 4 | Procedural road meshes, junction blending and collision quality | Holes, seams, cars catching edges | Few hand-tuned modules joined by spline segments; geometric validation tests per seed |
| 5 | Scope of the MVP list for a solo developer | Nothing finished | Strict phase order; each feature verified before the next |
| 6 | Asset consistency/licensing without 3D modelling | Mismatched look, licence risk | CC0 sources (Kenney, Quaternius, Poly Haven, ambientCG), one material/lighting pass, manifest per asset |
| 7 | This PC: atom-table leak, Smart App Control, muted mic | Godot windows crash, unsigned builds blocked, silent voice tests | `--accessibility disabled` in tools; reboot; no paid signing, itch page explains "Run anyway"; mic fixed by user (verified) |
| 8 | Headless tests do not prove feel, visuals or voice | False confidence | Windowed runs + screenshots + manual play checklist for each feature |

## 4. Status log
- 2026-10-11: tooling and setup (P0) done and committed.
- 2026-10-12: reference research done (`REFERENCE_RESEARCH.md`, `ART_DIRECTION.md`); Beckett Lite stays the
  only MCP server.
- 2026-10-12: P1.1 vehicle prototype implemented. Verified by 15 GUT driving tests (deterministic,
  `--fixed-fps 120`) and windowed screenshots of the dev track:
  - DONE: forward/reverse, throttle/brake (0.79 g on gravel), speed-sensitive steering, handbrake slide that
    can be caught, oversteer assist, surface grip (mud slower, wet brakes longer), bump response without
    bottoming, no roll at full lock, overturned/hung-up/wedged recovery offer after 3 s with upright reset,
    frontal impact event, chase camera + driver camera, dev HUD.
  - Not yet: real car model (art phase), cockpit interior, damage states (P2), team recovery confirm (P2),
    feel check with a gamepad by a human.
- 2026-10-12: independent review of the prototype (17 confirmed findings) fixed: engine braking no longer
  brakes like the pedal, static friction holds the car on slopes and camber, stuck detection ignores
  braking and keeps the offer until the car moves, recovery snaps from just above the car (not onto a bridge
  above), wheels on other bodies push back on them, airborne wheels spin down, physics interpolation on
  with an interpolated chase camera, camera stays behind when reversing, unfocused windows ignore the
  gamepad, dev track has a fall guard and a debug restart. Tests now 22 driving + 8 settings, all passing.
- 2026-10-12: P1.2 network prototype DONE (verified by `tools\nettest.ps1`: headless host + 3 clients, and a
  windowed 3-client run captured with `tools\capture_window.ps1`): room join/reject, 3 teams × driver/navigator
  seats validated on the host, ready + race start, driver-authoritative car snapshots at 30 Hz with 100 ms
  interpolation on every other peer (remote copy within ~1 m of the driver's car at 12 m/s), host-owned cabin
  window state and glovebox cans (spawn, host physics, despawn) reaching every peer, driver leaving removes the
  team's car, host quitting ends client sessions without a freeze. Decision: car physics on the driver's peer
  (no rollback in stock Godot; zero input lag), race-critical events on the host. First-person seats:
  DriverCamera/NavigatorCamera inside a placeholder cockpit (dashboard, roof, pillars, wheel).
  Not yet: internet NAT path (netfox/noray), reconnect, host migration, speed-bound validation of snapshots,
  car-vs-car collision fairness.
- 2026-10-12: P1.3 proximity voice prototype DONE in code and in the automated test: `Voice` autoload
  (push-to-talk V, voice-activity option, per-peer mute, mic-problem signal, fake-tone test mode), 16 kHz
  mono mu-law 20 ms packets (320 B, 50/s) client → host, host relays only to seated peers within 40 m of the
  speaker, receivers play from the speaker's seat through a 3D `VoicePlayback` with a jitter buffer.
  `tools\nettest.ps1`: driver's 3 s tone reaches its navigator and the other car (149/146 packets, level 0.28),
  dedicated host relays near=296 far=0, 6 codec unit tests. Still needed from a human: real microphone →
  headphones audibility, left/right placement and the in-car vs other-car loudness (spec §5.1), then Opus
  (TwoVoIP 6.5) to cut bandwidth ~10× before internet play.
- 2026-10-12: P1.4 procedural route graph DONE (and P1.5 can/window sync was already covered by P1.2):
  `RouteGenerator` builds a seeded lap (jittered loop that bulges where a shortcut cuts across and dents where
  a detour goes around) with 2-3 alternatives (mud shortcut / wide gravel detour, each leaving and rejoining
  the lap at ≥34°) and an optional dead-end spur with a turnaround; `RouteValidator` checks lap length, turn
  radii, junction angles, grades, crossings, reachability and checkpoint order; `TerrainField` gives seeded
  noise terrain flattened into a shallow trench under every road; `RoadBuilder` turns the graph into
  trimesh road ribbons with verges, junction pads, a HeightMapShape3D terrain and `Checkpoint` gates.
  Verified: 40 seeds valid, 0 fallbacks, 0.5 mean retries (8 generator tests); the `RouteFollower` bot
  drives the seed-1 lap (1517 m) in 62 s on the real geometry passing gates 1-2-3-0 in order with no
  recovery (2 drive tests); `RaceProgress` lap accounting (5 tests); `tools\nettest.ps1` passes with the
  route built from the race seed on every peer, cars on a grid at the start gate, bots driving the lap and
  the host broadcasting gate/lap progress. Screenshots: `reports/screenshots/route_overview_seed{1,7}.png`,
  `route_chase_seed1.png`, `route_driver_seed1.png`. Not yet: junction pad art, roadside props, biome
  surfaces per edge, hairpins/crests by design, map and pace notes (P2).
- 2026-10-12: P2.1 paper map + P2.2 pace notes DONE in code and tests: `MapCanvas` (SubViewport) draws the
  whole network of the race from the same RouteGraph (contour-shaded paper, main/shortcut/detour/spur line
  styles, numbered junctions, CP flags, S/F, fold creases, optional car marker) with a pace-notes column
  (`PaceNotes.build`: one numbered note per junction in lap order, TR + EN, side/turn from geometry, branch
  kind). `PaperMap` is a real sheet in the cabin: M unfolds it from the lap up in front of the navigator
  (0.45 s tween), wheel zooms 1-4.5×, drag pans, Home resets, Esc/M folds it; the driver's view is untouched.
  `Cabin` owns the state (host authority): navigator only (a solo driver may hold it), wind risk grows with
  speed over 50 km/h while a side window is open, the paper flutters as a warning, then flies out of the open
  window (visible tumbling sheet on every peer) or drops on a hard impact; the replacement is ready after
  exactly 6 s and cannot be opened before. 15 new tests (pace notes, canvas, cabin map rules incl. the spec's
  6 s), 82 total passing; `tools\nettest.ps1` still passes; screenshot `reports/screenshots/map_navigator_seed1.png`
  (`route_test.tscn --navigator --map-open --autodrive`). Not yet: paper/ink art pass, biome palettes for the
  map, wind sound, the navigator's hands, difficulty-dependent note detail.
- 2026-10-12: P2.6 joint R recovery DONE: the driver's car reports "stuck" in its snapshots, the host's
  `RecoveryRules` confirms it lasted 3 s without the car moving 1.5 m, then opens the offer to the team
  (`NET recovery team N offered 0/2`); each seat presses R (`RecoveryInput`; a solo driver holds it 0.6 s),
  a lone confirmation expires after 8 s, moving again closes the offer; at 2/2 the host picks the spot with
  `RecoveryAnchor` (nearest road point incl. legal alternatives, facing the road's flow, never on or past the
  next gate, start line as the last resort) and broadcasts it; only the simulating peer teleports, everyone
  sees the same car. Recoveries per team are counted for the results. 10 unit tests (rules incl. the spec's
  3 s, anchors) and `tools\nettest.ps1` (instance 1 rolls its car at 13 s, both seats confirm, host places it
  back on the road, team continues to the next gate). Not yet: recovery sound/animation + short control lock,
  HUD prompt in the real HUD (dev HUD only), debug key in dev builds.
- 2026-10-12: P2.5 damage levels DONE: `VehicleDamage` (pure, 6 tests) turns each impact (speed lost in one
  hit, direction in car space → front/rear/left/right/bottom zone) into points; scrapes under 3.5 m/s are free,
  side hits ×1.2, rear ×0.75; light ≥ 12, medium ≥ 40, critical ≥ 80. The host judges impacts from the
  driver's own snapshots (velocity change between consecutive packets, direction from the snapshot rotation;
  listen-server host uses its own car's impact signal) so clients never author damage; it broadcasts the zone
  array and every peer applies it: paint darkens, dent blocks per zone (placeholder art), medium damage costs
  ~7 % speed and pulls the wheel toward the damaged side (1.6 m drift over 3 s), critical halves the power
  (7.7 vs 16.1 m/s after 3 s, physics test) and counts as stuck so the recovery offer opens; a recovery
  repairs the car down to light damage. Dev HUD shows Hasar: hafif/orta/kritik. `tools\nettest.ps1` checks
  the host judges the rollover landing. Not yet: damage sounds/vibration, car-vs-car fairness tuning, real
  dented body variants (P4).
- 2026-10-12: P2.3 glass + P2.4 exposure/faint DONE in one cabin state system (`Cabin`, host authority):
  side windows closed/open/broken + cracked flag (a can at ≥ 8 m/s relative cracks, ≥ 13 m/s or a second hit
  breaks; broken stays open; `EnergyCan` reports hits on the host from the contact position), windshield
  intact/cracked/removed (stone chips on loose surfaces at speed; navigator or solo driver kicks it out with F,
  mesh disappears), windshield dirt by surface and speed (mud fastest) with wipers (T, driver) clearing it,
  per-seat exposure from the openings × surface grit × speed with random face hits, faint at 1.0 for exactly
  6 s (fainted driver's input node clears the controls and the car coasts; fainted navigator loses the map
  and cabin keys; bot drivers coast too), wake-up with residual exposure. `SeatEffects` draws the local
  seat's dirt tint, crack star, wiper sweep, face flash and faint fade (intensity setting). Dust/mud/sand
  particles behind the car by speed and surface (`RallyCar.Dust`, GPU particles; surface now rides in the
  snapshot). 5 physics tests (incl. the spec's 6 s and "no windshield at 90 km/h on gravel faints both seats
  after ~9 s"); `tools\nettest.ps1`: navigator kicks the windshield at 24 s, every peer sees it, the host
  faints the navigator later in the run. Screenshot `reports/screenshots/cabin_cracked_dirty_seed1.png`.
  Not yet: dirt masked to the windshield area, wind/gravel sounds, crack decals on the 3D glass, navigator
  "take can" step (cans are thrown straight from the glovebox), horn/flash keys.
- 2026-10-12: P3 six-player MVP flow DONE in code and automated tests: main menu (name, create room, join by
  room code, settings, credits, quit), room (LAN / this-PC / internet codes via free UPnP with CGNAT detection
  and a Radmin VPN hint, 3 teams × driver/navigator seat buttons, ready, host race choices difficulty/laps/
  biome/weather each with Random + Surprise Rally, the same summary on every peer, start with the reason it
  cannot start), race (loading barrier so no spawn RPC is lost, 3 s countdown with the cars locked, host-clock
  times with per-difficulty recovery penalty, results when everyone finished/left or 120 s after the first,
  results screen with same route / new route / back to room), pause menu (Esc, race keeps going), settings
  (language TR/EN, volumes on Master/Game/Voice buses, voice on/off, push-to-talk, microphone choice + live
  level test, camera shake, effects, map marker, fullscreen, vsync, key rebinding saved to user://). Biome and
  weather change surfaces, colours, grip, fog, falling rain/snow/dust and wet glass; difficulty changes road
  width, pace-note detail and the recovery penalty. Fixed on the way: voice-activity mode could never open
  (it read the transmit level), a held throttle on the grid offered a recovery. Verified: 135 GUT tests,
  `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1` (host + client from the main menu through a full lap:
  1:15.3 / 1:21.6, results, back to the room), screenshots `reports/screenshots/ui_*.png`.
  Not yet: internet relay for CGNAT homes (noray), reconnect after a drop, host migration, a 6-client load
  test, HUD/menu art pass, horn/headlight flash.
- P2 summary (2026-10-12): the playable core exists in code and automated tests: roles, cockpit cameras,
  paper map + pace notes, procedural routes with legal alternatives and checkpoints, glass/wind/faint, damage
  levels, joint recovery, cans. Human play-feel checks are still pending (see "manual steps").
- 2026-10-13: direction update from the user: a mix of "Left! Left! LEFT!" (asymmetric co-op, chaos in the
  cabin) and "Half Grip" (feel), realistic-leaning PBR look (not low-poly), named fixed stages instead of
  branching networks, AAA-feeling HUD/sound/camera. Done and verified the same day:
  - Real car (Sketchfab "Milano '95", CC BY): body, cockpit, glass wired to the Cabin, turning steering wheel,
    team paint; brake/reverse lamps and weather headlights. Forest: Sketchfab conifer and birch packs (CC BY)
    per tree with trunk collision, a thick edge band and a backdrop.
  - Six named point-to-point stages (Kara Çam Geçidi, Sisli Dere, Kızıl Kanyon, Akrep Tepeleri, Kartal
    Yuvası, Buzul Sırtı; 1.85-2.3 km): crests, jumps, dips, water splashes (slow the car, soak the glass and
    open-window seats), cliffs with steel rails (one gap each), canyon walls, switchbacks; terrain follows the
    road; invisible walls 36 m out keep cars on the stage; real rally pace notes; the paper map turns long
    stages and marks hazards; start line / splits / finish, places by distance; recoveries never gain ground.
  - Sound: engine loops from a real Toyota Corolla rally car recording pitched to a 5-speed sound gearbox,
    gravel/rumble/squeal by surface, water, wind, crashes, horn (H), rain and thunder, map rustle, UI clicks.
  - Broadcast-style HUD (stage bar with every car, split gaps, rev counter/gear/speed), mouse free look in
    the cockpit (driver looks into corners, recentres), dirt/cracks/wipers on the real windshield.
  - Fixed on the way: the grid sat behind the stage's start wall; jump landings counted as crashes (drivers
    now report body impacts); the model's 80 % dark glass; numpy FFT blocked by Smart App Control.
  Verified: 160 GUT tests, `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1` (both bots finish Kara Çam
  Geçidi: 2:08.4 / 2:18.6), screenshots `reports/screenshots/stage_*.png`, `hud_race.png`, `glass_*.png`.
  Not yet: crew bodies/hands (needs a free rigged character; a download needs the user's OK), more chaos
  events, lighting/time-of-day pass per biome, distant mountain backdrop, human play-feel test with friends.
- 2026-10-19: chaos, damage you can see, records, performance, and a second review round. Done and verified:
  - Stage surprises on five stages (`StageEvents`, `StageEventBuilder`): a fir falls across the road in
    front of the first crew (a moving body that shoves what it lands on; the trunk blocks the near half,
    the crown covers the rest and throws needles over the glass when a car pushes through), boulders come
    down canyon and mountain banks (host-simulated, synced like the cans). Bots (`RouteFollower.obstacles`)
    slow down and take the free side.
  - Visible damage (`CarDamageFx`): the bonnet unlatches and lifts with speed until the driver is blind,
    then tears off; bumpers sag and fall; the engine steams, then smokes black; a recovery restores them.
    Crashes jolt the seat camera.
  - Stage records and medals per PC (`StageRecords`): best time and crew per stage, bronze/silver/gold from
    the stage length, shown in the room and on the results with a "new record" banner.
  - Performance: scenery batched by mesh (draw calls 1429 → 608 on the forest stage), graphics quality
    Auto/Low/Medium/High. The dev laptop's frame cost is CPU draw submission, not triangles.
  - Second multi-agent review (39 findings, 38 confirmed and fixed): terrain blending and side profiles near
    other stretches, closed boundary walls, rails per merged cliff run, road direction across section
    changes, width checks, gearbox limiter/off-throttle upshift/clutch take-up, HUD and map translations,
    camera and blur fixes, scenery out of the corridor, pure-Python audio cutter (Smart App Control now
    blocks numpy entirely).
  - Fixed while verifying: critical damage kept reopening and closing the recovery offer while the car
    crawled (now it stays open); the host sent packets to a second client dropping in the same network poll
    (leave handling deferred; test instances quit host first); 3 cabin glass placeholders were leaked per car.
  Verified: 174 GUT tests, `tools\nettest.ps1` (3 clients, no engine errors), `tools\flowtest.ps1` (both trees
  fall in front of the bots, no damage, 2:14.7 / 2:20.4 on Kara Çam Geçidi), headless bot runs through every
  event on every stage (no recovery needed), screenshots `reports/screenshots/event_tree_*.png`.
  Not yet: crew bodies/hands, human play tests (feel, voice, internet), relay for CGNAT homes.
- 2026-11-04: A3 real details, step A3.12 (no-login part): DONE and verified.
  - Flags: every flag is the flag of Turkey (`TurkishFlag`, exact geometry, unit-tested sample points), on the poles, arches,
    banners, the start's board and the HUD's start marker.
  - Start and finish: real gantries (`RallyArch`), the grid moved back so its driver sees the banner. Splits: yellow boards.
  - Rails: a corrugated, worn W-beam with real posts (`GuardRail`, one mesh + one batch per rail).
  - Road: fine loose gravel, two packed wheel tracks, scattered stones, per surface (`road_surface.gdshaderinc`). Ground:
    a third layer in patches, hummocks, tufts, ferns and branches in the clearings too. Clouds; warmer shade; clear glass.
  - Found by looking: the grass and rooibos scans have no alpha, their cards showed a black ground (the desert's bushes
    were black blobs): `cut_out_leaf.gdshader`. The snow scan's hollows read as worms: clamped, relief cut.
  - Paper map: wrong ways are red dashes crossed out by their mouth; rings never lie on each other (tested on all stages).
  - Assets: `shrub_02`, `shrub_04`, single tufts of `grass_medium_01` in `RoadsideCatalog` and `ASSET_LICENSES.md`.
  - Perf (`tools\perf.ps1 -Stage 0 -Quality 1`, 26 s, three alternating rounds on the loaded PC, 1920x1080). After this step
    fps 38.8/36.0/36.5/35.3, 34.1/32.0/27.1/29.6, 32.3/28.4/27.9/29.5 (mean 32.3); before (c4b23dd) 36.3/32.9/32.0/31.4,
    38.1/34.6/30.2/24.9, 30.1/24.3/26.5/25.6 (mean 30.6). Draw calls 897/983/831/955 against 893/965/823/956, primitives
    3.65/3.75/3.30/3.32 M against 3.52/3.60/3.20/3.18 M, physics unchanged, stage build 3.2-4.3 s against 2.4-2.9 s. No fps loss
    beyond the PC's own noise.
  Verified: full GUT, `tools\nettest.ps1`, `tools\flowtest.ps1 -Stage 0` and `-Stage 4`, shots of every surface, biome and weather
  in `reports/screenshots/a312/`.

