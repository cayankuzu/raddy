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
- `tools\nettest.ps1 [-Clients 3] [-Seconds 22]`: automated multiplayer check (headless host + clients run
  `scenes/dev/net_test.tscn` with scripted actions, then the `NET ...` log lines are asserted). Exit 0 = pass.
- `tools\capture_window.ps1 -Instance N -Out reports\screenshots\x.png`: PNG of a windowed instance even when
  covered (PrintWindow); use it for multi-window visual checks since Beckett sees one game only.
- `tools\screenshot.ps1 -Scene res://x.tscn -Frames 120 -Out reports\screenshots\x.png [-ExtraArgs "--a,--b"]`:
  Movie Maker capture; open the PNG with Read. The PNG has the project viewport size; `-Resolution` only
  sizes the window. 60 movie frames = 1 s of game time.
- `launch.ps1` and `screenshot.ps1` need `-Scene` until the project has a main scene.
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
- Dev scene `scenes/dev/vehicle_test_track.tscn` is the current main scene (`--autodrive` user arg circles).

## Procedural route (scripts/procedural)
- `RouteGenerator.generate(seed)` → `RouteGraph` (nodes START/JUNCTION/DEAD_END, edges MAIN/SHORTCUT/DETOUR/SPUR
  as XZ polylines + heights, `main_route`, `checkpoints`); deterministic per seed, retries with jitter until
  `RouteValidator.validate()` returns no problems. `TerrainField(seed).set_roads(graph)` gives ground height
  flattened into a 12 cm trench under roads; `RoadBuilder.build(graph, terrain)` returns the `Track` node
  (Terrain HeightMapShape3D, Roads/Road<n> trimesh ribbons + verges with `surface` metadata, Junctions pads,
  Checkpoints/`Checkpoint` areas). Face winding for anything that must be hit from above: origin → +X → +Z
  (trimesh collision is one-sided; the wrong order is invisible from above and lets cars fall through).
- `RouteFollower` (pure pursuit + corner speed planner) drives a `RallyCar` round `graph.main_route_points()`:
  dev scenes `--autodrive`, tests, later respawn references. `RaceProgress` is the host's lap accounting.
- Dev scene `scenes/dev/route_test.tscn`: `--seed=N --autodrive --chase --overview --quit-after-seconds=N`.
  `RaceSession.settings.seed` builds the same track on every peer; cars spawn on a grid behind gate 0.

## Paper map and pace notes (scripts/map)
- `PaceNotes.build(graph)` → numbered notes per junction in lap order (TR/EN text, side, turn, branch kind).
  `MapCanvas` (SubViewport, 1792×1152) draws the network + notes column from the graph; `MapCanvas.contour_for`
  is computed once per race and shared. `PaperMap` (created by `Cabin._ready`) is the 3D sheet; `Cabin` holds
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
- Damage (spec §8): the host judges impacts from `BodyNetSync.snapshot_received` velocity jumps (or its own
  car's `impact`), keeps a `VehicleDamage` per team and broadcasts `_rpc_set_damage`; every peer calls
  `RallyCar.apply_damage` (effects + placeholder dents). Critical damage sets `needs_recovery` on the host.
- Dev bootstrap `scenes/dev/net_test.tscn` takes `--role --port --host --players --as-player --local
  --autodrive --test-script --quit-after-seconds`; without `--instance` it takes the first free seat.
- `Voice` autoload (scripts/audio): `VoiceCapture` (AudioServer input API, 48 kHz → 16 kHz mono) → mu-law
  20 ms packets → host `_relay` (range check through the world provider: `RaceSession.voice_position/anchor`)
  → `VoicePlayback` (AudioStreamPlayer3D + AudioStreamGenerator, jitter buffer) parented to the speaker's seat.
  Headless (Dummy audio driver) never opens the mic; `Voice.start_fake_transmit()` sends a tone for tests.
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
- The token is in `.mcp.json` (and Beckett's `.mcp.json.*` backups), `.cursor/`, `.beckett/` and
  `logs\editor.log`; all gitignored. Never commit or print them. Mask it when showing editor logs:
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
  Windows global atom table is full; this PC hit it after ~17 days of uptime and only a reboot clears it. Every
  windowed tool run and the desktop "RADDY Editör" shortcut pass `--accessibility disabled` (`$GodotWindowArgs`).
- If every Godot run suddenly takes 20 s+ to start (nettest timings slip, `--quit-after 5` takes 19 s), check
  for a leftover `chrome-headless-shell.exe` (Playwright, under `%LOCALAPPDATA%\ms-playwright`) rendering WebGL
  in software: a Sketchfab tab left in the built-in browser ate 65% of the CPU once. Kill its process tree.
- Game start is dominated by GDScript compilation (~35 scripts, 3-10 s on this laptop while other apps
  load the CPU; `net_test.tscn` prints `NET boot wall=`). Four instances booting at once take 20-30 s, so
  `tools
ettest.ps1` budgets 40 s and times its scripted actions from race start, not from launch.
- With the editor open, games launched by `tools\launch.ps1` make Beckett log "rejected a peer with a
  missing/invalid handshake token" once per connection attempt (the stub dials the editor's runtime port).
  Harmless; clear the editor Output panel when it gets slow.

## Third-party (pinned)
- `addons/beckett`: Beckett Lite v1.16.0, MIT, GitHub release zip (sha256 35b1274d…20ac). The Asset Library copy is older.
- `addons/gut`: GUT v9.7.1, MIT, the `godot_4_7` line. The Asset Library's 9.6.1 targets 4.6: do not "update" from there.
- Researched, not installed yet: TwoVoIP v6.5 for Opus voice (not 6.6: Windows editor crash, issue #107),
  netfox + noray for NAT punch-through/relay.
