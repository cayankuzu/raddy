# Reference repositories and tools (checked 2026-10-12)

All six repositories are MIT licensed (verified via the GitHub API and their licence files), so
ideas and code may be used in the paid game as long as any copied code keeps its copyright
notice. So far RADDY copies no code from them; everything below was reimplemented.

| Repository | Godot | Last commit | Verdict | What RADDY takes from it |
|---|---|---|---|---|
| [Seerban/godot-vehicle](https://github.com/Seerban/godot-vehicle) | 4.6, GodotPhysics 60 Hz | 2026-07-14 | Adapt ideas | Per-wheel grip budget, speed-proportional braking that holds at rest, surface grip multiplier, mirror-wheel anti-roll. Avoided: +X forward axis, tick-dependent damper, input read inside the car. |
| [HaileNegash/godot4-vehicle-framework](https://github.com/HaileNegash/godot4-vehicle-framework) | "4+" (no project file) | 2026-05-21 | Reference only | Too arcade for RADDY's weighty rally feel. |
| [thegatesbrowser/godot-multiplayer](https://github.com/thegatesbrowser/godot-multiplayer) | 4.5 | 2025-09-22 | Adapt ideas for voice | Uses TwoVoIP (Opus). Ideas: drain encoded chunks once per frame and send as one batch, sequence numbers, stop sending while silent. Demo assets partly CC-BY: do not copy assets. |
| [bearlikelion/cooties](https://github.com/bearlikelion/cooties) | 4.7 (Mobile, Rapier2D) | 2026-07-19 | Reference only | Depends on GodotSteam (RADDY must not). Lobby patterns worth reusing: server-side roster {peer: name, team, role, ready}, load barrier before start, ready re-check after disconnects. |
| [slangwald/godot-mcp](https://github.com/slangwald/godot-mcp) | 4.6 | 2026-02-12 | Skip | 21 of its 24 tools duplicate Beckett; no authentication on its port. |
| [Fulviuus/godot-mcp](https://github.com/Fulviuus/godot-mcp) | 4.7 | 2026-07-11 | Skip | Young, mostly duplicates Beckett; input tools assume one instance, a fixed port and `-d`, and edit `project.godot`. |

MCP decision: keep **Beckett Lite 1.16.0** as the only MCP server (verified end to end: 56 tools,
token auth, CI-tested on 4.7.2). Its gaps (input injection, export, several game instances) are
covered by `tools/*.ps1`, GUT tests that drive `VehicleControls`, and per-instance logs.

## Vehicle engineering notes applied in `scripts/vehicles/rally_car.gd`
- Custom RigidBody3D with ray wheels, not VehicleBody3D (its own docs call it unsuitable for realistic vehicles).
- Rays are cast by the car itself in `_integrate_forces` (RayCast3D nodes would be one tick stale).
- `can_sleep = false` (Jolt only calls `_integrate_forces` for awake bodies), `continuous_cd = true`,
  linear damping replaced by explicit drag (the project default 0.1 is a hidden brake).
- Known engine issue: Jolt's job pool occasionally runs dry and logs a warning, then recovers
  (godotengine/godot#110724). Tests treat only that warning as expected (`tests/support/physics_test_case.gd`).
- Later: contact-based impact zones (front/rear/side) for damage, optional sphere-cast wheels if
  road edges feel steppy, physics interpolation for 144 Hz screens (visuals must then move in
  `_physics_process`).

Art direction research (Half Grip as a mood reference only): see `ART_DIRECTION.md`.

## Gameplay references (checked 2026-10-13, public store pages and press only; nothing copied)
- **Left! Left! LEFT!** (Steam 5362020): asymmetric co-op rally. The driver gets no map or HUD; the
  co-driver holds a physical, droppable tablet with the route and must talk the driver through.
  The fun is the cabin chaos (items fly around, the view is blocked, the tablet goes missing) and a
  deliberately sloppy little hatchback. RADDY takes the asymmetry (paper map only in the
  navigator's hands, proximity voice) and the chaos (map blown out of the window, mud on the glass,
  faints, a bonnet flapping over the windshield, falling trees, rockfalls).
- **Half Grip** (Steam 4163270): mood and driving-feel reference only (see `ART_DIRECTION.md`).
- **Rally Panic** (Roblox, a popular imitation; ~3.2k concurrent players at peak, #2 in Racing):
  narrow forest roads, treacherous bridges, "technical turn chains", short runs, coins and a
  garage. Lessons: short stages (2-3 min) replay well; danger spots (bridges, drops) are what
  players talk about; progression gives a reason to replay.
- Real rally pace-note conventions used by `PaceNotes`: direction + severity 1 (slowest) to 6
  (nearly flat), "hairpin", "long", hazards (crest/blind crest, jump, dip, water, cliff), cautions.
