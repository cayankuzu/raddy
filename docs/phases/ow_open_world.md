# Phase OW: the open world. One region to roam, the stages are places in it

The owner (2026-11-17, translated): "An unlimited open world, a beautiful, detailed, big map with everything in it. Widen the map. As big
and as good as GTA and Postal. You must be able to get into cars. Continuity: the player must not get to the bottom of it at once." Today
RADDY is six separate corridors: `StageBuilder` makes one road, `TerrainField` lays ground 140 m round it (`MARGIN`), `TrackFeatures`
stands invisible walls 36 m out (`CORRIDOR`), and the race loads one of them for three minutes. This phase turns that into a region the
crews drive freely, in which the rally stages are places with a start control you drive to, joined by villages, farms, a lake, a river, a
quarry and a service park.

**What this phase is not.** It is not "GTA size": a big studio's city is the work of hundreds of people over years. What one free, zero-budget,
AI-built project can honestly reach is a countryside region of about 12-16 km² per biome, made procedurally from hand-placed plans, streamed
in tiles, lived in by the kits phases W and X make. Walking (phase P2) is built before this phase and streams with it; entering buildings
(I), people, animals and traffic (N), errands and the career (Q) come after it and build on its places, roads and save; the HUD's pieces are
phase F's; a browser build never carries a region (see "Out of scope").

**Where this phase sits (Direction 3, `order.md`).** Item 0, the spike, runs as its own short phase **OW0 right after phase F**, long before
the rest: if streaming cannot hold this laptop's budget, Direction 3's open world shrinks before X and W design for it. Items 1-10 and 12
(the first version below, Çamlık Vadisi) are **phase OW**, after P2, and are in the owner's play-test build. Item 11 (time and weather that
move) and the full version's two more regions are **phase OW2, after the owner's play-test**: the owner plays one region before the work is
tripled. This phase also builds the game's one save, `Profile` (item 10, to phase Q's design Q1), so that discoveries, the region's broken
things and later the wallet and the career live in one file.

The laws stay: GAME_DESIGN "Direction 2" (nothing alive is hurt, mayhem is things breaking, one road coordinate on a stage, budgets measured,
the same world on every peer at every graphics level), every flag is Turkey's, the rally is the heart: the region is where it happens.

## Read first
- CLAUDE.md, all of "Stages", "Multiplayer", "Screens and flow", the perf method (`tools\perf.ps1`, `--flip`), the gotchas.
- GAME_DESIGN §1, §4, §9 and "Direction 2"; DEVELOPMENT_PLAN's A9a entry (the frame is the GPU's; Medium on Black Pine with three crews
  77-80 fps, 870-910 draw calls; trees cost 6-9 ms on Medium, the first banked cut) and phase L's entries (bypasses, `along_of`).
- `docs/phases/w_world.md` (`VillagePlan`, `HouseRules`, fields: this phase places them, W builds them), `x_mayhem.md` (breakables are
  indexed from the seed; this phase gives them a tile index), `m_map.md` (the sheet's style, `MapPrint`), `p_on_foot_cars.md` (P1's
  named layers and protocol fingerprint, P2's walker), `j_join.md` (rejoin), `a8_net.md`, `d_demo.md` (the solo session this phase's roam
  reuses), `l2_stages_events.md` (Misty Creek's ford village).
- Code: `scripts/procedural/terrain_field.gd` (whole), `road_builder.gd`, `roadside_dresser.gd`, `stage_builder.gd`, `route_graph.gd`,
  `track_features.gd`, `rally_dressing.gd`; `scripts/gameplay/race_session.gd`, `race_look.gd`, `route_tracker.gd`, `recovery_anchor.gd`,
  `weather_fx.gd`; `scripts/core/biome_rules.gd`, `graphics_quality.gd`, `flow.gd`; `scripts/map/map_canvas.gd`, `map_sheet.gd`,
  `paper_map.gd`; `scripts/network/net.gd`, `body_net_sync.gd`; `scripts/dev/route_test.gd`; `tools/perf_probe.gd`.

## The size this laptop and this engine can stream (starting numbers; item 0, phase OW0, confirms or corrects them)
- **Coordinates.** Godot 4.7.2's stock build uses 32-bit floats; a double-precision build is a custom engine compile and is not taken. Keep
  every region inside ±4 km of its origin (an 8 km square at most): at 4 km a float resolves about 0.5 mm, enough for Jolt and for
  rendering. A region is centred on its origin.
- **One region per biome, not one world.** `RaceLook` lights one scene with one sky, one sun, one fog and one biome palette
  (`SurfaceMaterials.terrain(biome)`, `RaceLook.FOLIAGE`, `DUST_TINT`); a world that crossed biomes would need all of that blended by
  position. Three regions (forest, desert, mountain), each joining its biome's two stages, travelled between from the world map or a road
  that leaves the region (a loading screen). Full version: forest 4 x 3 km, desert 4 x 4, mountain 4 x 4 (about 44 km² in all).
- **Tiles.** 256 m square (64 cells of `TerrainField.CELL` 4 m): a 4 x 4 km region is 16 x 16 = 256 tiles. Rings round each focus (the
  local car's camera; later the walking body): *near* within 400 m on Medium (300 Low, 500 High): ground at 4 m with collision, roads,
  scenery, props, breakables; *mid* to 1200 m: ground at 16 m, no collision, far forest as impostor cards, buildings' simple hulls; *far*:
  the whole region's ground at 32 m (125 x 125 vertices for 4 km), always loaded, plus a horizon ring of hills that is never driven.
- **Speed.** A rally car at 180 km/h (50 m/s) crosses a tile in 5 s, so a new near row of 3-4 tiles every 5 s: a tile must be prepared on
  a worker in under 400 ms and committed on the main thread at no more than 2 ms a frame. Look ahead along the velocity (1.5 s of travel).
- **Memory.** About 16-25 near tiles and 60 mid tiles loaded: under 400 MB of RAM and 1.5 GB of VRAM for the region on Medium.
- **Frame.** Roaming with three crews on Medium: at least 60 fps average and p99 under 20 ms on the dev laptop (the same bar as a stage),
  under 1000 draw calls, no frame over 33 ms while driving across tiles after the first 2 s. Low at least 90, High at least 45.
- **Loading.** Into a region in under 15 s (GAME_DESIGN §9): the manifest, the far ground, the near ring round the spawn, the crew bake.
- **Download.** A baked region is 150-400 MB (tiles, the map picture, impostor atlases): fine, the owner set no size limit.

## The traps the code holds (each ends as a test)
1. **The terrain follows the road, and is slow.** `TerrainField._build_base` weights every road sample for every 20 m cell (inverse
   distance, all samples): a stage of 2.8 km takes part of the 6.5 s `RaceSession._build_route` prints (`NET stage ... built in 6522 ms`,
   logs/instance_0.log). Over 60 km of road in 16 km² it is hours of GDScript at load. And the land is shaped *by* the road (`_natural` ramps
   hills up from the road over `HILL_RAMP` 80 m): a region needs land first (valleys, a lake's basin, hills) and roads laid on it. So: the
   region's land is its own function (`RegionTerrain`), roads are fitted to it, and the whole region is **baked offline** by a tool into
   shipped data; the game only reads tiles. Every peer has the same files; the data's hash joins the join version.
2. **A stage must stay the stage its judges passed.** `RouteValidator`, `StageDesignRules` and `Sightline` measured each stage with its own
   terrain, screens and dressing. Inside a stage's footprint (its grid: the roads' box plus `MARGIN`) the region uses the stage's own
   `TerrainField.height()` (moved and turned into the region, lifted by one height offset) and the stage's own `RoadsideDresser` and
   `RallyDressing`; the region's scatter, roads and water stay out of it; the region's land blends to it over a ring of 80 m outside it.
   Tests: inside the footprint the region's height equals the stage's to 1 cm; no region road comes within 80 m of a stage road except at its
   liaison junctions; every stage's judges stay empty when built from the region's copy.
3. **Static state in the builders.** `RoadBuilder` keeps `_palette`, `_biome`, `_weather` as static vars; `RoadsideDresser` (`_part_cache`,
   `_plant_materials`), `RallyProps`, `RallyArch`, `GuardRail` cache meshes and materials statically. Tiles prepared on worker threads must not
   touch them: pass a build context instead of statics, warm the caches on the main thread before streaming starts, and keep scene-tree work
   (adding nodes) on the main thread. A test builds two tiles of different biomes in one process and compares them with tiles built alone.
4. **One canopy for the whole map.** `RoadsideDresser.dress` sets the global shader parameters `canopy_map` and `canopy_rect` for one stage.
   The region bakes one canopy picture for itself (2 m pixels: 2048 x 2048 R8 for 4 km, 4 MB) and sets it once; a stage pocket's canopy is
   drawn into it at bake.
5. **Seams.** Neighbouring tiles must share their edge heights exactly (the same function at the same points; a test reads both sides of
   every edge of a baked region) and their `HeightMapShape3D`s must meet; mesh tiles at different levels of detail leave cracks: give every
   ground tile a skirt 2 m down on its edges. A car crossing a tile edge at 40 m/s must feel nothing (a physics test: no vertical jolt over
   the one a flat road gives).
6. **Never pull the ground from under a body.** A near tile is unloaded only when no locally simulated body (the own car, the own walker,
   a host's boulder, a can, a flung breakable, X's debris, a promoted ordinary car) is within 300 m of it. The host simulates props and cans for cars far from its own: it keeps a collision-only
   island (near ring, no visuals) round every car that has a host-simulated thing near it.
7. **Triggers the host never loaded.** Today `StageEvents` fire from `Area3D` triggers the host's physics sees. In a region the host may be
   3 km away with that tile unloaded: every trigger the host decides in roam is a position check on data (the car's place from its
   snapshots against a rectangle or a distance along a road), never a physics area. Breakables (phase X) are indexed by (tile, index) from
   the seed alone; the host keeps the broken set as bits per tile and sends it to a joiner.
8. **Everything assumes a stage.** `RaceSession` (1042 lines) owns spawn, seats, recovery, damage, crash effects, shock, stones, cans and the
   voice provider, and reads `graph` (trackers, `_measure_gaps`, `RecoveryAnchor.find(graph, ...)`, `HudStageBar`, `MapSheet.of_track`, the
   paper map). Roam has no stage graph. Decide in part 8 (and write it down): a `mode` on `RaceSession` (roam: no countdown, gates, results
   or penalties) with every graph read guarded, or the shared half extracted into a session base both use. A headless roam test that spawns,
   crashes, recovers, throws a can and fires the gun proves no path still needs a graph.
9. **The walls.** `TrackFeatures._build_boundary` stands walls 36 m from the road; in roam they would be invisible walls in the middle of
   the land. Roam builds no corridor walls. A stage run keeps them (a closed stage, as a real rally is, with tape and a barrier across every
   liaison road that meets it): `RouteTracker` counts progress only within `ON_ROAD` 14 m, but cutting across a field between two stretches
   would still gain, so the walls stay until a rule replaces them.
10. **Weather is baked into the colliders.** `BiomeRules.apply_to_graph` turns the stage's surfaces by the weather before building, and
    `RoadBuilder` tags ditches and verges with `BiomeRules.surface_for(Surface.DIRT, _weather)`. Weather that changes during a session
    re-tags the loaded road bodies' `surface` meta (and every tile as it loads) at a wetness threshold with hysteresis, and moves
    `RallyCar`'s weather grip (`RaceSettings.grip_scale`) smoothly. Check that `RallyCar` reads the meta per contact and caches nothing.
11. **The sky is made once.** `race_sky.gdshader` has no TIME so its radiance is computed once; `RaceLook.create(biome, weather, time)`
    picks from four discrete tables. A clock that moves needs the look as a function of the sun's elevation (blend between the tables) applied
    in steps (every 0.5 degree of sun, about every 20 s of game time at the proposed rate) with the sky's radiance updated incrementally;
    measure the step's hitch. Lamps, beams and light pods are made at a car's spawn by `RaceLook.light_pods`/`lamp_light`: they must be
    switchable at runtime (on at dusk, off by day, with hysteresis).
12. **Two copies of a stage.** A stage run in a region and the same stage loaded alone must be the same road. A test builds the stage with
    `StageBuilder.build` and compares it, point by point after the region's transform, with the region's baked copy. Bumping
    `StageCatalog.LAYOUT` forces a rebake (the manifest records the layout; a mismatch fails the suite and refuses joins).
13. **user:// is shared by every instance** (CLAUDE.md gotcha): the region save is namespaced by `--instance` in tests.

## Deliver (each step leaves the game whole; the race keeps working as today throughout)

**0. The spike (1-2 parts).** Before any design is built: `scenes/dev/stream_test.tscn` loads and unloads 256 m tiles of noise ground with
the forest catalog scattered on it round a bot driving a straight 4 km road at 50 m/s, worker preparation through `WorkerThreadPool`,
commits under a per-frame budget. Print `STREAM tile x,z ring prep_ms commit_ms` and `HITCH ms`; measure with `perf.ps1` on Low, Medium,
High. Decide the tile size (256 or 128 m), the ring radii and the scatter density per tile by these numbers and write them into this brief's
numbers above and DEVELOPMENT_PLAN. If the commit cannot stay under 2 ms a frame, find out why (MultiMesh buffer upload, shape creation)
before going on.

**1. The plan of a region, as data (2 parts).** `RegionCatalog` (data, like `StageCatalog`): per region an id, biome, size, seed, and its
places: each stage {`stage` id, `at`, `yaw`}, villages {`at`, `radius`, kind: hamlet, village, town}, the service park, a lake {centre,
outline radius and noise, level}, a river {points, width, depth}, a quarry {at, size, depth, terraces}, farms {at, fields}, hills
{at, height, radius}, viewpoints and landmarks, and the liaison roads {from, to, waypoints, class: lane, gravel road, village street,
tarmac road}. `RegionPlan` (pure) turns it into roads (the same spline the bypasses use, `StageBuilder._add_bypass`'s cubic between
held ends), junctions and places; `RegionValidator` (pure, like `RouteValidator`): a road's radius at least 15 m (11 m on a lane), grade
at most 12 % (a stage's 30 % is its own), no crossing except at junction nodes (or on a bridge over water), junctions at least 60 m apart,
every place reachable from the service park, no region road within 80 m of a stage road except at its liaison junctions, nothing in a
stage's footprint, the region inside ±4 km. Tests: each rule on a plan whose answer is known, the catalogue's regions all pass.

**2. The land (2-3 parts).** `RegionTerrain` (pure, `RefCounted`): macro relief (the hills' stamps over `FastNoiseLite` at 1/900 m, relief
30-60 m by biome), the lake's basin (flat bed under its level, banks), the river's channel (its bed falls monotonically along it),
the quarry's terraces, the stage pockets (trap 2) blended over 80 m, and the region roads pressed in with the stage's own cross-section
(`TerrainField.cross_section`, `FLAT_BAND`, `FLOOR_DROP`: the same shoulder, ditch and lip; the smallest margin of 0.30 m tested as for a
stage). Roads' heights are the land's under them smoothed along the road until the grade rule holds, then the land is cut and filled to
them. Tests: pocket equality, continuity across the blend ring (no step over 0.2 m between 4 m samples), the road margin, the river's bed
falling, the lake's shore closed, the same heights from two instances with the same seed.

**3. The bake (2-3 parts).** `tools/make_region.gd` (headless, `--region=<id>`) writes `data/regions/<id>/`: `manifest.res` (region id,
`REGION_LAYOUT`, `StageCatalog.LAYOUT`, tile size, tile count, a hash of every file), per tile `tile_<x>_<z>.res` (`RegionTile`, a
`Resource`: heights at 4 m with the skirt, the mid ground at 16 m, road ribbons cut to the tile with their surfaces, the scenery
placements per catalog entry, the collision shapes' data, the breakables' slots, the places in it), the far ground mesh, the canopy picture,
the impostor atlas (item 6) and the world map's picture (item 10). The stage pockets are baked by the stage's own builders (`StageBuilder`,
`TerrainField`, `RoadBuilder`, `RoadsideDresser`, `RallyDressing` on the transformed graph) and cut into tiles like the rest. Print how long
each region takes to bake. Tests: one tile rebuilt in the test equals the shipped one byte for byte (so the data cannot drift from the code);
the manifest's hash; the stage copy (trap 12).

**4. Streaming (3 parts).** `StreamRules` (pure, tested): which tiles each focus wants at which ring, given positions and velocities
(look-ahead), hysteresis (a tile leaves a ring 40 m further out than it enters), the bodies that pin collision (trap 6), the order to load
(nearest first, ahead first). `RegionStreamer` (Node): `ResourceLoader.load_threaded_request` for tiles, mesh arrays and MultiMesh buffers
prepared on `WorkerThreadPool`, a main-thread commit queue under 2 ms a frame, the far ground always present, the horizon ring. Pools of
`MeshInstance3D`/`MultiMeshInstance3D`/`StaticBody3D` reused, not freed. Tests: the rules; a physics test of a car crossing tile edges at
40 m/s (trap 5); a headless soak (`tools/regiontest.ps1`) where a bot drives a 10 km loop of the region three times with `STREAM` and
`HITCH` lines asserted (no tile missing under a car, memory stable from the second lap).

**5. Roads in the region (2 parts).** `RoadBuilder` takes a build context instead of statics (trap 3) and builds a road cut to a tile
(the ribbon, shoulders, ditch body, aprons where a road ends); junctions between region roads use `_build_mouth`'s filler. Road classes:
a lane (3.2 m, grass between the tracks), a gravel road (the stage widths), a village street (cobbles or packed dirt), a tarmac road
(6 m, painted edge lines; the existing tarmac surface). Liaison roads end at each stage's start control and leave its finish control.
`RegionRoads` (pure): the junction graph, `nearest_pose(position)` (recovery in roam), `route(from, to)` (A* over junctions, the polyline a
`RouteFollower` drives: bots, tests, the flow test, later traffic). Tests: routes between every pair of places, the nearest pose always on a
road facing along it.

**6. Scenery that fills a region (3 parts).** `RegionScatter`: the roadside band along region roads through `RoadsideDresser`'s placing
(`_place` clipped to a tile), area scatter inside forest masks (the plan's forests, the hills' crowns, the river's banks), hedgerows and
single trees along fields, nothing in a stage pocket (its own dressing is there) or a village's or field's footprint (W's). The far forest
as impostor cards (A9a's first banked cut, now required): a tool bakes each tree kind from 8 directions into an atlas
(`tools/make_impostors.gd`, from the meshes on the disk, no downloads), one MultiMesh of cards per mid tile. Collision only for what a car
can reach (near ring). Whatever a peer's graphics level, what collides is the same (law 8): a test bakes at two levels and compares the
collision lists. Budget per near tile on Medium: at most 12 draw calls of scenery and 4000 instances; measure with `--flip-region-near`,
`--flip-region-mid`, `--flip-impostors`.

**7. Water (2 parts).** The lake: a flat plane at its level with the puddle shader's reflection (`puddle.gdshader`'s ray steps by level),
a shore band; the river: a ribbon following its bed in steps, flowing (a scrolled normal), a `WaterSplash` area where a road fords it
(the ford's sound and spray already exist); bridges where a tarmac or gravel road crosses it, from the downloaded `old_bridge` and
`stone_bridge_3arch` models (reduced, checked for marks as `w_world.md` says) or a deck built in code. A car in deep water stalls and is
recovered (the existing recovery), never sinks out of sight. Tests: every crossing of road and river is a ford or a bridge (the validator),
the splash areas line up with the water.

**8. Roaming (3 parts).** Main menu "Serbest sürüş" / "Free roam" next to the race: the same room (host, join, seats, ready), and alone
through phase D's local one-player session (no port opened), a region chosen instead of a stage, the crews spawn at the service park. This
is the game's calm mode too (the owner: "a game you enter to calm down"): no clock, no score, nothing to fail, the countryside to drive and
break; phase Q later adds the radio and the errands' boards, never a timer that roam did not ask for. This item is the one owner of the
roam mode (`RaceSettings.mode` `roam`, the session without a stage graph, recovery in roam): phase Q's draft item Q3 is folded in here.
Roam also loads **a single stage's world** for the four stages that have no region until OW2 (the stage's corridor and walls as built, every
road open both ways, no clock, no gates, recovery to the nearest road point of `graph.road_edges()`, the map marker from the car's world
position, never from `RouteTracker`): one session code for both, a test drives a stage end to start in roam and the marker never jumps.
Trap 8 decided and built; recovery to `RegionRoads.nearest_pose`
(confirmations as in a race, no penalty); damage and dirt stay until the service park's mechanics fix them (drive in, stop, hold R: the
car is restored, free of charge: phase Q's `Economy` later replaces the rule with a paid, timed service and keeps the place); the paper map in the navigator's hands shows the region sheet (item 10); the voice relay's range check keeps working
(crews far apart cost no voice traffic). The host relays a car's snapshots at 30 Hz to peers within 600 m of it and at 10 Hz beyond
(`BodyNetSync` unchanged on the sender; the host's relay thins). A remote car outside one's near ring is drawn without its crew and its
lamps' shadow passes. Bump `Net.PROTOCOL_VERSION`; `JOIN_VERSION` includes the region's `REGION_LAYOUT` and the data hash. Tests: the
headless roam test of trap 8; `tools\nettest.ps1 -Script roam` (three crews spawn, drive 1 km apart, one recovers, one throws a can, the
host's islands hold the can on the ground, discoveries stay local, everyone leaves cleanly).

**9. The start control (1-2 parts).** At each stage's start, the way a real rally runs it: a yellow time-control board 100 m before, the
control's table (W's), the start line and its arch. A crew that stops in the control's box sees "Kara Çam: start ver (R basılı)" / "Black
Pine: start (hold R)"; both seats confirm as for a recovery. First version: the host's crew starts it, the other crews get a prompt to join
(they are moved to the grid behind) or stay roaming; the game goes through `Flow` to the race scene of that stage as today, with the
region's current time and weather, and after the results returns everyone to the region at the stage's finish control. Full version: the
stage runs in place in the region (the stage closed: walls on, barriers across its liaison roads, the region's ring loaded round it), no
loading screen. Tests: the control's rule (pure), the flow test roam → stage → roam.

**10. The world map, discovery, fast travel, the save (3-4 parts: the map and discovery, fast travel, `Profile`).** The region's sheet in the paper map's style (`MapPrint`, phase M's
symbols and type): every road, the land's contours, forests, water, villages, farms, the quarry, stage roads with their start and finish
controls. A map is a printed map: roads and land are all on it from the start; a place's symbol and name show once the crew has been
within its radius (`Discovery`, pure: per player, each peer judges its own car, saved per PC). Baked at bake time (4096 px), the
discoveries and the crews' arrows drawn live on top. In the cabin the navigator holds it (zoom and pan as phase M built); in the pause menu
it is a full-screen map with fast travel to discovered places: the crew's car only, stopped, not in a stage run, both seats agree; the host
validates and moves the car (`reset_to` to the place's arrival pose on a road), the car is held until its near ring is loaded (a fade,
at most 3 s). **The save is `Profile`**, built here exactly as phase Q's brief designs it in Q1 (an autoload after `Settings`, three slots
in `user://profiles/`, `--instance` folders, `PROFILE_VERSION` with a migration chain, atomic writes with a `.bak` and a checksum, saved
never during a stage, the slot picker on the main menu; Q1's tests); this phase fills its sections `meta`, `flags` and `region`, and Q
adds the wallet, garage, career and the rest without a second file. `RegionSave` (pure, tolerant of a missing or corrupt file, versioned by
`REGION_LAYOUT`) is the `region` section: discovered places, the world
clock and weather, the last service park visited; the host's save holds what is broken (bits per tile), repaired when the area has been out
of every crew's sight for 10 minutes (a line in the feed: "Köy halkı tamir etti. Faturayı size kesecekler." / "The villagers fixed it.
They are sending you the bill." The owner rewrites the lines; never cruel, never about a people or a faith).
Tests: discovery, fast travel's rules, the save's round trip and a corrupt file, the map's truth (every road of the plan on the sheet).

**11. Time and weather that move (3 parts, the full version).** `WorldClock` (pure): minutes of the day, a day of 48 real minutes by
default (a setting), the sun's elevation and turn by minute, the host's clock sent every 10 s and on join, peers advancing locally.
`RaceLook` gains `look_at(minute, weather_state)`: its tables blended by the sun's elevation, applied in steps (trap 11); lamps, beams and
pods switched with hysteresis. `WeatherState` (pure, the host's, seeded): per biome a few states and their transitions (forest: clear,
overcast, rain, morning fog; desert: clear, haze, dust storm; mountain: clear, overcast, snow, which never melts within a session), each
change faded over 90 s: `WeatherFx` intensity, fog density, the `wet_mirror` global, wetness of the ground and the surfaces' re-tag
(trap 10). A stage run takes the moment's time and weather and keeps them for its three minutes (the race's discrete look). Tests: the
clock's sun against known minutes, the weather's chain deterministic from the seed and the same on every peer, the re-tag's hysteresis,
a measured step hitch under 4 ms.

**12. Budgets, evidence, docs (2 parts).** `perf.ps1` gains a roam scene (`--region=<id> --roam-route=<places>`) and the flips above; the
numbers per level with three crews into DEVELOPMENT_PLAN, twice in opposite orders, with what ran beside. Shots: the region map sheet;
from the seat at every place by day, golden hour and night; a hill's view over the region (the impostors at range); a tile edge from above;
a stream log of a full lap with no hitch. If Medium falls under 60, take A9a's banked cuts (shadow casters, the backdrop, the mirror at half
rate) inside this phase.

## The first playable version, phase OW (v1: items 1-10 and 12, item 9 in its first version; item 0 ran as OW0; item 11 is OW2's; about 24 parts)
**Çamlık Vadisi** (Pine Valley, the forest region), 3 x 2 km: Black Pine in the west half, Misty Creek (after its second-edition redesign in
L2) in the east, one village between them on a gravel road (W's `VillagePlan`, 6-14 houses; its square with the service park beside it), a
small lake north of the village, a farm with fields on the road to Misty Creek, about 12 km of liaison roads (lanes, gravel, a tarmac road
past the lake), the forest scattered by masks, a horizon of hills. Free roam online with three crews, recovery, the service park, two start
controls (stage runs through the race scene), the world map with discovery, a save. Fixed time and weather chosen in the room (no moving
clock yet). Done for v1: the spike's numbers written down, every test above that belongs to these items, the roam nettest and the roam
flow test pass, Medium over 60 fps with three crews roaming and on both stages, shots reviewed by eye, docs updated.
v1 depends on OW0 (the numbers), L2 (Misty Creek redesigned), W (the village kit, the farm, the people's looks), D (the solo session)
and P2 (the walker as a streaming focus): all are built before this phase in `order.md`, so nothing here is a stand-in.

## The full version: phase OW2, after the owner's play-test (about 40-50 more parts)
The three regions (forest with the small town as its hub: 40-60 buildings from W's kit round a square, a main street, the service park
and the stage starts' liaison roads; desert with Red Canyon, Scorpion Hills, the hamlet, a dry river bed and the quarry; mountain with
Eagle Nest, Glacier Ridge, the shepherds' hamlet and the frozen lake), the river through the forest region with fords and two bridges,
travel between regions, stages run in place (item 9's full version), the moving clock and weather (item 11), host collision islands for
host-simulated things anywhere, discoveries as a reason to roam (viewpoints, the region's signature places, the gags' homes from X in the
region: a market, a washing line, beehives). Honest ceiling: a countryside a crew roams for a few hours with six stages in it, not a city;
interiors, walking, traffic and missions add life in their own phases.

## What this phase owes the phases round it
- **On foot (P2, built before):** `StreamRules` takes every local focus from the start: the own car's camera and the own walker. A walker
  far from the car pins its own near ring (a crew may be 500 m apart: two foci). Parked cars in villages are W's placements, which P2's
  `VehicleKind` promotes to live cars: tiles keep their plan index so the id is the same on every peer.
- **Traffic and people (N, after):** `RegionRoads` carries lanes, a speed per class and the junction graph N9's traffic needs; places
  carry their `arrival` pose.
- **Interiors (I, after):** W builds houses as shells with their openings as data; a tile records each house's door anchors and footprint
  for phase I.
- **Errands, the career, collectibles (Q, after):** places, discovery, the start control and `Profile`. Q resolves its `MissionPlace`s on
  the region's places and roads.
- **The HUD (F):** never a minimap (Direction 3). Getting lost is the navigator's to solve with the region's sheet; the car's dash gets a
  ball compass (a `CarCockpit` part, a real one, lit by the dials at night) in item 10, and the pause menu's full-screen map shows where
  each crew is.
- **A browser build (WD):** never a region; a streamed region in a single-threaded tab is out of reach. The browser demo is standalone
  stages.

## Budget of work, honestly
OW0 (the spike, right after F): 1-2 parts. OW (v1): about 24 parts of 1-3 hours, listed in `order.md` (plan 2, land 2, bake 2, streaming 3, roads 2,
scenery 3, water 2, roaming and the service park 2, start control 1, map, discovery, fast travel, `Profile` and the repairs 4, evidence 1). OW2 (full): 40-50 more. Each part ends with the game whole: until item 8 the region is a dev scene (`scenes/dev/region_test.tscn`,
`--region --at=X+Z --autodrive-route=A+B --fly --quality=N`), the race untouched.

Done means: GAME_DESIGN (a section "The region": the decisions above), CLAUDE.md (the region's classes, tools and dev scene), DEVELOPMENT_PLAN
(the numbers), CHANGELOG, TEST_PLAN (what only people can judge: does roaming between stages feel worth it, is the map readable while
driving), the strings in TR and EN, `ASSET_LICENSES.md` for every model brought in; full GUT, nettest (race and roam), the flow tests
(race and roam → stage → roam) pass; commits on main.
