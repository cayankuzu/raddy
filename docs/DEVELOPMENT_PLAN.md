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
| A7 AAA HUD / UI / UX | design system, role HUDs, menus, onboarding, gamepad navigation, accessibility (with a seat and FOV option: A5 set the default seat and a vertical 62 degrees; from the driver's seat it should bring all of the interior mirror into the frame, 60 % of it at rest by default), the trip meter's numbers (`CarRallyKit.trip_display`) | UX audit, new-player test |
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
  - `CarDirt`: the body, trim and tyres wear skins of the car's own (`car_body.gdshader`, the model's material while clean: no draw call added). Dust 0.23 after
    300 m of gravel, 0.74 after 1.5 km, 0.93 after 3 km at 20 m/s (`test_car_dirt_rules.gd`); mud 0.69 after one 300 m stretch. Looked at from the side, the back,
    above and the seat on Black Pine (clean, 0.5, 0.85 dust; 0.75 mud), Glacier snow 0.8 and Red Canyon dust 0.85: red paint readable at every level.
  - `CarTyreMarks`: one mesh and one draw call per car, a ring of 7334 / 5867 / 4400 pieces per tyre (High / Medium / Low) for 4.4 km, about 4 MB of buffers a car
    on High (3.3 MB of vertices, 0.7 MB of indices). Looked at from above and low down on gravel, mud (rain on Misty Creek), snow, through a hairpin and a forced handbrake slide; no piece sinks into the road
    (2 cm above the ground found by a ray, marks break over creases and steep ground). Cost of drawing them, `tools\perf.ps1 -Quality 1 --flip-marks=1` (shown and
    hidden frame against frame): 40.5 ms shown, 41.6 hidden, below this PC's noise while another project loaded it.

- 2026-11-10: A4 effects, third part: bigger hits and a crack that looks like a crack (spec items 5 and 10): DONE.
  - `CrackPicture` + `glass_crack.gdshaderinc`: hair-thin straight lines from the bullseye, branches, rings, a little star per later stone, spreading with the
    hits; lit by their own `light()` (flare square to the light, against a low sun most). Baked 762x487 in 10.8 ms (a worker after the first stone), 1.6 % of
    the texels near a line. Looked at from the seat on Black Pine (away from, across and towards the sun, 2-6 stones, dusk with and without the dome lamp) and
    Red Canyon (a low sun 0, 12 and 25 degrees off ahead, a high one), from outside at 4 m, and on a side pane. The side panes' crack never showed before: its
    picture lay off the pane (the mesh runs x along the car, z up), fixed.
  - Crashes: `CrashRules` + meta `struck` on what can be hit; sparks, leaves, splinters, straw, chips, dust and a broken window's glass, looked at beside the car
    (metal, rock, tree, window, straw). A tree hit at 14 m/s in the GUT test: TREE at the front, 56 flakes.

- 2026-11-10: A4 effects, fourth part: times of day and a night that is hard and beautiful, weather on the trees, a forest floor (spec items 6, 7 and 8): DONE.
  - The room picks the time of day (`RaceSettings` key `time`: day, golden hour, dusk, night or Random; left out it is day), synced with the other choices and shown
    on the room's card, the HUD and the results in Turkish and English. The room's choices sit three to a row (five and Surprise Rally side by side ran off a
    16:9 window). `route_test --time=N` replaces `--dusk`, the flow test takes `-Time`.
  - `RaceLook` per time: the golden hour's sun at 12 degrees, warm and dazzling (the visors come down); at dusk the sun 4 degrees under the horizon (no sun light, no
    shadow pass) and the sky burning on its side (`shaders/race_sky.gdshader`: afterglow, clouds lit from the sun's side) over trees and ground falling dark; at
    night a moon of 0.05 and stars on a clear sky, neither under clouds, and a haze that does not glow. The haze keeps each biome's colour at every time. By day the
    sky shader is the procedural sky: an A/B against the old sky on three views, mean difference 0.03 of 255. `SunInTheSky` stays the one sky light for every camera.
  - Headlights: a projector pattern, brightest in a band round the horizon (the road from about 45 m on), cut under the nose, drawn through an empty shadow map on a
    layer nothing is on (`CarLamps.NO_CASTERS`: with no layer the engine dropped the map and the pattern with it); the seat's own car's beams cast real shadows on
    High. Read without mipmaps (project setting): a mipmap smeared the band and lit the road 20 m ahead instead of down it. Strength by the time of day
    (`RaceLook.lamp_light`: by day they hardly show, in snow a quarter of the night's: the snow's glare). Fog and dust scatter little of them, a puff of dust in front
    of a lamp glows instead of blazing; tail lights leave a faint red on the road behind, the dials light with the headlights, rain and snow are lit by the lamps
    from dusk on, mirrors keep a 512 px shadow atlas so a follower's beams light the road in them. The dome lamp makes the map readable at night; without it the
    notes column is hard to read.
  - Trees in the weather: leaves, needles, bark and the ground cover take `wetness` and `snow_cover` (`plant_weather.gdshaderinc`): snow in clumps on what faces up,
    the undergrowth white long before a branch, rain darkens and shines. 34 materials for every plant of every biome, one per material of the scans: no draw call added.
  - Forest floor: `RoadsideDresser.canopy` maps where the crowns shade the ground (2 m pixels, 41-73 ms for Black Pine's 358 x 926 map); the ground's shaders darken
    it there, and in the forest needles, leaves and moss replace the grass. Mountain and desert keep their ground, only shaded.
  - Contact sheets of every stage at every time of day in its own weathers (18 sheets, 216 shots: `stage_shots.ps1 -OwnWeathers -AllTimes -Kinds "corner,junction,spectators" -Sheet`),
    looked at by eye: day unchanged; golden hour warm with long shadows; dusk a burning or violet sky over dark silhouettes; night the road readable in the beams and
    dark round every corner. Hardest and still drivable: fog and dust storms at night (a lit veil), snow at night (glare), following in dust at night (the cloud
    glows in your own beams and hides everything); a junction at night shows only where the beams point.
  - Cost: `tools\perf.ps1 -Stage 0`, 30 s, day and night alternating, two rounds each. Medium: day 37.4-39.9 fps, night 35.6-38.7
    (about 1 ms: the beams' passes), draw calls 782-867 either way. High: the moon's shadow cascades made the night dearer (1248-1451 draw calls
    against 1024-1140, 28.5-31.7 fps against 32.0-34.4), so the moon casts none now: night 852-1034 draw calls, fewer than by day's 1027-1142; 21-35 fps
    either way while other programs loaded the PC. Once a stage: the canopy map 41-73 ms, the beam's 64 x 768 pattern 13 ms (once a game).
  Verified: 439 GUT tests (11537 asserts), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1 -Stage 2 -Time 3` (a whole race at night: 2:05.1 /
  2:15.2, 18.5 / 17.1 m/s, no script or engine error in either log).
- 2026-11-10: A4 effects, the review's findings (a player's, a bug hunter's and the spec's eyes): DONE.
  - Dusk was darker than night from the seat (the beams at 0.3 of the night's, the forest black): it is the blue hour now, the sky's blue light on the land
    (`RaceLook.BOUNCE_AT`, `DAYLIGHT` 0.45) and the beams in full. Black Pine from the seat at 12 and 28 s: frame mean 0.025 / 0.028 against the night's 0.013 /
    0.014 (it was below); the road reads without lamps for the first tens of metres, Eagle's Nest's open slopes lie dim and blue under the burning sky.
  - By day the beams are not drawn at all, whatever the weather (`lamp_light` 0): their shadow passes cost High 110-290 draw calls in the rain for nothing on screen.
  - A follower's beams shone through the car ahead onto its road and the dirt on its windshield (only the seat's own beams have real shadows): every car stands
    in the others' beams as a hull of 28 triangles inside its body (`CarLamps.HULL_LAYER`, shadows only, in every beam's shadow map, left out of the sun's). The
    leader's windshield no longer glows and its own shadow lies ahead of it; what passes beside it still lights the trees there, as a real car close behind does
    (leader's windshield, mean of 255: 93 / 36 at a 15 / 22 m gap against 20 / 18 alone, the 93 a bush beside the road in the follower's beam).
  - The glass shaders' light() of their own had left SPECULAR at 0.5: every pane mirrored the sky from the seat, a grey veil over the view (+18 % measured).
  - Low saw the beam-lit road crisply at night in fog and dust storms, where Medium and High see a glowing veil: Low's flat fog takes the light the beams
    give the volume (`RaceLook.BEAM_VEIL`): the windshield's mean 0.22 / 0.19 on Low in fog / a dust storm against Medium's 0.20 / 0.11 (Low may see less,
    never more; flat fog has no veil right in front of the car, so the near road stays a little clearer on Low).
  - Dirt skins were made per material with the first mesh's place: the trim's dirt was measured a metre off, the rims filled like the tyres. One skin per
    material and mesh space now, a tyre in its own space; the model's occlusion map, dropped with the skins, is back.
  - A cracked side pane baked its picture on the main thread of every peer (7-17 ms): a worker bakes it now (`CarModel._on_window`), the glass is there at
    once (0.3 ms of the frame the can hits in).
  - Other cars' glass was drawn over the dust they drive in: it goes under the puffs now, the seat's own glass over them (`CarModel.GLASS_PRIORITY`, `bind_seat`).
  - The first stone's bullseye was an opaque white splat 2 cm wide: a centimetre now, a dark pit, a half moon of crushed glass you see through, and a ring
    that flares like the crack's lines.
  - A tree crash's needles fell unseen (6-10 cm, dark, from up in the crown): leaves and sprigs of 8-24 cm, light and dry ones among them, come down between
    the car and the tree from windshield height up; none in a cabin (they fell through the roof: `road_flake.gdshader` `LEAF_NEAR`).
  - Snow on the firs read as flat white paper shards: on a card it lies only where the card faces up and is seen face on, on the blades and not their edges,
    broken by a finer noise (`plant_weather.gdshaderinc` `card_holds`).
  - The puff pool overflowed with three crews (720, 820 alive at the peak): 1280 (a test keeps three crews' dust in it). `tools\perf.ps1 -Stage 0` with a
    follower, alternating, two rounds each: 39.6 against 39.9 fps, the same draw calls.
  Verified: 447 GUT tests (11662 asserts), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1 -Stage 3` (2:02.2 / 2:07.6, 17.4 / 16.7 m/s, no script or engine
  error in the logs).
- 2026-11-10: A4 final check, the finished phase looked at once more from the seat, the chase camera and beside the road (dry gravel and a follower in its
  dust, mud and rain, snow, a dust storm, golden hour, dusk, night, a bullseye and a crack, a dusty and a muddy car): DONE.
  - The ground's own specular was the default 0.5 (the verge's the dry road's 0.2): the sky's sheen turned every shade blue-grey, the forest floor under the
    crowns most. Now 0.2 dry and 0.5 wet (`ground_common.gdshaderinc`), blended across the verge. A/B beside the road: Black Pine's floor reads as dark brown
    needles, Eagle's Nest's grassy slope keeps its green, Red Canyon is unchanged.
  - Rain on the plants: needles had a smooth film's gloss (roughness 0.32, specular 0.45) and wet bark 0.5 + 0.45, so the crowns looked frosted from the seat
    in the rain. Now roughness 0.55, specular 0.35 (water's), bark stays at 0.5: dark wet firs, the birches' white bark still white.
  - By day a braking car laid a red blob on the snow behind it: the rear lamps' glow on the road follows `RaceLook.lamp_light` like the beams' (the glass shows).
  - The weather's particles (P4): snowflakes were 7 cm squares, a dust storm's wisps rectangles, and a flake passing the lens a sheet with straight sides (the box
    of weather follows the camera and knows no cabin). Round flakes, soft wisps, drops that thin at both ends, nothing within 1.5 m of the eye, full from 4 m.
  - Tests: two scripts left behind the RoadFxPool a car makes beside itself, one compared a float with an int (three GUT warnings, now none).
  - Looked at and right: the cloud behind a car (a follower 2 s back on Black Pine, Medium: 94 / 96 % of the road 8-30 m ahead hidden, 97 / 79 % of 30-90 m, at 26
    / 44 s with a 52 / 46 m gap), the stones in it, mud spray and ruts on Misty Creek, the powder plume and the marks in the snow on Eagle's Nest, the golden
    hour into a low sun, the blue hour at a spectator place, the night (only what the beams light), the crack's thin straight lines by day, a car at 0.85 dust
    and 0.75 mud.
  - Known and left: the bot drives into a tree on Glacier Ridge in snow about 15 s in and stays against it braking (RouteFollower on snow; the flow tests run
    clear weather); the windshield's dirt is the same brown in every weather (dark specks in snow, black against a low desert sun: A3's look, it could take
    `CarDirt`'s layers); a chase camera pushed into a fir's crown shows straight-edged pale cards.
  Verified, on the fixed build: 447 GUT tests (11666 asserts, no GUT warning; one Jolt job-system warning under load), `tools\nettest.ps1` (3 clients, 40 s),
  `tools\flowtest.ps1 -Clients 1 -Stage 3` (2:02.2 / 2:07.6, 17.4 / 16.7 m/s), no script or engine error in their logs.

- 2026-11-10: A5 carry-over C1, windshield dirt that belongs to the road: DONE.
  - What lands on the windshield takes the colour of the road it came from (`CarDirtRules.glass_tint`, `CarDirt`'s layers): dust in the road's own colour
    (tan in the desert), brown mud and a splash's muddy water, grey slush in snow, each road for as much as it put there (`WindshieldGlass.tint`), worked
    out on every peer from how it sees the car drive. The door mirrors' grime takes the same colour (`CarMirrors.grime_filter`).
  - The dirt is a film the light comes through (`windshield.gdshader`): what it takes from the view it scatters on, the world behind it blurred (the copy
    of the screen the seat's motion blur already makes) and a forward lobe round a light beyond the glass, so it glows round a low sun instead of going
    black; the glass's inside sees the dark cabin, not the sky (AO). Flecks come by the square of the dirt: few, small and translucent at first, a film
    carries the loss. Mud lays a thicker film (it takes the light), slush a thinner one (a wet haze), dust in between (the colour's alpha).
  - What a dirty screen hides, `tools\fx_probe.ps1 -ExtraArgs "--glass-dirt=0.35+0.7+1"` (new: clean glass against each level in the same frozen
    frame, the road 8-30 m ahead), A3's look against the new one at 35 / 70 / 100 %: Black Pine by day 0.14/0.35/0.60 against 0.12/0.37/0.62; Red Canyon
    at the golden hour into the sun 0.17/0.44/0.76 against 0.12/0.30/0.49 (30-90 m 0.11/0.28/0.47 against 0.14/0.37/0.57: the glow lies over the far
    road); Glacier Ridge in snow 0.07/0.22/0.51 against 0.12/0.31/0.49; Misty Creek's mud in the rain 0.22/0.51/0.77 against 0.13/0.47/0.78; Black Pine
    at night with the dome lamp 0.07/0.21/0.40 against 0.10/0.30/0.51. Looked at from the seat at every level: no black swarm against the low sun, grey
    slush in snow, brown mud, a beige veil under the dome lamp, the wipers' arcs clean.
  - Cost, `tools\perf.ps1 -Stage 0 -Quality 1`, the new shader against the old, alternating, two rounds: 40.6 / 40.9 fps against 40.4 / 40.9, the same
    draw calls (782-869).
  Verified: 451 GUT tests (11695 asserts).

- 2026-11-10: A5 carry-over C2, a light pod for the night: DONE.
  - At dusk and at night every car wears a pod of four lamps on its bonnet on every peer (`CarLightPod`, `RaceLook.light_pods`), built in code
    in one draw call (`shaders/light_pod.gdshader`): a black fairing with a cover plate in the team colour, two spot lamps in the middle and a wide
    lamp at each end under clear covers in chrome bezels, the lamp cans behind, two legs bolted to the bonnet (1.7 cm clear of it, tested against
    its triangles). It rides the bonnet's hinge (`CarDamageFx.mount`): a loose bonnet at 90 km/h aims it 76 degrees up, a torn-off one takes it away
    dark (the glass that flies off too), a recovery bolts it back. Seen from the seat its black back is a strip along the bottom of the windshield,
    as in a real night onboard.
  - Its light is one beam through a projector, the headlights' way (`CarLightPod.beam_pattern`, tested): a long band from about 60 m on, a wide
    spread for a corner's sides, falling as the square of the angle below its band so the near road is no blaze; shadows for the seat's car on
    High. The two headlights became one beam from between them with the light of both: every beam is a shadow pass a frame, a car at night
    has two as before.
  - Contact sheet of every stage at night from the seat, before and after (`stage_shots.ps1 -Time 3 -Compare`, 47 places, new `turn_in` places
    and `-RoadLight`): the share of the windshield's view that reads 0.139 -> 0.198, its mean 0.049 -> 0.075. The road 100 m ahead on a
    straight: Black Pine 0.34 -> 0.68, Red Canyon 0.45 -> 0.82, Eagle's Nest 0.62 -> 0.82 (by a cliff 0.17 -> 0.56), Glacier Ridge 0.59 -> 0.81,
    Scorpion Hills 0.56 -> 0.76; 40 m into a corner: Black Pine 0.24 -> 0.47, Eagle's Nest 0.16 -> 0.33, Scorpion Hills 0.29 -> 0.62, a cliff on
    Red Canyon 0.00 -> 0.17 (tone-mapped luminance; it reads from 0.06). Where the road is in sight it reads past 100 m; a corner still shows
    late behind its screen of trees, and the wide lamps light its sides through the side windows.
  - Cost, `tools\perf.ps1 -Stage 0`, night, three cars (`route_test --follower=14+28`), the pod against A4's two headlight beams, alternating, two
    rounds: Medium 37.4 / 37.4 fps against 37.7 / 37.3 (draw calls 649-768 against 648-762); High 31.2 / 31.4 against 32.3 / 32.6 (1147-1337
    against 1039-1257: the pod's real shadows for the seat's car, a wider cone). Fog and dust storms at night: Low's flat fog still veils as
    much as Medium's volume (windshield mean 0.22 / 0.19 against 0.19 / 0.17).
  - Mirrors: as before; two cars close behind light the forest round the leader and fill its mirrors with their lamps.
  Verified: 459 GUT tests, `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1 -Stage 2 -Time 3` (a race at night: 2:05.0 / 2:15.1,
  18.5 / 17.1 m/s, no script or engine error in the logs).

- 2026-11-10: A5 items 8, 1 and 4 (where the crew sits, a rally car's cabin, the crew's bodies and who sees what of them): DONE.
  - The seat: the eyes moved 15-16 cm closer to the wheel (driver -0.32, 0.63, 0.06; navigator 0.32, 0.61, 0.10, car space) and the field of
    view narrowed from a vertical 72 to 62 degrees. Straight ahead the windshield took 0.31 of the frame height under 0.31 of headliner from
    either seat, now 0.50 under 0.14 (driver) and 0.47 under 0.15 (navigator); the interior mirror and the near door mirror stay in the frame,
    the far one within a 30 degree glance (`tests/unit/vehicles/test_seat_view.gd`, rays against the car's own triangles). The wheel is set
    4.5 cm higher than the model has it: the dials' hubs and the needles at stage speeds and revs read through the opening over the hub (14 of
    14 points; the old eye saw 12 of 18 points of the whole sweep) and the hands reach it with the elbows bent. From the closer eye the visors
    come down to 45 degrees (their edge 7.2 degrees over the eye line) and slide 12 cm out past the mirror (gone since A5's review: a caged
    car has none); the held map came 7 cm closer.
    The mirrors aimed themselves for the new eyes (their tests unchanged). Before and after: `reports/screenshots/a5_crew/before_*.png`,
    `after_*.png`.
  - The crew (`CrewBody`, `CrewPose`, `CrewHelmet`): Quaternius's UAL1 mannequin (CC0, 0.72 MB without the library's clips, 13.7k
    triangles) in every seat a player holds on every peer (`RaceSession._seat_crew` from the roster, `NET crew team N: ...` lines), none in an
    empty one. Posed in code: eyes on the seat's camera (within 1 mm), back reclined 16 / 18 degrees, the hip joints 9.5 cm over the bucket's
    cushion, feet on the clutch and throttle (the navigator's on the floor), the driver's hands on the wheel at a quarter to three, the
    navigator's on the thighs. Suit in the team colour with white stripes down the sleeves, legs and sides, dark gloves and boots (one draw
    call), a code-built full-face helmet (shell, stripe, visor in a gasket, chin vent, HANS posts; at least 1 cm round the head everywhere),
    a six-point harness in a deeper shade of the team colour. The seat's own camera leaves `CrewBody.OWN_HEAD_LAYER` out: your arms, knees
    and harness show, your head never; the mirrors and your partner see it.
  - The cabin (`CarRallyKit`, one mesh and one draw call): roll cage (front hoop up the A pillars and along the roof, main hoop with its
    diagonal and stays, door bars, foam on the A pillars and round the heads: it hides 0.0 % of the windshield's view from either seat, the
    helmets stay 9.3 / 10.7 cm from the tubes' middle lines; wrong: the cage, the trip meter and the extinguisher were not drawn at all and
    the measure lacked them too, see A5's review on 2026-11-11), bucket seats swept round the bodies on rails (the road seats, their buckles
    and the rear bench cut away), a loose harness on an empty seat, a trip meter by the navigator's A pillar, a fire extinguisher.
  - Cost, `tools\perf.ps1 -Stage 0 -Quality 1`, three cars (`--follower=14+28`), full crews against `--crew=none`, alternating, two
    rounds: 37.2 / 37.2 fps against 37.6 / 37.5 (about 0.25 ms; the bodies stand still, nothing re-skins them each frame yet), draw calls
    +15 to +33.
  - Looked at: both seats before and after, each seat looking at the other, the driver looking down at their arms, knees and harness, the
    navigator from outside through the side window and through the windshield, an empty seat, the map held up beside the navigator, the
    navigator under the dome lamp at night, the cage and the partner in the interior mirror (no cage was there: its seats' backs were taken
    for it), a rival car from a follower.
  - Left for the next A5 parts: the hands follow nothing yet (the rim turns through the driver's gloves at lock; item 2's IK), the map is
    not in the navigator's hands, heads do not turn with the look, gestures, states, sync, spectators, livery. The mannequin's facets show up
    close; no HANS collar on the shoulders yet.
  Verified: 482 GUT tests (11947 asserts), `tools\nettest.ps1` (3 clients, the crews seated on every peer), `tools\flowtest.ps1 -Clients 1`
  (2:11.2 / 2:17.4, 16.9 / 16.1 m/s), no script or engine error in their logs.

- 2026-11-10: A5 items 2, 3 and 5 (hands and heads, states and gestures, in sync on every peer): DONE.
  - The motion (`CrewRig`, every body in a car, every peer) runs on Godot 4.7's skeleton modifiers (ClassDB has `TwoBoneIK3D`, `ChainIK3D`,
    `FABRIK3D`, `CCDIK3D`, `CopyTransformModifier3D`, `AimModifier3D`, `LookAtModifier3D`, `BoneTwistDisperser3D` and more; used: `TwoBoneIK3D` for the
    arms and the kicking legs, `CopyTransformModifier3D` for each hand's turn, `LookAtModifier3D` for the head): the rig sets goal nodes in car space,
    the skeleton solves after the wheel turned. The driver's hands ride the rim within what the arms reach (the left from -30 to +90 degrees of a
    turn, the right from -88 to +30) and the rim slides through them past it (push-pull), within 1 cm of their grips (tested at 0, 0.15, -0.2, 0.6 and
    full lock); one leaves it for the shock gun (code-built, in the hand; the darts' wires leave its muzzle), the window's winder, the wipers' stalk,
    the horn's hub, the handbrake and a gear change. The navigator holds the real map by its edges, low so the notes stay readable, and rests the
    hands on the thighs. Heads turn with each player's look (the chest 6 %, the neck 35 % of a turn and 40 % of a nod, the head the rest, within
    0.1 degree); out cold the body slumps (chin to chest, hands to the lap), a shock shakes it first, a can goes out of the window, the legs kick.
  - Gestures as a mechanic (`CrewRules`, pure): `gesture_left/straight/right/slow` on 1-4 and the d-pad (nothing else uses them, tested), rebindable,
    TR/EN; the hand nearer the partner with its shoulder brought forward (the harness holds the back: the torso never leans out of its static
    straps), just past the car's middle: the fingertip 16-44 degrees off the partner's straight ahead (the view is 47 either side); pointing away
    from the partner the hand sweeps back into their sight. A gesture folds the navigator's map; the driver steers one-handed while a hand is on
    the gun, a gesture, the window, the wipers or the horn (not the handbrake or a shift).
  - Sync (`Cabin.seats`, `CrewRules.Seat`): the look, a gesture, a job and its count, the gun, 4 bytes 10 times a second from the seat's peer to the
    host (roster and rate checked) and on to everyone else, unreliable on channel 3; heads eased between packets. `tools\nettest.ps1`: the navigator
    turns its head 60 degrees and points left, every other peer prints `NET seat team 1 navigator gesture left job none gun down look 60 -10`.
  - Only a crew someone can see moves: the own car's always, another's on the screen within 60 m or within 10 m (a mirror); otherwise its modifiers
    are off and its skeleton does nothing (0 updates in 30 frames). The rig's script takes 175 us a frame for six moving bodies.
  - Cost, `tools\perf.ps1 -Stage 0 -Quality 1`, three cars (`--follower=14+28`), crews against `--crew=none`, alternating, two rounds (mean frame
    time): from the lead car 26.93 / 26.80 ms against 26.10 / 25.96; riding the second car, two crews in view, 27.60 / 27.76 against 27.22 / 27.13.
  - Looked at (`reports/screenshots/a5_hands/`): the driver's hands at rest, at 0.4 and at full lock from both seats; the map held from both seats
    and at night under the dome lamp; the four gestures of each seat from the other seat and in first person; the gun from both seats; the
    window, the wipers, the handbrake, a gear change, a throw from outside and the kick; a fainted and a shocked driver.
  - Left: the short motions are placed by eye (the model has no door winders or stalks); the kick's feet pass through the dash's underside for a
    moment; a thumbs-up gesture; leaning in corners and on hits (item 4).
  Verified: 499 GUT tests (12462 asserts), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1` (2:11.2 / 2:17.5, 16.9 / 16.1 m/s), no
  script or engine error in their logs.

- 2026-11-11: A5 items 4 (heads that swing with the car), 9 (the livery), 7 (the crowd), 6 (what the phase costs) and the final look: DONE.
  Phase A5 is complete.
  - Heads that swing (`CrewSway`, pure; `CrewRig` feeds it the car's place on every physics tick, its own or a snapshot's, nothing is sent): the
    harness holds the body to the seat and the neck gives: 6.5 degrees out of a 1 g corner (8.45 for the navigator, who holds on to nothing), a
    nod of 3.6 degrees under 0.8 g of braking, 7.4 when the car stops dead from 20 m/s and upright again within 2.5 s; 15 degrees at most,
    nothing from a recovery's jump. The navigator's kick slides the feet back out from under the dash, up behind its edge and over it onto the
    glass, soles first (the toes up to 0.62 m, 0 crossings of the dash in 118 frames, tested); the hands ride the thighs meanwhile.
  - The livery (`CarLivery`, `LiveryRules`, `shaders/car_sticker.gdshader`): every car is lettered for its crew on every peer from the roster
    (`RaceSession._seat_crew`): the team's number on a white panel on each front door (62 x 30 cm, the event's name on a black band over a
    stripe of the team colour) and on the rally plate on the bonnet (42 x 20 cm), printed on the paint's own skins, so they cost no draw call
    and the road covers them as it covers the paint; the crew's names, the driver's first, each after a small flag of Turkey on the rear side
    windows (40 x 13 cm; capitals the way the locale writes them, i to İ in Turkish; 20 letters at most) and the number at the top of the rear
    window, white vinyl on the glass's own triangles (one draw call); a mud flap behind each wheel with the game's name (one mesh, a `CarDirt`
    skin). One 1024 x 512 picture a car, drawn in code through the TextServer's glyph cache (it works headless) at 880 pixels a metre; no
    maker's logo anywhere.
  - The crowd (`Spectators`, `SpectatorRules`, `shaders/spectator.gdshader`): people at RallyDressing's places, the same on every peer from the
    stage's seed: 55 at 7 places on Black Pine, 46 at 6 on Red Canyon, 4-8 a place and 1.6 m apart. The crew's mannequin baked standing with
    what its bones weigh on each vertex, one MultiMesh and one draw call a place; the shader turns the arms and the heads about the standing
    pose's joints: arms down, crossed, hands on the hips or a small flag of Turkey held up; clothes for the biome (long sleeves on 0.23 of the
    desert's crowd and on all of the mountains', caps and beanies). Heads turn to the nearest car within 140 m; a place cheers a car going by
    within 70 m (arms up, clapping, a wave, the flag swung overhead, some jump) and is back to 0.65 a second after it has gone.
  - Cost (item 6). Two commits against each other say nothing on this PC: the phase's base against its head, alternating, read 39.2 / 28.5 fps
    against 32.6 / 30.4 (another program's load moves a run by 10 fps; the 2-3 ms read off such runs before was inside that). So
    `tools/perf_probe.gd` now shows and hides one thing every half second inside one run (`--flip-crew`, `--flip-crew-motion`, `--flip-kit`,
    `--flip-livery`, `--flip-pod`, `--flip-crowd` beside `road-fx` and `marks`) and gives the mean frame time either way and the share spent
    before the draw (every node's `_process`, the skeletons, the deferred calls: `work_cost_ms`, steady to 0.03 ms). Medium, Black Pine, three
    crews (`--follower=14+28`), 70 s runs, frame cost (of which before the draw): from the lead car the crews 0.71 ms (0.29), their motion
    alone 0.36 (0.30), the cage and seats -0.44 (-0.01; the seats alone: the cage was not drawn, see the review below), the livery -0.17
    (-0.02), the crowd 0.19 (0.03), a flip of nothing -0.25 (-0.01);
    riding the second car, another crew moving ahead, the crews 0.79 (0.34), their motion 0.61 (0.35), nothing -0.34 (-0.03); at night the
    crews 1.14 (0.37) and the pod with its beam 1.07 (it took the place of A4's second headlight beam). So a flip of nothing reads up to a
    third of a millisecond: only the crews cost anything that can be measured, 0.7-0.8 ms by day, and the phase stays under the 1.5 ms it
    was allowed.
  - Where the crews' cost goes: the rigs' scripts and the skeletons 0.2-0.35 ms (0.07 ms a moving body, 0.01 a resting one; all of the game's
    scripts together take 0.9 ms a frame), re-skinning nothing that can be measured (twenty bodies re-posed every frame in an empty scene:
    within 0.02 ms a body), the rest draw calls: 26-32 of 870 on Medium, 44 of 1120 on High for three crews standing at the start.
  - Cut: only the cabin the local player sits in casts shadows of its crew, cage and seats, a harness and a mud flap never (nobody sees them
    under a rival's roof, and each was a draw call in every shadow map the car is in): with three cars at the start 868 -> 862 draw calls on
    Medium from the lead car, 873 -> 863 riding the second, 1119 -> 1093 on High. The spectators' body carries levels of detail
    (`ImporterMesh.generate_lods`: 13756 triangles, 6878 within 3 mm, 3438 within 10 mm, 1718 within 21 mm, 858 within 40 mm; the engine
    picks one for a whole place by the error's size on the screen, under a pixel): the start's two places were 0.62 M triangles in the view
    and the sun's shadow maps on Medium (0.83 M on High), now 0.015 M (0.03 M); with and without it 0.02-0.14 % of a picture's pixels
    differ, all on the people's outlines.
  - The final look (`reports/screenshots/a5_final/`, and `high/` on High: a dev scene draws at the player's level and Auto is Low on this PC,
    so the phase's earlier pictures were Low's): the driver looking at the navigator with the map open, the navigator looking at the driver's
    hands on the wheel, a fainted driver from the other seat and through the windshield, a pointing navigator at a glance and looked at, a
    pointing driver, the car through its side window, a rival from the seat behind and from in front, the framing from both seats, the cage
    and both helmets in the interior mirror (both helmets: the cage was not there), the livery from all sides, from a follower in its dust and
    under 0.85 dust and 0.45 mud, the pod
    at night from both seats and from outside at night and at dusk, the crowd as a car goes by in the forest, the desert and in snow, from
    beside the road and from the seat. Fixed on the way:
    the suit's stripes were measured as angles round a limb and came out as ragged wedges where the mannequin's joints fold (a white fan on
    the hip, and from the own seat a saw-toothed patch on the own shoulder a hand's width from the eye): they are now measured in metres,
    straight bands of 3 cm that end in clean cuts along the mesh's rings, none over a shoulder or a hip; the crowd cheered a car that stood
    (the whole wait on the grid, the cars parked past the finish): it cheers one going by faster than 2 m/s, a standing one gets its eyes
    (0.82 half a second after a car has stopped beside it, then it settles); the spectators' shirts reached down to the crotch like a
    romper: the trousers come up to the belt; a pointing hand's thumb stuck straight down: it lies by the hand.
  - Known and left: the mannequin's facets show from the other seat and a spectator has no face (no free character or helmet model the
    owner has approved); the trip meter is black against the black A pillar until A7 lights its numbers; from outside at night a car's own
    headlights are flat white glass beside the pod's glowing lamps; the crowd makes no sound yet and does not flinch at a crash (the spec
    left sound for later; people jumping aside is GAME_DESIGN §6's); a rival's rig could work every second or third frame if A9 needs the
    0.07 ms a body.
  Verified: 518 GUT tests (16221 asserts, no warning), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1`
  (2:11.2 / 2:17.5, 16.9 / 16.1 m/s), no script or engine error in their logs.

- 2026-11-11: A5's review (three reviewers: the spec, the bugs, a player; 17 findings, two of them found twice) and what it changed: DONE.
  - Wrong in the entries above: the cage, its foam, the trip meter, the extinguisher and the seats' rails were never drawn. The kit's mesh
    held 16180 vertices and drew 784 triangles, the two seats': `SurfaceTool.append_from` of the cage (no indices) and the seats (indexed)
    keeps the seats' index array only. The reviewers found it with a headless probe of the mesh (no index named a vertex of the cage) and in
    the pictures (what passed for the cage in the mirror were the seats' backs, the trip meter's place on the dash was empty); the tests
    passed because they measured `get_faces()`, which lacked the cage too. So "hides 0.0 % of the windshield's view", "the cage and the
    partner in the interior mirror" and the kit's flip of -0.44 ms were measured or looked at without it. Fixed in da21138 (the cage indexed
    before the seats join it): 6016 triangles drawn, a test asks every part to be drawn; the cage hides 0.1 % of the windshield's view from
    the driver's seat and 0.9 % from the navigator's. Its cost, flipped inside one run, twice (Medium, Black Pine, three crews, the PC loaded
    to 18-25 fps by another program): -0.07 and -0.36 ms (before the draw -0.04 / -0.01), nothing that can be measured.
  - With the cage in place (da21138): the held map stood in the A pillar's tube and is held clear of it by its lower corners, the thumbs on
    free paper the notes now leave under them (they also ran off the sheet on Glacier Ridge); the sun visors are gone, as in a caged rally
    car (they hinged where the roof bars run and, lowered, hid 43 % of the windshield from where the crew sits); the extinguisher lies clear
    of the heels in a kick.
  - Heads swung only on the peer that simulates the car: a car played back from snapshots moves a frame's ticks at once, so on every other
    peer (the navigator's own screen included) the helmets whipped to their 15-degree limits on a straight and never leaned in a corner (the
    reviewers' probes: 0.03-0.15 degrees in a 1 g corner at 40 fps, where 6.5 is right). `CrewSway` follows `RallyCar.seen_velocity`, a test
    plays a car back at 2-4 ticks a frame, and it was checked in a real three-instance session (da21138).
  - Gestures (straight on looked like a fist, a sign to the side away from the partner left their sight, dark gloves on a dark dash, nothing
    at night without the dome lamp): a sign each (the finger across, the thumb away, a chop, a pat) made against the windshield from the
    partner's eye, the gloves' backs in the suit's colour with the stripe (da21138); after dark the dials glow on the hands. The glow sits
    6 cm in front of the panel: a first try 14 cm out lit the wheel's hub like a lamp from 0.07 m, a second by the radio the right hand from
    0.13 m; now 0.14 m from the hub, 0.27 / 0.28 m from the hands (tested).
  - Smaller (da21138): both hands off the wheel steered better than one (`one_handed` asked for exactly one); the glass went 0.02 s after F
    and the can flew before the hand moved (now when the soles land, 0.42 s, and when the hand lets go, 0.3 s); a kick seen on another peer
    stopped half way; the navigator reached through the driver for the far winder; the gun went out through a closed window; a gesture or
    the gun stayed up after the window lost the keyboard.
  - In the beams at night a flag a few metres ahead burned to a white sheet in a red glow (Red Canyon 584 m) and a guard rail to a white
    flare that veiled the road beyond the corner (Eagle's Nest 438 m). Both shade as the engine does (`shaders/lamp_cap.gdshaderinc`: by day
    and at golden hour the same pixels, a mean difference of 0.0002 over the rail, none over the flags) but no lamp gives them more than the
    sun: the flags stay red with the crescent and star, the rail is a grey W-beam with its bolts, the road beyond it reads as before (0.037
    against 0.038) and where the flare was (0.31) is road again (0.03).
  - Looking 120 degrees round filled 60-75 % of the frame with the seat's flat wing: the look stops at 100 degrees, the body's head too, and
    the seats are a racing mesh fabric woven in the shader in two sizes, each faded out by how far its threads pass in a pixel (the first
    weave, faded by distance, shimmered in moiré on the far wing).
  - The crowd: faces (eyes, the nose's shadow, a mouth) where UV marks the front of the head, the fingers loosely curled; the shirt's colour
    showed in a band across the forehead where hair met skin between vertices: the head is skin under the hair now (tested).
  - Decided, not changed: the driver's interior mirror is 60 % in the frame at rest (77 % at 60 km/h, 88 % at 100 km/h, all of it at a
    glance; the navigator's 87 % at rest). A rest look turned towards it would set the road off the middle, the mirror is the model's own on
    its stalk and the eye was set for the windshield: left to A7's seat and FOV options, on `TEST_PLAN.md`.
  - Known and left: at night without the dome lamp the navigator sees the driver's signs as dim shapes against the beams (the driver reads
    the navigator's well); a straw bale in the hot band still glows in a halo (its material is the engine's own; not among the findings);
    the crew and the crowd are still the mannequin (no free model the owner has approved).
  Verified: 532 GUT tests (16709 asserts), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1 -Stage 4` (Eagle's Nest:
  2:09.0 / 2:17.5, 16.7 / 15.7 m/s over 2152 m), no script or engine error in their logs (one Jolt notice that its job queue was full while
  a bot drove a whole stage in the GUT run, with another program loading the CPU). Phase A5 is complete.

- 2026-11-11: A5's final check (fresh eyes on the reviewed build, 0722e03): DONE.
  - Run first, before any change: 532 GUT tests (16709 asserts, 313 s, no error or warning in the log), `tools\nettest.ps1` (3 clients,
    40 s), `tools\flowtest.ps1 -Clients 1 -Stage 4` (Eagle's Nest: 2:08.6 / 2:17.1, 16.7 / 15.7 m/s over 2152 m), no script or engine
    error in their logs.
  - Heads in a car played back from snapshots, in a real session (a headless host, the driver's peer headless and driving by bot, the
    navigator's windowed, looking at the driver, 60 s on Black Pine): over the same corners the driver's head swings on the navigator's
    peer as on the peer that simulates the car (2 s windows, to the side: at 14.3 m/s a mean of 3.30 degrees against 3.44, at most 8.79
    against 8.92, changing 23.5 degrees a second against 26.8; at 17.4 m/s 2.78 / 7.02 against 2.55 / 7.02). No whip, nothing lost.
  - Looked at (`reports/screenshots/a5_check/`, High, 1600 x 900): both seats by day, at dusk and at night with the dome lamp off and on;
    the cage from both seats and in the interior mirror (it frames the rear window there, the road and the car behind stay in sight; through
    the windshield only the foam on the A pillars shows, at its edges); the trip meter from the navigator's seat; each seat's four signs
    from the other by day, at dusk and at night; the held map and its notes; a rival's crew from behind and through the side windows; the
    crowd close up and cheering a car going by; the flags in the beams at night (red, the crescent and the star); the pod at night from the
    seat and from outside; the real race from the main menu (`--flow-test`), from the driver's seat with the empty seat beside it.
  - Fixed: a flat hand (the chop for straight on, the pat for slow down, the horn) kept the mannequin's rest thumb, 27 degrees out of the
    hand's plane towards the palm: from the other seat it hung under the patting hand like a broken finger and stood up off the chop. It
    lies along the index finger now, 5 degrees off the hand's plane (tested for both flat signs of both seats).
  - Known and left: from the navigator's seat at night without the dome lamp the driver's signs are dim shapes (`TEST_PLAN.md`); the thumb
    for the side away from the partner rests 58 degrees up, near a thumbs-up, and reads as a way only as it jerks to 32 (people judge it
    with the hand signals on `TEST_PLAN.md`); the trip meter's display stays blank until A7 prints its numbers; from outside at night a
    car's own headlights are flat white glass; concrete blocks and straw bales in the hot band of the beams glow white with a halo.
  Verified after the fix: 532 GUT tests (16713 asserts, 196 s), no script or engine error. Phase A5 is complete.

- 2026-11-11: A5b items 1 (a smooth body) and 5 (the crowd too), BODY_SOURCE mannequin: DONE.
  - The body (`tools/make_crew_mannequin.gd`): one step of Loop subdivision when it is baked, 13.7k triangles to 32.8k (2.4 times: the 7.4k
    of the balls at the fingers' joints are round already and stay as they are; the rest four times), the rims of the soles and of the
    fingertips' ends creased, every new vertex's weights blended by the same masks and cut to its four heaviest bones (the sums are one to
    5e-5 after the import's compression), the normals smooth across the rest and across the source's two materials: 3.0 % of the edges
    bend more than 30 degrees, against 14 % on the source; the soles stay on the ground (1.1 mm). A sliver at the nape (four triangles on
    one edge) needed masks that add a point named twice. The asset grows from 0.72 MB to 1.39 MB. `CrewBody.suit_mesh` takes the baked
    normals (its averaging would have undone the creases). The suit's regions stay where they were: gloves from 0.737 m out (0.743 on the
    source), the head from 1.497 m up (1.496), boots up to 0.170 m (0.138: a new ring that `BOOT_TOP`'s blend reaches), the stripes' rules
    unchanged; the head fills its helmet to 91 % at the tightest; the own head still folds away (tested as before).
  - From the other seat most of the facets were the harness: flat webbing folded at each of its points in the suit's colour (with
    `route_test --hide=Harness` the rounded body read smooth). Its straps now bend over the body (a curve through their points, four
    pieces between two, shaded smooth along them).
  - The crowd (`SpectatorClothes`, pure, tested; `Spectators.body_mesh`): each piece stands off the body by its cloth and hangs round its
    limb's axis from where the limb is widest, then is smoothed where it folded over the mannequin's grooves, its edges kept. Measured on
    the baked body: a shirt 1.5 cm off the chest, 3.5 cm at the waist's sides (2.2 at the chest's), its hem 2.8 cm off the body over the
    trousers' 1.4; trousers 2.6 cm off the ankles, loose from the calf; short and long sleeves per person (a long one put on in the
    shader), the hem, the collar and a short sleeve's end cut straight across the triangles. Arms an ordinary man's (0.82 and 0.92 of
    the mannequin's girth) resting by the sides (the wrists 2.3 cm further out than the shoulders: `STAND_OUT` 9 to 3 degrees, the
    shader's rest 4 to 1.5), the palms to the thighs, the fingers relaxed; hair off the scalp, the hairline lower at the temples. The face
    is shaped (a nose 1.5 cm out, brows over sunken eyes, lips, a chin) and painted to read at 10 m: dark hollows round the eyes with their
    whites and irises, brows, the shadow under the nose, lips, a short beard on three in ten.
  - Levels of detail, regenerated: 32.8k triangles, 16.4k within 2 mm, 4.1k within 9 mm, 1.0k within 31 mm; a place of eight at 10 m and
    at 40 m differs from full detail in 0.44 % and 0.78 % of its pixels (by more than 24/255), checked by eye. The bake takes 0.1-0.26 s once
    a session (it was 0.04 s); a stage still builds in 2.9-3.0 s.
  - Cost (Medium, Black Pine, three crews, `tools\perf.ps1 -Seconds 60 -ExtraArgs "--follower=14+28,--flip-..."`, inside one run, twice;
    another project's Godot running): before, the same day, the crews 0.66 / 0.61 ms (before the draw 0.27 / 0.28), the crowd 0.21 / 0.22
    (0.03 / 0.03); after, the crews 0.70 / 0.57 (0.26 / 0.26), the crowd 0.08 / 0.09 (0.02 / 0.03). Skinning twice the vertices costs
    nothing that can be measured.
  - Looked at (`reports/screenshots/a5b_body/`, High, 1600 x 900; `ba/` puts before and after side by side): the partner from both seats,
    with the map open, the driver's hands on the wheel, the crew through both side windows, the interior mirror, the crowd from the grid
    (11 m) and from the roadside (3-5 m), a place of eight at 4.5, 10 and 40 m with and without its levels of detail.
  - Known and left: the suit (item 2: a glossy red, the mannequin's seams at the shoulders and elbows), the gloves' palms (item 3) and the
    helmet (item 4) are as A5 left them; the harness is in the suit's colour (item 2's to choose); on a long sleeve the shoulders stay
    broad; the crotch's V shows faintly on light trousers; close up the collar's edge wanders by a few millimetres.
  Verified: 542 GUT tests (26994 asserts), `tools\flowtest.ps1 -Clients 1` (2:11.1 / 2:17.5, 16.9 / 16.1 m/s), no script or shader
  error in their logs (the Jolt notice that its job queue was full, once, as in A5).

- 2026-11-13: A5b items 2 (a race suit) and 3 (gloves and boots): DONE.
  - The cut (`CrewSuit`, pure, tested; `CrewBody.race_suit`, 0.1 s once a session): round each limb's axis and the body's the cloth lies on a
    taut line between what stands out (a sleeve over the elbow's groove, a leg over the knee's, the body over its blocks), evened out, 4 mm off
    the body; the body's cloth rises to meet a limb's ball. What crease is left round a shoulder and a hip gets a seam sewn along it
    (`CrewSuit.meeting`: how far each vertex lies outside the other piece's surface). The stripes move with the cloth (their coordinate shifted
    by how far each vertex moved front to back: before, they widened at the knee).
  - The shader (`shaders/crew_suit.gdshader`, one surface and one draw call a body as before) places everything where each vertex lies on the
    standing suit (CUSTOM0): fabric matte (wrap lighting, rim sheen 0.3), a plain weave and the knit's ribs, each fading out before they
    shimmer (as the seats' mesh fabric), folds that gather at the elbows, the knees and the waist, panels a darker shade (0.36 of the team
    colour) down the sides, the legs' outsides and under the arms, ribbed stretch panels (0.5) over the shoulders (round the joint, which
    keeps the shoulder's crease inside the panel) and the knees, a collar, the zip's cover, every seam a groove with a line of stitches either
    side. Flag patch on the upper left sleeve, 69 x 46 mm, `TurkishFlag.texture()`, the hoist to the front, a wound border; the stripe passes
    under it. The name: `LiveryRules.seat_name` (the seat's player's, as the livery letters it) -> `CrewBody.wear_name` -> `CarLivery.name_picture`
    (576 x 96, the HUD's font), 72 x 12 mm on the right of the chest beside the shoulder strap, raised satin thread, white on red and blue, black
    on yellow. Gloves: the backs in the suit's colour with the stripe (a finger's back by where a vertex lies on its piece: by the normal the
    round end of each piece was palm-coloured and the fingers read as a doll's), a charcoal suede palm, a black ribbed cuff stitched on.
    Boots: black leather, a rubber sole wrapping the heel, the welt stitched, a toe cap, laces, a suede ankle, the team colour on the heel tab.
    The harness's webbing black (`CarRallyKit.HARNESS`), loose ones on empty seats too.
  - Looked at (`reports/screenshots/a5b_suit/`: `s7_tpose`, `s6_car`, `game_day`, `game_more`; High): the T-pose close up (patch, name,
    shoulders, elbows, knees, gloves, boots, collar), both seats in the real car by day, at dusk, at night under the dome lamp, red, blue and
    yellow, from outside, the interior mirror, from a car 14 m behind.
  - Cost (Medium, Black Pine, three crews, `tools\perf.ps1 -Seconds 40 -ExtraArgs "--follower=14+28,--flip-crew=0.5"`, twice): 0.74 / 1.16 ms
    (median 1.04 / 1.14, before the draw 0.33 / 0.35), against 0.70 / 0.57 after item 1.
  - Known and left: the mannequin's shoulder still shows as a rounded lump from the partner's seat (inside the stretch panel, its crease a
    seam); the name is small (12 mm letters) and seen at a slant from the other seat. For the helmet (item 4): `CrewBody.name_picture` (an
    ImageTexture, null with no name) or `CarLivery.name_picture(lettered)` gives the same name; the helmet is untouched.
  Verified: 548 GUT tests (27035 asserts), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1` (2:11.2 / 2:17.5,
  16.9 / 16.1 m/s), no script or shader error in their logs; the T-pose close-ups shot again on the commit (`r6_tpose`).

- 2026-11-13: A5b item 4 (a real rally helmet): DONE.
  - Open face, no peak, no visor: most rally crews' helmet, the boom microphone shows in front of the mouth, nothing hangs into the cage
    overhead; a full-face helmet's chin bar would hide the microphone and its visor would need a second, transparent draw call.
    `CrewHelmet.mesh()` (one surface, 29k triangles, 0.3 s once a session): the shell an egg taller than wide (`shell_point`), cut out of a
    3 x 2.5 degree grid where its edges cross (`presence`: the lower edge, the face opening closing in on the jaw; each grid triangle clipped,
    the crossing found on the shell), a rubber trim and the liner and cheek pads under every edge, ear cup bulges, two intakes and two
    exhausts, the HANS posts, an intercom boom from the left cheek to 1.4 cm before the lips with its cable, a chin strap. The face: a black
    balaclava (a height field fitted to the mannequin's face, the shapes under the fabric) with a slot for the eyes; the shader paints the skin,
    the eyes (iris, pupil, lashes, the lid's shade, wet enough to glint) and the knit.
  - Skinned (`CrewHelmet.skin`): the tethers and the cable end on the hips, which hold still as the HANS collar does; the collar
    (`CrewBody._hans`, `CarRallyKit.band`) is a carbon band from the chest over the shoulders standing up behind the neck to the clips.
  - The shader: team colour under a coat whose mirror sees only the windows (the roof, doors and seat leave the cabin's dark sheen), its glint
    the lamps' capped at the sun's (`lamp_cap`); a white stripe between black lines, a darker band along the lower edge, the flag of Turkey
    (white border) and the seat's player's name (`CrewBody.name_picture`) on both flanks, read from the left.
  - The head stops where the helmet meets the seat (measured against the seat's own cross-sections and the cage's tube lines at every
    combination of the look, the swing and a faint): up 12 degrees looking ahead, 0 from 60 degrees aside (`CrewRig.HEAD_LIMITS`,
    `HEAD_UP_ASIDE`; the camera still looks up 30), the swing 9 degrees to a side, 4 aside, back only as far as the look leaves room
    (`SWAY_SIDE`); the shell 0.118 wide, 0.139 behind (half sizes), the head inside with 4.6 mm at the tightest. At the extremes the helmet keeps
    3.0 mm off the seat and 19 mm off the cage's padding (`test_crew_helmet.gd`), more than 30 mm off the harness and the HANS (measured once).
  - Looked at (`reports/screenshots/a5b_helmet/`: `h4_car`, `f1`, `n1` night with the dome lamp, `k1` dusk, `t2` blue, `t3` yellow at golden
    hour, `game_day`, `game_more`; High): both seats close up and from the other seat, from outside through both side windows and the
    windshield, the interior mirror (the own helmet in it), turned and fainted heads, a crew from the car 7 m behind (the seats' head
    restraints hide most of the helmets from there, as in a real car).
  - Cost (Medium, Black Pine, three crews, `tools\perf.ps1 -Seconds 40 -ExtraArgs "--follower=14+28,--flip-crew=0.5"`, twice): 0.85 / 1.25 ms
    (median 0.80 / 1.03, before the draw 0.30 / 0.34), against 0.74 / 1.16 with the old helmet: nothing measurable.
  - Known and left: the balaclava's face is a fitted height field, not a sculpted head; from 7 m behind a rival's helmets hide behind the
    seats.
  Verified: 551 GUT tests, `tools\nettest.ps1` (3 clients), no script or shader error in their logs.

- 2026-11-16: A5b items 7 (the night glare) and 6 (the final look), the cost and the record: DONE. Phase A5b is complete.
  - In the hot band of the beams straw bales, concrete blocks and barriers and the boards burned to white flares with halos. They take the
    lamp cap the flags and rails have (`shaders/lamp_cap.gdshaderinc`, its parameters now `surface_*`): the bale has a straw shader of its own
    (`shaders/straw.gdshader`, rain and snow on it like the plants), the blocks and barriers are `weathered` scans like the rocks, the boards
    keep their reflective glow under the cap (3cab375). Night, before and after (`reports/screenshots/a5b_night/before`, `after1`; Black Pine's
    start, Eagle's Nest 438 m, Red Canyon 584 m): the whole frame differs by a mean of 0.0041 / 0.0039 / 0.0013, all of it where the halos stood
    (2.3 / 1.5 / 0.7 % of the pixels by more than 8/255): a grey block, straw, a chevron's board, the road beyond them as before. By day and at
    golden hour the same pictures (a mean of 0.00004-0.00006, 0.02-0.04 % of the pixels by more than 8/255; Eagle's Nest none).
  - Every lamp of the car glows through the model's own picture of it (`shaders/car_lamp.gdshader`, A4's flat `HEAD_GLOW` plates gone): the
    chrome reflector and the flutes glow, the housing stays dark, the headlight's projector lens is a hot core (`HEAD_LENS`), and the glass
    glows less seen from the side.
  - A car ahead in a follower's beams was a white blob with a halo: its skins (`car_body.gdshader`: paint, livery, trim, tyres) take the lamp
    cap and the clear coat's glint is the engine's own under it; the helmet's coat glints only as much as each light allows (the dials' glow
    left an orange speck on its flank) (e5a06a3).
  - The crowd from the final look (e5a06a3, c857ba0): the ball the arm turns in at the shoulder slimmer and pressed down (`BALL_SLIM`,
    `BALL_TOP`), long sleeves narrowing faster below the shoulder, trouser legs hung from the top of the thigh and their seat following the
    pelvis (hung from the belly it stood 1.7 cm out over the groin like a pair of briefs, now 0.5, tested), the collar's round drawn to the
    pixel (it wandered across the triangles round the neck), the throat never the collar (a patch of the shirt's colour under the chin).
  - Looked at (`reports/screenshots/a5b_look/`, High): both seats close up by day, at dusk and at night with the dome lamp off and on (`crew`,
    `crew2`, `r4_crew`), red, blue and yellow, from outside through the side window, the interior mirror, a rival crew from a following car by
    day, at dusk and at night (`outside`, `outside2`), the crowd from the grid and as a car passes, by day, at dusk, at night in the beams and
    in snow (`crowd`, `crowd2`, `final_crowd`, `final_night`, `people`), the real race from the main menu (`final/race_1300`: `--flow-test`).
  - Cost (Medium, Black Pine, three crews, `tools\perf.ps1 -ExtraArgs "--follower=14+28,--flip-..."`, inside one run, twice): the crews 1.07 /
    1.20 ms (median 0.85 / 0.84, before the draw 0.37 / 0.36) against A5's 0.66 / 0.61 (0.27 / 0.28): the part that holds still run to run
    grew by 0.1 ms, the whole by 0.4-0.6 (it wanders by 0.3 and more); the crowd at the start -0.10 / 0.29 (median 0.42 / 0.42), held in view
    (`--view=22+1+1.7`) -0.01 / 0.30 (median 0.02 / 0.09), before the draw 0.01-0.03, against A5's 0.21 / 0.22.
  - Known and left: a spectator's short sleeves stand out like caps over the shoulders and a long sleeve's upper arm is broad close up (the
    mannequin's ball joint; slimming the ball further changed nothing that shows); a faint V at the crotch on light trousers and the
    neckline's edge ragged by a few millimetres closer than 4 m; from the grid at 8-11 m they read as shirts and trousers. The crew and the
    crowd stay the mannequin until the owner approves a free character model.
  Verified: 555 GUT tests (29455 asserts, 165 s), `tools\nettest.ps1` (3 clients), `tools\flowtest.ps1 -Clients 1` (2:11.1 / 2:17.5,
  16.9 / 16.1 m/s over 2218 m), no script or shader error in their logs.
- 2026-11-16: A5b's review (player, bugs, spec) and its fixes: DONE.
  - Fairness: the first crew body of a session made the suit (about 0.2 s) and the helmet (about 0.3 s) inside the spawn RPC, so a client
    handled the countdown half a second after the host. `RaceSession._ready` bakes them (`CrewBody.bake`, `CarRallyKit.kit_mesh`) before
    `Net.report_race_loaded()`; a seat then costs about 5 ms (test_crew_body pins that the seat wears the baked meshes). nettest's logs (the
    spawn's time, the countdown and the go on the PC's clock): the first car's spawn 102-113 ms on every peer (the car's own first-time
    work, as before A5b), the second 45 ms; the clients' countdown 35-37 ms and their go 66-71 ms after the host's. What is left (the first
    car's 0.1 s and the poll) belongs to A8's start (a start time from the host's clock instead of a countdown on each peer).
  - The gloves read as the mannequin's jointed fingers with a red cap on each piece (the upper half of every finger was the glove's back):
    the fingers and the palm are dark suede all round with less sheen, the back of the hand in the suit's colour to the knuckles with the
    sleeve's stripe, its edge a stitched seam (`CrewSuit.finger_backs` gone). From the own seat on the wheel, a gesture from the driver's seat
    and the driver from the partner's seat, before and after in one sheet: black race gloves, the segments hidden, a gesture still reads by
    the coloured back.
  - The name picture cut the marks over the capitals' dots and breve by 5-7 px of 96: a line's box takes in the marks of `CarLivery.MARKED`
    (`_with_marks`), every name the same size (tested: no ink in the top or bottom row, a dotted and an undotted I the same height).
  - The "hole" at the own neck looking down was the harness's chrome buckle mirroring the sky between the shoulder straps: the buckle is black
    anodised (`CarRallyKit.ANODISED`); no sky-blue pixel left from either seat.
  - The model's number plates (white, glossy) burned to a flare with a halo in a follower's beams at night: `shaders/number_plate.gdshader`
    under the lamp cap (`CarModel.plate_material`, tested).
  - The shoulder's dark knit cap read as a pad from the partner's seat: the stretch panel lies behind the joint only (over the shoulder
    blade); the shoulder's rounded shape stays (the mannequin's ball, TEST_PLAN).
  - The helmet decision recorded (GAME_DESIGN section 7, the brief's item 4 corrected): open face, boom microphone, no visor, no chin bar.
  - The lamp-cap tests still read the shader's source for its `lamp_capped_light(` call: a test of what it does needs a light rendered,
    and headless GUT renders nothing.
- 2026-11-16: A5b's final check: DONE. GUT 557/557 (29837 asserts, 152 s), nettest passed (3 clients; the first spawn 101-102 ms, the second
  42-43 ms on every peer; the clients' countdown 24-31 ms and their go 74-82 ms after the host's), flowtest -Stage 2 passed (2:05.0 / 2:15.2,
  the client's go 78 ms after the host's), no script or shader error in any log. Seen in three sheets (both seats by day and under the dome
  lamp at night, the own hands on the wheel by day and night, a rival from a follower at night, the crowd from the grid): no white blob, the
  rival's plate reads under the beams. Left as it is: from the own seat the coloured back of the glove ends in a ragged edge short of the
  knuckles (TEST_PLAN's gloves row judges it).
  - The suit and the helmet carry levels of detail (`CrewBody.thinned`, as the crowd's body): the suit 32.8k triangles, 16.4k within 3.6 mm,
    4.1k within 10.6 mm; the helmet 29.1k, 7.3k within 3.1 mm, 1.8k within 77 mm. The bake now takes about 0.55 s, behind the loading.
  - Cost (Medium, Black Pine, three crews, `tools\perf.ps1 -ExtraArgs "--follower=14+28,--flip-crew=0.5"`, twice): 0.89 / 0.64 ms (median
    0.91 / 0.66, before the draw 0.31 / 0.30), against the phase's 1.07 / 1.20 (0.85 / 0.84, 0.37 / 0.36) and A5's 0.66 / 0.61: within
    what the measure wanders by, the crews cost about what A5's did plus 0.1-0.3 ms.
  Verified: 557 GUT tests (29837 asserts, 297 s on a loaded PC), `tools\nettest.ps1` (3 clients; on the loaded PC the first spawn 260-269 ms
  and the second 123-128 on every peer alike, the clients' go 79-94 ms after the host's), `tools\flowtest.ps1 -Clients 1 -Stage 2` (2:05.0 /
  2:15.2, 18.5 / 17.1 m/s over 2316 m; the client's go 77 ms after the host's); a body built after the bake 5.0-5.1 ms, a car's first entry
  61 ms, as before the LODs, inside one process; no script or shader error in their logs.
- 2026-11-16: A5b's leftover, gestures that read at night (done during A9a): DONE. At night without the dome lamp a raised sign's suede fingers
  were black on black. The back of every finger and of the thumb is one panel in the suit's colour from the knuckle to the tip
  (`CrewSuit.finger_back`: which way a vertex lies from its bone's line or faces, the more; the thumb's root on the palm's piece too), the palm's
  side suede, the seam's stitches along each finger's side; the glove's cloth spans the pinches of the mannequin's beaded fingers
  (`CrewSuit.fill_fingers`: the line drawn taut over them, 0.6 mm under it a crease at each joint), or the coloured fingers read as a string of
  beads. The dials' glow needed nothing more. Seen in two sheets (the four signs of each seat from the other at night, before and after; the
  own hands on the wheel by day and at night): every sign reads, no cap per piece, no dark ring at a joint; from the own seat
  the coloured back runs on over the fingers on the rim (the final check's ragged edge short of the knuckles is gone). GUT 560/560.
- 2026-11-17: M, the map page (points 1-5, 9, 10 of `docs/phases/m_map.md`): DONE. `MapSheet` (the page as data, once a race),
  `MapRules` (the three levels: Explore and Rally the highlighter, Redline none; the round numbers), `MapLandmarks` (from
  `RallyDressing.plan`), `MapPrint` (inks, fonts, symbols), `MapCanvas` rewritten (the page in its own viewport printed only on change,
  layers, legend, title block with the flag, scale bar, north arrow, stamp), `RouteGraph.roads()` (every road for the map, a bypass
  is one more entry), shaders `map_land`, `map_stamp`, `paper_map`. Decided: no MSDF fonts (the variable fonts' overlaps broke them:
  the page is oversampled at the zoom instead); the land's heights before the road was pressed in; the stamp, flag and legend in the
  margins, the legend left of the corner the thumb holds. Measured: an open map 0.05 ms GPU / 0.03-0.04 ms CPU (VIEWPORT map), the frame
  0.15-0.25 ms cheaper with it up (`--flip-map`, Low/Medium/High, two runs each, another project's two Godot processes beside it); the
  sheet made in 0.1-0.3 s at load. Verified: 21 map tests (each level's contents, page round trip, every wrong way on its world line at
  its width, km ticks/gates/hazards at their places, nothing printed over anything on any stage at Rally and Redline, the scale bar,
  north on a turned sheet), full GUT 573/573, nettest and flow test pass; shots in `reports/screenshots/m_map/`. Left for the next parts:
  the road book, trip meter and following view (points 6-8), the audit.
- 2026-11-17: A9a, item 1, where a frame goes: DONE (measured; nothing cut but the probe's own fault).
  - The first finding was the probe's: it set vsync off on every frame, which rebuilt the swap chain each time (about 10 ms a frame) and left
    the renderer's GPU stamps at 0. Every older number from `tools\perf.ps1` (30-37 fps on Medium, the 8.5-12 ms "floor", Vulkan's 17 fps) was
    that. The game itself sets vsync once, when the settings apply. The NVIDIA RTX 5070 Laptop renders (discrete, D3D12 12_0; the game's log and
    the probe's `ADAPTER` line say so), so Auto picks High on this PC. No hidden cap: `Engine.max_fps` 0, the panel 60 Hz.
  - The floor (`--scene=look_test`: an empty stage with the race's sky, light and post, Medium, vsync off): windowed 575-665 fps (GPU 1.15 ms),
    fullscreen 615-625 (1.5 ms), exclusive fullscreen 670-715 (1.3 ms); Vulkan windowed 740-750 (1.0 ms). The present path of the hybrid
    laptop costs a few tenths of a millisecond at most. Vulkan now runs Black Pine as D3D12 does (69-83 fps on Medium): D3D12 stays pinned.
  - Baselines, Black Pine, three crews (`-ExtraArgs "--follower=14+28"`), the bot driving, 1080p, twice each (the second time beside another
    project's headless test run, CPU only; the first beside whatever the owner ran then):

    | Level | fps avg | p95 / p99 ms | over 33 ms | draw calls | primitives | work / draw / GPU ms |
    |---|---|---|---|---|---|---|
    | Low | 131.7-140.3 | 8.4-9.0 / 9.3-9.8 | 0 | 683-808 | 2.5-2.8 M | 1.1 / 4.4-5.1 / 6.9-7.5 |
    | Medium | 77.1-79.6 | 14.0-14.6 / 14.3-15.0 | 0 | 870-910 | 3.1-3.2 M | 1.2 / 8.8-9.6 / 12.4-12.9 |
    | High | 60.0-60.6 | 18.0-18.6 / 18.6-18.9 | 0 | 1084-1157 | 4.3-4.5 M | 1.2 / 12.0-12.5 / 16.3-16.6 |
    | Medium, Red Canyon (desert) | 149.2-175.2 | 6.8-8.5 / 7.7-9.7 | 0 | 618-656 | 2.3-2.4 M | 1.2 / 3.4-3.8 / 4.4-5.3 |
    | Medium, Glacier Ridge (snow) | 124.6-147.4 | 8.2-11.2 / 9.5-13.2 | 0 | 672-674 | 2.7 M | 1.5 / 4.0-4.5 / 5.4-6.9 |

    The phase's targets already hold on this laptop (Medium 60, 75 if the floor allows, p99 under 20; High 45; Low 90). The frame is the
    GPU's: the main thread's own work is 1.2 ms and a physics tick 1.1-1.5 ms; the draw call waits on the GPU. Black Pine's main view on
    Medium: opaque pass 3.8-3.9 ms, depth pre-pass 3.5-3.7 (as dear as the opaque pass: the alpha-cut leaves are drawn in both), shadows
    1.8-1.9, transparent 0.8; on High 4.9 / 4.7 / 3.0 / 0.9. Viewports apart (`VIEWPORT`): the door mirror 0.9-1.3 ms GPU and 0.5 ms CPU a
    frame on Medium, the open map 0.17 ms GPU and 0.21 CPU, drawn every frame though it seldom changes.
  - What each thing costs (`--flip-<what>=0.5`, all of them in one run taking turns, two runs in opposite orders; ms of the frame it saves when
    hidden, each run; by day on Black Pine with three crews; under 0.3 ms is within what the measure wanders by):

    | Thing | Low | Medium | High |
    |---|---|---|---|
    | trees (crowns and trunks, by class) | 2.0 / 4.3 | 6.1 / 9.3 | 11.6 / 7.7 |
    | shadows (every light's) | 1.7 / 1.3 | 1.9 / 1.9 | 6.6 / 2.5 |
    | backdrop | 0.4 / 0.5 | 1.3 / 1.2 | 2.2 / 1.8 |
    | mirrors (a new picture) | 0.9 / 0.8 (median) | 1.0 / 1.8 | 1.2 / 2.2 |
    | SSR | off | 0.5 / 3.3 (median 0.4 / 2.3) | 0.5 / 0.6 |
    | AA (FXAA; SMAA; MSAA 2x + SMAA) | 0.1 / 0 | 0.3 / 0 | 1.0 / 0.5 |
    | glow | off | 0.5 / 0 | 0.7 / 0.3 |
    | low plants | 0.1 / 0.2 | 0.3 / 0.3 | 0.7 / 0.6 |
    | road fx | 0.5 / 0.3 | 0.2 / 0.6 | 0 / 0.6 |
    | crowd | 0.2 / 0.2 | 0.3 / 0.2 | 0.5 / 0 |
    | crews (work before the draw) | 0.1 / 1.7 (0.3) | 0 / 0.3 (0.3) | 0 / 0.5 (0.3-0.4) |
    | rocks, SSAO, HUD, kit, livery, tyre marks | 0 | 0 | 0-0.2 |

    At night (Medium): the cars' lamps 1.0 / 1.5, the light pods 0.35 / 0.6, shadows 0.4 / 0.5, the mirrors 0.8 / 1.6, the trees 6.8 / 7.6. In
    fog (Medium) the volumetric fog costs nothing measurable (0 / -0.1); the trees 6.9 / 8.5.
  - The game's own script work a frame (`--work-top=0.5`, Medium, two runs; the process step / a physics tick): `CrewRig` 0.25-0.44 (six
    bodies), `CarMirrors` 0.20 / 0.13, `CockpitCamera` 0.10-0.13, `CarCockpit` 0.12, `SpeedBlur` 0-0.10, `PaperMap` 0.04-0.08, `CarLamps`
    0.07 / 0.07, `Cabin` 0.04-0.22 / 0.08-0.14, `WindshieldGlass` 0.04, `CarAudio` 0.03 / 0.08-0.33; `CarRoadFx` 0.09, `CarDirt` 0.04-0.13 and
    `CarTyreMarks` 0.02-0.10 a tick. All of it together is about 1.2 ms: no script is worth a cut before the GPU's work.
  - The separate render thread (`--render-thread separate`, Medium, twice against the default): the same frame (67.0-85.1 fps against
    67.3-85.8), the GPU stamps unreadable from the main thread and an engine error about an empty image: not kept.
  - The cuts that should follow, ranked by gain (item 2): far trees as impostors or fewer crowns at range and the leaves out of the depth
    pre-pass (Medium 6-9 ms); tree LODs per level; shadow casters and splits on High (2.5-6.6 ms) and Medium (1.9); the backdrop as fewer, larger
    meshes (1.2-2.2); the mirror at half rate or a smaller picture (1-2); MSAA off on High (0.5-1.0); the map's picture drawn only when it changes
    (0.2 GPU + 0.2 CPU).
  Verified: `tools\perf.ps1` runs listed above (logs kept out of the repo), the floor in three window modes and in Vulkan; GUT unchanged.
- 2026-11-17: L, part 1, roads that fork (deliverables 1 and 2 of `docs/phases/l_levels.md`, every trap as a test): DONE.
  `RouteGraph.Bypass` (a `SideRoad`, like `Spur` now) with `along_of`, `followed_roads`, `path_through`, `edge_by_id`; the recipe key
  `bypass` (`StageBuilder._add_bypass`: straight out of each junction for `hold`, a cubic between); `RouteValidator._check_bypasses`;
  junction spacing and the side rule over every junction (`StageDesignRules.junctions_of`); the world (road, ditches closing at both ends,
  mouths at both ends, walls, the terrain's samples); the prices (`FarmGate` + `GateRules`, the ford's pool, `RoadBuilder._build_banks`,
  ruts); the notes ("Uzun yol solda!", "Kısayol solda: dere!", the rejoin as a junction call); the map (a road, the ford's water, the price's
  pictogram; `MapPrint` gate, rough, narrow); protocol 2 (the gate's two RPCs); `cabin_gate` (G). Black Pine: the decoys at 200 and 434 m
  went (one stood where the long way leaves, one inside its stretch), a long way left round the first jump (283 m for 156 m of stage, a T
  at both ends) and the field near the end (the road round it, 318 m) with a shortcut straight across that fords a creek (171 m); 2476 m;
  `StageCatalog.LAYOUT` 3.
  Every call site that walks the stage or thinks in a distance along it, decided:
  - follows two roads now: `RouteTracker` (the road the car is on, a change of road faded over 40 m), `RecoveryAnchor` (any followed road,
    facing its way), `RaceSession._measure_gaps` and so the stone chips' range (only cars on the same road, along it), the bots
    (`RaceSession`, `route_test`: `path_through` of a seeded choice, `set_slow_places` for the price), `PaceNotes` (mouth and rejoin calls),
    `MapSheet` (roads, ford, pictograms, ring danger), `StageDesignRules` (junctions, spectators clear of both ends), `RouteValidator`,
    `TerrainField` (side roads' ditches, base samples, `edge_by_id`), `RoadBuilder`, `TrackFeatures` (walls, the ford's water, the gate),
    `RallyDressing` (nothing standing in a bypass's mouth or rejoin), `RoadsideDresser` and `BiomeRules.apply_to_graph` (through
    `road_edges()`), `tools/list_stage_spots.gd` (mouth and rejoin spots).
  - unchanged, because they read `tracker.distance` (already `along_of`) or a car's place: `RaceSession.distance_of` and the standings,
    `HudStageBar`, `RaceResults.set_progress` (furthest), `PaperMap`'s marker (the car's position) and its inked progress (the stage's line up
    to the mapped distance: on a bypass the stretch it replaces fills in as the car goes), `Voice` (seat positions), `RaceProgress` (no gate
    in a bypassed stretch: the validator).
  - stage line only, nothing of them stands on a bypass: `Sightline`, `StageEventBuilder`, `GuardRail`, `RallyArch`, `Spectators`,
    `RallyDressing.plan` (boards, chevrons, tape), `tools/stage_shots.gd`, `tools/fx_probe.gd`.
  Measured, headless bot (`route_test --autodrive --bypasses=..`, Black Pine from the grid, clear, day; the same on Explore, Rally and
  Redline to a tenth of a second: the width offsets do not change the bot's line):

  | Way | Explore | Rally | Redline | Recoveries |
  |---|---|---|---|---|
  | the stage's own road | 149.8 s | 149.8 s | 149.8 s | 0 |
  | the long way round the jump | 164.0 s (+14.2) | 164.1 s | 164.1 s | 0 |
  | the shortcut, ford | 139.4 s (-10.4) | 139.5 s | 139.5 s | 0 |
  | the shortcut as a gate (rammed), rough, narrow (Rally) | | 136.3 / 137.9 / 137.2 s | | 0 |

  Tests: `test_bypasses.gd` (16: along_of, followed roads, the path, the validator's rules, each price, the notes, the map, the tracker
  continuous over every mouth and rejoin with the car driven along the line 1.2 m off it, recovery at twenty seeded places on and round the
  bypasses, stones, the bots' coin), `test_bypass_drive.gd` (a real car through both bypasses: 148 s, 0 recoveries, every gate in order, the
  tracker never back), `test_farm_gate.gd` (4), the map's truth test extended to the prices. GUT 595/595, nettest, flowtest (host on the
  stage 2:32.6, the client through both bypasses 2:42.5). Seen: every mouth and rejoin from the seat by day and at night, from above, each
  price, the map sheet (reports/screenshots/bypass, git-ignored).
  Decided: rough is ruts on the stage's own surface, not a new `Surface` (a new one needs scans, sounds, dust and a network slot); the
  gate is opened by a held key without a crew animation (the body's job poses are A6/H's); bots ram the gate; the long way stays as long
  as the junction rule leaves it (a shorter one ran beside the road); the side rule holds at a rejoin as at a mouth.
  Not done (later parts): the bypass's own corners are not called and its sightline is not measured; the long way's +14 s for a bot is
  for the redesign to weigh; deliverables 3-6 (the measures, gag slots, the signature place, the six stages) and Red Canyon's bypasses.
- 2026-11-17: L, part 2, the rules of a real rally road (deliverables 3, 4 and 5 of `docs/phases/l_levels.md`): DONE, no stage redesigned.
  `StageDesignRules`' second edition: `measures()` (turning per km and over the plainest km, straights between the notes' corners and how
  each ends, the severities, hairpins and square turns at a junction, linked sequences, corners that tighten or open, crests and jumps in
  or before a corner, the biggest climb and descent within 500 m, the longest stretch without a crest, jump, dip or water, bypasses, gag
  slots, the set piece, spectators, the longest stretch without a rhythm moment), `summary()` (one line, printed by
  `test_every_stage_meets_the_design_rules` and `tools/stage_measures.gd`, which also prints what the second edition still `WANTS`),
  `check_catalogue()` (a shortcut and a long way in each biome). A stage claims its edition in the catalogue (`rules`, all six 1 for now:
  `test_stage_builder.gd` `WAITING` lists them); the second edition's rules judge only a stage that claims 2. Recipe keys `tightens` /
  `opens` (the turn grows or eases, its total the same) and the notes' "kapanıyor" / "açılıyor", "tightens" / "opens"
  (`PaceNotes.corners`, last third against first, 1.5 times). Gag slots (`gag`: beside, across_slow, overhead) and the set piece
  (`signature`) as features the judges check whatever the edition (gates, junctions, surprises, a crest's blind side, cliffs and banks,
  room, in sight from the braking distance of the speed a crew carries there; the set piece's length, bend, approach, exit and what must not
  be in it). `TerrainField` flattens their room and lays no ditch through the set piece, `RallyDressing.clearings()` keeps them clear.
  `GagDirector` (pure): three or four of a twelve-gag catalogue (data, no looks) into the slots from the room's `gag_seed`
  (`RaceSettings.resolve`, new every race) and the stage's seed; `RaceSession.gags` on the `NET stage` line; `--gags=` in `route_test`
  and the race. Protocol 3 (the new setting).
  The baseline, today's six stages measured (`tools/stage_measures.gd`; first-edition stages, so none is judged by these yet):

  | Stage | Turning deg/km (plainest km) | Longest straight | Severities | Hairpins + square | Sequences | Tighten/open | Crests in corners | Climb / descent in 500 m | Flat gap | Bypasses | Rhythm gap |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | Black Pine | 570 (460) | 156 m | 1-6 | 4 | 6 | 1 | 4 | 14 / 8 m | 282 m | 2 (1 short, 1 long) | 488 m |
  | Misty Creek | 623 (533) | 92 m | 1-5 | 3 | 5 | 0 | 3 | 8 / 5 m | 326 m | 0 | 280 m |
  | Red Canyon | 368 (335) | 148 m | 2-6 | 0 | 0 | 0 | 0 | 8 / 9 m | 385 m | 0 | 445 m |
  | Scorpion Hills | 478 (402) | 150 m | 1-5 | 2 | 1 | 0 | 6 | 14 / 10 m | 275 m | 0 | 410 m |
  | Eagle Nest | 575 (468) | 116 m | 1-6 | 3 | 1 | 1 | 3 | 36 / 12 m | 616 m | 0 | 305 m |
  | Glacier Ridge | 452 (443) | 122 m | 1-6 | 1 | 1 | 0 | 3 | 8 / 13 m | 240 m | 0 | 317 m |
  | Second edition | >= 700 (500 desert), every km >= 300 | 250 m, one of 450 | 1-6 | >= 2 | >= 3 | >= 2 | >= 2 | >= 15 / 15 m | <= 400 m | 1-3 | <= 600 m |

  None of the six turns enough (Red Canyon least: 368 degrees a km, no hairpin, no linked corners); none climbs and descends 15 m within
  500 m; only Black Pine has bypasses; no stage has a gag slot or a set piece; the straights are already short (the first edition's
  sightline budget). Every stage keeps 2-3 places for spectators and danger gaps of 228-396 m.
  Tests: `test_stage_design_rules.gd` (12: every measure on a road whose answer is known, each rule, the slots, the set piece and its flat
  ground, the catalogue), `test_gag_director.gd` (4: kinds, none twice, stage order, the same on every peer, `--gags=`, the race's roll),
  `test_stage_builder.gd` (the summaries, the waiting list, the catalogue). GUT 612/612, nettest (the stage line with its gags).
  Seen: a set piece's ground tried on Black Pine (not committed): the forest stands back from it (reports/screenshots/sig, git-ignored).
  Decided: the measures and the second edition judge the stage's own road (a bypass's corners stay unmeasured, as in part 1); a slot's
  speed comes from the notes' corners (0.7 g in a corner, 2.5 m/s² out of it, 130 km/h at most) and its braking distance (0.5 s, 0.7 g);
  the set piece's ground is grass, not bare (until phase W builds on it, it reads as a meadow); a gag slot's room widens the flat band too.
  Not done: the six stages' redesign (part 3, the next agents), so no stage has a slot or a set piece yet and the second edition's numbers
  are untried at the wheel.
- 2026-11-17: L, part 3, Black Pine and Red Canyon redesigned (deliverable 6 for two stages, to the second edition): DONE; the other four
  stay at the first edition for a later run. Both claim `rules` 2, both judges are empty, `StageCatalog.LAYOUT` 4 (old times went).
  - Black Pine (forest, 2762 m): a left-right out of the start over a crest, the long way left round the first jump, then a long right that
    tightens into a left kink over a dip, the caution left at the barrier, a right that opens into the water splash and its crowd, a blind
    crest where a fir may fall, esses (left, right, left, right), the farm (a muddy yard, a right 1 round it, straight through the barn's
    ground, 50 m with 60 m in sight before it) and a climb of 19 m up the hill out of it, the second jump with its crowd, a fast descent
    of 20 m to the field, the ford shortcut straight across it, and the run to the finish. Four gag slots: beside on the outside of the
    tightening right (where a car that runs wide goes), across the road at the end of the esses (a flock or a tractor), beside on the
    descent after the jump, beside after the field.
  - Red Canyon (desert, 2826 m): the canyon's walls left then right on a left that tightens, a climb onto the rim with the drop on the
    left (a right 2 with the cliff outside), the biggest jump in the game, a left 2 that opens down off the rim, sand, the street of a
    hamlet (the set piece is a `village`: houses stand on flat ground beside a road, which is what this phase can reserve; a bridge would
    need a gorge under it, which flat ground is not), a long way right and inland round a left 3 along a drop and the second jump over the
    cliff's lip, the rockfall between walls on both sides, a left hairpin, a climb to a crest in a right, the flat-out (298 m over three
    yumps into a right hairpin, where the crowd stands), a slot canyon (the `narrow` shortcut, 171 m for 318 m) that cuts off the last loop,
    and a left hairpin under a wall. Five gag slots, one overhead after the hairpin. The desert pair's shortcut and long way are both
    here, so `check_catalogue` holds whatever Scorpion Hills gets.
  - Read call by call against the road (`PaceNotes.build`, Turkish): every corner, crest and junction lands where the road is; a rejoin
    once read "Kavşak: Sağ 4, sağa değil!" (a right 4 just past a bypass joining from the right, which nobody can call): the stage now runs
    100 m straight after the jump so the corner gets its own call ("Kavşak: Düz, sağa değil!", then "Sağ 4").
  - Found by the bot: Red Canyon's slot canyon first rejoined where the road ran on along a drop on its side; the rail stood across the
    bypass's end and the bot crashed into it three times. `RouteValidator._check_bypasses` now says "meets the road on the cliff's side"
    (a cliff on the side a bypass leaves or joins, within 60 m: `test_a_bypass_never_meets_the_road_on_a_cliff_s_side`); the road there
    now runs under a wall on the inside of its hairpin.

  | Stage | Length | Turning deg/km (plainest km) | Longest straight | Severities | Hairpins + square | Sequences | Tighten/open | Crests in corners | Climb / descent | Flat gap | Bypasses | Gag slots | Set piece | Spectators | Rhythm gap | Danger gap |
  |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
  | Black Pine before | 2476 m | 570 (460) | 156 m | 1-6 | 4 | 6 | 1 | 4 | 14 / 8 m | 282 m | 2 (1 short, 1 long) | 0 | 0 | 3 | 488 m | 306 m |
  | Black Pine after | 2762 m | 701 (615) | 124 m | 1-6 | 4 | 7 | 3 | 4 | 19 / 20 m | 355 m | 2 (1 short, 1 long) | 4 | barn | 3 | 431 m | 308 m |
  | Red Canyon before | 2316 m | 368 (335) | 148 m | 2-6 | 0 | 0 | 0 | 0 | 8 / 9 m | 385 m | 0 | 0 | 0 | 2 | 445 m | 308 m |
  | Red Canyon after | 2826 m | 572 (449) | 298 m (the flat-out, over a crest) | 1-6 | 4 | 5 | 3 | 3 | 17 / 19 m | 344 m | 2 (1 short, 1 long) | 5 | village | 2 | 522 m | 442 m |

  Measured, headless bot (`route_test --autodrive --bypasses=..`, from the grid, day; Explore, Rally and Redline the same to a tenth: the
  width offsets do not change the bot's line), 0 recoveries and every gate in order in every run:

  | Stage, way | Explore | Rally | Redline | Rain / dust storm (Rally) | Fog (Rally) |
  |---|---|---|---|---|---|
  | Black Pine, its own road | 171.6 s | 171.5 s | 171.5 s | rain 178.9 s | 171.5 s |
  | Black Pine, the long way round the jump | 186.0 s (+14.4) | 186.2 s | 186.1 s | | |
  | Black Pine, the ford shortcut | 161.1 s (-10.5) | 161.0 s | 161.0 s | | |
  | Black Pine, both bypasses | | | | rain 196.2 s | 175.8 s |
  | Red Canyon, its own road | 160.1 s | 160.2 s | 160.2 s | dust 160.2 s | 160.2 s |
  | Red Canyon, the long way round the cliff and jump | 174.3 s (+14.2) | 174.4 s | 174.4 s | | |
  | Red Canyon, the slot canyon (narrow) | 147.4 s (-12.7) | 147.4 s | 147.5 s | | |
  | Red Canyon, both bypasses | | | | dust 161.6 s | 161.6 s |

  The bot's average over the stage's length (what `StageRecords.MEDAL_SPEEDS` is judged on, the stage's own road): Black Pine 16.1 m/s,
  Red Canyon 17.6 m/s; the flow test's bots 15.9 and 15.0 m/s on Black Pine, 16.9 and 15.9 m/s on Red Canyon. Inside the 15-18.5 m/s the
  medal speeds were set from, so they stay (14 / 17.5 / 20.5): bronze for a clean bot on both, silver for it on Red Canyon only; gold
  needs a crew faster than the bot everywhere. Black Pine's turning costs it 1.5 m/s against Red Canyon.
  Flow tests: Black Pine (host on the stage 2:53.9, the client through both bypasses 3:03.9) and Red Canyon (2:46.8 / 2:57.7), both with
  `--bot-roll=153`, picked so on every stage with bypasses the host keeps to the stage and the client takes them all (19 sent Red Canyon's
  host onto a bypass; `test_bypasses.gd` checks the roll on every stage). Nettest passed. GUT 613/613 (`test_stage_builder.gd`'s
  `WAITING` lost both stages; `test_map_canvas.gd` takes whichever stage runs north-south, Black Pine no longer does).
  Seen (reports/screenshots/l_stages, git-ignored): the map sheets before and after (`sheet_maps.png`), every mouth and rejoin from the seat
  by day and at night (`sheet_junctions_day.png`, `sheet_junctions_night.png`), the slot canyon from its seat, the barn's and the hamlet's
  ground from above (`sheet_signature.png`: a meadow the forest stands back from, open desert with the rocks kept off).
  Decided: Red Canyon's long way keeps Black Pine's T shape (283 m for 156 m: every shorter shape tried ran beside the road or turned
  tighter than 11 m), so a long way costs a bot 14 s on both stages, the price of not jumping beside a drop; the medal speeds stay one set
  for every stage; the set piece's call in the notes waits for phase W (no barn stands there yet).
  Not done: the other four stages (a later run); the bypasses' own corners are still uncalled and their sightlines unmeasured; the bot
  drives into the end of the road after the finish at 17-26 m/s in `route_test` (Misty Creek, untouched, does the same: the dev scene's
  bot, not the race).
- 2026-11-17: L, the reviewers' findings on parts 1-3 fixed: DONE. `StageCatalog.LAYOUT` 5 (old times went again).
  - The forks were copies and no choice: both stages had the same T-shaped long way (283 m for 156, +14 s) and the same square field
    loop mirrored (four 90-degree corners, a straight shortcut at 54 %, -10.5 / -12.8 s). Now each is its own (`test_no_two_bypasses_are_alike`):
    Black Pine's long way leaves left round a right 2, the first jump and a square left off its landing (221 m for 190, 116 %); its field
    loop is a right, a dip, a left 1 caution, a crest and two lefts, the ford track running straight on (144 m for 260), its call 40 m
    clear of the caution left before it ("Sol 3! Dikkat" 2090, "Kısayol düz: dere!" 2130, "Sağ 2" 2168); Red Canyon's long
    way leaves right 56 m past the crest (its call no longer on the crest) and comes back inland round the jump on the cliff and a right
    that tightens off it (205 m for 170, 121 %), the stage running 78 m straight after the rejoin so the junction is "Düz, sağa değil";
    its narrow sunken lane forks right at 40 degrees off a left 2 (193 m for 290); its tail is its own. `RouteValidator.LONG_MOST` 1.4: a
    longer long way is a detour nobody takes (`test_a_long_way_is_a_choice_not_a_detour`). Found by searching every shape of each
    bypass's angles, holds, reaches and rejoins against both judges (a scratch harness), then timing the passing ones with the bot.
  - Bot (`route_test --autodrive`, day unless said, 0 recoveries, every gate, no hit of 8 m/s on the stage in any run):

    | Stage | Its road | Long way | Shortcut | Both: Explore | Both: Redline, rain / dust | Both: fog | Road: Redline rain |
    |---|---|---|---|---|---|---|---|
    | Black Pine | 175.5 s | 179.6 s (+4.1) | ford 171.5 s (-4.0) | 175.5 s | rain 178.2 s | 175.5 s | 176.3 s |
    | Red Canyon | 160.9 s | 166.2 s (+5.3) | narrow 156.2 s (-4.7) | 161.4 s | dust 161.6 s | 161.5 s | |

    Medal speeds stay: the bot averages 15.8 m/s on Black Pine and 17.6 m/s on Red Canyon over their own roads.
  - A straight shortcut was called by its side ("Kısayol solda" while the stage turned 90 degrees and the track ran on): a bypass within
    `PaceNotes.BYPASS_STRAIGHT` 20 degrees of the stage's heading 30 m in is "Kısayol düz: dere!" / "Shortcut straight: ford!".
  - Recovery put a car stuck in the open beside a shortcut onto the shortcut past its price (a shortcut's metre is worth 1.9 of the
    stage's): `RecoveryAnchor.find` takes `on_road` (the tracker's road) and lands only on the stage or that bypass.
  - The tracker changed road 6-8 times a run while a car drove the stage 1.5-3 m off centre beside a mouth (and the car behind it lost
    its stones): it now changes road only once the car is off its own road's surface and shoulders (`test_a_car_beside_a_mouth_stays_on_the_stage`).
  - The map's forest came from the dresser's canopy thinned by the graphics level (15 % of Black Pine's forest pixels differed between
    Low and High): the canopy meta is now placed at full density on every peer (what is thinned is never hard, so placing it again sees
    the same world); the ground's shade keeps the thinned one.
  - The north arrow stood over the scale bar's unit: the bar now keeps `MapSheet.SCALE_ROOM` (156 px) clear of it (tested per stage).
  - `Net.JOIN_VERSION` is the protocol and `StageCatalog.LAYOUT`: a build on other roads is refused as a version mismatch.
  - Red Canyon's narrow lane is a sunken lane between earth banks, as the seat shows: its description says so (no slot canyon).
  Checks: GUT 618/618, nettest passed, flow test on Black Pine passed (host on the stage 2:57.6, the client through both bypasses
  3:03.2; 15.7 and 15.2 m/s).
  Seen (reports/screenshots/l_fix): both map sheets, each bypass on them up close, the mouths and the ford and the lane from the seat.
  Not done: the bypasses' own corners are still uncalled.
  Final check (2026-11-17, HEAD b923599): GUT 618/618 (41336 asserts), nettest passed (3 clients), flow test on Black Pine passed
  (2:57.6 / 3:03.2, the client's bot through bypasses 0 and 1; 15.7 and 15.2 m/s), no SCRIPT ERROR or ERROR in any log.
- 2026-11-17: Phase F parts 1-2, the measuring kit (`docs/phases/f_feel_hud.md` Part 1 item 1). `tools/feel_probe.gd` (route_test
  `--feel=<script>[+..]|all`, `--feel-device=key|pad|wheel`, `--feel-assist`, `--feel-tag`) drives the car through `tools/feel_scripts.gd`'s
  twelve scripts (step, slalom, liftoff, trail, power, hairpin, catch, crash15/45/90, land, flick) on a flat gravel pad 6 km off the stage
  with a wall and a 0.8 m ledge (`tools/feel_run.gd`), and writes `reports/feel/<tag>/<script>.csv` (a row a tick: input, command, wheel
  angle, speed, yaw rate, slip, g, `RallyCar.assist_torque`, `tyre_yaw_moment`, wheels, impact) and `<script>.frames.csv` (a row a camera
  frame, `tools/feel_camera_log.gd`). Two files, not one: a tick and a frame are different clocks. Camera jerk: each frame's turn as a
  rotation vector scaled to a 60th of a second, its frame-to-frame change; frames where the free look moved count none (the ride is
  measured, not the hand); the probe and `--feel-log` run at 60 fps (two ticks a frame). `tools/plot_feel.gd` (Image only, the glyphs from
  the TextServer) and `tools/feel.ps1 [-Compare <tag>]` draw a sheet per script, two runs overlaid. `nettest` passes `--feel-log=0.5+12.5`
  and prints both seats' jerk.
  First numbers (kit_a, windowed, Medium, assist 1, raw axis): the flick turns 0.118 deg/px up to 150 px over three frames and stops at
  47.3 deg from 200 px on (the 120 px clip: 0.026 deg/px at 600 px); catch peaks at 20.7 deg slip, 77 deg/s yaw, 5547 N m of assist;
  crash45 spins the car to 145 deg/s; land is airborne 0.27 s. nettest (headless, 60 fps, GO+0.5 s to 12.5 s after the start, shake on):
  driver p99 0.515, client navigator 0.350 deg/frame^2 (median 0.126 / 0.111): the road buzz's noise is in both, so the baseline (part 3)
  also reads them with `camera_shake` 0.
  Checks: GUT 623/623 (`test_feel_scripts.gd`: every script headless but the flick, the jerk's maths), nettest passed.
- 2026-11-17: Phase F part 3, the **F baseline** (`docs/phases/f_feel_hud.md` Part 1 item 2), HEAD 3ad79fc with nothing changed in the
  game. The kit now also logs the camera's move jerk (its place's second difference, cm per frame^2 at 60 fps: a car played back in steps
  shows there first, in the straights too), the head's lean (`CockpitCamera.lean()`) and the road roughness a frame, `--feel-shake=S`
  (probe and net_test) sets the seat camera's shake (0: the ride alone), net_test `--feel-tag=T` writes each seat's frames to
  `reports/feel/<T>/<role>/seat.frames.csv`, and `plot_feel.gd` draws a frames-only run and four more panels. Runs: `feel.ps1 -Tag baseline`
  (all twelve scripts, raw axis, assist 1, windowed Medium), `-Tag baseline_pad -Device pad` and `baseline_key -Device key` (step, slalom),
  `baseline_a0 -Assist 0` (catch, hairpin), `nettest` (headless, shake on), and a windowed driver + client navigator on Black Pine (headless
  host, the bot circling, GO+1 s to 26 s; `baseline_net` shake on, `baseline_net_still` shake 0; the other project's two headless Godot
  runs beside it). Sheets: `reports/feel/baseline/plots/<script>.png`, the two seats in `plots/baseline_net*/seat.png` (driver blue,
  navigator orange; the two logs start at each peer's own GO, so the traces are not aligned in time).

    | Suspect (Part 1's traps) | Measure | Baseline | Sheet |
    |---|---|---|---|
    | Client navigator plays the car back in steps | camera jerk p99 turn / move, driver vs client navigator | headless nettest 0.419 / 0.635 vs 0.353 / 3.118 (0.84x / 4.9x); windowed shake on 0.401 / 0.587 vs 0.491 / 10.09 (1.23x / 17x); windowed shake 0 0.147 / 0.390 vs 0.987 / 15.88 (6.7x / 41x); the navigator's window drew 31-48 fps, frame p99 68 ms | baseline_net*/seat |
    | G lean on a copy reads `linear_velocity` | head lean, lateral g, median / max | driver 0.23-0.26 / 0.79-1.10 g, client navigator 0.04 / 0.24-0.26 g (a sixth) | baseline_net*/seat |
    | Roughness on a copy | `road_roughness()` mean / p99 | driver 0.42 / 0.97, navigator 0.23-0.30 / 0.53-0.56: no spike every fourth tick (the extras are interpolated), but the 30 Hz snapshots lose the wheels' faster travel: half the buzz at its peaks | baseline_net*/seat |
    | Mouse clip at 120 px an event | head turn for 3 frames of N px | 0.118 deg/px to 100 px, 47.34 deg for every flick of 200-600 px (0.026 deg/px at 600) | flick |
    | Counter-steer capped at speed | catch: slip 20 deg at 100 km/h, full counter-steer | assist 1: caught but overshoots to -15.4 deg 1 s later (wheels 13.6 deg at most); assist 0: lost, slip grows to 38.7 deg, 30.6 deg and 48 km/h at the end (wheels 19.1 deg at most) | catch (baseline, baseline_a0) |
    | Two steering filters | input to 90 % of the command / of the road wheels, half lock at 44 / 72 / 100 km/h | raw axis 0 ms / 83, 67, 42 ms (the car's own rate limit); pad 100 ms / 83, 100, 183 ms; keyboard (full lock) 167, 217, 300 ms to the command | step (baseline, _pad, _key) |
    | Assist an invisible hand | peak torque, ticks acting, its share of the tyres' yaw moment (median / max), largest change in a tick | slalom 3764 N m, 41 %, 0.43 / 4.3; liftoff 3149, 12 %, 2.9 / 3.5; hairpin 4970, 26 %, 2.9 / 4.3; catch 5547, 36 %, 0.57 / 4.7; every script goes from 0 to its peak in one tick | step ... catch |
    | Tyres numb | yaw per metre in the 0.5 s after the change against the 0.5 s before | lift-off -15 %, trail braking 1.54 deg/m braking vs 1.52 after (-2 %), full power mid-corner -8 %: every one turns the car less, never more | liftoff, trail, power |
    | Gearbox only heard | the drive force (code) | `engine_force * (1 - t^2)`, the same at every rpm; a shift cuts nothing (`Gearbox` is audio and dash) | step (speed) |
    | Head looks where the wheels point | catch: travel direction minus the corner look | assist 0: the head turns toward the travel but trails it by 24 deg (mean, 28.5 max); assist 1: -9 deg mean, -23 max. Not away from it, as the brief guessed: behind it | catch |
    | Cabin FOV breathes | FOV range | 62.0 to 69.9 deg at 100 km/h (8 deg of the 11) | step |
    | Keys all or nothing | (code) | throttle and brake 0 or 1; holding the brake under 1 m/s reverses at once | |
    | Hits | crash at 60 km/h into a flat wall: impact, bounce back, speed 0.5 s after, yaw | 15 deg: 3.9 m/s, no bounce, 46 km/h on, 57 deg/s; 45 deg: 16.0 m/s, stops dead (0.6 km/h), spins at 145 deg/s; 90 deg: 17.4 m/s, 1 % bounce, 0.1 km/h: it sticks to the wall | crash15/45/90 |
    | Landing (A2's drop) | airborne, the driver's camera jerk p99 turn / move | 0.27 s in the air, 0.45 / 0.79 | land |

  A2's benchmarks, rerun today unchanged (`test_handling_benchmarks.gd`): 0-100 km/h 5.36 s, 100-0 km/h 48.0 m (0.82 g), half lock at
  70 km/h answers in 0.10 s and settles at 25.7 deg/s and 0.92 g, keyboard to full lock 0.21 s at 20 km/h, 0.20 s at 50, 0.33 s at 100
  (lock 27.6, 21.1, 10.3 deg), handbrake hairpin 150 deg in 2.97 s, full lock from a standstill 170 deg in 5.3-6.1 s, the 0.8 m drop
  lands at 2.70 s with 5.4 deg of pitch.
  What the numbers say is worst for a player, worst first:
  1. A client navigator's view stutters: its camera's place jerks 5x (headless) to 17-41x (windowed) the driver's, its turn 6.7x with the
     shake off. Half the players see it all race (part 4).
  2. A client navigator's head neither leans nor feels the road: a sixth of the driver's lean, half the buzz at its peaks (part 5).
  3. With the assist off a fast slide cannot be caught, whatever the hands do (part 6); with it on the catch overshoots into the other
     slide.
  4. The assist steers the car: up to three times the tyres' own yaw moment, full strength in one tick (part 7).
  5. Lift-off, trail braking and power never rotate the car; each turns it less (parts 8-9).
  6. A pad reaches the road wheels in 83-183 ms, 10-22 ticks against GAME_DESIGN §9's one (part 6).
  7. A quick mouse look turns 47 deg however far the hand flicks (part 5).
  8. A car that hits a wall stops dead against it or spins at 145 deg/s (part 10).
  9. The cabin breathes 8 deg of FOV with speed; the head trails a slide's travel by 24 deg (part 10).
  10. Shifts and pedals: no shift is felt in the car, keys are on or off, the brake reverses at once (parts 9-10).
- 2026-11-17: Phase F parts 4-5, the invisible bugs fixed (Part 1 item 3), no tuning changed.
  - The playback clock: `SnapshotBuffer.playback(delta, local_ms, delay)` moves on by each physics tick's delta, pulled toward the wall clock
    minus the 100 ms delay at 4/s and at most a quarter faster or slower, stepped only after a stall of more than 250 ms; `BodyNetSync`
    plays every copy on it. A snapshot carries the sender's physics tick (`Engine.get_physics_frames()`), not whole milliseconds of the wall
    clock: a slow frame's two snapshots shared one (the later dropped as a duplicate) and 33/34 ms wobbled the copy (its median move jerk
    was twice the driver's). The place and the turn run on Hermite curves through the snapshots' velocities and spins (straight pieces
    turned every 33 ms). A first cut that pulled at 2/s within a tenth fell behind a navigator window drawing 13-15 fps and caught up in a
    step every few seconds (85-135 cm move jerks); a test now holds 13 fps.
  - `CockpitCamera` reads `RallyCar.seen_velocity()`: a copy moved by transform once in three ticks leaned 0.03 g in a 1 g turn, now 1.00
    (`test_cockpit_camera.gd`, which fails on the old line). The roughness needed no code of its own: on the playback clock each tick's
    change of the interpolated compressions is the change over its snapshot interval; measured on the copy 0.39-0.44 mean, p99 0.97-0.98,
    against the driver's 0.41-0.46 and 0.97 (0.23-0.30 and 0.53-0.56 before).
  - The mouse: the 120 px cap (`CAPTURE_JUMP`) holds only the first motion after the mouse is captured. Flicks of 3 frames now turn the
    head 0.118 deg/px a frame at every size (200 px 71.0 deg, before 47.3; 600 px 71.0 deg a frame up to the seat's 100 deg), and ten
    400 px motions each turn it four times a 100 px one (`test_cockpit_camera.gd`).

    | Camera jerk p99, turn / move (deg, cm per frame^2) | Driver before | Client navigator before | Driver after | Client navigator after | Navigator / driver after |
    |---|---|---|---|---|---|
    | nettest, headless, 60 fps, shake on | 0.419 / 0.635 | 0.353 / 3.118 | 0.440 / 0.629 | 0.507 / 0.677 | 1.15x / 1.08x |
    | windowed, shake on | 0.401 / 0.587 | 0.491 / 10.09 | 0.403 / 0.709 | 0.377 / 1.015 | 0.94x / 1.43x |
    | windowed, shake 0 (the ride alone) | 0.147 / 0.390 | 0.987 / 15.88 | 0.207 / 0.585 | 0.218 / 1.223 | 1.05x / 2.1x |

  The gate holds: a client navigator's p99 camera jerk is within 1.5x the driver's in every run (it was 6.7x with the shake off). The move
  jerk with the shake off is still 2.1x the driver's (median 0.29 against 0.20 cm): left as it is, for A8's buffer work to look at.
  Windowed runs: driver and client navigator at High on one GPU (45-60 fps each, frames to 38 ms at p99), a headless host, the bot
  circling on Black Pine, GO+1 s to 26 s; beside them the other project's two headless test runs and a windowed screenshot run. One
  more windowed run is not counted: the driver's own game crawled (2 s of race in 5.5 s of wall clock) and its copy with it.
  Checks: GUT 632/632, nettest passed (3 clients) at every step with the 100 ms delay and its RPCs as they were (the snapshot's first
  argument is now a tick, still an int), flow test on Black Pine passed (2:57.6 / 3:03.1, the client's bot through both bypasses;
  15.7 and 15.2 m/s, as before).
