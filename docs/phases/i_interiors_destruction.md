# Phase I: houses with an inside you can walk into, glass that breaks, and things that come down

The owner (2026-11-17): "Every building's inside detailed; every place can be entered. The feel of destruction must be realistic; people
must really experience it. More things, more interaction, everything thought through." Direction 2 (laws 1, 4, 7, 8) and Direction 3 say
what that can mean in RADDY: nothing alive is ever hit, what breaks stays broken for the crews behind, every kit is measured, the world that
can be hit is the same on every peer.

**What moved out of this brief (Direction 3, `order.md`).** The draft had four blocks. How a hit is felt (`ImpactFeel`, its item 1) is phase
F's, built first. The car's dents, dragging bumper, rattles and crash-cracked windshield (its item 2) and the way a breakable thing breaks
(its items 3-5: `FractureRules`, `DebrisPool`, `DebrisLaunch`, a break per material, the sounds) are phase X's (`x_mayhem.md`), so one
phase owns everything that breaks beside the road and on the car. **This phase comes after W (the houses), P2 (walking) and OW (the region),**
so it does what neither the draft nor W could: rooms a person walks into.

So this phase does three things, and is honest about each:
- **Glass and collapses.** Every pane a car or a can can reach breaks the way glass does; a porch, the market roof, a fence run and a plank
  shed come down when their posts go. It builds on X's catalogue, fracture, debris pool and broken set.
- **Insides.** Every house phase W builds in code gets real rooms behind its windows and doors, furnished and lit, seen from the road
  through glass and open doors, with the places a car goes in (the barn, the market hall, the ruin, a half-built house).
- **Walking in.** Every code-built house's ground floor, the shop, the tea house, the kiosk and the barn can be entered on foot through its
  front door (P2's walker and `use`); upstairs in a two-storey house where its stairs fit the walker's step. The downloaded houses
  (`house`, `old_house`, `old_vilage_house_lod_0`) have no insides and cannot get them cleanly: they stand at the back of a village and their
  doors are locked with a dry line ("Kimse yok. Perdeler kımıldadı ama." / "Nobody home. The curtain moved, though."). So "every place can
  be entered" is true of every building made in code and false of the few downloaded ones, and the game never claims more.

What a free, zero-budget, AI-built version reaches: four to six building kinds with insides, each in seeded variations, a few dozen
furniture models, 20-30 enterable buildings in the region and the stages' villages, three to eight insides drawn at a time; four kinds of
collapsing structure. That is a well-made countryside, not a city. Never call it "GTA size".

## Read first
- GAME_DESIGN "Direction 2" and "Direction 3", §6, §9; CLAUDE.md: `CrashRules`, `RoadFxPool`, `CarLamps` (`HULL_LAYER`, beams),
  `GraphicsQuality` (layers, levels), `RaceLook` (sun, `daylight`, `lamp_light`), the multiplayer model, the frame's cost and the `--flip`
  method of `tools\perf.ps1`; what phases X (catalogue, `FractureRules`, `DebrisPool`, the broken set, `MayhemTally`), W (`VillagePlan`,
  `HouseRules` with its openings as data, lit windows, collision), P1 (the named layers), P2 (`Walker`, `use`, `Interactable`, `Talkable`)
  and OW (tiles, door anchors, the streamer's foci, `Profile`'s `region` section) wrote into DEVELOPMENT_PLAN and CLAUDE.md.
- `docs/phases/downloads.md` (Batch E: the 70 Poly Haven models on the disk; Batch F: the house and barn models; Batch G: the
  furniture approved on 2026-11-17).

## The traps (each ends as a test)
- **The car's beams light through walls.** A beam's shadow map holds only the cars' hulls (`CarLamps.HULL_LAYER`), so a headlight aimed at a
  house would light the room inside it through the wall. The same for the sun on Low (no shadows) and the roof. Interiors go on a render
  layer of their own (`GraphicsQuality.INTERIOR_LAYER`, a free bit: 13-19 are taken; P1 named the physics layers, not these), the sun's and the beams' `light_cull_mask` leave it out, and the daylight
  inside is the room's own (item 6). Test: the masks.
- **The windows are one truth.** `HouseRules` (W) places the windows and doors of the façade; the rooms must agree. `RoomRules` reads the
  openings from the house's spec and may not put an inner wall, a stair or a wardrobe across one. Test over every footprint W can make.
- **Indexes the same everywhere.** X's list of breakables comes from the stage or the region's tile, the dressing plan and the seed; this
  phase appends window panes and structure parts after X's entries, in plan order, built from the seed alone. Interiors themselves can
  differ by graphics level only in how they are drawn, never in what a walker or a car can touch (law 8): the walk layer's collision is
  built from the plan alone, at every level.
- **A walker inside a house that streams out.** An inside is freed past its range; its walk layer must never go while a walker (any peer's,
  as this peer sees it) is inside or within 10 m of its door. A walker in a house whose inside is not built on a peer (another player's
  view) is still drawn on that peer through the open door or windows, standing on the floor's plane: the floor's height is in the plan.
- **Remote cars are frozen kinematic bodies played 100 ms behind**: what a remote car breaks is played when the host's word comes; both
  peers' pieces are cosmetic (X's rule).
- **Glass is not a body.** A pane breaks by the host's word (a hit's `at`, a can in its area, a falling structure), never by a physics
  contact on one peer.

## Deliver (the smallest version that works first; each step leaves the game whole, tests green)

### A. Glass and things that come down
1. **Glass.** `GlassShatter` (pure, tested; from the draft's item 3): a 2D Voronoi of 14-24 cells in the pane round the hit, dense at
   the hit and long towards the frame, about 0.4 ms; the pieces nearest the frame stay in it as a jagged rim. Every pane a car or a can can reach is a breakable: the shop's front, the kiosk, the bus stop, a parked car's windows (W), a
   house's ground-floor windows on the street side. One `MultiMesh` of panes per village (instance custom data: intact, cracked, gone), a
   pane that goes hides and becomes `GlassShatter`'s pieces (the near ones X's `DebrisPool` bodies, the rest `flake`s that glint, `road_flake.gdshader`) with
   the shatter sound. What breaks a window: a car's hit within 1 m of it (the host, from the hit's `at`), a can the navigator throws (cans are
   the host's bodies: the host sees the can enter the pane's area and breaks it, which is the best gag the navigator has), a structure that
   falls on it. Cracked first if the hit is soft (the `CrackPicture` look on a house pane), gone if hard. Host-confirmed, in X's broken set. The shatter's sound is X's glass kind (item 5 there); the hit's feel is F's `ImpactFeel`.

2. **`StructureRules` (pure, tested).** A structure is parts with supports: posts stand on the ground; beams, rails and roof panels rest on
   posts. Breaking posts (each a breakable, X's index) leaves parts unsupported; a part with less than half its supports falls; a roof that
   falls takes what rests on it. Four kinds, built in code from planks, poles and the existing materials:
   - **a porch** in front of a W house (two to four posts, a lean-to roof of tiles or planks): the house stays solid, the porch is not;
   - **the market roof** (X's stall: a canopy of cloth on six poles; it folds down on what stands under it);
   - **a fence run** (posts and rails: a post that goes drops the ends of its two rails; three posts in a row and the run lies down);
   - **a shed of planks** (four corner posts, plank walls, a corrugated roof): hit at a corner it racks, hit square it collapses.
   The host decides the collapse (from the posts broken) and sends one message with its start time; the fall is a function of time, the same
   on every peer: each falling part turns about its last support's edge under gravity (analytic, no bodies) and breaks into its baked pieces
   where it meets the ground. If a car is under a falling roof when it lands (the host's snapshot), that crew takes a light hit and the
   canopy or the planks on the windshield (X's sheet gag on the `Cabin` glass: the wipers or the speed clear it). Bots: structures stand off
   the line (X's rule: no gag decides a medal by luck). Tests: two of four posts gone collapses, one does not; the fence's domino; the pose at a
   time; the same message gives the same fall.

### B. Insides
3. **`RoomRules` (pure, tested).** From a house's spec (`HouseRules`: footprint, storeys, openings, kind) and its seed: rooms by splitting
   the footprint (the longer side first, never under 2.4 m a side; a hall behind the front door; stairs along a wall in a two-storey house),
   kinds by building:
   - **house:** hall, kitchen (at the back, by the yard door), sitting room (the street's windows), one to three bedrooms (upstairs first),
     a wash room;
   - **village shop:** the shop (counter, shelves, the till, crates of fruit by the door), a store room behind;
   - **tea house:** one big room (tables, stools, the stove, the tea counter), a kitchen corner;
   - **barn:** stalls along one side, the hay loft, the open floor (the set piece's barn: both doors open, the floor clear for a car);
   - **kiosk, bus stop:** one room or none; **the ruin:** no ceiling, rubble and what was left.
   Doors between rooms on the shortest walls' middles; every room reachable from the front door (a graph test); every façade window owned by
   exactly one room; no inner wall within 0.15 m of a window's edge; a ceiling height and a floor that a person could walk later (the floor is
   a plane at the doorstep's height, the stairs a real rise of 0.18 m a step). Tests over every footprint and storey W can make.
4. **`FurnishRules` (pure, tested) and the furniture catalogue.** Per room kind, slots along the walls and in the middle; never in a door's
   swing, never under a window's sill if taller than it, nothing overlapping (boxes), the bed's head on a wall, the table with chairs round
   it; seeded, so each house differs. The catalogue (data, like `RoadsideCatalog`): the model, its box, its room kinds, wall or middle, its
   `struck` and its breakage (for the places a car reaches: the barn, the shop's front, the tea garden). Built in code, because these
   are what make the rooms read as this country's: a sedir (the low sofa along the sitting room's walls, with cushions), kilims and rugs
   (`shaders/kilim.gdshader`: a seeded geometric pattern, never text or emblems), lace curtains and tulle (`cloth.gdshader`), a wood stove
   with its pipe to the wall, shelves of jars, a hanging lamp, framed pictures of landscapes and of nobody (no faces), a tea glass on every
   tea-house table. From Batch E on the disk: `painted_wooden_table`, `painted_wooden_chair_01/02`, `painted_wooden_stool`, `WoodenTable_01`,
   `round_wooden_table_01`, `sofa_02`, `tea_set_01`, `wooden_bucket_01`, `wicker_basket_01/02`, `metal_jerrycan`, `wooden_broom`,
   `vintage_oil_lamp`, `Lantern_01`, `barrel_stove`, `boombox`, `cardboard_box_01`, `wooden_crate_01/02`, the fruit and vegetables, `metal_toolbox`,
   `wooden_ladder`, `rusted_spade_01`, `hand_truck`, `portable_generator`.
   **Approved on 2026-11-17 (the owner left the decision to the lead) and on the disk as `downloads.md`'s Batch G: 66 Poly Haven models
   (CC0, glTF with 1k textures) in `raw_assets/downloads/polyhaven/models/<id>/`, the list read from `api.polyhaven.com/assets?t=models`
   (`decorative_book_set_01` is not there: no glTF, and its covers carry text):** furniture `ArmChair_01`, `Rockingchair_01`, `WoodenChair_01`, `WoodenTable_02`,
   `WoodenTable_03`, `dining_table`, `dining_chair_02`, `small_wooden_table_01`, `side_table_01`, `coffee_table_round_01`, `CoffeeTable_01`,
   `old_bed_frame`, `vintage_day_bed`, `painted_wooden_cabinet`, `painted_wooden_cabinet_02`, `painted_wooden_nightstand`,
   `painted_wooden_shelves`, `painted_wooden_sofa`, `vintage_cabinet_01`, `vintage_wooden_drawer_01`, `drawer_cabinet`, `wooden_bookshelf_worn`,
   `wooden_display_shelves_01`, `steel_frame_shelves_01`, `steel_frame_shelves_02`, `Shelf_01`, `plastic_monobloc_chair_01` (the tea garden's
   chair everywhere in this land), `folding_wooden_stool`, `wooden_stool_01`, `wooden_stool_02`, `bar_chair_round_01`, `ornate_mirror_01`,
   `throw_pillows_01`; the house `electric_stove`, `CashRegister_01`, `ceiling_fan`, `scandinavian_masonry_heater` (as a tiled stove),
   `vintage_electric_kettle`, `wall_clock`, `mantel_clock_01`, `vintage_grandfather_clock_01`, `vintage_microwave`; things on shelves
   `jug_01`, `pot_enamel_01`, `brass_pot_01`, `brass_pot_02`, `brass_pan_01`, `ceramic_vase_01` to `04`, `wooden_bowl_01`, `wooden_bowl_02`,
   `carved_wooden_plate`, `potted_plant_01`, `potted_plant_02`, `planter_box_01`, `decorative_book_set_01`, `chess_set`,
   `hanging_picture_frame_01` to `03`, `standing_picture_frame_01`, `brass_candleholders`, `vintage_suitcase`; light `Chandelier_01`,
   `industrial_wall_sconce`. Look at each in the engine (no text in another language, no emblem, no foreign flag, no face in a picture frame:
   the frames take a picture made in code). Each copied with its manifest row. A model that turns out unusable (missing, broken, a mark
   that cannot be covered) is left out and its slot takes a Batch E model or one built in code; say which.
   Tests: no overlap, no door blocked, every room kind furnished, every catalogue id exists on the disk, the same seed the same room.
5. **`InteriorBuilder` and `InteriorStreamer`.** The builder makes a house's inside from its plan: the inner skin of the walls (plaster or
   painted plaster, a skirting, a tiled kitchen wall), floors (boards, tiles, a rug), ceilings with a beam or two, stairs, inner doors on
   hinges (some open, seeded), the furniture as one `MultiMesh` per model per house, the code-built furniture merged into one mesh per house:
   about 8-12 draw calls a house. The mesh data is made on `WorkerThreadPool` (pure arrays), the nodes added on the main thread at most 1.5 ms
   a frame. The streamer (local, per peer, cosmetic) keeps the insides of the houses near the local camera: built within 70 m, freed past 95 m
   on Medium (Low 40/55 m, High 100/130 m), at most 4 / 6 / 8 at once, nearest first; the façade's windows show the far version (item 6)
   until then. Collision: the walk layer of item 9 (the house's shell stays W's solid body for cars; the barn, the market hall and the ruin are open
   to cars by W's own collision). Tests: the hysteresis, the cap,
   the per-frame slice, the plan built twice is the same mesh.
6. **Light inside.** By day: the sun and the beams leave `INTERIOR_LAYER` out (the first trap), so the inside is lit by its windows:
   a baked term per vertex (`InteriorLight`, pure: how much sky each point sees through the room's windows, a few rays a vertex at build,
   tested on a box room), and the sun's patch on the floor and walls, computed in the interior's shader from the sun's direction and the
   room's window rectangles (up to four a room, uniforms): the pool of light under a window that moves with the time of day; at golden hour
   it stretches long and warm. At night: the rooms behind W's seeded lit windows have their lamps on, one shadowless `OmniLight3D` a lit room
   within 60 m of the local camera (at most 8), an emissive lamp beyond; the rest dark, a television's flicker in one house a village (a
   light whose colour wanders, no picture). Far away: `shaders/interior_window.gdshaderinc` on W's window glass draws a room behind the pane
   (interior mapping: a ray into a box, its walls, floor and ceiling from an atlas, a furniture card or two at a depth), the atlas baked by
   `tools/make_room_atlas.gd` (needs a window) from the real rooms of each kind, so the far and the near version are the same room; the switch
   crossfades over 0.3 s. Curtains are a layer in front, half drawn, by seed.
7. **Doors, and the village reacting.** Doors swing on hinges (`HouseDoor`, a state per door from the seed until a walker or a car changes it, then
   the host's; it is the `Interactable` of item 9; the shop's open in the day);
   a crash, a broken pane or a collapse within 40 m of a house (the host's word, already sent) makes that village answer on every peer,
   each peer from the same message: a light comes on behind a dark window, a door opens and a villager (W's kinds) steps onto the step,
   hands on the hips or shaking a fist (a pose of the crowd's shader; phase N later gives the villager a body and a line), a dog barks (approved farm sounds or synthesised). Nobody comes into
   the road (law 1). The feed's lines for it (X's `MayhemTally` and F's `HudFeed`, navigator's HUD only) are written as dark, dry understatement about things, never
   about people's misfortune: "Muhtarın çardağı artık yok" / "The headman's porch is no more", "Bakkalın camı: sigortalı mıydı?" / "The shop's
   window: was it insured?", an award for the most collapses ("Yıkım Ekibi" / "Demolition Crew"; not "Kentsel Dönüşüm": urban renewal is politics, which the
   writing guide bans); every line goes through the writing guide and the lead approves it.
8. **The places a car goes in.** The set piece's barn (W) gets its inside: hay, stalls with nobody in them, tools on the walls, a loft with
   bales that fall when a post is hit (item 2), dust hanging in the light from the doors; the market hall (a roof on posts over stalls, item
   2's market roof at the size of a street); the ruin (`abandoned_house`, Batch F: rubble, a fallen beam, a bed frame, weeds); a half-built
   house (a concrete frame and brick infill built in code, empty, scaffold planks that break). The downloaded houses (`house`, `old_house`,
   `old_vilage_house_lod_0`) have no insides and cannot get them cleanly: they stand at the back of a village, their glass darkened or
   given the far interior shader if their windows are separate meshes (look at each); the code-built houses stand where the road sees in; the downloaded ones' doors are locked (item 9).

### C. Walking in
9. **Walking in.** The walk layer, built from the same plan as the inside (law 8: from the plan alone, at every graphics level): the
   floors as `HeightMapShape3D`-free boxes on P1's `world` layer, the inner walls as thin boxes, the stairs as a ramp collider under the
   drawn steps (a rise of 0.18 m a step, inside P2's 0.35 m step and 40 degree slope), door frames left open. Front doors and inner doors
   are P2's `Interactable` (`use` opens and shuts them, the hint line names them, a door's state the host's and synced like the car's doors,
   one byte a door per village in X's broken set's message); a door a car breaks (the barn's, the shop's) stays open. The streamer keeps the
   walk layer of every house a walker is in or near (the trap above) whatever the draw range; a walker who walks in sees the inside built
   within a frame budget before the door finishes opening (the door's swing hides the build: start it at `use`). Things inside that a
   walker may move: P2's carry rule (under 25 kg: a chair, a bucket, a tea glass, a basket; furniture over 25 kg stays where it is, a wardrobe
   is part of the room); breakables inside are X's catalogue kinds placed by `FurnishRules` with their index after the panes'. Nothing alive
   inside a house except phase N's people on their schedule (N adds them; this phase leaves each room a `spot` list for them: a chair, a
   window, a stove). Tests: every room reachable on foot from the front door (a walker bot walks every house of every kind and seed in a
   headless physics test: no stuck, no fall through a floor, no wall passed); stairs climbable; the walk layer the same at Low and High; the
   streamer never frees a layer under a walker.

## Budgets (the dev laptop, RTX 5070 Laptop; Medium over 60 fps with three crews, measured in the region's village and at Black Pine's barn)
- Insides: 8-12 draw calls and at most 60k triangles a house, at most 6 live on Medium; all of it at most 0.6 ms of the frame on Medium by
  day and 0.9 ms at night with its lamps (`--flip-interiors`); the far windows' shader at most 0.1 ms; building one inside never costs a
  frame more than 1.5 ms of main-thread work (`work_ms`). The walk layer: at most 40 static shapes a house, none outside the near ring.
- Glass: a shatter at most 0.5 ms on the frame it happens; at most 2 a frame (the rest wait a frame).
- Collapses: no bodies while falling; at most two at once.
- If Medium goes under 60, take A9a's banked cuts (trees first) inside this phase and measure again.

## Tests
`test_glass_shatter`, `test_structure_rules`, `test_room_rules`, `test_furnish_rules`, `test_interior_light`, `test_interior_streamer`,
`test_walk_in` (the walker bot through every house kind and seed), a test that the breakables' indexes with panes, structure parts and the
things inside match at two graphics levels and two effects settings, the light masks. Nettest: a client breaks a porch's posts and every
peer prints the same `NET collapse <id> <t>`; a navigator's can breaks a shop window everywhere; a walker opens a house's door and every peer
sees it open; a late peer gets the broken set and the doors. A headless bot through each stage with every structure drawn in turn: no
recovery, the same time within a second. A flow test with a village.

## Evidence (few contact sheets, `reports/screenshots/i_*`)
From the seat: a porch coming down, a shop window to a can; a village street by day, golden hour and night from the road (the near rooms and
the far windows side by side, to judge that they match), the sun's patch moving through a sitting room, the barn's inside from the car. On
foot: walking from the street into a house, through its rooms and up its stairs (six frames each, day and night, first and third person).
Sound: a Movie Maker capture's WAV of a pane and a collapse, peaks under -1 dBFS. `perf.ps1` flips twice, both orders, with what ran beside
it named. TEST_PLAN (what only people judge): is walking into a house worth it, does the village's answer stay funny the tenth time, does a
room read as a room in this land.

## Out of scope
Breaking a house's walls (houses stay solid: a wall that a client's car went through on one peer and not another is X's first trap again);
the downloaded houses' insides; destruction of terrain, trees or the road; soft-body car deformation (X's dents are a shader); any download
the owner has not approved; anything alive in a place a car can reach; people inside houses (phase N puts them on the `spot`s).

## Size
About 16 builder parts of 1-3 hours: glass 2, structures 2, rooms 2, furnishing 2, builder and streamer 2, light inside 2, doors and the
village's answer 1, the places a car goes in 1, walking in 1-2, measuring, evidence and the docs 1.

Done means: GAME_DESIGN (§6 and "Direction 3": insides, walking in, what is and is not enterable), CLAUDE.md (each new class beside the ones
it extends), DEVELOPMENT_PLAN (the measures), CHANGELOG, TEST_PLAN, `ASSET_LICENSES.md` and the credits for every model and recording used,
the strings; full GUT, nettest and flow tests pass; commits on main.
