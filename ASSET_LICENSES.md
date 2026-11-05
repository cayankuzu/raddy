# Asset licences

Every third-party file shipped with RADDY, where it came from and under which licence. Only
licences that allow use in a sold game are accepted (CC0, CC-BY with credit, MIT). Keep this file
in step with `assets/`: add a row when an asset is added, remove it when the asset goes.

## Code and tools
| Component | Licence | Source |
|---|---|---|
| Godot Engine 4.7.2 | MIT | https://godotengine.org/license |
| GUT 9.7.1 (tests only, not exported) | MIT | https://github.com/bitwes/Gut |
| Beckett Lite 1.16.0 (editor only, not exported) | MIT | https://github.com/beckettlab/beckett-godot-mcp |

## Textures (Poly Haven, CC0 1.0)
Poly Haven assets are CC0 (public domain dedication, https://polyhaven.com/license); no credit
is required, it is given anyway. Files: `assets/textures/<id>/<id>_{diff,nor_gl,arm}_1k.jpg`
(diffuse, OpenGL normal, AO/roughness/metal), downloaded with `tools/fetch_polyhaven.py`.

| Asset | Author(s) | Used for | Page |
|---|---|---|---|
| Rocky Trail | Amal Kumar | the stones scattered on gravel roads | https://polyhaven.com/a/rocky_trail |
| Gravelly Sand | Dario Barresi | dirt roads, packed wheel tracks, desert ground (patches) | https://polyhaven.com/a/gravelly_sand |
| Brown Mud Leaves 01 | Rob Tuytel | mud roads, forest ground (patches) | https://polyhaven.com/a/brown_mud_leaves_01 |
| Sand 01 | Rob Tuytel | sand roads, desert ground | https://polyhaven.com/a/sand_01 |
| Snow 02 | Rob Tuytel | snow roads, snow cover | https://polyhaven.com/a/snow_02 |
| Asphalt 02 | Rob Tuytel | tarmac | https://polyhaven.com/a/asphalt_02 |
| Forest Ground 01 | Rob Tuytel | forest ground | https://polyhaven.com/a/forrest_ground_01 |
| Sparse Grass | Amal Kumar | forest ground (second layer), mountain ground (patches) | https://polyhaven.com/a/sparse_grass |
| Dry Ground 01 | Rob Tuytel | desert ground (second layer) | https://polyhaven.com/a/dry_ground_01 |
| Rocky Terrain 02 | Amal Kumar | mountain ground | https://polyhaven.com/a/rocky_terrain_02 |
| Gravel Ground 01 | Rob Tuytel | loose gravel on roads, mountain ground (second layer) | https://polyhaven.com/a/gravel_ground_01 |
| Rock Face 03 | Dario Barresi, Rico Cilliers | rock on steep slopes | https://polyhaven.com/a/rock_face_03 |

## Models (Poly Haven, CC0 1.0)
glTF with 1k textures in `assets/models/<id>/`, downloaded with `tools/fetch_polyhaven.py`.

| Asset | Author(s) | Used for | Page |
|---|---|---|---|
| Shrub 03 | Rico Cilliers | forest/mountain bushes | https://polyhaven.com/a/shrub_03 |
| Shrub 02 | Rico Cilliers | forest/mountain undergrowth (tall, airy bushes) | https://polyhaven.com/a/shrub_02 |
| Shrub 04 | Rico Cilliers | forest/mountain undergrowth (low creeper) | https://polyhaven.com/a/shrub_04 |
| Grass Medium 01 | Rob Tuytel, Rico Cilliers | single tufts of grass in forest and mountain | https://polyhaven.com/a/grass_medium_01 |
| Fern 02 | Rob Tuytel, Rico Cilliers | forest ferns | https://polyhaven.com/a/fern_02 |
| Dry Branches Medium 01 | Rico Cilliers | fallen branches | https://polyhaven.com/a/dry_branches_medium_01 |
| Tree Stump 01 | Rob Tuytel | forest stumps (collide) | https://polyhaven.com/a/tree_stump_01 |
| Boulder 01 | Rico Cilliers | boulders (collide) | https://polyhaven.com/a/boulder_01 |
| Namaqualand Boulder 04 | Jenelle van Heerden | desert boulders (collide) | https://polyhaven.com/a/namaqualand_boulder_04 |
| Namaqualand Boulders 01 | Greg Zaal, Jenelle van Heerden | stone scatter | https://polyhaven.com/a/namaqualand_boulders_01 |
| Rock 07 | Jenelle van Heerden | pebbles | https://polyhaven.com/a/rock_07 |
| Rock Face 01 | Dario Barresi | rock outcrops (collide) | https://polyhaven.com/a/rock_face_01 |
| Dead Quiver Trunk | James Ray Cock, Dario Barresi, Rico Cilliers | desert dead trees (collide) | https://polyhaven.com/a/dead_quiver_trunk |
| Crystalline Iceplant | James Ray Cock, Jenelle van Heerden | desert ground plants | https://polyhaven.com/a/crystalline_iceplant |
| Wild Rooibos Bush | James Ray Cock, Jenelle van Heerden | desert bushes | https://polyhaven.com/a/wild_rooibos_bush |
| Old Tyre | MP | race furniture (tyre stacks) | https://polyhaven.com/a/old_tyre |
| Concrete Road Barrier 02 | Amal Kumar | race furniture (barriers, the blocks at the arches' towers) | https://polyhaven.com/a/concrete_road_barrier_02 |
| Wooden Picnic Table | Ulan Cabanilla | spectator areas | https://polyhaven.com/a/wooden_picnic_table |
| Painted Wooden Bench | Kirill Sannikov | spectator areas | https://polyhaven.com/a/painted_wooden_bench |
| Plastic Monobloc Chair 01 | Kuutti Siitonen | spectator areas | https://polyhaven.com/a/plastic_monobloc_chair_01 |
| Covered Car | MP | cars parked behind the tape | https://polyhaven.com/a/covered_car |

## Sketchfab models (CC BY 4.0, credit required)
Downloaded 2026-10-13 with the user's approval from their logged-in Sketchfab session; licence and
author confirmed on api.sketchfab.com. CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ —
the same credit lines are shown in the game's Credits screen.

| Asset | Credit line | Used for | File |
|---|---|---|---|
| Milano '95 - Low poly model | "Milano '95 - Low poly model" by Daniel Zhabotinsky (https://sketchfab.com/DanielZhabotinsky), CC BY 4.0, https://sketchfab.com/3d-models/milano-95-low-poly-model-122a22d210234596ad23623588d0d166 | the rally car (body, interior, glass, wheels) | `assets/vehicles/milano95/milano95.glb` |
| Coniferous Forest Assets Pack | "Coniferous Forest Assets Pack" by Dari (https://sketchfab.com/dariiiii), CC BY 4.0, https://sketchfab.com/3d-models/coniferous-forest-assets-pack-240ce9cf0ad3474f809a59f9446e63cd | firs, pines, saplings, dead trees, logs | `assets/models/sketchfab/conifer_pack.glb` |
| Birch trees | "Birch trees" by Igor_K. (https://sketchfab.com/Igor_K.), CC BY 4.0, https://sketchfab.com/3d-models/birch-trees-de6263e5400b4a52a795decf84f06575 | birches | `assets/models/sketchfab/birch_set.glb` |
| Birch tree | "Birch tree" by evolveduk (https://sketchfab.com/evolveduk), CC BY 4.0, https://sketchfab.com/3d-models/birch-tree-aa842dffd9654d33b8b91170ce83c172 | large birch | `assets/models/sketchfab/birch_treeit.glb` |

Changes made in RADDY: the car is re-oriented, its axles centred, its paint recoloured per team,
its glass wired to the cabin systems and its wheels/steering animated; trees are instanced and scaled.

## Foliage atlases (ambientCG, CC0 1.0)
ambientCG assets are CC0 (https://ambientcg.com/license). Colour and opacity are merged into
`<id>_albedo.png`; downloaded with `tools/fetch_ambientcg.py`.

| Asset | Used for | Page |
|---|---|---|
| Foliage 008 (grass blades) | grass clumps | https://ambientcg.com/view?id=Foliage008 |
| Foliage 002 (dry grass) | dry grass in desert and mountains | https://ambientcg.com/view?id=Foliage002 |

## Sounds
Cut and mixed into `assets/audio/` by `tools/cut_audio.py` from the raw files that
`tools/fetch_audio.py` downloads into the git-ignored `raw_assets/audio/`.

| Source | Licence | Used for | Files |
|---|---|---|---|
| Sonniss #GameAudioGDC 2020, Pole Position Production: "Toyota Corolla 1998 Rally car" (t9 onboard exhaust, t11 horn) | Sonniss GDC bundle licence: royalty-free in commercial products, no attribution required, not to be resold as sound effects | engine loops (low/mid/high), horn | `assets/audio/engine/*.wav`, `assets/audio/car/horn.wav` |
| Sonniss #GameAudioGDC 2018, Pole Position Production: "Skids & Screeches Tarmac" (t4) | as above | tyre squeal loop | `assets/audio/tyres/skid.wav` |
| Sonniss #GameAudioGDC 2020, Pole Position Production: "Car Destruction" (t44 impacts interior) | as above | crash one-shots | `assets/audio/impacts/crash_*.wav` |
| BigSoundBank (Joseph Sardin): #1293 rain on a car roof, #2718 thunder, #2799 and #2805 road map | CC0 1.0 (https://bigsoundbank.com) | rain on the roof, thunder, paper map | `assets/audio/ambience/*.ogg`, `assets/audio/car/map_rustle_*.ogg` |
| Kenney "Impact Sounds" and "Interface Sounds" | CC0 1.0 (https://kenney.nl) | small knocks, UI clicks | `assets/audio/impacts/impact*.ogg`, `assets/audio/ui/*.ogg` |

Synthesised by `tools/cut_audio.py` (no source recording): gravel crunch, tyre rumble, wind,
water slosh and the splash. By `tools/make_exhaust_pops.py`: the exhaust's pops. By `tools/make_shock_sounds.py`: the shock
gun's pop and crackle (`assets/audio/shock/`).

## Fonts and icons (fetched by `tools/fetch_assets.py` for the UI of phase A7; they ship with the build)
| Source | Licence | Files |
|---|---|---|
| Saira, The Saira Project Authors | SIL OFL 1.1 (`assets/fonts/saira/OFL.txt`) | `assets/fonts/saira/Saira-Variable.ttf` |
| Inter, The Inter Project Authors | SIL OFL 1.1 (`assets/fonts/inter/OFL.txt`) | `assets/fonts/inter/Inter-Variable.ttf` |
| JetBrains Mono, The JetBrains Mono Project Authors | SIL OFL 1.1 (`assets/fonts/jetbrains_mono/OFL.txt`) | `assets/fonts/jetbrains_mono/JetBrainsMono-Variable.ttf` |
| Tabler Icons, Pawel Kuna | MIT (`assets/icons/tabler/LICENSE`) | `assets/icons/tabler/*.svg` |

## Generated in the project
Terrain, road ribbons, the paper map drawing, particle puffs, the puddle ripples and the noise
used for surface variation are generated by RADDY's own code at run time. The instrument face
(`assets/vehicles/milano95/gauge_face.png`) is baked by `tools/make_gauge_face.gd`, its digits in Godot's
default font (Open Sans, OFL). The clouds (`assets/sky/clouds_*.png`) are baked by `tools/make_clouds.gd`.
