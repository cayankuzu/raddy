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
- 2026-10-19: A0 solid ground: DONE. Review findings fixed: rockfalls start only on ground above the road (Eagle's Nest's moved to a
  real bank), boulders settle into one static rock on every peer, recoveries never land on a trunk or a boulder, bots dodge only
  the next group of obstacles and stay on the road, finished teams get no offers, snapshots stop when the race ends, torn-off parts leave clear
  of the car, records and medals compare at screen precision, bot runs never write records, the camera key left the player's bindings.
  `tools\ci.ps1` runs everything in one go; `GAME_DESIGN.md` written (A1). Verified: 182 GUT tests, nettest, flow test with 3 crews.
- 2026-10-19: A2 driving feel 2.0: DONE in code and benchmarks; a human's feel check is still to come. `SteeringInput` per device, assist levels,
  gamepad softness and rumble, analog deadzone 0.08 (was 0.2). Measured on flat gravel (`test_handling_benchmarks.gd`, deterministic): 0-100 km/h 5.36 s
  (was 6.3 s), 100-0 km/h 48.0 m at 0.82 g, half lock at 70 km/h answers in 0.10 s and settles at 25.7 deg/s and 0.92 g, keyboard to full lock
  0.21 s at 20 km/h, 0.33 s at 100 km/h, handbrake hairpin of 150 degrees from 45 km/h in 2.97 s (was 3.35 s), a 0.8 m drop at 80 km/h lands with 5.4 degrees of
  pitch. Verified: 186 GUT tests, nettest, flow test.
- 2026-10-19: A6, first item: the shock gun DONE (doors, intercom, gestures, more events, awards and room modes are still to come). Rules, feed, wires,
  sparks, sounds, one-handed steering, map folding, room rule (off / rivals / everyone). Verified: `test_shock_gun.gd` (openings, aim, the spec's 6 s faint and 4 s
  immunity), `tests/unit/test_scripts_compile.gd`, 191 GUT tests, nettest (the navigator shocks its own driver at 28 s, the host validates, every peer sees the driver faint).
  Not tested with people yet: whether 8 m and two darts make a good duel.
- 2026-11-04: A3 stages 2.0, steps A3.0 to A3.11: DONE and verified (screens and numbers from the current build; the last gate is further down).
  - Narrow roads: 3.6-5.0 m wide, a drivable 0.8 m shoulder, a 0.4 m ditch, a bank a car can drive back up; records kept per road layout (`LAYOUT` 2).
    The ground grid lies 0.7 m under all that: smallest margin to the road's sides 0.30 m. A bot steering by the road's curvature keeps its wheels on
    the shoulder on every Redline road.
  - Stage design (`StageDesignRules`): lengths 2218, 2034, 2316, 2130, 2152, 2154 m; worst gap between dangers 368, 323, 308, 396, 228, 258 m; 5, 5, 4, 4, 4, 5 wrong ways.
  - Sightline (`test_sightline.gd`, in stage order): median 62, 54, 68, 54, 60, 62 m; longest 150, 124, 168, 140, 152, 146 m; over 150 m on at most 1.0 % of a road.
  - Forest: 24.8 trunks per 100 m per side within 2.6-10 m of the road (the wall of the plan), trunks at least 1.89 m apart, 94-100 % of the screened 10 m stretches hold 2+
    occluders, 5062 obstacle shapes on Kara Çam; rows share batches, no new draw calls.
  - Wrong ways: U-turn on the 9 m turning area in 5.1 s with no knock; barrier roads closed deep in the track; 4-5 notes "Kavşak: Sol 3, düz değil!" per stage; the map dashes them.
  - Rally dressing: 491-570 items per stage on the ground within 0.000 m, nothing nearer than 0.99 m to a road's edge; at least 2 places for spectators per stage, with `spectator_spots` for A5.
  Bridge and village street wait for their assets; real loops wait until the tracker can follow two roads.
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
- 2026-11-05: A3 real details, mirrors, reflections and a car where everything works: DONE and verified.
  - Mirrors (`CarMirrors`, `MirrorMath`, `CarParts`): real planar reflections from both seats, in place and the right way round
    (a car on the left shows on the left of the picture: unit test against the engine's projection, and by eye), a follower and
    its headlights at dusk, aimed per seat, door mirrors convex, dirt on them, a door mirror breaks and a recovery restores it.
  - Cost, measured by switching the mirrors every second in one process while the bot drives stage 0 at 1920x1080 (the same
    road, the same load of the PC): Medium +1.08 and +1.15 ms a frame (draw +0.92 and +1.04 ms), +60 and +64 draw calls, +0.34 M
    triangles; Low +1.62 ms, +34 calls; High +1.45 ms, +57 calls. First version, before leaving things out: +4.8 ms, +290 calls.
    What did it: no shadow pass per mirror (+2.8 ms), a sky that stays one sky for every camera, no fine scenery.
    `tools\perf.ps1 -Stage 0 -Quality 1` with it all in (--quality now sets the whole level, so not comparable with the runs
    above, which had High's light on Medium's scenery): fps 33.7/30.2/34.2/34.5, draw calls 826/810/780/840, 2.7-3.0 M triangles.
  - Reflections: SSR from Medium up, +0.28 ms on Medium (toggled the same way), +0.6 to +0.95 ms on High. Standing water on a wet
    road is a real mirror where it runs; water pools march their own ray (the engine's only sees opaque surfaces).
  - Audit of everything in the car. Made to work: speed, rev, temperature, oil, fuel and volt needles, six warning lamps,
    ignition sweep, backlight; pedals, gear lever; handbrake (fitted, the model has none); tail, brake, reversing lights, hazards
    (the model's blinkers), dome lamp; wipers (the model's own now, they were parked decoration beside fitted blades); side
    panes slide; the wheel turns about its real column (it wobbled about a straight axis) the right way; rear and small side
    glass clear; exhaust pop and flame; discs. Checked, already right: wheels spin, steer and travel; horn. Left as they are,
    nothing there pretends to act: door pulls, sun visors, glovebox lid, radio and vents (printed), suspension and engine meshes.
  - Also found: brake glow tinted the cabin red (now cones backwards), motion blur was running inside the mirror pictures,
    clouds met in a star at the zenith that paint mirrored (clouds baked with a clear zenith by `tools/make_clouds.gd`).
  Verified: full GUT, `tools\nettest.ps1`, `tools\flowtest.ps1 -Stage 0` and `-Stage 4`, shots in `reports/screenshots/a3_real/`.
  Not yet: the partner in the interior mirror (crew bodies come with A5), dusk in the room's settings (A4's night lights).
- 2026-11-05: A3 final gate (A3.13): DONE and verified.
  - Medals: the bots' averages in the flow tests (two crews a stage, in m/s, stage order) 16.9/16.2, 15.8/15.3, 18.5/17.1, 17.4/16.7, 16.7/15.7,
    17.5/16.8. All over the 15 m/s the plan set, so `MEDAL_SPEEDS` stays 14 / 17.5 / 20.5: a bot takes bronze or silver, gold is for people. The final
    values come after a human playtest (TEST_PLAN.md).
  - Every stage on Low and High in its own weathers (`tools\stage_shots.ps1`), looked at one by one. Found and fixed that way: no edge smoothing on
    any level (`SCREEN_AA`, `MSAA` on High, `ANISOTROPY`), rock slabs standing up like wings (now shelves, with a collider where the rock is), posts through
    boards, a low sun turning the gravel white, fog and dust per level, a results table of one letter per line, rain and snow not reaching rocks, door
    mirror housings flashing like polished metal.
  Verified: 348 GUT tests (9124 asserts), `tools\ci.ps1 -SkipFlow` green on the build before the rocks (GUT, nettest, every stage event, export: 104 MB
  exe, 156 MB pck), `tools\flowtest.ps1` on all six stages.
- 2026-11-10: A3 independent reviews (players, bugs, spec): every finding checked against the code or the running game, the real ones fixed.
  - Flags: every car wore another country's colours beside its FIDA and MILANO badges; the Turkish flag is baked into the tile they share (`tools/make_badge_flag.gd`).
  - The rock face scan is an open shell (torn strips in the sky, hovering slabs, a box collider where nothing was): gone from the game. Whole stones in its place (`outcrop`,
    `crag`, tested: no open edge on any rock), which go down to the lowest ground round them on a slope (`seat`).
  - Light: a follower's headlights lit the dash and the map through the bodywork; the car lamps leave what is inside a car out (`CABIN_LAYER`).
  - Map held clear of the A pillar and the mirror (test against the car's own triangles). Panes cut at the door's sill. Spray from the flanks. Rev counter: the driver's,
    fades over the right door mirror. Door mirrors have their own faint film, no wiper reaches it. Pools: two calm rays, no slivers. Guard rail on exact metres
    (`RouteGraph.sample_exact`) with its texture to the very ends. Recovery keeps the engine hot. Rolling back is not reversing (`RallyCar.is_backing_up`).
    The HUD's flag reads. The navigator's key line names the dome lamp. Boards' words and tape go with their boards in the mirrors.
  - What the mirrors show: everything over 2 m by the road (`tall`, `RoadsideDresser.is_fine`, tested). Cost, the mirrors switched every second in one process on Black Pine,
    1920x1080, Medium: +1.25 ms and, with the PC under load, +1.47 ms a frame; +78 draw calls (budget about 2 ms).
  - Made to work: the sun visors (down for a low sun ahead on a clear sky, sliding clear of the mirror), the glove box (opens when a can is taken), the radio (lit readout
    with the engine, off with the charge). Left as they are, on purpose: the vents and the door pulls, which a crew does not touch in a race.
  - Final numbers, `tools\perf.ps1 -Stage 0`, alternating runs of 30 s, the sections of the road: Medium 35.0/32.1/32.8/32.6 fps and, with other programs loading the PC, 23.0/19.4/19.2/19.9,
    draw calls 791-864, 2.7-3.0 M triangles; High 34.5/29.6/29.0/26.2 fps and 27.8/21.6/22.4/20.3, draw calls 1021-1138, 3.7-4.3 M triangles. The gate's Medium was 33.7/30.2/34.2/34.5, 780-840 draw calls: no worse.
  Verified: 372 GUT tests, `tools\nettest.ps1`, `tools\flowtest.ps1 -Clients 1 -Stage 2` (2:06.3 / 2:16.9, 18.3 / 16.9 m/s: the same as the gate's averages, 18.5 / 17.1).
- 2026-11-10: A3 final check, the finished phase looked at once more from the real game and the stage shots (Black Pine, Red Canyon, Glacier Ridge in snow, mirrors by day and dusk, the HUD, the map, the results): DONE.
  - Found and fixed: the rev counter sat at 18 % for most of a drive (36 of 47 one-second samples on Black Pine, every speed over 50 km/h): the HUD read a camera that had not moved yet this frame against
    a mirror a physics tick ahead, which put the right door mirror under it. Now 0 of 47: the HUD runs after the cameras, `CarMirrors.glass_center` is where the glass is drawn (tested at 30 m/s).
    Dirt on the windshield was a threshold of big noise, a camouflage net: now a film of dust with the wind's runs and small specks of mud stretched up the glass (`windshield.gdshader`), 35 %, 70 %, 100 % looked at against a dark forest and an open sky.
    A pool's mirrored ray steps a little differently per pixel: whole trees instead of bands, on Medium and High.
  - Cost of the two shaders, `tools\perf.ps1 -Stage 0 -Quality 1`, 30 s, two alternating rounds at 1920x1080 with another project's tests loading the PC: before 35.7/36.7/37.5/36.7 and 25.4/25.5/23.0/22.0 fps, after 34.8/36.0/36.0/37.3 and
    37.2/32.0/31.2/30.4; draw calls 797-863 and 778-852 before, 797-862 and 794-863 after; 2.7-3.0 M triangles, physics 1.3-1.8 ms (up to 3.6 under the load): no change beyond the PC's noise.
  - Known and left for their phases: firs stay green in snow (A4), crew bodies (A5), the menus are still plain (A7), 30-37 fps on this laptop against the 60 of the quality bar (A9), a stone chip cracks the windshield on most gravel stages (0.012 a second at 20 m/s: judged with people at the wheel, `TEST_PLAN.md`).
  Verified: 375 GUT tests (10369 asserts, one Jolt job-system warning under load), `tools\nettest.ps1`, `tools\flowtest.ps1 -Clients 1 -Stage 2` (2:05.2 / 2:15.3, 18.5 / 17.1 m/s), no script or shader error in their logs.

- 2026-11-10: A4 effects, first part: dust that hangs in the air, thrown stones, what they do to the car behind (spec items 1, 2, 9 and the landing's ring of item 5): DONE.
  - `CarRoadFx` is the one owner of what a car throws off the road (`RallyCar._update_dust` and `_update_splash` are gone), on every peer from what that peer sees the car do, with the rules in `RoadFxRules` (pure) and two world-space pools every car shares (`RoadFxPool`, one draw call each).
  - A follower 2 s behind on a dry stage, `tools\fx_probe.ps1` (the same frozen frame with and without the cloud, what of the road shows through), six moments each: Black Pine 94 % of the road 30-90 m ahead hidden (92-100 % at speed), 70 % of the 8-30 m in front of the car; Red Canyon, in the open wind, 79 % and 72 %.
    Shots: `reports\screenshots\fx\final_black_pine\26.0.png` beside `26.0_clear.png`.
  - Cost, `tools\perf.ps1` with `--flip-road-fx=1.5` (shown and hidden frame against frame in one run), riding in the cloud: Medium 0.77 ms Black Pine, 0.27 ms Red Canyon; High 0.35 ms; Low 0.49 ms; Medium outside the cloud (the leading car) 0.28 ms. Three alternating rounds on/off of the whole effect, 36 s, stage 0: 31 ms on, 34 ms off, inside the noise of this PC (25-41 fps either way); draw calls 660-930 either way, 2 draw calls at most for all cars.
  - Stone chips (`StoneChipRules`): a lone bot's run, `tools\chip_odds.ps1`, stones a run and runs of 100 with a bullseye / a crack: Black Pine 0.51 (40 / 9.2), Misty Creek 0.42 (34 / 6.7), Red Canyon 0.62 (46 / 12.9), Scorpion Hills 0.55 (42 / 10.6), Eagle Nest 0.53 (41 / 10.0), Glacier Ridge 0.55 (42 / 10.6): one run in ten cracks. Following 5 m behind at 72 km/h is 0.21 stones a second against 0.006 alone.
  - The crack's picture is still the old one (item 10, next).
  Verified: GUT, `tools\nettest.ps1`, `tools\flowtest.ps1` (a follower got its bullseye: "NET stone chip 1 team 2").

- 2026-11-10: A4 effects, second part: a car that gets dirty, marks on the road (spec items 3 and 4): DONE.
  - `CarDirt`: the body, trim and tyres wear skins of the car's own (`car_body.gdshader`, the model's material while clean: no draw call added). Dust 0.19 after
    300 m of gravel, 0.64 after 1.5 km, 0.87 after 3 km at 20 m/s (`test_car_dirt_rules.gd`); mud 0.66 after one 300 m stretch. Looked at from the side, the back,
    above and the seat on Black Pine (clean, 0.5, 0.85 dust; 0.75 mud), Glacier snow 0.8 and Red Canyon dust 0.85: red paint readable at every level.
  - `CarTyreMarks`: one mesh and one draw call per car, a ring of 7334 / 5867 / 4400 pieces per tyre (High / Medium / Low) for 4.4 km, about 3.5 MB of buffers a car
    on High. Looked at from above and low down on gravel, mud (rain on Misty Creek), snow, through a hairpin and a forced handbrake slide; no piece sinks into the road
    (2 cm above the ground found by a ray, marks break over creases and steep ground). Cost of drawing them, `tools\perf.ps1 -Quality 1 --flip-marks=1` (shown and
    hidden frame against frame): 40.5 ms shown, 41.6 hidden, below this PC's noise while another project loaded it.
