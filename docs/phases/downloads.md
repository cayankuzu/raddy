# Raw downloads no phase has used yet

Approved by the owner on 2026-10-19 (the picks' batches A, B and D2) and fetched on 2026-11-16 through the owner's own signed-in Chrome
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
