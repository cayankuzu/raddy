# Phase X: mayhem. Things break the way they are made, the living get out of the way

**Revision of the first X brief (Direction 3, 2026-11-17): this file replaced it.** The owner, again: "The feel of destruction
must be realistic; people must really experience it." The first X made a dozen things breakable as splinters in `RoadFxPool` and one flung
body; this edition breaks each thing the way its material breaks, gives the pieces the car's momentum, leaves them on the ground for the
crews behind, and makes the car's own crashes heavier to look at and to hear. It takes items 2-5 of the interiors draft
(the car's dents and the way a thing breaks: `i_interiors_destruction.md` says what moved), so that one phase owns everything that breaks beside the road and on the car. What
stays for phase I (after W, P2 and OW): window panes in houses and shops, structures that come down (a porch, the market roof, a fence run,
a shed), the insides of houses. How a hit is *felt* (the camera's hold, the FOV punch, the sound's duck and thump, the rumble:
`ImpactFeel`) is phase F's, built before this phase: every break here calls it.

The owner (2026-11-17): "Add things that go viral: features, ways of playing. Fun. The cheek of the big sandbox comedies." Direction 2
(`docs/GAME_DESIGN.md`, laws 1, 4, 5, 7, 8) and Direction 3 say what that means here: whatever is a thing beside the road breaks, flies and is
counted; nothing alive is ever hit (people dive aside, animals scatter); what a crew breaks stays broken for the crews behind; it earns awards
and a line in the feed, never a score mode; each run draws three or four gags from a catalogue into the slots phase L checked; every kit has a
measured budget; the world is the same on every peer whatever its graphics level.

Read first: GAME_DESIGN "Direction 2" and "Direction 3"; CLAUDE.md on `CrashRules`, `RoadFxPool`, the `Cabin` (dirt, wipers, windows,
exposure), `WindshieldGlass`, `Spectators`, `StageEvents`, `RallyDressing`, `RouteFollower.obstacles`, the horn, the multiplayer model, and what
phase L wrote about gag slots and `GagDirector`; what phase F wrote about `ImpactFeel` and phase P1 about the named physics layers and the
protocol fingerprint; `scripts/procedural/farm_gate.gd` (the one thing a car bursts today: the simulating peer decides at once, takes the
speed off its own car, sets `last_impact_struck` / `last_impact_at`, emits `RallyCar.impact` by hand, then asks the host: the pattern);
`scripts/vehicles/rally_car.gd` `_detect_impact`, `race_session.gd` `_on_driver_impact`, `_judge_impact`, `_rpc_crash_fx`; `crash_rules.gd`,
`vehicle_damage.gd`, `car_damage_fx.gd`, `road_fx_pool.gd`, `car_audio.gd`; `docs/phases/downloads.md` (the Poly Haven and Sketchfab models on
the disk: copy what is used into `assets/` with its manifest row and its `ASSET_LICENSES.md` row; look at each in the engine first: no maker's
badge, no foreign text, no flag).

## The traps (each ends as a test)
- **First contact is the driver's peer's.** A solid prop would stop a client's car a round trip before the host knew. Breakables are
  overlap shapes, never solid: the driving peer breaks the thing at once, takes the speed the catalogue says (a drag by mass, as an
  impulse on its own car) and reports it; the host confirms by index (it exists, it stood, that car was near it by its tracker) and tells
  every peer. Solid stay: walls, houses, big trees, the tractor.
- **Nothing cosmetic touches a car.** A debris body that collides with a car pushes it on one peer and not on another. In Godot a pair
  collides when either one's mask holds the other's layer, and both respond: there is no one-way contact. Debris lives on P1's `debris`
  layer, which collides with the ground, the walls and other debris only; it is moved by cars from script (`DebrisPool` kicks what a car's
  box sweeps through, with that car's `seen_velocity`). The car's loss of speed is the catalogue's drag, applied once, never the pieces'.
  Test: a car through a row of crates has zero contacts with debris and loses exactly the drag.
- **`_detect_impact` sees contacts only**, and overlaps make none: a breakable's hit reaches the feel, the sound and the host only if the
  breaking code emits it, as `FarmGate._burst` does. It also has `IMPACT_COOLDOWN`: a row of crates hit in 0.2 s would be one hit. F's
  `ImpactFeel` queues its own events and never reads the cooldown. Small things must not count as damage: a crate's drag is under
  `VehicleDamage.SCRAPE_SPEED` (3.5 m/s) by the catalogue; a test sweeps the catalogue.
- **`CrashRules.Struck` travels as an int** (`_rpc_report_impact` clamps it to `Struck.size() - 1`). New kinds (GLASS, PLASTIC, CERAMIC,
  CARDBOARD, FRUIT, CLOTH) are appended at the end, never inserted.
- **Indexes are the same everywhere.** The list of breakables comes from the stage, its dressing plan and the room's seed alone: a test
  builds it at two graphics levels and two effects settings and compares. A broken thing is a bit in a set the host keeps and sends to a
  peer that joins the race again. Phase I appends window panes and structure parts after this phase's entries, in plan order.
- **`RoadFxPool`'s pools are fixed rings** (`BITS` 192, `FLAKES` 192, `SPARKS` 128): a market stall's burst would overwrite the dust of
  the car ahead. Every break asks for a share (`BreakFx.budget`) and the pools grow only if the flip says it is free.
- **Remote cars are frozen kinematic bodies played 100 ms behind.** What a remote car breaks is played when the host's word comes, and the
  pieces fly from that car's position then; the driving peer's pieces fly at once. Neither is wrong; both are cosmetic.
- **Moving things need no stream.** The tractor's place is a function of the race clock, the same on every peer; a honk is a host message
  "pull over from t". The flock is the host's, sent ten times a second on the unreliable channel, with no collision: a tenth of a second
  of lag cannot matter.
- **A gag never decides a medal by luck.** Slots sit beside the stage's own line or cost every crew the same; say for each gag what it costs
  a clean run (the bot's time with and without, per stage) and keep the medal speeds honest.
- **The protocol.** Every new RPC and setting bumps `Net.PROTOCOL_VERSION`; P1's fingerprint test fails otherwise.
- **Dents must not reach the glass.** `test_seat_view` must hold with the worst dents (the windshield's view and the mirrors unchanged).

## Deliver (each step leaves the game whole, tests green)
1. **Breakables.** A catalogue (data: the model, a mass class, its `material` and `fracture` kind, its sound kind for `CrashRules`, the drag,
   its weight for the awards, a price for phase Q's insurer, an owner kind for phase N's reactions) of about fifteen kinds from the
   downloaded models: wooden crates, barrels, plastic crates, cardboard boxes, wicker baskets, a trash can, the jerrycan, the picnic table,
   benches and chairs, cones, bales, the "wet floor" sign, the garden gnome, the concrete cat, a football, the log fence, the portable toilet
   (it tips over; nobody is in it), and a market stall built in code from crates, a table and the fruit. Drawn as MultiMesh chunks by kind;
   a broken one leaves its chunk and becomes its pieces (item 2). What breaks stays broken for the race, on every peer, for the crews behind.
2. **`FractureRules` (pure, tested) and baked pieces.** Each kind is broken once, at bake, by a tool (`tools/make_fractures.gd`, headless,
   seeded) into `assets/fx/fractures/<kind>.res` (one `ArrayMesh`, one surface, the piece index in `CUSTOM0`; per piece its centre, mass share
   and a hull of at most 12 points): no cutting at run time.
   - **Islands first**: most models are built from parts (a chair's legs, seat, back; a crate's planks; a barrel's staves and hoops): split
     by connected triangles, as `CarParts` cuts the car.
   - **Slab cut** for anything long and wooden (a plank, a rail, a post, a leg): cut across at a seeded place into two or three, the ends
     jagged (a sawtooth of 3-6 splinters, each a thin wedge along the grain), the cut faces capped with fresh, pale wood (the `UV2` flag the
     material reads).
   - **Convex Voronoi** (cells of 8-16 seeds clipped from the island's convex hull, each cell kept only where it holds triangles of the model;
     caps from the cell's face) for pots, the gnome, the concrete cat, the trough. If a non-convex island's caps look wrong in the shots, fall
     back to islands and slab cuts for that kind and say so.
   Tests: the pieces' volume sums to the source's (within 3 %), every piece closed and convex where it must be, the same seed the same
   pieces, piece counts per kind, every cap faces out.
3. **`DebrisPool` and `DebrisLaunch`.** `DebrisLaunch` (pure, tested): per piece a velocity from the car's at the contact times a share by
   mass ratio and the material, spread round the hit's normal, a spin from the piece's offset from the hit, the face hit first going furthest;
   the pieces' momentum together never more than the momentum the car lost (the drag) times 1.5. `DebrisPool` (one per scene, beside
   `RoadFxPool`): Jolt `RigidBody3D`s with the baked hull shapes on the debris layer; at most 24 awake per peer, the oldest frozen first; a
   piece slower than 0.15 m/s for 1 s freezes and joins the **rubble**: one `MultiMeshInstance3D` per kind per 96 m chunk, no collision, there
   for the race, kicked awake again into the pool when a car's box sweeps it (local, cosmetic). At most 3000 pieces of rubble a stage; past
   that the smallest fade. A peer that joins late lays the rubble of what was broken before from the seed (the pieces dropped round the spot,
   flat on the ground), not from a stream. Check the Jolt sleep settings' names in 4.7.2 before changing any (and `test_project_settings` if
   one changes). Physics test: 30 crates at 25 m/s: at most 24 awake, `tick_ms` within the budget, zero car-debris contacts.
4. **Each material its own break** (`CrashRules.Struck` extended at the end): wood splinters into its pieces plus `flake` splinters; plastic
   flies whole (one body, high bounce, a dent in the vertex shader, never pieces); metal (trash can, jerrycan) flies whole, loses its lid,
   dents; cardboard crumples (flattened on its short axis in 0.1 s) and flies; straw bursts in flakes and a puff and leaves a flattened bale;
   ceramic and concrete crack into 3-8 shards and a puff of grit; fruit splats (flakes, the pulp of item 6 on the glass). `BreakFx` asks
   `RoadFxPool` for a share, plays the sound and calls F's `ImpactFeel` with the thing's mass class.
5. **Sounds by material and size.** Small, medium, large for each material, four variations, pitch by mass, a first transient then the
   pieces' patter landing over a second (a few late ticks from where the rubble lands). From what the game has (`impacts/`, crash, metal,
   the downloaded mud splat for fruit), `tools/make_break_sounds.py` (pure Python, modal synthesis: wood knocks and cracks, ceramic rings,
   cardboard thuds) and a bleat and a far flock from the approved farm sounds; bees, a flapping sheet and a tractor synthesised the same way.
   The CC0 Freesound recordings approved on 2026-11-17 (`docs/phases/downloads.md` Batch H, in `raw_assets/downloads/freesound_x/`: a
   plank's snap, a crate smashed, plastic crates handled, a clay pot breaking, a flag's flap for the tarp, a glass pane shattering for
   phase I, a cardboard box crushed, a metal trash can hit) are cut into the sizes and variations with `tools/cut_audio.py` and layered with
   the synthesised ones; what the batch lacks (a plastic crate bouncing, a trash can rolling) and any file that turns out unusable is left
   to the synthesis, and the evidence says which. Game bus, under -1 dBFS, a low-pass with distance, nothing heard twice in one frame.
6. **Gags that reach into the cabin** (each is a job for the crew; host-decided, pure rules, tested): fruit pulp on the windshield from a
   market stall (blobs the wipers clear in two sweeps), straw from bales and stacks (the wipers smear it first), a sheet from a washing
   line across a village lane over most of the glass (off after two wipes or a few seconds at speed), bees through an open window when a
   hive is hit (a buzz, specks in that seat's view, the view flinching until the windows have been shut for three seconds). They ride on
   the `Cabin`'s existing glass and exposure systems; the seat's body shows it where that is cheap (a hand batting at bees).
7. **The crowd dives: `DiveRules`.** In front of every place for spectators stands something solid a car cannot pass (the bales and a low
   bank), so a car never reaches a person. When a car comes at a place fast and close, the people of that place throw themselves back and
   aside (a pose of the crowd's shader, by a pure rule of distance, closing speed and line, `DiveRules`: each peer works it out from what it
   sees, like the cheer), then come up shaking fists and flags. `DiveRules` is the one rule of a dive: phase P2's walkers and phase N's
   `ReactionRules` call it and add to it, never replace it (its tests stay).
8. **What the horn moves.** A tractor (the downloaded one, with the trailer if it holds up in the engine) that pulls out at an `across_slow`
   slot, trundles along the road and pulls off again, sooner when honked at: solid, on the clock, the bots brake for it and honk. A flock
   of sheep (the downloaded model, a simple gait in the shader) on the road at such a slot: the sheep always get out of a car's way (no
   contact, each peer keeps them off its cars' boxes), the road through them is slow until they have cleared it, and the horn clears it in
   a third of the time. Pace notes do not call either: they are the run's surprise; the map marks neither. Phase N turns the flock into
   `AnimalRules`' first user without changing this item's tests.
9. **The car's own damage, heavier** (from the interiors draft's item 2; what damage does to the *driving*, `VehicleDamage.effects`, does
   not change: the medal speeds and the handling benchmarks stay):
   - **Dents.** `DentRules` (pure, tested): a car keeps up to 16 dents (car-space point, normal, radius 0.15-0.6 m, depth up to 7 cm), each
     from a hit's `at`, direction and strength; a new one near an old one deepens it; a recovery keeps them (`VehicleDamage.REPAIRED_TO`);
     phase Q's service park takes them away when it repairs the zone. `car_body.gdshader`'s `vertex()` pushes the paint, trim and lamps'
     skins in along the dent's normal with a smooth falloff and creases the paint's normal at the rim (a scratched, dull ring). Every peer
     adds the same dents from the same `_rpc_crash_fx` (it carries `at` and strength; add the direction), the driver's peer from its own hit.
     Test: deterministic from a list of hits; no vertex moves more than 7 cm; `test_seat_view` with the worst dents. No draw call added.
   - **A sagging bumper drags** (`CarDamageFx` `BUMPER_SAG`): its low corner scrapes the road, sparks on tarmac and rock, a scrape loop in
     `CarAudio`; a loose bonnet flutters with a rattle loop; from MEDIUM a loose-panel rattle that follows the suspension's compressions.
   - **The windshield takes crashes too:** a front hit over 14 m/s cracks it through the existing `Cabin` crack (a host rule beside
     `StoneChipRules`), so a big hit shows from the seat for the rest of the stage.
10. **The gag director, filled.** The catalogue of gags for phase L's slots: beside the road (a market stall, a stack of crates, a wall of
   bales, barrels, a picnic, the portable toilet, a garden of gnomes, a run of fence), across it and slow (the flock, the tractor), overhead
   (the washing line). Three or four a run from the room's seed; Surprise Rally changes the draw from day to day; `--gags=` picks them
   for shots and tests.
11. **Awards and the feed.** The host counts per crew (one pure class with tests, `MayhemTally`): things broken by kind and material, the
   stall, sheets worn, bees let in, flocks honked through or ploughed through, tractors passed, the cleanest run. The results show three to
   five named awards with the crew's names, in Turkish and English ("Pazarı da götürdüler", "Arı kovanına çomak sokan"); a short line names
   a feat as it happens on the navigator's HUD only, through F's `HudFeed` (the driver hears it and stays blind). This is the first piece of
   A6's awards and of phase Q's payouts: build it so they only add to it. Every line goes through the writing guide (Direction 3).

## Measured
`perf.ps1 --flip-props`, `--flip-gags` and `--flip-debris` (twice, both orders): what the breakables, each gag and the debris cost a frame on
Low, Medium and High with three crews; Medium stays over 60 fps. Budgets: debris at most 24 awake bodies, hulls of at most 12 points, the
physics tick at most +0.15 ms with 24 awake; rubble one draw call per kind per chunk; dents no draw call. A headless bot finishes each stage
with every gag drawn in turn, on each difficulty (no recovery, the same time within a second). nettest: a client breaks a thing, the host and
the other client see it broken, a late peer gets the set and lays its rubble; the flock and the tractor in the same place on every peer; a
flow test with gags on. Evidence: one contact sheet per gag (before, during, after, from the seat); a crate row at 25 m/s in Movie Maker
frames (0, 2, 4, 8, 16 and 60 of 60 a second); each material's break; the car's dents from outside at light, medium and critical; the crowd
diving from the seat and from beside the road; the awards on the results. Sound: a Movie Maker capture's WAV of each material's break, peaks
under -1 dBFS.

## Size
About 18 builder parts of 1-3 hours: breakables and their catalogue 2, fracture 2, debris pool and launch 2, materials 1, sounds 2, cabin gags
2, the dive 1, tractor and flock 2, the car's damage 2, the director and the awards 1, measuring and evidence 1.

Done means: GAME_DESIGN, CLAUDE.md, DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN (what only a crew on voice can judge: is it funny the tenth
time, does a crate row feel like wood), `ASSET_LICENSES.md` and the credits' rows, the strings; full GUT, nettest and flow tests pass; commits
on main.
