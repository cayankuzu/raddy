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
   the same data drives road mesh, collision, map and pace notes.
5. Physics object + cabin state: one thrown can and one window state synced over the network.
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
