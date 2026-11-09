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
- `project.godot` pins Jolt Physics, 120 physics ticks, D3D12, `audio/driver/enable_input`, and turns off
  Blender/FBX2glTF import. `tests/unit/test_project_settings.gd` guards these.

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
- `tools\perf.ps1 [-Stage 0] [-Quality 1] [-Seconds 30] [-Start 0]`: the bot drives, windowed at 1920x1080, vsync off
  (`tools/perf_probe.gd`): build ms, then `PERF fps_avg p95_ms p99_ms draw_calls primitives physics_ms` lines; its cpu/gpu render
  times read 0 here. This PC's fps wander run to run: compare alternating runs, never one run each.
- `tools\stage_shots.ps1 [-Stage n] [-Quality 1] [-Weather 0 | -OwnWeathers] [-Tag now] [-Chase]`: every place worth a
  look (`tools/list_stage_spots.gd`) from the driver's seat, one process per stage and weather (`tools/stage_shots.gd`, about
  a minute each), plus an overview per stage, into `reports\screenshots\stages\<Tag>\<stage>\w<weather>\`. The overview is a
  check of the road's layout: straight down and orthographic, it shows hardly any trees.
- `tools\capture_window.ps1 -Instance N -Out reports\screenshots\x.png`: PNG of a windowed instance even when
  covered (PrintWindow); use it for multi-window visual checks since Beckett sees one game only.
- `tools\screenshot.ps1 -Scene res://x.tscn -Frames 120 -Out reports\screenshots\x.png [-ExtraArgs "--a,--b"]`:
  Movie Maker capture; open the PNG with Read. The PNG has the project viewport size; `-Resolution` only
  sizes the window. 60 movie frames = 1 s of game time.
- The main scene is `scenes/ui/main_menu.tscn`. Screenshots of a running room or race: `screenshot.ps1 -Scene
  res://scenes/ui/main_menu.tscn -ExtraArgs "--flow-test,--role=server,--players=1,--autodrive"`.
- `tools\export_windows.ps1 [-Debug]`: `builds\windows\RADDY.exe` via the "Windows Desktop" preset.
- `tools\editor.ps1 [-Headless | -Stop]`: open the editor (Beckett MCP runs inside it).
- `tools\mic_check.ps1 [-Device <name>]`: input level per microphone (user speaks while it listens).
- Baked assets: `tools/make_gauge_face.gd` (needs a window), `tools/make_badge_flag.gd`, `tools/make_clouds.gd`, `tools/make_exhaust_pops.py`,
  `tools/make_shock_sounds.py`. Downloads, all free and no login: `tools/fetch_polyhaven.py`, `fetch_ambientcg.py`,
  `fetch_assets.py`, `fetch_audio.py` (only what the owner approved; `ASSET_LICENSES.md` gets a row);
  `tools/texture_imports.py` sets 3D import options on new textures.

## Specs and plan
- `docs/RADDY_MEGA_MASTER_PROMPT_FINAL.md` is the main spec; `docs/RADDY_SUPPLEMENT_*.md` add art direction,
  engineering and MCP rules. `docs/DEVELOPMENT_PLAN.md` merges them into phases and tracks status; update it
  when a feature is verified. `docs/GAME_DESIGN.md` is the design bible: pillars, the rules every phase builds against,
  the 9.8 quality bar; it records the decisions taken since the spec. `docs/ART_DIRECTION.md` and
  `docs/REFERENCE_RESEARCH.md` hold the research. `CHANGELOG.md` is for players, `TEST_PLAN.md` holds what only people can check.

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
- Everything on the car works, on every peer. `CarParts` cuts what moves out of the Milano's one-piece meshes (by the
  island inside a box, test_car_parts.gd pins the triangle counts; meshes shared by every car, in car space). `CockpitRules`
  (pure) says what every needle, lamp and lever shows; `CarCockpit` puts it on the car near the camera: the instrument
  panel (`shaders/gauge_panel.gdshader` over a face baked by `tools/make_gauge_face.gd`, keep both layouts in step),
  pedals, H-gate lever, fitted handbrake. `CarLamps`: tail lights only with the headlights, brake, reversing, hazards
  on a stuck or critical car, the dome lamp (`Cabin.dome_on`, L, the map holder's; shows in the glass through
  `shaders/glass_ghost.gdshaderinc`). `CarHeat`: pops and flame on a lift at high revs, front discs that glow after
  really hard braking. The wheel turns about `CarModel.WHEEL_AXIS` and is set in so the dials show through the rim.
  `Cabin` slides the side panes into the doors (along their own slant, cut at the door's sill: `sill` in `car_glass.gdshader`); the
  sun visors come down for a low sun ahead, the glove box's lid opens when a can is taken, the radio's readout lights with the engine
  (`CarCockpit`, `CockpitRules`); `GraphicsQuality.CABIN_LAYER` is what is inside a car, which the car lamps' shadowless beams leave out;
  `WindshieldGlass` sweeps the model's own wipers on their hinges and
  tells the shader the ring each blade passes. The handbrake comes with the snapshot extras; gear and revs come
  from each peer's `CarAudio.gearbox`.
- Mirrors: `CarMirrors` on every car, plain glass until `CarModel.bind_seat(camera)` (local seat only, never
  headless). Each mirror is a `SubViewport` + camera at the eye reflected in the glass, frustum fitted to the glass
  (`MirrorMath`, tested against the engine's projection; the picture is flipped by the display, `mirror_glass.gdshader`).
  Linear HDR picture, no tone mapping: the main view grades it with the world. Turns and sizes per level in
  `GraphicsQuality`; at most one mirror a frame, only those the seat can see. A mirror's camera leaves out
  `CarMirrors.SELF_LAYER` (glass, housings, the motion blur), `GraphicsQuality.FINE_SCENERY_LAYER` (`RoadsideDresser.is_fine`, and the boards' words and tape go with their boards: low,
  backdrop, no collision unless `tall`, or `fine` in the catalog) and `RaceLook.SUN_LAYER`: it has a shadowless sun of its own
  (`MIRROR_SUN_LAYER`, which it clears from the main camera). `RaceLook`'s `SunInTheSky` is what the sky shows, the same
  for every camera: different sky lights per camera would rebuild the sky's reflections every time the view changes.

## Screens and flow (scripts/core, scripts/ui, scripts/gameplay/race.gd)
- Autoloads: `Settings` (user://settings.cfg: language, volumes, voice, effects, driving assist, graphics, key bindings; tests set
  `Settings.save_path`), `Flow` (menu → lobby → race → results → lobby; leaves dev scenes alone).
- `RoomCode` packs IPv4 + port into a checked `XXXX-XXXX-XXXX` code; `PortOpener` (UPnP, thread) gives the
  internet code when the router allows it (CGNAT detected). `RaceSettings` resolves Random / Surprise Rally
  (keys `stage`, `difficulty`, `weather`, `shock`; the stage gives `biome` and `seed`); `BiomeRules` applies
  weather/difficulty to the stage. UI strings: `data/locale/strings.csv` (TR/EN).
- Race start: `Net.report_race_loaded()` from every player; the host spawns only when `Net.all_players_loaded()`
  (scene changes are deferred: spawn RPCs sent earlier are lost), then a 3 s countdown with `car.input_locked`.
  Results: host clock + recovery penalty, `RaceResults.rows()`, published when all finished/left or 120 s after
  the first finisher. `StageRecords` (user://records.cfg, per PC, section `best_v<StageCatalog.LAYOUT>`: bump `LAYOUT` when
  the roads change so much that old times mean nothing) keeps the best time per stage and gives
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
  ones a stage comes in). A recipe is segments (`len`, `turn`, `rise`, `crest`/`jump`/`dip`, `water`, `cliff`/`bank`
  left|right|both with `drop`/`wall`, `surface`, `caution`, `falling_tree`/`rockfall` left|right, `decoy`, `spectators`
  left|right); `StageBuilder.build(stage)` → `RouteGraph` (START → WAYPOINT(s) where the surface changes →
  FINISH, 2 m polylines + heights, `features` by distance, gates: start line at 40 m, two splits, finish 70 m
  before the end). `graph.sample(distance)`, `route_distances()`, `RouteIndex` (nearest road point + distance
  along) and `RouteTracker` (follows a car along the stage; progress counts only within `ON_ROAD` 14 m of it) work in
  metres along the road. Preview layouts with a script that draws `graph.main_route_points()` into an Image.
- Two judges, both must stay empty for every stage (tests/unit/procedural/test_stage_builder.gd). `RouteValidator.validate()`,
  playable: length, radius >= 11 m, grade <= 30 %, no crossing, stretches >= 30 m apart, width >= 3.6 m and never stepping
  along a stage (ditches run unbroken), `_check_spurs`. `StageDesignRules.check()`, a good rally stage (GAME_DESIGN §4): 2-4 km,
  a danger at least every 500 m (`worst_danger_gap`, on the summary notes), the sightline budget, 3-6 junctions 150 m apart and
  never on the side the road itself turns to, at least 2 places for spectators. When a stage fails, fix the recipe, never the
  threshold. Width: the stage's own (3.6-5.0 m) + `RaceSettings.WIDTH_OFFSET` (Explore +0.8, Redline -0.2), set by
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
  per rail + one batch of posts, ends turned down, one gap with torn ends, `shaders/guard_rail.gdshader`),
  `RallyArch` over the start and finish lines (box truss on plates behind concrete blocks, a banner printed in code
  with the word from the strings, a flag on each tower), invisible walls 36 m out and end caps). The grid's first row
  stands `StageBuilder.GRID_BEFORE_LINE` before the line, in sight of the banner. Face winding for anything hit from
  above: origin → +X → +Z.
- What the ground is: `shaders/road_surface.gdshaderinc` (road and verge, no seam): fine `loose` material, two wandering
  `packed` wheel tracks, scattered `stones`, per surface in `SurfaceMaterials.ROAD_SETS`; `ground_common.gdshaderinc`: two
  sets, a third in patches, hummocks that only tilt the light. A scan's flaw is fixed in the shader (snow's hollows:
  `darkest`, `relief`); a dry road keeps `DRY_SPECULAR` (a low sun ahead turned it white). `RaceLook` adds clouds (`sky_cover`, baked by
  `tools/make_clouds.gd`) and a shade lit by the biome's bounce as well as the sky.
  Car glass is premultiplied (`car_glass.gdshader`, `windshield.gdshader`): only mud and cracks scatter light, so nothing
  hazes a dark forest seen through it.
- On a switchback the next leg is uphill on the side the hairpin turns to: bank on that side, cliff on the
  other (the terrain test probes only open ground).
- `RoadsideDresser` (+ `RoadsideCatalog`): Poly Haven scans and the Sketchfab conifer/birch packs (`node` picks
  one tree from a pack, `unit` 0.01 for the centimetre birches, `foliage` = alpha scissor, `black_ground` = a scan
  whose JPEG atlas has no alpha but a black ground, cut away by `shaders/cut_out_leaf.gdshader`: check a new plant's
  atlas, those cards are opaque black otherwise; `low` = grows in the clearings too; `weathered` = a rock the rain and snow reach,
  `shaders/weathered_scan.gdshader`), a thick edge band
  before the walls and a backdrop beyond (`backdrop` entries stay outside the corridor); nothing on a cliff's
  lip. Scenery is batched by mesh into MultiMeshInstance3D chunks (48-192 m, 96 m for `low`) with visibility ranges: the
  frame cost on this laptop is CPU draw submission, not triangles. `GraphicsQuality` (Settings
  `graphics_quality`, AUTO = Low on integrated GPUs) scales scenery density/range, shadows, SSAO/glow,
  the render scale, the edges (`SCREEN_AA`: FXAA on Low, SMAA from Medium, `MSAA` 2x on High; no TAA: trails round a cabin that
  stands still while the world flies past) and `ANISOTROPY`; Low and the mirrors draw a volume of fog as flat fog (`flatten_fog`:
  as dense and as dim); dev scenes take `--quality=0|1|2`. Every rock in the catalog is a whole stone (tested: a scan with no back
  shows as torn strips in the sky); `seat` lets a big one down to the lowest ground round it.
- Every flag in the game is the flag of Turkey: `TurkishFlag` (the law's geometry as a signed distance, `color_at`,
  `image`, `texture`, unit-tested), on the crowd's poles, the arches and their banners, the start's board, the HUD's
  start marker and the car's badges (baked into the model's atlas by `tools/make_badge_flag.gd`); 3:2 always, the hoist at the pole, never on the ground, nothing printed over it. The finish is chequered
  (boards, banner panels), not a flag.
- Rally dressing: `RallyDressing.plan(graph, terrain)` says where everything goes, as data (km boards, time
  control, start, split boards, finish warning, finish, STOP, end bales, chevrons on every hairpin and caution corner except where
  a wrong way leaves it, caution boards, a bale before each rail, tape, flags, parked cars, seats, `spot`s for
  people); `build()` makes `Features/Rally` (batched by mesh, one chunk per place; `Props` collides; meta
  `spectator_spots` for A5), `clearings()` is where `RoadsideDresser` plants nothing tall (a place's ribs, the road's end,
  the view onto each board; `bare` capsules: the footprints of what stands there, not even grass). `RallyProps` is how it
  looks: generated signs, straw and tape
  (`shaders/board.gdshader`, `cloth.gdshader`), Poly Haven seats and covered car, the Milano '95 as an ordinary car.
  Places: recipe key `"spectators": "left"|"right"` (`StageDesignRules`: at least 2, inside of a corner, never over a
  cliff, beside a wrong way or under an event; `Sightline.screens` opens the side, 10 m past the segment) and `crowd`
  features `StageBuilder` adds on both sides of the start and finish lines. The forest also closes the view past the
  road's end.
- Stage events: `StageEventBuilder` (from `TrackFeatures`) puts `Event<n>` bodies with a trigger area
  before the spot (a fir that falls across the road, rocks off a bank); `StageEvents` (child of the race)
  lets the host decide and every peer play it (`_rpc_stage_event`); boulders are host-simulated props like
  the cans (`_rpc_spawn_boulder`). Offline (route_test) the trigger plays locally.
- `RouteFollower` (the path's own curvature ahead + heading and line corrections: pure pursuit cuts corners by more than a rally
  road is wide; a corner speed planner, `start_delay`, stops at the end of an open path,
  `obstacles` Callable → steers around fallen trunks/boulders at `AVOID_SPEED`) drives a `RallyCar`:
  `--autodrive`, tests, flow-test bots (which also confirm their own recovery offers). `RaceProgress` is the host's gate accounting.
- Dev scene `scenes/dev/route_test.tscn`: `--stage=N|id --start=M --autodrive --chase --overview --weather=N --quality=N`
  (forces the whole graphics level) `--dusk --follower=D` (a second car D m behind, for the mirrors)
  `--view=M+E+H [--view-at=M+E+H]` (a fixed camera E m right of road metre M, H m up) `--quit-after-seconds=N`.
  `RaceSession.settings.stage` builds the same stage on every peer.

## Paper map and pace notes (scripts/map)
- `PaceNotes.build(graph, detail)` → numbered rally calls in stage order ("Sol 3", "Saç tokası sağ", "Kör tepe!",
  "Atlama!", "Su geçişi!", "Uçurum solda!", cautions; Explore adds distances, Redline only the dangers).
  `MapCanvas` (SubViewport, 1792×1152) draws the stage (turned sideways when it runs north-south), hazards, every wrong
  way as red dashes with a crossed-out disc by its mouth, gates as lines across the road, numbered rings and gate labels
  on free paper (`_free_spot`: never on each other, the road or a cross) and the notes column;
  `MapCanvas.contour_for` is computed once per race. `PaperMap` (created by `Cabin._ready`) is the 3D sheet; `Cabin` holds
  `map_state` (CLOSED/OPEN/GONE), the host-side wind risk, the 6 s replacement and the map RPCs.
  Dev: `route_test.tscn --navigator --map-open --autodrive`; input actions `map_toggle` (M), `map_reset` (Home).

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
  Input: Q/E windows, F kick windshield (navigator), T wipers (driver), M map, L dome lamp, LMB throw. Fainted seats are
  checked by `PlayerCarInput`, `RouteFollower` and `CabinInput` via `cabin.is_fainted(role)`.
- Shock gun (GAME_DESIGN §6, `scripts/gameplay/shock_*.gd`): `ShockRules` (pure, tested, kept by the host): 2 darts a stage,
  refilled at each split, 1.2 s reload, 8 m range; between cars the dart leaves and enters through an opening (`Cabin.is_open_for_shot`);
  inside one cabin it always reaches. Room rule `settings.shock` (`Mode`: off, rivals only, everyone). `ShockInput` (the local seat): hold
  `shock_aim` (right mouse, right stick click) to raise it (crosshair with the darts left), `cabin_throw` fires along the view and
  picks the first head near the line → `RaceSession.request_shock` → the host's `_handle_shock` checks the seat, darts, openings, range, line
  of sight and immunity; a hit is `Cabin.host_shock`: the same 6 s faint, then 4 s immune. Every peer: `_rpc_shock_fx` → `ShockFx`
  (wires, sparks, flash, pop and crackle), `_rpc_shock_darts`, `shock_landed` → the HUD's feed; the victim's view flickers
  (`SeatEffects`). The hands: `Cabin.aiming[role]`: an aiming driver steers one-handed, an aiming navigator folds the map and throws no cans.
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
- Reflections: `Environment.ssr_*` from Medium up (`GraphicsQuality.apply_look`, also the global `wet_mirror` that lets
  standing water on the road be a real mirror); it only sees opaque surfaces, so water pools march their own ray
  (`puddle.gdshader`, `reflection_steps`, 0 on Low).
- Glass: `WindshieldGlass` puts the Cabin's dirt (`windshield.gdshader`: a film of dust plus specks that stay apart; a threshold of noise that joins up reads as camouflage), crack and wipers on the
  windshield mesh (its own plane is measured from the triangles); `SeatEffects` keeps only the face-hit flash and the faint.
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
