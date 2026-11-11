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
