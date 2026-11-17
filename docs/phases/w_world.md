# Phase W: a countryside that is alive

The owner (2026-11-17, four times): "Make the world much richer: houses, people, use every 3D model you can. Everything must be full,
perfect. A real rally's chaos." Today a stage is forest, rock and sand with rally dressing and a few crowds: no village, no farm, no field,
no one at home. Direction 2 (laws 1, 7, 8) and phase L's signature places and gag slots say where the life goes; this phase builds it.

**Since Direction 3 (2026-11-17, `order.md` phase 8).** `VillagePlan` takes a footprint and a road polyline, not a stage: the region of
phase OW places villages too. `HouseRules` outputs each house's openings (windows, doors) and door anchors as data for phase I's insides.
Parked cars are placements phase P2's `VehicleKind` can promote to live cars (an index from the plan, the same on every peer). The marshals
and every official are the rally's own (law 10: no gendarme, police or soldier), and no place of worship is built anywhere. X, built
before this phase, gives the village its breakables (crates, fences, the market stall) and the crowd's dive.

Read first: GAME_DESIGN "Direction 2" and §4; CLAUDE.md on `RoadsideDresser`, `RallyDressing`, `RallyProps`, `Spectators` and
`SpectatorClothes`, `GraphicsQuality`, the frame's cost and the `--flip` method; `docs/phases/downloads.md` (what lies on the disk: the
Sketchfab village, farm and rally-side models, the Poly Haven props, the ambientCG plaster, brick, tile and plank materials); the A9a section of
DEVELOPMENT_PLAN (the frame's budget and the banked cuts).

## Rules for every model brought in
Copy what is used from `raw_assets/downloads` into `assets/` (the Poly Haven layout of `tools/fetch_polyhaven.py`; a Sketchfab model in
`assets/models/sketchfab/<slug>/`), reduce textures to 1k-2k and triangles where a level of detail does it (`ImporterMesh.generate_lods`),
look at it in the engine in daylight and at night before it is placed: no maker's badge or name, no text in another language, no emblem, no
flag but Turkey's (cover it in the material or leave the model out; the moped's maker's name, the Soviet-themed bus stop, the water tower's
marking, the three cars' and the camera's badges are known to check). Each gets its row in `ASSET_LICENSES.md` (CC BY: the author, the
title, the address) and so the credits. A model that does not hold up is left out and the brief's item is built in code.

## Deliver
1. **Villages.** `VillagePlan` (pure, tested: from a footprint, a road polyline and a seed, which a stage's signature place or the region gives): a village is a street of 6-14 buildings
   along the stage's own road or round a square beside it, with yards, walls and gates, set back so the road keeps its width and its
   sightlines (the judges see a village like any feature). Houses are built in code by a pure `HouseRules` (footprint, one or two storeys,
   a hipped or gabled or flat roof, the walls' material, windows with shutters, a door with steps, a balcony on some, a chimney, a yard wall)
   with the ambientCG plaster, painted plaster, brick, tiles and planks, so that a village looks like a place in this land: whitewashed
   plaster and tiles in the desert's and the mountains' villages, timber and the downloaded log house, cottage and plastered house in the
   forest's; the barns, the village shop, the kiosk, the ruin and the bus stop where they fit; a fountain or the well on the square, the
   trough, benches, a tea garden (tables, chairs, the tea set), a few parked cars, bicycles and the moped, utility poles with wires that sag
   between them, lamps. One mesh per house kind and material set, batched by chunk; budgets measured.
2. **Farms and fields.** Fields by the road as patches of ground with rows (a shader pattern of the ground: ploughed, stubble, green,
   snowed over) bounded by the dry stone wall, the wire fence and the log fence with its gate; bales and a haystack, the tractor and
   trailer in a yard, sheep and cows grazing behind the walls (a slow idle in the shader; they look up as a car passes, each peer from
   what it sees), the windmill and the water towers on rises as landmarks seen from far, scarecrows, beehives (a box in code).
3. **More people, more kinds.** The crowd's system gains kinds of people, each a pose and an outfit, and a second bake: women in long
   skirts and headscarves, children, old men with caps; marshals in orange vests with whistles and boards (never a flag but Turkey's),
   photographers crouched by the road with a camera on a tripod, a TV crew, campers by their tents and a fire (the two tents and the
   campfire models), tea drinkers sitting at the tea garden, villagers at their doors, a granny with a broom on her step; at the start and
   finish the densest crowd, on a bank, a wall, a roof. Every kind obeys law 1 (phase X's dive applies to all who stand near the road).
4. **The rally's own place.** At the start: the service van, a gazebo (built in code), tents, the generator, flood lights at night, a
   loudspeaker on a pole, portable toilets, a car of the organisers, the time control's table; at the finish a flying finish board, the
   stop control, a crowd behind tape. Sounds: a far loudspeaker voice (a pure-Python tone sketch or silence: no invented words), the
   generator's hum, the crowd.
5. **Night.** Lit windows (a seeded few per village, warm, emissive with no light), lamps with one cheap light each only near the road,
   campfires glowing and flickering, the flood lights at the start as real lights; the beams find the rest.
6. **The map knows.** Villages, farms, fields, landmarks and the rally's place go into `RallyDressing.plan` (or a plan beside it) as items
   with a kind, a place, a turn and a size, so phase M's map prints them without new drawing code; give each kind a symbol in `MapPrint`.
7. **Collision and peers.** What a car can reach collides (houses, walls, poles, parked cars: solid; bales, fences, crates: phase X's
   breakables); all of it from the stage's seed alone, the same on every peer and at every graphics level (a test compares two levels);
   nothing placed where it changes a sightline the judges measured, unless it closes one.

## Budget and evidence
`perf.ps1 --flip-village --flip-farms --flip-people` (twice, both orders) on Low, Medium and High with three crews on every stage that has
them: Medium stays over 60 fps on the dev laptop; if it does not, take up A9a's banked cuts (trees first) inside this phase and measure again.
Evidence in few contact sheets: each stage's signature place and village from the seat by day, at golden hour and at night; a field with its
animals; the start's place at night; the map sheet with the villages on it; before and after for each stage (`tools\stage_shots.ps1 -Compare`).

Done means: GAME_DESIGN, CLAUDE.md, DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN, `ASSET_LICENSES.md` and the credits, the strings; full GUT, nettest and
a flow test pass; commits on main.
