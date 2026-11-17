# RADDY

Online 3-team co-op rally game. Godot 4.7.2, GDScript only, Windows x64 desktop, itch.io.
The user writes Turkish: answer in Turkish.
Zero cost: everything must be free (CC0/CC-BY assets, free tools, player-hosted networking with a free relay,
no paid servers or code signing). If something has no free path, say so and offer the best free alternative.
No Blender; model in Godot only as a last resort.

## Engine
- Godot lives in `C:\Tools\Godot\4.7.2\` (override with `GODOT_DIR`). Use `Godot_v4.7.2-stable_win64_console.exe`
  whenever output or the exit code matters; the GUI exe is for windows launched in the background.
- Export templates 4.7.2 are installed in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- `project.godot` pins Jolt Physics, 120 physics ticks, D3D12, `audio/driver/enable_input`, light projectors read without
  mipmaps (the headlights), the shader globals, and turns off Blender/FBX2glTF import. `tests/unit/test_project_settings.gd`
  guards these.

## Commands (PowerShell, repo root)
- `pwsh -NoProfile -File tools\import.ps1`: headless import. Run after adding addons, assets or `class_name` scripts.
- `pwsh -NoProfile -File tools\test.ps1 [-Select <part of file name>] [-SkipImport]`: GUT suite. Exit 0 pass,
  1 a test failed or a test file did not load, 2 GUT did not run (import failed, Godot missing, 0 tests).
  `-Select` matches the file name only (case-sensitive). Tests live in `tests/`, files `test_*.gd`,
  `extends GutTest`. JUnit: `reports/junit.xml`.
- `tools\launch.ps1 -Clients N [-Server] [-Headless | -HeadlessClients K] [-Scene res://x.tscn] [-ExtraArgs "a,b"]`
  / `tools\launch.ps1 -Stop`: multi-instance run, tiled windows, headless host as instance 0. Logs:
  `logs\instance_<n>.log`; pids in `logs\instances.json`. User args: `--instance=<n> --role=server|client`
  (read with `OS.get_cmdline_user_args()`). From a command line pass -ExtraArgs as ONE comma-joined string
  (pwsh -File binds only the first token). Start it detached (Start-Process) and never redirect its stdout:
  the GUI children inherit the handle and the caller hangs.
- `tools\nettest.ps1 [-Clients 3] [-Seconds 40]`: automated multiplayer check (headless host + clients run
  `scenes/dev/net_test.tscn` with scripted actions, then the `NET ...` log lines are asserted). Exit 0 = pass.
- `tools\flowtest.ps1 [-Clients 1] [-Seconds 300] [-Stage 0]`: end-to-end check of the real game from the main
  menu: host creates a room, clients join by room code, seats + ready, start, bots drive the whole stage,
  results, back to the room, quit (`--flow-test`, see `scripts/core/flow.gd`). Exit 0 = pass (~3.5 min). Prints each
  bot's average over the stage's length, what `StageRecords.MEDAL_SPEEDS` is judged against.
- `tools\ci.ps1 [-AllStages] [-SkipExport] [-SkipFlow]`: GUT, nettest, flow test (all six with -AllStages), a headless bot
  through every stage event (`tools/list_stage_events.gd`), export; stops at the first failure. Takes longer than one
  foreground call may (about 20 min with -AllStages): run its steps one by one or in the background.
- `tools\perf.ps1 [-Stage 0] [-Quality 1] [-Seconds 30] [-Start 0] [-ExtraArgs "--a,--b"] [-GodotArgs "--render-thread,separate"]`: the bot
  drives, windowed at 1920x1080, vsync off once, Godot with `--gpu-profile` so the renderer stamps its passes (`tools/perf_probe.gd`, its header
  says every field). Prints `ADAPTER` (which GPU renders, its type, the API, the window mode, the refresh, `max_fps`), every 5 s `PERF fps_avg
  p95_ms p99_ms over33 draw_calls primitives work_ms tick_ms draw_ms gpu_ms render_cpu_ms mirrors_gpu_ms map_gpu_ms` (work: the main thread's
  process step; tick: one physics tick; draw: the draw call on the main thread, which waits on the GPU when it is behind; the engine's
  `process_max_ms` includes the draw), at the end `GPUPASS <pass> gpu_ms cpu_ms` (the main view) and `VIEWPORT main|mirror|map|other`.
  Before measuring list the Godot processes (`Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'"`): the owner's other projects run
  tests and shots beside this one; never touch them, say in every number what ran beside it. This PC: the RTX 5070 Laptop renders (Auto is
  High), the frame is the GPU's (A9a's table in DEVELOPMENT_PLAN), the floor of an empty stage with the race's look is about 1.2 ms
  (`--scene=look_test`, `--window=fullscreen|exclusive`). Never set the vsync mode every frame: it rebuilds the swap chain (about 10 ms) and
  the GPU stamps read 0, which every number before A9a was. The fps wander run to run by more than most things cost: measure a thing inside
  one run. `--flip-<what>=S` shows and hides it every S seconds (0.5 is good); several flips take turns (`--flip-each=T` seconds each) and
  print `FLIP <what> nodes shown_ms hidden_ms cost_ms median_cost_ms work_cost_ms tick_cost_ms draw_cost_ms gpu_cost_ms render_cpu_cost_ms`
  (`work_cost_ms` steady to 0.03 ms; `cost_ms` wanders by 0.3 ms and more: run twice, the second time in the reverse order): `road-fx`,
  `marks`, `crew`, `crew-motion` (the rigs only), `kit`, `livery`, `pod`, `crowd`, `hud`, `trees`, `low`, `backdrop`, `rocks` (the scenery
  by `RoadsideDresser.scenery_class`), `shadows`, `lamps`, `mirrors`, `ssr`, `ssao`, `glow`, `fog`, `aa`, `map` (an open map: pass
  `--navigator,--map-open`). `--work-top=S` takes turns over
  every script that processes (`FLIP work:<file>`: its `_process` a frame, its `_physics_process` a tick). The probe is compiled before the
  autoloads exist: it may name no class of the game that leans on one (`Net`, `Settings`), it finds nodes by `find_children("*", "<class>")`.
- `tools\feel.ps1 [-Scripts "step,catch" | all] [-Tag now] [-Compare <tag>] [-Device key|pad|wheel] [-Assist 1] [-ExtraArgs "--a,--b"]`: the
  feel probe (`tools/feel_probe.gd`, route_test `--feel=<script>[+..]`, its header says every arg and FEEL line) drives the car through
  `tools/feel_scripts.gd`'s scripts (step, slalom, liftoff, trail, power, hairpin, catch, crash15/45/90, land, flick) on a gravel pad of its
  own (`tools/feel_run.gd`) and writes `reports\feel\<Tag>\<script>.csv` (a row a physics tick) and `<script>.frames.csv` (a row a camera
  frame, `tools/feel_camera_log.gd`: the camera's jerk, median and p99 in degrees per frame squared at 60 fps, and its move jerk in cm, the
  head's lean and the roughness; `--feel-shake=0` measures the ride without the shake); `tools/plot_feel.gd` (Image
  drawing only) draws a sheet per script into `<Tag>\plots\`, with -Compare that tag's runs under these into `<Tag>\vs_<Compare>\`. Leave
  the window alone during the flick (it captures the mouse). `test_feel_scripts.gd` runs the scripts headless; nettest's `--feel-log`
  prints `FEEL jerk` for the driver's peer and a client navigator (turn and move; `--feel-tag=T` writes their frames to
  `reports\feel\<T>\<role>\seat.frames.csv`, which plot_feel draws with `--run=<navigator folder> --compare=<driver folder> --scripts=seat`).
- `tools\fx_probe.ps1 -At "22+30" [-Stage 0] [-Quality 1] [-Weather 0] [-Tag now] [-ExtraArgs "--follower=9,--follower-delay=2,--ride-follower"]`: at those
  seconds of game time the same frame with and without the cloud into `reports\screenshots\fx\<Tag>\`, and `FXPROBE` lines with how much of the road ahead it hides.
  `-ExtraArgs "--glass-dirt=0.35+0.7+1"` measures the windshield's dirt instead (clean glass against each level, `GLASSPROBE` lines; A3's balance and
  A5's numbers are in DEVELOPMENT_PLAN); `--time=N` and the other route_test args pass through.
- `tools\chip_odds.ps1 [-Stage n] [-Weather 0]`: how many runs of a lone bot end with a bullseye or a cracked windshield, per stage (`CHIPS` lines).
- `tools\stage_shots.ps1 [-Stage n] [-Quality 1] [-Weather 0 | -OwnWeathers] [-Time 0 | -AllTimes] [-Kinds "corner,junction"] [-Tag now] [-Chase] [-Sheet]
  [-Compare <tag>] [-RoadLight] [-ExtraArgs "--a,--b"]`:
  every place worth a look (`tools/list_stage_spots.gd`; -Kinds keeps the first of each kind) from the driver's seat, one process per
  stage, weather and time of day (`tools/stage_shots.gd`, about 15 s for three places), plus an overview per stage, into
  `reports\screenshots\stages\<Tag>\<stage>\w<weather>t<time>\`; -Sheet adds a contact sheet per stage and weather (`tools/contact_sheet.gd`,
  windowed: a row per place, a column per time of day) into `<Tag>\sheets\`. Every stage at every time with its own weathers:
  `-OwnWeathers -AllTimes -Kinds "corner,junction,spectators" -Sheet` (about 20 min). The overview is a check of the road's layout:
  straight down and orthographic, it shows hardly any trees. `-Compare <tag>` makes a sheet per stage, weather and time with that earlier
  tag's shots beside these (before and after; the night before the pod: `-ExtraArgs "--no-light-pod"`); `-RoadLight` prints `ROADLIGHT`
  lines: how bright the road is every 10 m ahead in each shot and how far it reads (the road drawn alone in magenta finds where it is
  in sight). Spot kinds include `turn_in`, 8 m before a hairpin or caution corner.
- `tools\capture_window.ps1 -Instance N -Out reports\screenshots\x.png`: PNG of a windowed instance even when
  covered (PrintWindow); use it for multi-window visual checks since Beckett sees one game only.
- `tools\screenshot.ps1 -Scene res://x.tscn -Frames 120 -Out reports\screenshots\x.png [-ExtraArgs "--a,--b"]`:
  Movie Maker capture; open the PNG with Read. The PNG has the project viewport size; `-Resolution` only
  sizes the window. 60 movie frames = 1 s of game time. A dev scene draws at the player's graphics level (Auto is High on this PC, Low on
  integrated graphics): pass `--quality=2` to judge a look.
- The main scene is `scenes/ui/main_menu.tscn`. Screenshots of a running room or race: `screenshot.ps1 -Scene
  res://scenes/ui/main_menu.tscn -ExtraArgs "--flow-test,--role=server,--players=1,--autodrive"`.
- `tools\export_windows.ps1 [-Debug]`: `builds\windows\RADDY.exe` via the "Windows Desktop" preset.
- `tools\editor.ps1 [-Headless | -Stop]`: open the editor (Beckett MCP runs inside it).
- `tools\mic_check.ps1 [-Device <name>]`: input level per microphone (user speaks while it listens).
- Baked assets: `tools/make_gauge_face.gd` (needs a window), `tools/make_badge_flag.gd`, `tools/make_clouds.gd`, `tools/make_exhaust_pops.py`,
  `tools/make_shock_sounds.py`, `tools/make_stone_sounds.py`, `tools/make_road_puffs.gd`. Downloads, all free and no login: `tools/fetch_polyhaven.py`, `fetch_ambientcg.py`,
  `fetch_assets.py`, `fetch_audio.py` (only what the owner approved; `ASSET_LICENSES.md` gets a row);
  `tools/texture_imports.py` sets 3D import options on new textures.

## Specs and plan
- `docs/RADDY_MEGA_MASTER_PROMPT_FINAL.md` is the main spec; `docs/RADDY_SUPPLEMENT_*.md` add art direction,
  engineering and MCP rules. `docs/DEVELOPMENT_PLAN.md` merges them into phases and tracks status; update it
  when a feature is verified. `docs/GAME_DESIGN.md` is the design bible: pillars, the rules every phase builds against,
  the 9.8 quality bar; it records the decisions taken since the spec. `docs/ART_DIRECTION.md` and
  `docs/REFERENCE_RESEARCH.md` hold the research. `CHANGELOG.md` is for players, `TEST_PLAN.md` holds what only people can check.
- `docs/phases/*.md` are the phases' briefs. The order of work is `docs/phases/order.md` (Direction 3 in GAME_DESIGN; it also gives each
  phase's parts, review lenses and flow stage, and the one owner of every system): F (`f_feel_hud.md`: the car's feel, the race HUD, Turkish
  and English everywhere), OW0 (`ow_open_world.md` item 0, the streaming spike), M2 (`m_map.md` points 6-8), H (`h_hands.md`), L2
  (`l2_stages_events.md`), P1 (`p_on_foot_cars.md` steps 1-2), X (`x_mayhem.md`), W (`w_world.md`), J (`j_join.md`), D (`d_demo.md`
  items 1-4), P2 (`p_on_foot_cars.md` steps 3-9), OW (`ow_open_world.md`: the region, roam, `Profile`), I (`i_interiors_destruction.md`), N
  (`n_npc_life.md`), Q (`q_missions_career.md`), A6 (`a6_chaos.md`), A7 (`a7_ui.md`), A8 (`a8_net.md`), A9b (`a9_a10.md`), the owner's
  play-test build, then T, OW2, WD (`web_demo.md`) and A10 (`a9_a10.md`). L (`l_levels.md`), A9a (`a9a_perf.md`) and M's map page are
  built. A phase's brief is its spec; what was done goes into DEVELOPMENT_PLAN. A built phase's brief stays as its record
  (`a5b_crew_look.md`). `docs/phases/downloads.md` lists the approved raw downloads no phase has used yet (Freesound sounds, Sketchfab
  models; under the git-ignored `raw_assets/`, on the dev PC only) and what each is for.

## Vehicle code (scripts/vehicles)
- `RallyCar` (RigidBody3D) simulates in `_integrate_forces`: ray wheels cast by the car, spring/damper/bump stop,
  slip-angle tyres with a cornering-priority friction circle, AWD drive, handbrake, anti-roll, drag,
  oversteer assist, impact and recovery detection. It never reads Input.
- Whoever owns the car writes `car.controls` (`VehicleControls`) before each tick: `PlayerCarInput` locally,
  later the network layer, and tests. Tunables live in `VehicleConfig` (`data/vehicles/rally_hatch.tres`).
- Steering (GAME_DESIGN §5): `SteeringInput` (pure, tested) turns the raw axis into the steer command per device: a key
  ramps in by speed (0.21 s to lock at 20 km/h, 0.33 s at 100 km/h) and comes back faster, with a counter-steer assist while
  no key is held; a gamepad gets a response curve (`linearity`) and light smoothing; a wheel (`device_for_joypad`, by its
  name) passes through. `PlayerCarInput` follows the device last touched, sets the assist level (Settings `driving_assist` 0-2 →
  `RallyCar.assist_scale`, the stability help, which yields after a handbrake pull while the driver steers into the rotation; on
  a gamepad counter-steer only at level 2), the gamepad's `steer_linearity`, the rumble (`vibration`: road and slides on the
  weak motor, crashes on the strong one) and one hand on the wheel while the driver aims the shock gun (`ONE_HAND_LOCK`,
  `ONE_HAND_RATE`). `tests/unit/vehicles/test_handling_benchmarks.gd` pins what a feel change is judged by: 0-100, 100-0,
  turn-in, keyboard ramp, handbrake hairpin, pulling away on full lock, landing.
- Surfaces: colliders set metadata `surface` (see `Surface`); untagged ground is gravel.
- Dev scene `scenes/dev/vehicle_test_track.tscn` (`--autodrive` user arg circles) for car tuning.
- What a car throws off the road: `CarRoadFx` (a child of every `RallyCar`, the one owner of it), on every peer from what that peer sees the car do, never sent.
  `RoadFxRules` (pure, tested) says what each surface throws: dry gravel, dirt and sand a cloud of `DUST` that hangs 4-7 s, snow `POWDER`, mud and wet roads `SPRAY`
  and clods, tarmac nothing; the rear wheels stones (by speed, throttle, slide), a hard landing a `BLAST` ring, `pings_per_second` the stones under the floor (`CarAudio`,
  the crew only). `RoadFxPool` (one per scene, beside the cars, group `road_fx_pool`) holds them in two world-space `GPUParticles3D`, one draw call each for all cars: soft puffs (`shaders/road_puff.gdshader`, a
  lit card facing the view that the `tools/make_road_puffs.gd` map models like a cloud; `road_puff_motion.gdshader`) and hard bits (`road_bit_motion.gdshader`), filled only from script with
  `emit_particle` (`emitting` stays false, the engine takes emitted particles only then). `pool.puff()` and `pool.bit()` are for anything else that belongs in the air (sparks, glass, leaves). Puffs by the metre of
  road, whatever the frame rate; puffs are drawn after the pools and the other cars' glass, before the seat's own glass (`PUFF_PRIORITY`,
  `CarModel.GLASS_PRIORITY`: `bind_seat` raises the seat's car's). `PUFFS` 1280: three crews' dust at once. `RoadFxRules.cloud_share`: Low and the effects setting thin the puffs but each gets thicker and
  bigger, so nobody sees further for choosing less; stones go with the effects setting. Wind and dust colour: `RaceLook.wind`, `dust_tint`. A headless peer only counts (`puffs_thrown`, `bits_thrown`).
- Dirt on the car: `CarDirt` (child of the `CarModel`, every peer, never sent) gives the paint, the trim (`UCB_BOTTOM`) and the tyres a skin of the
  car's own (`shaders/car_body.gdshader`: the model's StandardMaterial3D while clean, so no draw call of its own, its occlusion map kept, its light
  and its clear coat's glint capped by `lamp_cap` like the rails', or a car ahead in a follower's beams was a white blob; one skin per material and mesh space, the dirt measured where each mesh lies, a
  tyre in its own space about its axle; `CarDirt.paints` take the team colour)
  and climbs three layers, dust, mud and snow (`CarDirtRules`, pure: per metre by surface and speed, about 0.8 after a short stage, 0.93 after 3 km of gravel). The mask is in car
  space: sills first, fans behind the wheels, the rear face, what faces up last; `assets/fx/car_dirt.png` (`tools/make_car_dirt.gd`: patches, drops,
  streaks). A splash washes the lower half (`washed`, back within 500 m of dirty road); a recovery cleans nothing; the flag's badges and the glass are no
  skins (the Cabin owns the glass). `route_test --car-dirt=D+M+S` for shots.
- Tyre marks: `CarTyreMarks` (child of every `RallyCar`, every peer, never sent): one world-space mesh per car (one draw call, on
  `FINE_SCENERY_LAYER` so the mirrors leave it out), a `TyreTrack` ring of pieces per tyre (pure: a piece every `TyreMarkRules.spacing` 0.6-1.0 m by
  level, 4.4 km kept, memory fixed from the start), each piece written in place with `surface_update_vertex_region`/`attribute_region`. Every point
  comes from a ray down to the ground, `LIFT` 2 cm above it; no mark in water, on steep ground (`FLOOR`), across a crease or a sharp turn (a new mark
  starts). `TyreMarkRules` (pure): per surface the pressed ground's colour (about half the road's own, darker than its packed tracks), how strong a
  rolling tyre's mark is, how deep and wet; scrub from slides, the handbrake, hard braking and spinning away widens and darkens it; tarmac only takes
  rubber. `shaders/tyre_mark.gdshader`: a lit strip (render priority -2: under puddles, puffs and glass), rut walls from screen derivatives, tread blocks
  on soft ground, raked lines when swept. A headless peer follows the tyres and draws nothing.
- Bigger hits: `CrashRules` (pure) says what a crash throws off what the car hit: sparks off rock and metal, leaves from the crown and bark off a
  tree (`RaceLook.foliage`, snow off the branches in snow), splinters, straw, chips, dust. Colliders say what they are with meta `struck`
  (`CrashRules.META`): the roadside obstacles' shapes (`RoadsideDresser`: a sphere is rock, a box wood, a cylinder a living tree unless the catalog's
  `struck` says otherwise), rails and arches (metal), props (bales straw, parked cars metal, seats wood), log piles, barriers (concrete as rock),
  the fallen tree, boulders; loose bodies are metal, the rest ground. The driver's peer plays its own crash at once from `RallyCar.last_impact_at` /
  `last_impact_struck` (the tick's hardest contact); everyone else from `RaceSession._rpc_crash_fx(team, strength, at, struck)`, relayed by the host. A
  broken side window drops its glass (`Cabin.window_state_changed`). Two more pools in `RoadFxPool` (`Flake`: flakes, `road_flake.gdshader`, and sparks,
  `road_spark.gdshader`, both flown by `road_flake_motion.gdshader`) are hidden between crashes: no draw call.
- Everything on the car works, on every peer. `CarParts` cuts what moves out of the Milano's one-piece meshes (by the
  island inside a box, test_car_parts.gd pins the triangle counts; meshes shared by every car, in car space). `CockpitRules`
  (pure) says what every needle, lamp and lever shows; `CarCockpit` puts it on the car near the camera: the instrument
  panel (`shaders/gauge_panel.gdshader` over a face baked by `tools/make_gauge_face.gd`, keep both layouts in step),
  pedals, H-gate lever, fitted handbrake. `CarLamps`: tail lights only with the headlights (their glow a faint red on the
  road behind, the brake lights' a bright one: from dusk on, by `RaceLook.lamp_light` like the beams), brake, reversing, hazards on a stuck or critical car (each lamp's glass glows
  through the model's own picture of it, `shaders/car_lamp.gdshader`: the chrome reflector and the flutes glow, the housing stays dark, the
  headlight's projector lens a hot core, `HEAD_LENS`; seen from the side it glows less: a flat plate of light before), the dome lamp
  (`Cabin.dome_on`, L, the map holder's; shows in the glass through `shaders/glass_ghost.gdshaderinc`). Headlights: one beam from
  between the two lamps with the light of both (every beam is a shadow pass a frame), a
  projector pattern (`CarLamps.beam_pattern`, tested: brightest in a band round the horizon, so the road reaches 80 m and
  more, cut under the nose) drawn through each beam's shadow map, which holds only the cars' hulls (`CarLamps.HULL_LAYER`: a few triangles inside every
  car, shadows only, so no beam shines through another car onto its road and windshield; with no layer the engine drops the map
  and the pattern; the sun leaves the hulls out) except the seat's own car on High (`cast_shadows`, real shadows); read without mipmaps (`rendering/textures/light_projectors/filter=1`, guarded by test_project_settings, or the
  band smears). Their strength is `RaceLook.lamp_light` (what eyes used to the dark make of them: in full from dusk on; by day 0, whatever the
  weather: the beams and their shadow maps are not drawn, the lamps' glass shows they are on). Light pod (`CarLightPod`, built in code, one draw
  call, `shaders/light_pod.gdshader`): every car at dusk and night (`RaceLook.light_pods`, every peer) wears four lamps on the bonnet, a black
  fairing with a cover plate in the team colour (`CarModel.set_paint`), two spot lamps and two wide ones; `CarModel` bolts it to the bonnet's
  hinge (`CarDamageFx.mount`: a loose bonnet aims it at the sky, a torn-off one takes it, dark, `CarLamps._show_pod`). Its light is the car's
  other beam, the headlights' way (`CarLightPod.beam_pattern`: a long band from about 60 m on and wide sides, falling as the square of the
  angle below its band so the near road is no blaze); `route_test --no-light-pod` leaves it off. `CarHeat`: pops and flame on a lift at high revs, front discs that glow after
  really hard braking. The wheel turns about `CarModel.WHEEL_AXIS` and is set (`WHEEL_SET_IN`) so the dials show through the rim.
  `Cabin` slides the side panes into the doors (along their own slant, cut at the door's sill: `sill` in `car_glass.gdshader`); the
  glove box's lid opens when a can is taken, the radio's readout lights with the engine, after dark the lit dials glow on the hands and on a
  raised gesture (`CarCockpit`, `CockpitRules`; the glow 6 cm in front of the panel, as far from both hands and 0.14 m behind the hub: nearer,
  it made a lamp of what it lit). No sun visors (`CarParts` cuts them away): the cage's roof bars run where they would hang, and from where
  the crew sits a lowered one hid 43 % of the windshield. `GraphicsQuality.CABIN_LAYER` is what is inside a car, which the car lamps'
  shadowless beams leave out; `WindshieldGlass` sweeps the model's own wipers on their hinges and tells the shader the ring each blade
  passes. The handbrake comes with the snapshot extras; gear and revs come from each peer's `CarAudio.gearbox`.
- Where the crew sits: the seats' cameras in `rally_car.tscn` are the eyes (low, upright, close to the wheel), `CockpitCamera.BASE_FOV` 62
  (vertical); `tests/unit/vehicles/test_seat_view.gd` pins it with rays against the car's own triangles: the windshield about half the frame
  height straight ahead from either seat, the interior and the near door mirror in view, the dials' needles through the wheel, the cage hiding
  at most 1 % of the windshield's view (0.1 % from the driver's seat, 0.9 % from the navigator's). From the driver's eye only 60 % of the
  interior mirror is in the frame at rest (77 % at 60 km/h, 88 % at 100 km/h, all of it at a glance): left to A7's seat and FOV options in
  the settings, the road stays the star. The head turns `CockpitCamera.LOOK_YAW` 100 degrees either way, no further than between the bucket
  seat's wings (the body's head as far, `CrewRig.HEAD_LIMITS`; up only 12 degrees looking ahead and not at all from 60 degrees aside,
  `HEAD_UP_ASIDE`: further, the helmet's back went into the head restraint; the eyes look on, the camera to 30).
- Crew (`CrewBody`, `CrewPose`, `CrewHelmet`): every seat a player holds has a body, on every peer (`RaceSession._seat_crew` from the roster, again
  on `Net.roster_changed`; `CarModel.seat_crew(role, seated)`; no body in an empty seat). Quaternius's mannequin (`assets/characters/crew_mannequin.glb`,
  UAL1's without its clips, `tools/make_crew_mannequin.gd`; bones `DEF-*`, the dots imported as `_`), rounded when it is baked: one step of Loop
  subdivision (`subdivide`, 13.7k triangles to 32.8k: all but the balls at the fingers' joints, already round), the rims of the soles and the
  fingertips creased, each new vertex's weights blended by the same masks (four bones, summing to one), the normals smooth across the rest
  (`tests/unit/vehicles/test_crew_mannequin.gd`; the suit, the crowd and the own-head folding read its vertices as before). Posed in code: `CrewPose` (pure, tested) puts
  the eyes on the seat's camera (`seat_position`), the pelvis and back reclined, the head upright, the legs and arms as two-bone chains to
  `CrewBody.SEATS` (driver: clutch and throttle, the wheel at a quarter to three; navigator: the floor, hands on the thighs). The suit
  (`CrewBody.race_suit`, one surface for both of the mannequin's, shared by every body) is cut as cloth over it when it is baked (`CrewSuit`,
  pure, tested: round each limb's and the body's axis a taut line over the elbows', knees' and belly's grooves, the body rising to meet a limb's
  ball; where a ball still meets the body `meeting` says how far, and the shader sews a seam along that crease). Per vertex: COLOR r glove, g boot,
  b head, a a glove's back; UV2 how far a vertex is from a stripe's line (metres) and whether one runs there (`CrewBody.suit_region`,
  `stripe_coordinate`, by bone groups: straight bands of one width along the arms, the legs and the flanks; none over a shoulder or a hip); UV.x
  the meeting, UV.y a glove's back (a finger's one panel from the knuckle to the tip, `CrewSuit.finger_back`: by its bone's line, not by its
  piece; the glove's cloth spans the pinches of the mannequin's beaded fingers, `fill_fingers`, a crease left at each joint); CUSTOM0 where it is on the suit
  standing in its T-pose (left arm along +x, front +z) and its piece (`CrewSuit.Part`). `shaders/crew_suit.gdshader` places everything there:
  matte fabric (wrap lighting, rim sheen), a weave and the knit's ribs that fade before they shimmer, folds gathering at the joints, darker panels
  down the sides and under the arms, ribbed stretch panels over the shoulders and the knees, a collar, a covered zip, tape stripes, every seam a
  groove with stitches (`sew`); the flag patch on the upper left sleeve (`CrewBody.PATCH_AT`/`PATCH_SIZE`, `TurkishFlag.texture()`, the hoist
  to the front, a wound border); the seat's player's name on the right of the chest (`wear_name` from `RaceSession._seat_crew` and
  `LiveryRules.seat_name`, the livery's capitals; `CarLivery.name_picture` draws it, white on nothing, `CrewBody.name_picture` keeps it for the
  helmet; no name, nothing; thread white on a dark suit, black on a light one); gloves with a suede palm and a stitched elastic cuff; thin-soled
  boots (toe cap, laces, suede ankle, the team colour on the heel tab). `route_test --names=A+B` letters car and suits. The helmet
  (`CrewHelmet.mesh()`, the one place a real model would replace; one surface, about 29k triangles with levels of detail like the suit's, `CrewBody.thinned`; built once a session with the suit by `CrewBody.bake` in `RaceSession._ready` before the race reports loaded, about 0.55 s: made at a car's spawn it held a client's start back) is an
  open-face rally helmet in the head bone's space: a shell (`shell_point`: an egg taller than wide, narrowing to the brow, the nape tucked in,
  the lower edge flared, ear cup bulges) cut out of a grid where its edges cross (`presence`: the lower edge `RIM`, the face `OPENING`
  closing in on the jaw, the cheeks' corners rounded; each grid triangle clipped, the crossing found on the shell), a rubber trim round the
  edge and the liner and cheek pads going in under it to the face and the neck, intakes over the brow and exhausts behind; no peak and no
  visor (the cage is overhead). The face: a black balaclava over the mannequin's (`face_point`, a height field fitted to it, 2.6 mm in front
  of it at least, with brow, nose, cheeks, lips and chin under the fabric) and its slot round the eyes (`EYE`). An intercom boom from the
  left cheek to 1.4 cm before the lips (`MIC_TIP`), its cable down to a plug on the HANS collar, a chin strap, the HANS posts and tethers.
  It is skinned (`CrewHelmet.skin`, a child of the skeleton): all of it rides the head but the tethers' and the cable's lower ends, which ride
  the hips (they hold still in the seat, as the HANS collar does), so they stay clipped however the head turns. `shaders/crew_helmet.gdshader`
  (cull disabled: the shell's inside is liner wherever it shows): the team colour under a gloss coat whose own glint is the lamps' (capped at
  the sun's, `lamp_cap`) and whose mirror sees the world only through the windows (`window`, in the body's space: the roof, doors and seat
  leave the cabin's dark sheen), a white stripe between black lines, a darker band along the lower edge, on both flanks the flag of Turkey in
  a white border and the seat's player's name (`CrewBody.name_picture`, `wear_name` sets both materials), read from the left as on the
  windows; in the slot, skin and eyes (anti-aliased by their own screen derivative, `covered`) wet enough to glint. The HANS
  (`CrewBody._hans`, `CarRallyKit.band`: a rounded carbon band) runs from the chest under the straps over the shoulders and stands up behind
  the neck to the tethers' clips at `CrewHelmet.TETHER_LOW`. `tests/unit/vehicles/test_crew_helmet.gd` pins the fit, the name and flag, the
  skin and that the helmet clears the seat's wings and head restraint (>= 3 mm) and the cage's padding at the look's, the swing's and a faint's
  extremes; the harness
  (`CrewBody.harness_mesh`, buckled over the pose; its webbing bends over the body as a curve through its points, `STRAP_STEPS`, shaded smooth
  along it: folded flat it read as the body's facets) is black (`CarRallyKit.HARNESS`). Own head: `CarModel.bind_seat` takes `CrewBody.OWN_HEAD_LAYER` (1 << 13) out of the seat camera's mask; that body's helmet
  sits on that layer and its suit folds the head away for a camera without it (`CAMERA_VISIBLE_LAYERS`); the mirrors keep it.
  Only the cabin the local player sits in casts shadows of its crew, cage and seats (`bind_seat` → `CrewBody.cast_shadows`,
  `CarRallyKit.cast_shadows`): in a rival's nobody sees them, and each was a draw call in every shadow map; a harness and the mud flaps never do.
  `route_test --crew=driver+navigator|driver|navigator|none` (default both, every car), `--look=Y+P` holds the head turned (screenshots).
- What a crew member does (`CrewRig`, built by each `CrewBody` in a car, every peer): Godot's skeleton modifiers on the mannequin (`TwoBoneIK3D` arms
  to goal nodes the rig sets in car space each frame, `CopyTransformModifier3D` gives each hand its goal's turn, `LookAtModifier3D` the head, a
  `TwoBoneIK3D` for the legs only while kicking); the skeleton has `process_priority` 1, so it solves after the car turned its wheel and the rig set
  the goals. The rig itself turns the chest and the neck (a share of the look) and the fingers (`Grip`, from `CrewPose.curl_fingers`); the harness
  and HANS are static meshes, so the torso never leans: a reach brings a shoulder forward instead (`REACH`). What each hand does is
  `Cabin.hands_of(role)` → `CrewRules.hands` (pure, tested): the driver's ride the rim (push-pull: as far round as the arm reaches, `_wheel_arcs`,
  then the rim slides through the hand) and leave it for the shock gun (`ShockGun`, code-built, right hand; the shot's wires leave its muzzle,
  `RaceSession._seen_from`), the window's winder, the wipers' stalk, the horn, the handbrake (`CarCockpit.handbrake_grip`) and a gear change
  (`lever_knob`, from each peer's gearbox); the navigator's rest on the lap, hold the open map by its edges (`PaperMap.hold`), the gun, throw, wind.
  Gestures with the hand nearer the partner, against the windshield where the partner sees them without turning, placed from the partner's
  eye (tested), each a sign of its own (`CrewRules.sign_of`): the finger across to the partner's side, the thumb for the side away (a hand held
  out that way leaves their sight), a chop for straight on, a pat for slow down; the gloves' backs, the fingers' to their tips, are in the suit's colour
  with the sleeve's stripe (`CrewBody.suit_region` alpha, `CrewSuit.finger_back`), so a hand shows on a black wheel and a dark dash and a sign
  reads at night in the dials' glow alone. A job's outcome waits for the body's move: the
  windshield goes when the kick's soles meet it (`CrewRules.KICK_LANDS`), a can flies when the hand lets go (`THROW_LEAVES`), a kick another
  player began plays to its end; the navigator does not reach across the driver for the far winder (`CrewRules.job_hand`), and the gun stops
  at a closed window's glass. Out cold it slumps,
  a shock (`Cabin.shocked`) shakes it. The harness holds the body, the neck gives to the car (`CrewSway`, pure, tested: a corner tilts the head
  out of it by 6.5 degrees a g, braking nods it, a hit jolts it, 15 degrees at most, the navigator's neck the looser, the seat stopping it
  where the helmet meets it: 9 degrees to a side, 4 looking aside, back only as far as the look's limit leaves, `CrewRig.SWAY_SIDE`; each peer works it out on
  its physics ticks from `RallyCar.seen_velocity`, never sent: the body's own where it is simulated, the driver's from the snapshots elsewhere,
  since a car played back moves a frame's ticks at once and its place says nothing of how it turns). Only a crew someone can see moves: the
  local player's car's always, another's on the screen within `CrewBody.DRAW_RANGE` or within `MIRROR_RANGE` 10 m; otherwise the modifiers
  are off and the skeleton does nothing. Three crews cost about 0.85-1.2 ms a frame on Medium by day (`perf.ps1 --flip-crew`, since A5b's
  suits and helmets): 0.37 of it the rigs' scripts and skeletons (0.07 ms a moving body), the rest some thirty draw calls. `route_test --crew-look=R+Y+P --gesture=R+G --aim=R --job=R+J+T --faint=R+T --shock=R+T --steer=S --handbrake
  --windows-open` pose them for screenshots.
- `CarRallyKit` (one mesh, one draw call, `shaders/cabin_kit.gdshader`, parts by vertex like the pod): roll cage (black foam on the A pillars and
  round the heads, the main hoop at z 0.43 behind the seats), bucket seats swept along `SEAT_PROFILE` round the bodies (`seat_surface` is the
  fabric's surface, UV.x 1: the shader weaves a racing seat's mesh fabric in two sizes, each faded out by how far its threads pass in a pixel,
  so it never shimmers; `CarParts` cuts the road seats, their buckles and the rear bench away), a trip meter by the navigator's A pillar
  (`trip_display()` for A7's numbers), a fire extinguisher; `strap`/`buckle` make harness webbing, a loose harness lies on an empty seat
  (`seat_taken`). 6016 triangles drawn. `SurfaceTool.append_from` of a surface without indices and one with them keeps only the indexed
  part: the cage, the trip meter and the extinguisher went undrawn for most of A5 while the tests measured `get_faces()`, which lacked them
  too; the cage is indexed before the seats join it and `test_car_rally_kit` asks every part to be drawn.
- Livery (`CarLivery`, child of the `CarModel`; `LiveryRules`, pure, tested): every car is lettered for its crew on every peer
  (`RaceSession._seat_crew` → `livery.show_crew(number, names)`: the team's number, the names of the seats players hold, the driver's first, in
  capitals the way the locale writes them, 20 letters at most). One picture drawn in code (`draw_picture`, 1024x512; the text through the
  TextServer's glyph cache, which works headless): a panel on each front door and the rally plate on the bonnet are printed on the paint's own
  skins (`car_body.gdshader`: `livery_map`, `door_box`, `plate_box`; no draw call, `CarDirt` covers them like paint), the names after a small flag
  of Turkey on the rear side windows and the number on the rear window are vinyl on the glass's own triangles (`sticker_mesh`,
  `shaders/car_sticker.gdshader`, one draw call), a mud flap hangs behind each wheel (one mesh, a `CarDirt` skin). The event's name is
  `LIVERY_EVENT` in the strings; no maker's logo anywhere. `route_test --names=A+B` (an underscore for a space).
- Mirrors: `CarMirrors` on every car, plain glass until `CarModel.bind_seat(camera)` (local seat only, never
  headless). Each mirror is a `SubViewport` + camera at the eye reflected in the glass, frustum fitted to the glass
  (`MirrorMath`, tested against the engine's projection; the picture is flipped by the display, `mirror_glass.gdshader`).
  Linear HDR picture, no tone mapping: the main view grades it with the world. Turns and sizes per level in
  `GraphicsQuality`; at most one mirror a frame, only those the seat can see. A mirror's camera leaves out
  `CarMirrors.SELF_LAYER` (glass, housings, the motion blur), `GraphicsQuality.FINE_SCENERY_LAYER` (`RoadsideDresser.is_fine`, and the boards' words and tape go with their boards: low,
  backdrop, no collision unless `tall`, or `fine` in the catalog) and `RaceLook.SUN_LAYER`: it has a shadowless sun of its own
  (`MIRROR_SUN_LAYER`, which it clears from the main camera). `RaceLook`'s `SunInTheSky` is what the sky shows, the same
  for every camera: different sky lights per camera would rebuild the sky's reflections every time the view changes. A
  mirror's viewport keeps a small shadow atlas (`BEAM_ATLAS`): a follower's beams draw their pattern through it.

## Screens and flow (scripts/core, scripts/ui, scripts/gameplay/race.gd)
- Autoloads: `Settings` (user://settings.cfg: language, volumes, voice, effects, driving assist, graphics, key bindings; tests set
  `Settings.save_path`), `Flow` (menu → lobby → race → results → lobby; leaves dev scenes alone).
- `RoomCode` packs IPv4 + port into a checked `XXXX-XXXX-XXXX` code; `PortOpener` (UPnP, thread) gives the
  internet code when the router allows it (CGNAT detected). `RaceSettings` resolves Random / Surprise Rally
  (keys `stage`, `difficulty`, `weather`, `time`, `shock`; the stage gives `biome` and `seed`; a `time` left out is day,
  every stage comes at every time); `BiomeRules` applies weather/difficulty to the stage. UI strings: `data/locale/strings.csv` (TR/EN).
- Times of day (`RaceSettings.TimeOfDay`, lit by `RaceLook`): day; golden hour (the sun at 12 degrees, warm, dazzling to
  drive into); dusk (the blue hour: the sun 4 degrees under the horizon, no sun light or shadow pass, the sky's afterglow, its blue light on the
  land, a road readable without lamps, headlights on in full: dusk is never darker than night from the seat);
  night (a moon of 0.05 and stars on a clear sky, neither under clouds; the moon casts no shadow: its cascades cost High 200-300
  draw calls for shadows nobody sees). `RaceLook.daylight` (cabin fill, the
  weather's particles: lit from dusk on) and `lamp_light` follow it. The sky is `shaders/race_sky.gdshader`: by day the
  procedural sky to the pixel (A/B checked), then the afterglow, clouds lit from the sun's side that hide what is behind
  them, the moon's disc and stars; nothing in it moves (no TIME), so its radiance is made once.
- Race start: `Net.report_race_loaded()` from every player; the host spawns only when `Net.all_players_loaded()`
  (scene changes are deferred: spawn RPCs sent earlier are lost), then a 3 s countdown with `car.input_locked`.
  Results: host clock + recovery penalty, `RaceResults.rows()`, published when all finished/left or 120 s after
  the first finisher. `StageRecords` (user://records.cfg, per PC, section `best_v<StageCatalog.LAYOUT>`: bump `LAYOUT` when
  the roads change so much that old times mean nothing; `Net.JOIN_VERSION` carries it, so a build on other roads cannot join) keeps the best time per stage and gives
  bronze/silver/gold from the stage length (`MEDAL_SPEEDS`); results show the medal and a new record,
  the room shows the medal times and the record. Host buttons: same stage / next stage (`Net.start_race(settings, true)`) / back to room.
- UI is built in code with `UiTheme` (static helpers must use `TranslationServer.translate`, not `tr`).
  Canvas layers: SeatEffects 5, RaceHud 8, ResultsPanel 12, PauseMenu 15, SettingsMenu 20.
- `RaceHud` is drawn in code (`HudStageBar`, `HudCluster` rev counter/gear/speed: the driver's, fading over the right door mirror; it runs after the cameras and `CarMirrors.glass_center` is where the
  glass is drawn, a tick's difference moved the mirror under it at speed) in `UiTheme.hud_font()`
  (Windows' Bahnschrift via SystemFont, nothing shipped). The race captures the mouse for free look
  (`CockpitCamera.look`) unless a menu is open or it is a flow test.

## Stages (scripts/procedural)
- Six named point-to-point stages in `StageCatalog` (two per biome; names `STAGE_<ID>` in strings.csv; `weathers` lists the
  ones a stage comes in; `rules` the edition of `StageDesignRules` it is built to). A recipe is segments (`len`, `turn`,
  `tightens`/`opens`, `rise`, `crest`/`jump`/`dip`, `water`, `cliff`/`bank` left|right|both with `drop`/`wall`, `surface`, `caution`,
  `falling_tree`/`rockfall` left|right, `decoy`, `bypass`, `spectators` left|right, `gag`, `signature`); `StageBuilder.build(stage)` → `RouteGraph` (START → WAYPOINT(s) where the surface changes →
  FINISH, 2 m polylines + heights, `features` by distance, gates: start line at 40 m, two splits, finish 70 m
  before the end). `graph.sample(distance)`, `route_distances()`, `RouteIndex` (nearest road point + distance
  along) and `RouteTracker` (follows a car along the stage; progress counts only within `ON_ROAD` 14 m of it) work in
  metres along the road. Preview layouts with a script that draws `graph.main_route_points()` into an Image.
- Two judges, both must stay empty for every stage (tests/unit/procedural/test_stage_builder.gd). `RouteValidator.validate()`,
  playable: length, radius >= 11 m, grade <= 30 %, no crossing, stretches >= 30 m apart, width >= 3.6 m and never stepping
  along a stage (ditches run unbroken), `_check_spurs`. `StageDesignRules.check()`, a good rally stage (GAME_DESIGN §4): 2-4 km,
  a danger at least every 500 m (`worst_danger_gap`, on the summary notes), the sightline budget, 3-6 junctions 150 m apart and
  never on the side the road itself turns to, at least 2 places for spectators, every gag slot and the set piece where they may
  stand (`_check_gag_slots`, `_check_signature`); the second edition (a real rally road in numbers: turning per km, straights, the
  mix of corners, the land, choices, places, rhythm; `measures()`, `summary()`, `check_catalogue()`) only on a stage whose `rules` is 2.
  `tools/stage_measures.gd` (`Godot --headless --path . -s res://tools/stage_measures.gd`; the Net compile errors it prints are harmless)
  prints each stage's `MEASURES` and what the second edition still `WANTS`; `test_stage_builder.gd` `WAITING` lists the stages not yet
  redesigned (Black Pine and Red Canyon are built to the second edition: Black Pine's set piece is the barn, Red Canyon's a hamlet's
  street, `village`). A bypass never meets the road on a cliff's side. `route_test` prints `ROUTE impact` for every hit of 8 m/s or more
  with where it happened. When a stage fails, fix the recipe, never the threshold. Width: the stage's own (3.6-5.0 m) + `RaceSettings.WIDTH_OFFSET` (Explore +0.8, Redline -0.2), set by
  `BiomeRules.apply_to_graph`; one width per stage, a segment's `width` would fail the validator.
- `Sightline`: how far ahead the road is readable from the eye (`ahead`, `survey`), ended by a crest or a side `screens(graph)`
  calls screened: forest and mountain sides are, desert sides only by a bank or a corner's screen; cliffs and places for the
  crowd are open. `StageBuilder` adds a `screen` feature on the inside of every corner of `SCREEN_TURN` 25 degrees or more and
  `RoadsideDresser` plants `screen` catalog entries there, never thinned (Low must not see further). Budget: median at most 80 m,
  at most 3 % of the road over 150 m, never past 200 m (real: medians 54-68 m, longest 168 m).
- Wrong ways: a segment's `decoy` {`side` straight|left|right, `len` 60-250, `end` dead_end|barrier, `at`, `angle`, `bend`,
  `rise`} makes a `RouteGraph.Spur` in `graph.spurs`, apart from `edges` (edge ids from `SPUR_EDGE_BASE` 1000): whatever
  follows the stage (tracker, follower, recovery, gates, notes) sees one road, only what builds the world reads `road_edges()`.
  It looks like the road carrying on (same width and surface, no warning at the mouth); `RouteValidator._check_spurs`: never
  near a gate, on a jump or under a surprise, never a way through to another part of the road, never over a cliff. World:
  `Track/Spurs/Spur<id>` (`Road<id>`, the `Landing` turning area of `LANDING_RADIUS` 9 m, the `Mouth` filler),
  `RallyDressing.junction_furniture` (a log pile, or barriers and tape deep in the track). Paper: `MapCanvas`, junction notes.
- Bypasses (phase L): a segment's `bypass` {`kind` shortcut|long, `side`, `at`, `rejoin` m along the stage from its mouth, `angle`/`join`
  degrees off the road at each end, `hold` m straight at each end, `reach`, `rise`, `price` ford|gate|rough|narrow, `price_at`, `surface`,
  `width`} makes a `RouteGraph.Bypass` in `graph.bypasses` (edge ids from `BYPASS_EDGE_BASE` 2000; `SideRoad` is the base of it and of
  `Spur`; `side_roads()`, `edge_by_id()`). One coordinate (GAME_DESIGN law 2): `graph.along_of(road, metres)` maps a bypass linearly onto
  the stretch it replaces, `followed_roads()` gives the stage (`RouteGraph.STAGE`) and every bypass to what follows a car, `path_through(ids)`
  is a bot's way. `RouteValidator._check_bypasses`: a shortcut at most 70 % of its stretch with a price, a long way 115-140 % (longer is a detour nobody takes), no gate
  inside the stretch, a branch turning 60 degrees or more at each end, the stage's way at both ends, 30 m from other stretches, nothing
  crossed. `RouteTracker` follows the road the car is on (`road`, `road_distance`) and changes road near a junction once the car is off
  its own road's surface and shoulders and the other is nearer, the difference fading over `SWITCH_BLEND` 40 m; `RecoveryAnchor.find` lands
  on the stage or on the bypass the tracker has the car on (`on_road`; a car stuck beside a shortcut never lands past its price); stones fly only
  between cars on the same road; bots take each bypass by a coin (`RouteFollower.choose_bypasses`, `--bot-roll=N`; flowtest 153: host on the
  stage, client on both) and slow for a price (`price_places`). Prices: a ford is a pool on the bypass's own dip (`Ford<id>`), a gate is a
  `FarmGate` (`GateRules`: burst at 5.5 m/s and more, the car keeps 60 % of its speed and takes a hit the host judges; a standing crew holds
  `cabin_gate` (G) 3 s; `StageEvents.gate_wanted` -> the host's `_rpc_open_gate`), narrow is a 3.2 m lane between earth banks
  (`RoadBuilder._build_banks`), rough is ruts on the stage's own surface. World: `Track/Bypasses/Bypass<id>` (road, `Mouth`, `Rejoin`,
  `Banks`), its own walls. Notes: "Kısayol solda: dere!" / "Long way left!" 40 m before the mouth ("Kısayol düz" / "straight"
  when it runs on within 20 degrees where the stage turns, `PaceNotes.BYPASS_STRAIGHT`), the rejoin a junction call. Map: a road
  like every other, the ford's water, each price's pictogram. `route_test --bypasses=all|none|0+1 --price=P --on-bypass=B`.
- `TerrainField(seed, relief).set_roads(graph)`: IDW surface through the road heights + hills growing away from
  the road + cliff drops / bank walls from the features. It owns the ground grid (`CELL` 4 m, `MARGIN` 140 m, `grid_at`), the
  mesh and collision `RoadBuilder` makes: within `FLAT_BAND` 8.5 m of a road's edge it lies flat, `FLOOR_DROP` 0.7 m under the
  lowest road height within `FLOOR_WINDOW` 6 m along the road, so its triangles never poke through a shoulder or a ditch
  (smallest margin 0.30 m, tested). `height()` is the surface you see: `cross_section(e, d)` out to `RoadBuilder.ROADSIDE`, the grid beyond.
- The road's cross-section (`RoadBuilder`, metres from the edge, heights below the road): `SHOULDER` 0.8 drivable gravel down to
  `SHOULDER_DROP` 0.05, a V ditch with its bottom from `DITCH_IN` 1.3 to `DITCH_OUT` 1.6 (`DITCH_DEPTH` 0.4, dirt, mud or snow by the
  weather), the lip at `DITCH_END` 2.1 (`LIP_DROP` 0.15), a gentle bank to the ground at `ROADSIDE` 4.6 (a car in the trees drives back
  up). `POST_OFFSET` 2.6: where anything standing beside the road starts (hard scenery: `RoadsideDresser.HARD_CLEAR`; undergrowth from
  `SOFT_CLEAR` 1.2, in the ditch). The ditch fades over `DITCH_FADE` 8 m to nothing on cliff sides, at water, on a rockfall's side, within
  `DITCH_CLEAR_ENDS` 15 m of a road's end and `MOUTH_CLEAR` 12 m of a junction (`ditch_at`). Road ends slope away over `APRON` 2 m.
  `RoadBuilder.build(graph, terrain, palette)` → `Track` (rectangular HeightMapShape3D terrain, Roads/Road<n>
  ribbons + shoulders + a `Ditch` body with `surface` metadata, Spurs, Checkpoints spanning the corridor without reaching another
  stretch, `TrackFeatures`: water pools + `WaterSplash` areas, `GuardRail` on cliffs (corrugated W-beam, one mesh
  per rail + one batch of posts, ends turned down, one gap with torn ends, `shaders/guard_rail.gdshader`; like a flag's cloth, a straw bale
  (`shaders/straw.gdshader`), a board, a concrete block or barrier (`weathered` scans), the cars' skins, their number plates (`shaders/number_plate.gdshader`) and the helmets it takes its light
  through `shaders/lamp_cap.gdshaderinc` (its parameters `surface_*`, apart from an including shader's uniforms): the engine's own shading, the
  same pixels by day, but no lamp gives it more than the sun, or the hot band of the beams at night burned it to a white flare that hid the
  road behind it),
  `RallyArch` over the start and finish lines (box truss on plates behind concrete blocks, a banner printed in code
  with the word from the strings, a flag on each tower), invisible walls 36 m out and end caps). The grid's first row
  stands `StageBuilder.GRID_BEFORE_LINE` before the line, in sight of the banner. Face winding for anything hit from
  above: origin → +X → +Z.
- What the ground is: `shaders/road_surface.gdshaderinc` (road and verge, no seam): fine `loose` material, two wandering
  `packed` wheel tracks, scattered `stones`, per surface in `SurfaceMaterials.ROAD_SETS`; `ground_common.gdshaderinc`: two
  sets, a third in patches, hummocks that only tilt the light, a dry ground's specular the dry road's (`GROUND_DRY_SPECULAR`: at the default
  the sky's sheen turned every shade blue-grey; the verge blends the two); under the crowns (`RoadsideDresser.canopy`, the globals
  `canopy_map` and `canopy_rect`, 2 m pixels) the ground lies in shade, and in the forest needles, leaves and moss replace the
  grass (`canopy_shade`, `canopy_litter`, `canopy_moss` per biome in `SurfaceMaterials.BIOME_GROUND`). A scan's flaw is fixed
  in the shader (snow's hollows: `darkest`, `relief`); a dry road keeps `DRY_SPECULAR` (a low sun ahead turned it white).
  `RaceLook` adds clouds (`tools/make_clouds.gd`) and a shade lit by the biome's bounce as well as the sky.
  Car glass is premultiplied (`car_glass.gdshader`, `windshield.gdshader`): only mud and cracks scatter light, so nothing
  hazes a dark forest seen through it.
- On a switchback the next leg is uphill on the side the hairpin turns to: bank on that side, cliff on the
  other (the terrain test probes only open ground).
- `RoadsideDresser` (+ `RoadsideCatalog`): Poly Haven scans and the Sketchfab conifer/birch packs (`node` picks
  one tree from a pack, `unit` 0.01 for the centimetre birches, `foliage` = leaves cut out by alpha (`shaders/leaf.gdshader`)
  and bark (`bark.gdshader`), both taking rain and snow (`plant_weather.gdshaderinc`: snow in clumps on what faces up, sooner
  on what is `low`; rain a rough film of water's sheen, a smooth one looked like frost; one material per material of the scan, no draw call added), `black_ground` = a scan
  whose JPEG atlas has no alpha but a black ground, cut away by `shaders/cut_out_leaf.gdshader`: check a new plant's
  atlas, those cards are opaque black otherwise; `low` = grows in the clearings too; `weathered` = a rock the rain and snow reach,
  `shaders/weathered_scan.gdshader`), a thick edge band
  before the walls and a backdrop beyond (`backdrop` entries stay outside the corridor); nothing on a cliff's
  lip. Scenery is batched by mesh into MultiMeshInstance3D chunks (48-192 m, 96 m for `low`) with visibility ranges: the
  frame cost on this laptop is CPU draw submission, not triangles. `GraphicsQuality` (Settings
  `graphics_quality`, AUTO = Low on integrated GPUs) scales scenery density/range, shadows, SSAO/glow,
  the render scale, the edges (`SCREEN_AA`: FXAA on Low, SMAA from Medium, `MSAA` 2x on High; no TAA: trails round a cabin that
  stands still while the world flies past) and `ANISOTROPY`; Low and the mirrors draw a volume of fog as flat fog (`flatten_fog`:
  as dense and as dim; on Low from dusk on it glows with what the headlights light in the volume, `RaceLook.BEAM_VEIL`); dev scenes take `--quality=0|1|2`. Every rock in the catalog is a whole stone (tested: a scan with no back
  shows as torn strips in the sky); `seat` lets a big one down to the lowest ground round it.
- Every flag in the game is the flag of Turkey: `TurkishFlag` (the law's geometry as a signed distance, `color_at`,
  `image`, `texture`, unit-tested), on the crowd's poles, the arches and their banners, the start's board, the HUD's
  start marker and the car's badges (baked into the model's atlas by `tools/make_badge_flag.gd`); 3:2 always, the hoist at the pole, never on the ground, nothing printed over it. The finish is chequered
  (boards, banner panels), not a flag.
- Rally dressing: `RallyDressing.plan(graph, terrain)` says where everything goes, as data (km boards, time
  control, start, split boards, finish warning, finish, STOP, end bales, chevrons on every hairpin and caution corner except where
  a wrong way leaves it, caution boards, a bale before each rail, tape, flags, parked cars, seats, `spot`s for
  people); `build()` makes `Features/Rally` (batched by mesh, one chunk per place; `Props` collides; meta
  `spectator_spots`, where `Spectators` stands its people), `clearings()` is where `RoadsideDresser` plants nothing tall (a place's ribs, the road's end,
  the view onto each board; `bare` capsules: the footprints of what stands there, not even grass). `RallyProps` is how it
  looks: generated signs, straw and tape
  (`shaders/board.gdshader`, `straw.gdshader`, `cloth.gdshader`), Poly Haven seats and covered car, the Milano '95 as an ordinary car.
  Places: recipe key `"spectators": "left"|"right"` (`StageDesignRules`: at least 2, inside of a corner, never over a
  cliff, beside a wrong way or under an event; `Sightline.screens` opens the side, 10 m past the segment) and `crowd`
  features `StageBuilder` adds on both sides of the start and finish lines. The forest also closes the view past the
  road's end.
- Spectators (`Spectators`, built by `TrackFeatures` at the `spectator_spots`; `SpectatorRules`, pure, tested, the same crowd on every peer from
  the stage's seed): 4-8 people a place, 1.6 m apart or more, the crew's mannequin baked standing (`CrewPose.stand`: the arms by the sides, the
  palms to the thighs) with what its bones weigh on each vertex (CUSTOM0/1), one MultiMesh and one draw call a place (a MultiMesh cannot share
  a skeleton). Dressed when it is baked (`SpectatorClothes`, pure, tested): each piece stands off the body by its cloth along the normals and
  hangs round its limb's axis from where the limb is widest, less a taper (`hang`: a shirt from the chest, 1.5 cm off it and looser down to its
  hem; trousers from the top of the thigh, loose to the shoes, their seat following the pelvis; sleeves from under the shoulder), then is smoothed where it
  folded over the mannequin's grooves (`relax`, the edges stay); its hem over the trousers and theirs over the shoes stand proud, a collar and
  a short sleeve's end roll down to the skin (`EDGE_ROLL`). The arms are an ordinary man's (`SLIM`; the ball the arm turns in at the
  shoulder slimmer and pressed down, `BALL_SLIM`, `BALL_TOP`: dressed it stood like a puffed sleeve), the hair stands off the scalp, the face is
  shaped (`face_relief`: a nose, brows over sunken eyes, lips, a chin). `shaders/spectator.gdshader` turns the arms and the head about the
  standing pose's joints: four ways of standing (arms down, crossed, hands on the hips, a small flag of Turkey held up), the head to the nearest
  car, clothes for the biome by index (`outfit`; a long sleeve put on along the normals from UV2.x; the shirt's hem and top cut straight at
  UV2.y = `_shirt_cut`, the collar's round drawn to the pixel (`collar`), a short sleeve's end at CUSTOM1.y), the face painted to read at 10 m (UV says where, `face_uv`: the eyes in dark
  hollows, brows, the nose's shadow, lips, a short beard on some), the whole head skin under the hair (or the shirt's colour showed where the
  two meet), the fingers relaxed. A place cheers a car going by
  (`thrill(distance, speed)`: within 70 m and faster than 2 m/s; `cheer` comes within half a second and goes in three), a car standing on the grid
  or stuck gets their eyes only; each peer works it out from how it sees the cars move (`RallyCar.GROUP`), never sent. The body carries levels
  of detail (`ImporterMesh.generate_lods`: 32.8k triangles, 4.1k within 9 mm and 1.0k within 31 mm, the engine picking by the error on the
  screen, under a pixel: a place of eight at 10 m and at 40 m differs from full detail in 0.4 % and 0.8 % of its pixels; a MultiMesh picks one
  for the whole place); baked once a session (0.1-0.3 s); on `FINE_SCENERY_LAYER` (not in the mirrors), drawn to 160 m. `route_test --no-crowd`.
- Gag slots and the set piece (law 5): a segment's `gag` {`slot` beside|across_slow|overhead, `side`, `at`} is a `gag` feature (its
  room `StageBuilder.GAG_SLOTS`), `signature` {`kind`, `reach`} a `signature` feature over the whole segment. `TerrainField` widens
  the flat band to their room (`_max_flat`) and lays no ditch through the set piece; `RallyDressing.clearings()` keeps them clear of
  anything tall. `GagDirector` (pure): the run's gags from the room's `gag_seed` (`RaceSettings.resolve`, every race) and the stage's
  seed, three or four, each in a slot of its kind (`CATALOGUE`, data: phase X adds looks); `RaceSession.gags`, printed on the `NET stage`
  line; `--gags=` (a seed, or names joined by `+`) in `route_test` and the race.
- Stage events: `StageEventBuilder` (from `TrackFeatures`) puts `Event<n>` bodies with a trigger area
  before the spot (a fir that falls across the road, rocks off a bank); `StageEvents` (child of the race)
  lets the host decide and every peer play it (`_rpc_stage_event`); boulders are host-simulated props like
  the cans (`_rpc_spawn_boulder`). Offline (route_test) the trigger plays locally.
- `RouteFollower` (the path's own curvature ahead + heading and line corrections: pure pursuit cuts corners by more than a rally
  road is wide; a corner speed planner, `start_delay`, stops at the end of an open path,
  `obstacles` Callable → steers around fallen trunks/boulders at `AVOID_SPEED`) drives a `RallyCar`:
  `--autodrive`, tests, flow-test bots (which also confirm their own recovery offers). `RaceProgress` is the host's gate accounting.
- Dev scene `scenes/dev/route_test.tscn`: `--stage=N|id --start=M --autodrive --chase --overview --weather=N --quality=N --follower=D --follower-delay=S --ride-follower --chips=N --no-road-fx`
  (forces the whole graphics level) `--time=0..3 --dome --follower=D` (a second car D m behind, for the mirrors; `--follower=14+28` three crews)
  `--no-light-pod --no-crowd --names=A+B --crew=... --look=Y+P` and the crew's poses (see the crew above); it has the
  race's weather particles (`WeatherFx`)
  `--view=M+E+H [--view-at=M+E+H]` (a fixed camera E m right of road metre M, H m up) `--quit-after-seconds=N`.
  `RaceSession.settings.stage` builds the same stage on every peer.

## Paper map and pace notes (scripts/map; phase M, `docs/phases/m_map.md`)
- `PaceNotes.build(graph, detail)` → numbered rally calls in stage order ("Sol 3", "Saç tokası sağ", "Kör tepe!",
  "Atlama!", "Su geçişi!", "Uçurum solda!", cautions; Explore adds distances, Redline only the dangers).
- `MapRules` (pure, tested): what each difficulty shows (`contents`: Explore and Rally the route's highlighter, Redline none; the notes'
  detail; the live car marker always) and the sheet's round numbers (scale bar, grid, contour interval and index lines, 1:N, the
  biome's datum for printed heights). The map's truth never changes with the difficulty.
- `MapSheet` (made once a race in `RaceSession._build_route`, `MapSheet.of_track(graph, terrain, track, notes, settings)`, shared by
  every car; 0.1-0.3 s, the land's heights on the worker pool): the page as data, in page pixels (`PAGE` 1216×1152; `world_to_page` /
  `page_to_world`, `page_direction`; a stage whose box prints bigger turned a quarter, `north` then points right). Roads come from
  `RouteGraph.roads()`: one list of {kind, points, width, surface, end (through|dead_end|barrier), end_at, end_turn, landing,
  landing_radius} (the stage per edge, every wrong way up to where a car can go); a new kind of road (a bypass) is an entry there and
  is printed like the others, closed ends included (MapLandmarks puts the barrier or the log pile at `end_at`). Landmarks come from
  `MapLandmarks.collect(graph, plan)` (pure): {kind, position, turn, at, side, text, size, points} out of `RallyDressing.plan` (its meta
  `plan` on `Features/Rally`), whatever a later phase adds to the plan shows by itself (a kind `MapPrint.SYMBOLS` lacks is a building of
  its `size`); the crowd's tape is its place's outline, chevrons one set a corner, arches at the start and finish. Also the route's line
  and arrowheads, gates, a tick at every km board, water, cliffs' hachures (longer where the drop is), banks' ticks, rails as built
  (`GuardRail.gap_of`), hazard pictograms (jump, crest, dip, water, caution, hairpin, a cliff's start; no surprise events) and the
  calls' numbered rings, each on free paper (`_free_spot`, `is_free`: never on another, a road or the frame; a leader line back when
  pushed off), the forest from the dresser's canopy (meta `canopy`, `canopy_rect` on `Dressing`), the legend's entries, title facts.
- `MapPrint`: inks, the fonts (Saira, Inter, JetBrains Mono; no MSDF: their overlapping outlines break it) and every symbol as vectors,
  the same drawing on the map and in the legend; colour is never the only sign (surfaces have a pattern). `MapCanvas` (SubViewport
  1792×1152): the page in a viewport of its own (`Page`: layers Land (`shaders/map_land.gdshader`: relief shading, forest tint and tree
  dots, contours as hairlines at any zoom), Grid, Relief, Places, Roads, Route (the highlighter multiplied, paler behind the car),
  Marks, Frame, Title, Legend, Stamp (`map_stamp.gdshader`)) printed again only when the view or its content changes, at the zoom's
  oversampling (crisp type at 4.5x), then the notes column (the road book's place, a later part) and the car marker, printed only when
  the marker moves. `PaperMap` (created by `Cabin._ready`) is the 3D sheet (`shaders/paper_map.gdshader`: fibre, wear, the folds catch
  the light), `RouteTracker` gives the highlighter's progress; `Cabin` holds `map_state` (CLOSED/OPEN/GONE), the host-side wind risk,
  the 6 s replacement and the map RPCs; `Cabin.setup_map(sheet, notes)`, `canvas.set_crew(number, names)` letters the title block.
  An open map costs about 0.05 ms GPU and 0.03 ms CPU a frame on every level (`--flip-map`; the frame is cheaper with it up, it hides
  the world). Dev: `route_test.tscn --navigator --map-open --autodrive --map-png=P [--map-zoom=Z+X+Y]` (the sheet's picture);
  input actions `map_toggle` (M), `map_reset` (Home).

## Multiplayer (scripts/network, scripts/gameplay)
- `Net` autoload: ENet session + roster `{peer: {name, team, role, ready}}` owned by the host (peer 1).
  Clients send requests (`request_seat`, `set_ready`); the host validates with `RosterRules` (pure, tested)
  and broadcasts. `Net.start_race()` refuses new connections and emits `race_started` on every peer.
- Car physics is driver-authoritative: `BodyNetSync` (child of the body, authority = driver peer) sends
  30 Hz snapshots; other peers freeze the body kinematic and play back 100 ms behind via `SnapshotBuffer`.
  Cans are host-simulated (authority 1). `RallyCar.simulated == false` skips all forces.
- `RaceSession` (node path must match on all peers): host spawns `Cars/Car<team>` and `Props/Can<id>` via
  `authority call_local reliable` RPCs; each peer binds its own seat (camera + `PlayerCarInput`/`CabinInput`).
  `Cabin` (authority 1) owns window state and can stock; seat holders ask, host validates against the roster.
- Recovery (spec §16): `RallyCar.needs_recovery` rides in the snapshot extras; the host runs `RecoveryRules`
  per team (3 s stuck → offer, confirmations with an 8 s window, 1 seat = hold R; critical damage holds the
  offer open while the car crawls), picks the spot with
  `RecoveryAnchor.find(graph, position, next_gate)` and sends `_rpc_recover_car`; the simulating peer applies
  `reset_to`. `PlayerCarInput.local_recovery` and `RouteFollower.self_recover` are false inside a session.
- Cabin (spec §9-10): `Cabin` is the one state system for windows (state + cracked), windshield, dirt,
  wipers, per-seat exposure and faints, the map and the cans; host authority, `_broadcast(rpc, args)` runs
  the RPC everywhere or just locally offline. `SeatEffects` (CanvasLayer) shows the local seat's view of it.
  Input: Q/E windows, F kick windshield (navigator), T wipers (driver), M map, L dome lamp, LMB throw, 1-4 gestures. Fainted seats are
  checked by `PlayerCarInput`, `RouteFollower` and `CabinInput` via `cabin.is_fainted(role)`.
- Seat state (`Cabin.seats[role]`, `CrewRules.Seat`): what a seat's player does with the head and the hands (the look from the seat camera's
  `head_angles()`, a gesture, a job and how many so far, the gun up) is the seat's own peer's: `CabinInput` (gestures `gesture_left/straight/right/slow`,
  1-4 and the d-pad, rebindable; a gesture folds the navigator's map) and `ShockInput` write it, `Cabin._keep_local_seat` sends its 4 bytes 10 times a
  second (channel 3, unreliable) to the host, which checks the roster and the rate and passes it to every other player (`_rpc_seat`); a change of the
  hands prints `NET seat team N role gesture .. job .. gun .. look Y P` (nettest). `CrewRules.one_handed`: the driver steers one-handed
  (`PlayerCarInput`) while a hand is on the gun, a gesture, the window, the wipers or the horn, and no better with both off (not for the
  handbrake or a gear change while the other holds the rim). A key let go while the window had lost the keyboard never says so: `CabinInput`
  and `ShockInput` let a gesture and the gun go once their action is no longer pressed.
- Stones on the windshield (`StoneChipRules`, pure, the host's): rare alone (one run in ten of a bot cracks, `tools\chip_odds.ps1`), much likelier within `FOLLOW_RANGE` 30 m behind a car on loose ground, more the closer and
  faster, none on tarmac, snow, mud or wet; `RaceSession._measure_gaps` gives each `Cabin.gap_ahead` from the trackers. `Cabin.stone_hits`, `_rpc_stone_chip`: the first stone is a bullseye (`windshield.gdshader` `chipped`, where
  `WindshieldGlass.crack_center` says the crack will start: a centimetre, a dark pit, a half moon of crushed glass, a ring that flares
  like a crack's lines), the second `CRACKED`, more up to `MOST_HITS` make it worse; a stone on glass is heard in that car only.
- Shock gun (GAME_DESIGN §6, `scripts/gameplay/shock_*.gd`): `ShockRules` (pure, tested, kept by the host): 2 darts a stage,
  refilled at each split, 1.2 s reload, 8 m range; between cars the dart leaves and enters through an opening (`Cabin.is_open_for_shot`);
  inside one cabin it always reaches. Room rule `settings.shock` (`Mode`: off, rivals only, everyone). `ShockInput` (the local seat): hold
  `shock_aim` (right mouse, right stick click) to raise it (crosshair with the darts left), `cabin_throw` fires along the view and
  picks the first head near the line → `RaceSession.request_shock` → the host's `_handle_shock` checks the seat, darts, openings, range, line
  of sight and immunity; a hit is `Cabin.host_shock`: the same 6 s faint, then 4 s immune. Every peer: `_rpc_shock_fx` → `ShockFx`
  (wires, sparks, flash, pop and crackle), `_rpc_shock_darts`, `shock_landed` → the HUD's feed; the victim's view flickers
  (`SeatEffects`). The hands: `Cabin.seats[role].aiming` (synced with the seat): an aiming driver steers one-handed, an aiming navigator folds the
  map and throws no cans; the gun shows in the right hand (`CrewRig`).
- Damage (spec §8): the driver's `RallyCar.impact` (body contact; a landing on the wheels does not count) is
  judged by the host (`_rpc_report_impact` from a client driver), which keeps a `VehicleDamage` per team, sends
  crash sounds + a camera jolt (`_rpc_crash_fx`) and `_rpc_set_damage`; every peer calls `RallyCar.apply_damage`,
  which drives `CarDamageFx` (Model/DamageFx: bonnet unlatches and lifts with speed, then tears off; bumpers
  sag/fall; engine steam then black smoke; a recovery restores the parts). Critical
  damage sets `needs_recovery` on the host. Snapshot extras carry steer, compressions, stuck flag, surface,
  throttle, horn and brake (remote cars' sound and lamps).
- Dev bootstrap `scenes/dev/net_test.tscn` takes `--role --port --host --players --as-player --local
  --autodrive --test-script --quit-after-seconds`; without `--instance` it takes the first free seat.
- `Voice` autoload (scripts/audio): `VoiceCapture` (AudioServer input API, 48 kHz → 16 kHz mono) → mu-law
  20 ms packets → host `_relay` (range check through the world provider: `RaceSession.voice_position/anchor`)
  → `VoicePlayback` (AudioStreamPlayer3D + AudioStreamGenerator, jitter buffer) parented to the speaker's seat.
  Headless (Dummy audio driver) never opens the mic; `Voice.start_fake_transmit()` sends a tone for tests.
- Car sound: `CarAudio` (child of every `RallyCar`) cross-fades three engine loops by `Gearbox` rpm (pure, tested),
  plus gravel crunch / rumble / squeal by surface and slide, water, wind for the crew, crashes and the horn (H).
  Assets come from `tools/cut_audio.py` (raw files in git-ignored `raw_assets/audio/`, fetched by
  `tools/fetch_audio.py`); loops carry a smpl chunk. Players do not play headless.
- Falling weather: `WeatherFx` (rain, snow or a dust storm in one box of particles that follows the camera, rain and thunder sounds; lit
  from dusk on): round flakes, soft wisps, drops that thin at both ends, nothing within `NEAR_FADE` 1.5 m of the eye (the box knows no cabin).
- Reflections: `Environment.ssr_*` from Medium up (`GraphicsQuality.apply_look`, also the global `wet_mirror` that lets
  standing water on the road be a real mirror); it only sees opaque surfaces, so water pools march their own ray
  (`puddle.gdshader`, `reflection_steps`, 0 on Low).
- Glass: `WindshieldGlass` puts the Cabin's dirt (`windshield.gdshader`: a film plus a few small flecks that stay apart, by the square of the dirt; a threshold of noise that joins up reads as camouflage), crack and wipers on the
  windshield mesh (its own plane is measured from the triangles); `SeatEffects` keeps only the face-hit flash and the faint. The dirt takes the
  road's colour (`WindshieldGlass.tint`, each road for as much as it put there, from `CarDirtRules.glass_tint`: dust in the road's colour, brown
  mud and splash water, grey slush; the colour's alpha is how thick a film it lays) and is a layer the light comes through: what it takes from
  the view it scatters on (the screen copy the seat's motion blur makes, blurred, and a forward lobe round a light beyond the glass, so it
  glows against a low sun); the glass's inside sees the dark cabin (AO). A door mirror's grime takes the same colour (`CarMirrors.grime_filter`).
- Cracks: `CrackPicture` (pure, seeded per car) lays the lines (a star from the hit with a few long ones, branches, rings round it, a little star per
  later stone, `spread(hits)` how far they have run) and bakes a picture of the distance to them (signed distance, the way a line runs, when it shows,
  how far to trust it). `shaders/glass_crack.gdshaderinc` draws them as thin as they are at any distance (fading past 4-12 m) and lights them in a
  `light()` of its own (`glass_light`, shared by the windshield and the side panes): a line flares where it lies square to the light passing the pane,
  most against a light ahead, weakly for one on the eye's side; the bullseye's crushed glass is lit from anywhere. The windshield's picture is baked on a
  worker after the first stone (about 11 ms), a cracked side pane's on a worker too (`CarModel._on_window`: the glass at once, its
  picture a frame or two later), the broken mirror's at once. A side pane's mesh runs x
  along the car and z up (`car_glass.gdshader` `PANE_FROM`, `PANE_UV`, `CarModel.PANE_METRES`). route_test `--cracked-window=0|1`.
- Editor-launched games need `--accessibility disabled` too on this PC: set once via Beckett
  `call_method target=res://tools/editor_run_args.gd method=apply` (editor setting `run/main_run_args`).

## Tests
- Physics tests extend `PhysicsTestCase` and wait with `wait_ticks(n)` (exact ticks; GUT's
  `wait_physics_frames` overshoots in loops). `tools\test.ps1` runs with `--fixed-fps 120`, so physics
  runs faster than real time and results are deterministic run to run.
- GUT ignores errors raised in `before_each`; `PhysicsTestCase.after_each` fails the test on them.
  Subclasses that override `after_each` must call `super()`.
- Spec numbers (3 s recovery delay, etc.) are asserted against the spec value, not the config value,
  so a tuning change cannot silently break the spec.
- Print measured values with `gut.p()` so tuning changes are visible in the output.
- `tests/unit/test_scripts_compile.gd` compiles every game script: most are only loaded by the scenes that use them.
- Skeleton modifiers run headless; a body's drawn pose (after them) is read on `Skeleton3D.skeleton_updated`, outside it a bone's global pose is
  the one before them (`tests/unit/vehicles/test_crew_rig.gd` `_drawn`).
- `ResultsPanel` writes finishes into user://records.cfg unless `Flow.args` has `autodrive` (bots) or it is a flow test: a test or
  a scratch script that opens it sets that first.
- A label from `UiTheme.label` wraps, and asks a container for no width of its own: give it a width (a `custom_minimum_size`, a full-width
  column) or turn wrapping off. In a grid it came out a letter a line (`tests/unit/ui/test_results_panel.gd`). Look at every screen you touch.

## Beckett MCP (addons/beckett)
- The editor plugin is the MCP server: `http://127.0.0.1:8770/mcp/<token>`, token auth on. It only runs while an
  editor (GUI, or `tools\editor.ps1 -Headless`) has this project open.
- The token is in `.mcp.json` (and Beckett's `.mcp.json.*` backups), `.cursor/`, `.codex/config.toml`,
  `.beckett/` and `logs\editor.log`; all gitignored (so is `AGENTS.md`, Beckett's copy of this file). Never commit or print them. Mask it when showing editor logs:
  `-replace '/mcp/[0-9a-f]{32}', '/mcp/<token>'`.
- Lite edition: no input simulation, no export, watches one game instance at a time. Use the CLI tools above for
  multi-client runs, tests and exports.
- Keep one editor per project: a second one moves to port 8772 and rewrites `.mcp.json`.

## Gotchas found during setup
- Never pass `-d` in unattended runs: the stdout debugger can hang at a `debug>` prompt.
- `--headless` means the Dummy audio driver and no rendering: mic and screenshot checks need a window.
- Official export templates (debug and release) refuse a scene path or `--path` on the command line, so exported
  builds always start at the main scene. Run a single scene with the editor binary (`tools\launch.ps1 -Scene`).
- Smart App Control is ON on this PC. It blocked the unsigned exported console wrapper (the preset exports none);
  the exported `RADDY.exe` itself ran. No paid code signing (zero-cost rule): the itch.io page must tell players
  how to get past the SmartScreen warning ("More info" → "Run anyway").
- All instances share `user://` (Godot has no user-data-dir flag): namespace per-instance files by `--instance`.
- Two clients dropping in the same network poll: ENet frees the second one's channels before Godot reports
  it, so any send to it logs "Unable to send packet on channel 0". `Net` defers its leave handling past the
  poll, but SceneMultiplayer's own leave notice still hits it; test instances quit host first, clients after.
- Local multiplayer tests: bind the ENet host to `127.0.0.1` (verified: host + 2 clients, RPCs both ways, no
  firewall prompt). Binding `*` for internet play triggers the Windows Firewall prompt.
- Mic API: `AudioServer.set_input_device_active()` / `get_input_frames()` (4.6+, marked experimental).
  Windows default input here is the virtual "iTop Microphone"; the real mics are
  "Mikrofon Dizisi (Realtek(R) Audio)" (laptop array) and "Mikrofon (Realtek(R) Audio)" (jack).
- Stock 4.7.2 cannot step physics manually, so there is no rollback/resimulation of RigidBody vehicles.
- Godot 4.7.2's AccessKit (accessibility) panics at window creation (exit 0xC0000409, "subclass.rs:109") when the
  Windows global atom table is full; this PC hit it after ~17 days of uptime and only a reboot clears it (the
  2026-10-12 reboot did). Every windowed tool run and the desktop "RADDY Editör" shortcut still pass
  `--accessibility disabled` (`$GodotWindowArgs`) as a guard.
- IObit Malware Fighter's anti-ransomware guard (`C:\ProgramData\IObit\IObit Malware Fighter\rsconfig.ini`
  lists 246 protected extensions, incl. .ps1 .png .csv .txt) denies some processes (Git Bash's grep/head/cp,
  sometimes pwsh) access to such files under the user folders, and can lock a file for every process. Symptoms:
  "Access denied" with a normal ACL. Python and Godot usually still read; a locked tracked file can be restored
  with Python: write `git show HEAD:path` to `path.restore`, then `os.replace` onto the path. Do not change the
  security software yourself; the user was asked to uninstall it (it also leaked the atom table).
- Smart App Control blocks numpy's DLLs (first `numpy.fft`, now any numpy import): the Python tools
  (`tools/cut_audio.py` etc.) are pure Python.
- If every Godot run suddenly takes 20 s+ to start (nettest timings slip, `--quit-after 5` takes 19 s), check
  for a leftover `chrome-headless-shell.exe` (Playwright, under `%LOCALAPPDATA%\ms-playwright`) rendering WebGL
  in software: a Sketchfab tab left in the built-in browser ate 65% of the CPU once. Kill its process tree.
- Game start is dominated by GDScript compilation (~35 scripts, 3-10 s on this laptop while other apps
  load the CPU; `net_test.tscn` prints `NET boot wall=`). Four instances booting at once take 20-30 s, so
  `tools\nettest.ps1` budgets 40 s and times its scripted actions from race start, not from launch.
- With the editor open, games launched by `tools\launch.ps1` make Beckett log "rejected a peer with a
  missing/invalid handshake token" once per connection attempt (the stub dials the editor's runtime port).
  Harmless; clear the editor Output panel when it gets slow.

## Third-party (pinned)
- `addons/beckett`: Beckett Lite v1.16.0, MIT, GitHub release zip (sha256 35b1274d…20ac). The Asset Library copy is older.
- `addons/gut`: GUT v9.7.1, MIT, the `godot_4_7` line. The Asset Library's 9.6.1 targets 4.6: do not "update" from there.
- Researched, not installed yet: TwoVoIP v6.5 for Opus voice (not 6.6: Windows editor crash, issue #107),
  netfox + noray for NAT punch-through/relay.
