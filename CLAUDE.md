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
  results, back to the room, quit (`--flow-test`, see `scripts/core/flow.gd`). Exit 0 = pass (~3.5 min).
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

## Specs and plan
- `docs/RADDY_MEGA_MASTER_PROMPT_FINAL.md` is the main spec; `docs/RADDY_SUPPLEMENT_*.md` add art direction,
  engineering and MCP rules. `docs/DEVELOPMENT_PLAN.md` merges them into phases and tracks status; update it
  when a feature is verified. `docs/ART_DIRECTION.md` and `docs/REFERENCE_RESEARCH.md` hold the research.

## Vehicle code (scripts/vehicles)
- `RallyCar` (RigidBody3D) simulates in `_integrate_forces`: ray wheels cast by the car, spring/damper/bump stop,
  slip-angle tyres with a cornering-priority friction circle, AWD drive, handbrake, anti-roll, drag,
  oversteer assist, impact and recovery detection. It never reads Input.
- Whoever owns the car writes `car.controls` (`VehicleControls`) before each tick: `PlayerCarInput` locally,
  later the network layer, and tests. Tunables live in `VehicleConfig` (`data/vehicles/rally_hatch.tres`).
- Surfaces: colliders set metadata `surface` (see `Surface`); untagged ground is gravel.
- Dev scene `scenes/dev/vehicle_test_track.tscn` (`--autodrive` user arg circles) for car tuning.

## Screens and flow (scripts/core, scripts/ui, scripts/gameplay/race.gd)
- Autoloads: `Settings` (user://settings.cfg: language, volumes, voice, effects, key bindings; tests set
  `Settings.save_path`), `Flow` (menu → lobby → race → results → lobby; leaves dev scenes alone).
- `RoomCode` packs IPv4 + port into a checked `XXXX-XXXX-XXXX` code; `PortOpener` (UPnP, thread) gives the
  internet code when the router allows it (CGNAT detected). `RaceSettings` resolves Random / Surprise Rally
  (keys `stage`, `difficulty`, `weather`; the stage gives `biome` and `seed`); `BiomeRules` applies
  weather/difficulty to the stage. UI strings: `data/locale/strings.csv` (TR/EN).
- Race start: `Net.report_race_loaded()` from every player; the host spawns only when `Net.all_players_loaded()`
  (scene changes are deferred: spawn RPCs sent earlier are lost), then a 3 s countdown with `car.input_locked`.
  Results: host clock + recovery penalty, `RaceResults.rows()`, published when all finished/left or 120 s after
  the first finisher. `StageRecords` (user://records.cfg, per PC) keeps the best time per stage and gives
  bronze/silver/gold from the stage length (`MEDAL_SPEEDS`); results show the medal and a new record,
  the room shows the medal times and the record. Host buttons: same stage / next stage (`Net.start_race(settings, true)`) / back to room.
- UI is built in code with `UiTheme` (static helpers must use `TranslationServer.translate`, not `tr`).
  Canvas layers: SeatEffects 5, RaceHud 8, ResultsPanel 12, PauseMenu 15, SettingsMenu 20.
- `RaceHud` is drawn in code (`HudStageBar`, `HudCluster` rev counter/gear/speed) in `UiTheme.hud_font()`
  (Windows' Bahnschrift via SystemFont, nothing shipped). The race captures the mouse for free look
  (`CockpitCamera.look`) unless a menu is open or it is a flow test.

## Stages (scripts/procedural)
- Six named point-to-point stages in `StageCatalog` (two per biome; names `STAGE_<ID>` in strings.csv). A recipe
  is segments (`len`, `turn`, `rise`, `crest`/`jump`/`dip`, `water`, `cliff`/`bank` left|right|both, `surface`,
  `width`, `caution`, `falling_tree`/`rockfall` left|right); `StageBuilder.build(stage)` → `RouteGraph` (START → WAYPOINT(s) where surface/width change →
  FINISH, 2 m polylines + heights, `features` by distance, gates: start line at 40 m, two splits, finish 70 m
  before the end). `graph.sample(distance)`, `route_distances()`, `RouteIndex` (nearest road point + distance
  along) and `RouteTracker` (follows a car along the stage) work in metres along the road.
  `RouteValidator.validate()` (length, radius >= 11 m, grade <= 30 %, no crossing, stretches >= 30 m apart) must
  stay empty for every stage (tests/unit/procedural/test_stage_builder.gd). Preview layouts with a script that
  draws `graph.main_route_points()` into an Image.
- `TerrainField(seed, relief).set_roads(graph)`: IDW surface through the road heights + hills growing away from
  the road + cliff drops / bank walls from the features, pressed into a 12 cm trench under the road.
  `RoadBuilder.build(graph, terrain, palette)` → `Track` (rectangular HeightMapShape3D terrain, Roads/Road<n>
  ribbons + verges with `surface` metadata, Checkpoints spanning the corridor without reaching another
  stretch, `TrackFeatures`: water pools + `WaterSplash` areas, steel rails with one gap on cliffs, start/finish
  arches, invisible walls 36 m out and end caps). Face winding for anything hit from above: origin → +X → +Z.
- On a switchback the next leg is uphill on the side the hairpin turns to: bank on that side, cliff on the
  other (the terrain test probes only open ground).
- `RoadsideDresser` (+ `RoadsideCatalog`): Poly Haven scans and the Sketchfab conifer/birch packs (`node` picks
  one tree from a pack, `unit` 0.01 for the centimetre birches, `foliage` = alpha scissor), a thick edge band
  before the walls and a backdrop beyond (`backdrop` entries stay outside the corridor); nothing on a cliff's
  lip. Scenery is batched by mesh into MultiMeshInstance3D chunks (48-192 m) with visibility ranges: the
  frame cost on this laptop is CPU draw submission, not triangles. `GraphicsQuality` (Settings
  `graphics_quality`, AUTO = Low on integrated GPUs) scales scenery density/range, shadows, SSAO/glow and
  the render scale; dev scenes take `--quality=0|1|2`.
- Stage events: `StageEventBuilder` (from `TrackFeatures`) puts `Event<n>` bodies with a trigger area
  before the spot (a fir that falls across the road, rocks off a bank); `StageEvents` (child of the race)
  lets the host decide and every peer play it (`_rpc_stage_event`); boulders are host-simulated props like
  the cans (`_rpc_spawn_boulder`). Offline (route_test) the trigger plays locally.
- `RouteFollower` (pure pursuit + corner speed planner, `start_delay`, stops at the end of an open path) drives
  a `RallyCar`: `--autodrive`, tests, flow-test bots. `RaceProgress` is the host's gate accounting.
- Dev scene `scenes/dev/route_test.tscn`: `--stage=N|id --start=M --autodrive --chase --overview --weather=N`
  `--quit-after-seconds=N`. `RaceSession.settings.stage` builds the same stage on every peer.

## Paper map and pace notes (scripts/map)
- `PaceNotes.build(graph, detail)` → numbered rally calls in stage order ("Sol 3", "Saç tokası sağ", "Kör tepe!",
  "Atlama!", "Su geçişi!", "Uçurum solda!", cautions; Explore adds distances, Redline only the dangers).
  `MapCanvas` (SubViewport, 1792×1152) draws the stage (turned sideways when it runs north-south), hazards,
  numbered rings beside the road and the notes column; `MapCanvas.contour_for` is computed once per race. `PaperMap` (created by `Cabin._ready`) is the 3D sheet; `Cabin` holds
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
  per team (3 s stuck → offer, confirmations with an 8 s window, 1 seat = hold R), picks the spot with
  `RecoveryAnchor.find(graph, position, next_gate)` and sends `_rpc_recover_car`; the simulating peer applies
  `reset_to`. `PlayerCarInput.local_recovery` and `RouteFollower.self_recover` are false inside a session.
- Cabin (spec §9-10): `Cabin` is the one state system for windows (state + cracked), windshield, dirt,
  wipers, per-seat exposure and faints, the map and the cans; host authority, `_broadcast(rpc, args)` runs
  the RPC everywhere or just locally offline. `SeatEffects` (CanvasLayer) shows the local seat's view of it.
  Input: Q/E windows, F kick windshield (navigator), T wipers (driver), M map, LMB throw. Fainted seats are
  checked by `PlayerCarInput`, `RouteFollower` and `CabinInput` via `cabin.is_fainted(role)`.
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
- Glass: `WindshieldGlass` puts the Cabin's dirt, crack and wipers on the windshield mesh (its own plane is
  measured from the triangles); `SeatEffects` keeps only the face-hit flash and the faint.
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
