# Raw downloads no phase has used yet

Approved by the owner on 2026-10-19 (the picks' batches A, B and D2; batches E and F and netfox on 2026-11-17, below) and fetched on 2026-11-16 through the owner's own signed-in Chrome
(the owner, that day: whatever needs an account is downloaded there, not in the built-in browser). They lie under `raw_assets/`, which git
ignores: they exist on the dev PC only, and the addresses below fetch them again. Until a phase uses one it is untrusted data: unpack a zip
with a script into a new folder of its own (check every member's name first), read with `python -I`, run nothing that comes out of it.
What goes into the game is a cut or reduced copy under `assets/` (sounds through `tools/cut_audio.py`, textures at 1k-2k) with its row in
`ASSET_LICENSES.md` and its line in the credits. Nothing else may be downloaded without the owner's word.

## Sounds: `raw_assets/audio/freesound/` (A6, item 1)
`tools/cut_audio.py` reads WAV. This PC has Python 3.13 (no `aifc`), no ffmpeg and no numpy: AIFF is big-endian PCM in chunks (a few lines of
`struct`), FLAC needs a small decoder in pure Python (fixed and LPC subframes, Rice-coded residuals), checked against the MD5 of the decoded
sound that the file's STREAMINFO block carries. The number a file's name starts with is its page: `https://freesound.org/s/<number>/`.

| File | By | Licence | For |
|---|---|---|---|
| `445109__breviceps__mud-splat.wav` (0.1 MB) | breviceps | CC0 | clods and a splash landing on the car in mud (`SPRAY`) |
| `265247__anthonychan0__civilian-stun-gun-12-second-zap.wav` (2.1 MB) | anthonychan0 | CC0 | the shock gun: a real zap under or in place of the synthesised one, the crackle while the victim is out |
| `494071__kinoton__big-tree-fall-in-forest.wav` (2.3 MB) | kinoton | CC0 | the falling fir: the creak, the fall, the crash |
| `455659__kyles__applause-cheer-ext-medium-crowd-enthusiastic-whistling-for-outdoor-show-nice-if-take-out-close-claps.flac` (3.4 MB) | kyles | CC0 | the people at the spectator places as a car passes (`Spectators.cheer`) |
| `159763__timgormly__cowbell_rattle_2.aiff` (0.2 MB) | timgormly | CC0 | a fan ringing a cowbell at a spectator place |
| `350710__rp1312__cowbell-single-02.wav` (0.5 MB) | rp1312 | CC0 | the same, single strokes |
| `863981__j_soundeffects__tire-bead-seater-air-blast.wav` (0.3 MB) | j_soundeffects | CC BY 4.0 (credit "j_soundeffects") | a blast of air: a tyre let go by a hard hit, if A6 gives the damage a puncture; else unused |
| `784177__loganzsound__honda-crv-2014-interior-gravel-road-03.wav` (23.7 MB) | loganzsound | CC0 | a cabin on a gravel road: the bed under the stones on the floor (`CarAudio`, the crew only) |

## Models: `raw_assets/downloads/sketchfab/` (all CC BY 4.0: each author is credited by name)
`manifest.json` there has the same list. A `.glb` is Sketchfab's converted file with its textures inside; a `.zip` is the author's own
format, not unpacked yet. Whatever stands beside the road goes through `RoadsideCatalog` or `RallyDressing` like the scans before it:
batched by mesh, a visibility range, a `struck` kind, inside the frame budget A9a leaves; nothing alive where a car can reach it.

| Folder/file | Model | By | For |
|---|---|---|---|
| `hilbre_wall/hilbre-wall.zip` (15.4 MB) | [Hilbre Wall](https://sketchfab.com/3d-models/hilbre-wall-838ee7cacef3427ea879d115c5973b29) | megalitharchive | a dry stone wall along a field and behind a spectator place (struck: rock) |
| `wire_fence/wire_fence.glb` (15.6 MB) | [Wire Fence](https://sketchfab.com/3d-models/wire-fence-a9fd3ae41f744b9bb8becb64180a1231) | Pixel-bit (Hannes Lissner) | a field fence along a straight: posts and wire (fine scenery, not in the mirrors) |
| `hay_bales/hay_bales.glb` (10.3 MB) | [Hay Bales](https://sketchfab.com/3d-models/hay-bales-6b775049e57e4d9da87977905493ebfb) | FrodoUndead | bales in the fields, and beside today's generated straw bales where they look better (struck: straw) |
| `stone_bridge/stone_bridge_3arch.glb` (71.3 MB) | [Stone Bridge_3arch](https://sketchfab.com/3d-models/stone-bridge-3arch-58691a67ba774f2bbccff7ce8f85d1d8) | xplanepilot | the bridge GAME_DESIGN §4 and DEVELOPMENT_PLAN wait for ("bridge and village street wait for their assets"): only with a recipe feature of its own, or as scenery over a stream beside the road; 4k textures, reduce |
| `uk_road_signs/uk-road-signs.zip` (4.6 MB) | [UK Road Signs](https://sketchfab.com/3d-models/uk-road-signs-8bbf0de673114d9d9a1d729f78fdf378) | DrEasu | ordinary road furniture where a stage runs on a public road: pictogram signs only, never at a wrong way's mouth |
| `start_finish_boards/start__finish______sign_boards.glb` (37.8 MB) | [Start & Finish Sign Boards](https://sketchfab.com/3d-models/start-finish-sign-boards-ac0a56d967af4bc8b52fb58eedddb8cb) | Every_3D | the rally's control boards beside the generated ones (`RallyProps`); 4k textures, reduce |
| `delineator_post/traffic--delineator--post-02.zip` (1.8 MB) | [Traffic_ Delineator_ Post_02](https://sketchfab.com/3d-models/traffic-delineator-post-02-a856829217cb42fca00a5fb95459f827) | poryzo3d-works | roadside posts on tarmac stretches and along a cliff side |
| `traffic_cone/traffic_cone.glb` (2.5 MB) | [Traffic Cone (worn)](https://sketchfab.com/3d-models/traffic-cone-66b282e65d3b4da8a883ae8579bfb33c) | jamiemcfarlane | cones at the time control and round the parked cars |
| `flag_swing/flag_swing.glb` (0.8 MB) | [Flag Swing](https://sketchfab.com/3d-models/flag-swing-9d0965e9e71241baa89583ea02090af6) | s.probka | a flag on a pole: only with the flag of Turkey (`TurkishFlag.texture()`, 3:2, the hoist at the pole), and only if it beats today's cloth |
| `old_shed/old_wooden_shed.glb` (41.6 MB) | [Old Wooden Shed](https://sketchfab.com/3d-models/old-wooden-shed-761c0879b18041e1a42bc10de88d2228) | donnichols | a wooden shed in a field or by a junction (struck: wood) |
| `grass_pack/grass_pack_lowpoly_game-ready.glb` (4.6 MB) | [Grass pack (15 tufts)](https://sketchfab.com/3d-models/grass-pack-lowpoly-game-ready-422f42f618d342c6958b02613dc57403) | lolipop_1707 | tufts for the verge and the clearings (`low`, fine scenery) |
| `fir_trees/realistic_fir_trees_pack_lods_gameready.glb` (50.9 MB) | [Realistic fir trees pack (LOD)](https://sketchfab.com/3d-models/realistic-fir-trees-pack-lods-gameready-f58e8b6d733e4b0586e5b7db847b89e7) | lolipop_1707 | young firs with levels of detail for the forest's edge band and the clearings' young growth |
| `sheep/sheep.zip` (30.3 MB) | [Sheep (animated)](https://sketchfab.com/3d-models/sheep-08b05ae799d947f1a68c49b2d661eb53) | kenchoo (MightyGangsta13) | a few sheep far off in a field behind a wall or a fence, never where a car can come |
| `farm_cow/farm_cow_animated_dairy_cattle.glb` (1.0 MB) | [Farm Cow Animated](https://sketchfab.com/3d-models/farm-cow-animated-dairy-cattle-0e780cb5ab6d457198ded7d4e191a03e) | rukh3d | a few cows the same way (the model carries an idle animation: bake a pose or keep the skeletons few) |
| `racing_helmet/racing_helmet.glb` (1.1 MB) | [Racing helmet](https://sketchfab.com/3d-models/racing-helmet-b92c1426837e47778db2487f2c2d7121) | MizuCorp (mizucorp4) | a closed helmet with a visor, the picks' first choice before A5b built the open-face one in code (`CrewHelmet`, GAME_DESIGN §7): only if the owner asks for visors |

## Batch F, 2026-11-17: village, farm and rally-side models (`raw_assets/downloads/sketchfab/`, CC BY 4.0)
Approved by the owner that day ("E ve F'yi indir") after the lead had looked at every preview; fetched through the owner's Chrome.
Nobody has seen them in the engine yet: check each for a maker's badge, a text in another language, an emblem or a flag before it
is used (the moped is a Suzuki, the bus stop is Soviet-themed, the steel water tower has a marking on its tank, the three cars and the
camera may carry badges): cover it or leave the model out. Reduce 4k textures; the farm trailer has 245k triangles.

| Folder/file | Model | By | For |
|---|---|---|---|
| `house/house.glb` (53.9 MB) | [House](https://sketchfab.com/3d-models/e70c4aebc911429ba9a894b38146892c) | SpatialNeglect (@jeandiz) | village house, plastered, hipped roof |
| `old_house/old_house.glb` (119.5 MB) | [Old house](https://sketchfab.com/3d-models/19a1121bab5a4aaaad4d973abe5b61cb) | Yury Misiyuk (@Tim0) | village house, timber cottage |
| `old_vilage_house_lod_0/old_vilage_house_lod_0.glb` (10.4 MB) | [Old vilage house_LOD_0](https://sketchfab.com/3d-models/065cb734d68446ec90e3b43da86a5530) | Nikolay Fedorov (@tomich516) | village house, log house with shutters |
| `old_wooden_barn/old_wooden_barn.glb` (21.3 MB) | [Old wooden barn](https://sketchfab.com/3d-models/4887c7e3de244a9db3eb5b4974418b1b) | Elizabeth Watts (@mitin41401) | old wooden barn |
| `barn_with_mini_shop_old_age/barn_with_mini-shop_old_age.glb` (27.1 MB) | [Barn with mini-shop (old age)](https://sketchfab.com/3d-models/5e59322d38d445ada354967ef5932abf) | Dorin.Stoica | barn with a shop front (village shop) |
| `american_old_barn/american_old_barn.glb` (1.5 MB) | [American Old Barn](https://sketchfab.com/3d-models/1d0b768a8e2449de990b3f69f94c5db6) | andrewriddle | barn to drive through (set piece) |
| `abandoned_house/abandoned_house.glb` (12.2 MB) | [Abandoned House](https://sketchfab.com/3d-models/a0c01ce35a474545b805c0739806aace) | Sengchor (@Sengchor) | ruined house frame |
| `simple_90s_kiosk/simple_90s_kiosk.glb` (3.4 MB) | [Simple 90's Kiosk](https://sketchfab.com/3d-models/a04e69a838054f7cb39a635943ab9b0d) | Vagabondare (@Vagabondare) | roadside kiosk |
| `old_soviet_bus_stop/old_soviet_bus_stop.glb` (8.3 MB) | [Old Soviet Bus Stop](https://sketchfab.com/3d-models/fe4d132434c24e1c8447a6d1190e8c6d) | Coozy (@GameDevNick) | bus stop shelter; title says Soviet: check for emblem/text |
| `old_well_with_hanging_bucket/old_well_with_hanging_bucket.glb` (7.1 MB) | [Old Well with Hanging Bucket](https://sketchfab.com/3d-models/7fa29793eff14a7587ee0af15446a675) | Glowbox 3D (@glowbox3d) | well with bucket |
| `feeding_trough/feeding_trough._low_poly_and_game-ready..glb` (9.6 MB) | [Feeding Trough. Low poly and game-ready.](https://sketchfab.com/3d-models/18d5d6a265214b689f6065d4139fbb6a) | Hakan Unlu (@hakan3d) | feeding trough |
| `old_bridge/old_bridge.glb` (34.9 MB) | [Old bridge](https://sketchfab.com/3d-models/293190e5169947c1a374a9ec850264d3) | NoodlePoodle (@NoodePoodle) | wooden trestle bridge |
| `wooden_bridge/wooden_bridge.glb` (0.6 MB) | [Wooden Bridge](https://sketchfab.com/3d-models/8fa6c9cf27f8494db2e52a8d27804eff) | Akshat (@shooter24994) | wooden footbridge |
| `utility_pole_2048px/utility_pole_-_2048px2.glb` (16.8 MB) | [Utility Pole - 2048px²](https://sketchfab.com/3d-models/dbb782fcb99b4b4395ffc44b0bca7e92) | Mark Peters (@mark-peters) | wooden utility pole |
| `windmill/windmill.glb` (5.0 MB) | [Windmill](https://sketchfab.com/3d-models/0730705327e045bd8cb98a888bd0f954) | Yury Misiyuk (@Tim0) | stone tower windmill (landmark) |
| `water_tower/water_tower.glb` (10.4 MB) | [Water Tower](https://sketchfab.com/3d-models/4e98f8c8fe4e4e9fae250a026974fe99) | Mehdi Shahsavan (@ahmagh2e) | steel water tower (landmark); check the marking on the tank |
| `water_tower_2/water_tower.glb` (16.1 MB) | [water tower](https://sketchfab.com/3d-models/1c2f86dc8f794c85a91706d401d104db) | Lora (@Lora_o) | small water tank on legs |
| `log_fence_and_gate/log_fence_and_gate.glb` (49.0 MB) | [Log Fence and Gate](https://sketchfab.com/3d-models/7562812325144302a1a1669a562a7c64) | Sunbox Games (@sunboxgames) | log fence and field gate |
| `tractor/tractor.glb` (7.9 MB) | [Tractor](https://sketchfab.com/3d-models/278fc1e0516c401eba358d3aa2e55635) | le0tard (@le0tard) | old farm tractor |
| `tractor_trailer_farm_trailer/tractor_trailer_farm_trailer_21_mb.glb` (20.7 MB) | [tractor trailer_farm trailer_21_MB](https://sketchfab.com/3d-models/e4cdf59e867a4e3ca1cd49cf19ca19c2) | Mehdi Shahsavan (@ahmagh2e) | farm trailer (245k triangles per brief: reduce at bake) |
| `fairheaven_sw_84/fairheaven_sw_84_-_low_poly_model.glb` (17.3 MB) | [Fairheaven SW '84 - Low poly model](https://sketchfab.com/3d-models/aa0becb6e854422596cac6b21bf79787) | Daniel Zhabotinsky (@DanielZhabotinsky) | estate car, parked; check for maker badge/logo |
| `lct_3000_95/lct_3000_95_-_low_poly_model.glb` (11.5 MB) | [LCT 3000 '95 - Low poly model](https://sketchfab.com/3d-models/663a0953c038434a918cb85725c88ffa) | Daniel Zhabotinsky (@DanielZhabotinsky) | box truck, parked; check for maker badge/logo |
| `shvan_92/shvan_92_-_low_poly_model.glb` (12.6 MB) | [Shvan '92 - Low poly model](https://sketchfab.com/3d-models/09d718c9cf72401b8534d265a06a803f) | Daniel Zhabotinsky (@DanielZhabotinsky) | van: the rally service van; check for maker badge/logo |
| `classic_bicycle/classic_bicycle__lowpoly__game_ready.glb` (47.5 MB) | [Classic Bicycle | LowPoly | Game ready](https://sketchfab.com/3d-models/da6507928c0c4a5c8776008cdb9f747e) | by__Rx (@by__Rx) | bicycle |
| `mobile_optimized_suzuki_pv_50/mobile_optimized_suzuki_pv_50.glb` (2.1 MB) | [[Mobile Optimized] Suzuki PV 50](https://sketchfab.com/3d-models/2417ca0dab054765981cbd7ddc5efd1c) | Jorma Rysky (@Rysky) | moped; Suzuki maker logo: cover it |
| `tent/tent.glb` (25.6 MB) | [Tent](https://sketchfab.com/3d-models/fa46028e8d3849399ba5271df07ed99c) | Musaev H.N. (@Gajk.Mv) | canvas tent |
| `tent_2/tent.glb` (4.6 MB) | [Tent](https://sketchfab.com/3d-models/9006af5d7af4491dbb573fdddaf8b30b) | Tactical_Beard (@Tactical_Beard) | dome tent |
| `campfire/campfire.glb` (42.8 MB) | [Campfire](https://sketchfab.com/3d-models/1f6834effb514d4c8a0fd34accb88251) | Mandrake (@mandrake_3d) | campfire with pot |
| `camera_with_tripod/camera-with-tripod.zip` (1.2 MB) | [Camera With Tripod](https://sketchfab.com/3d-models/cc324baf6dc548de965c3a47b87f1e27) | FatWasHere (@fathin880) | camera on a tripod; cover any logo |
| `porta_potty_porta_loo/porta_potty__porta_loo.glb` (35.8 MB) | [Porta Potty | Porta Loo](https://sketchfab.com/3d-models/b970702ea74a456e89673e73cfb6d873) | Sean Thomas (@foon.) | portable toilet |

## Batch E, 2026-11-17: Poly Haven models (CC0, no credit owed) in `raw_assets/downloads/polyhaven/models/<id>/`
70 models as glTF with 1k textures, in the layout `tools/fetch_polyhaven.py models <id>` makes under `assets/models/`: copy a folder
there and add its row to `assets/_polyhaven_manifest.tsv` (the rows are in `raw_assets/downloads/polyhaven/_polyhaven_manifest.tsv`), or
fetch it again with the tool; then `tools/texture_imports.py` and the import. Things to knock over, to sell at a market, to sit on,
to stand in a village and beside a rally:

`wooden_crate_01`, `wooden_crate_02`, `wooden_barrels_01`, `wine_barrel_01`, `Barrel_01`, `Barrel_02`, `barrel_03`, `plastic_crate_01`, `plastic_crate_02`, `cardboard_box_01`, `metal_trash_can`, `wicker_basket_01`, `wicker_basket_02`, `wooden_bucket_01`, `metal_jerrycan`, `propane_tank`, `old_tyre`, `cement_bag`, `trashbag`, `hand_truck`, `watering_can_metal_01`, `food_apple_01`, `food_pomegranate_01`, `food_lime_01`, `lemon`, `yellow_onion`, `food_pears_asian_01`, `sweet_potato`, `painted_wooden_bench`, `painted_wooden_chair_01`, `painted_wooden_chair_02`, `painted_wooden_table`, `painted_wooden_stool`, `WoodenTable_01`, `round_wooden_table_01`, `wooden_picnic_table`, `outdoor_table_chair_set_01`, `sofa_02`, `tea_set_01`, `CoffeeCart_01`, `garden_gnome`, `rubber_duck_toy`, `concrete_cat_statue`, `horse_statue_01`, `football`, `boombox`, `WetFloorSign_01`, `standing_chalkboard_01`, `wooden_ladder`, `wooden_broom`, `rusted_spade_01`, `tire_pump`, `metal_toolbox`, `fire_hydrant`, `utility_box_01`, `power_box_01`, `flood_lights`, `portable_generator`, `Megaphone_01`, `stone_fire_pit`, `barrel_stove`, `concrete_road_barrier_02`, `rollershutter_door`, `rollershutter_window_01`, `large_iron_gate`, `vintage_video_camera`, `Camera_01`, `binoculars`, `Lantern_01`, `vintage_oil_lamp`.

ambientCG materials (CC0) as unopened 2K-JPG zips in `raw_assets/downloads/ambientcg/<id>/`, for houses built in code: `Plaster004`,
`Plaster007`, `PaintedPlaster017`, `Bricks108A`, `RoofingTiles012B`, `RoofingTiles014B`, `Planks040` (`tools/fetch_ambientcg.py <id> --textures`
fetches the 1K maps into `assets/textures/`). Not fetched yet, to be chosen by eye: a corrugated steel (`CorrugatedSteel002` to `009`) and a
rubble stone wall (`Rock030`, `Rock051`, `Bricks085` to `100`).

## netfox v1.35.3 (MIT) in `raw_assets/downloads/netfox/v1.35.3/`, for the joining phase
Approved by the owner on 2026-11-17 ("netfox adımlarını sen yap"). The release's zips from https://github.com/foxssake/netfox/releases/tag/v1.35.3,
not unpacked and not installed (sha256 beside each in `RELEASE.txt` there):

- `netfox.extras.v1.35.3.zip` sha256 `4179ac82d607ec907db5cac710ad837ae08a08440e15a509b570bb50be75f71e`
- `netfox.noray.v1.35.3.zip` sha256 `bc116730febcc1f00075f93edb5c238f8bb9fbab5b4f54c3841ab8f0e248da66`
- `netfox.v1.35.3.zip` sha256 `aba89f4e43031cadd643483904dd0844ea89368f72815cad343d02a21f795fb7`

The public noray server and the addon's fit with Godot 4.7.2 are checked when the phase starts; TwoVoIP stays unapproved.
