# Phase WD: a taste in the browser, the game as a download

The owner (2026-11-17) wants a demo that plays in the browser on itch.io and the full game as a download. GAME_DESIGN §1 said "no browser
version at launch" and allowed a web teaser only if a Compatibility build of one stage with the solo mode passes the look gate (§9). This
phase is that teaser, built from the same code: one or two stages, solo with the bot co-driver, the cabin's chaos, in the browser; a big
"download the full game / play with friends" button on its menu and its page. It is a shop window for the download, not a second game.

It comes **after the owner's play-test and its fixes, and just before A10** (Direction 3, `order.md`): D has built solo, the share card
and the credits, F the shipped HUD fonts, A7 the menus, A9b the measured desktop build; A10 publishes the downloadable demo and this teaser
together, so the page's two buttons go live on one day. Doing it earlier means porting things that are still changing. What it carries is
the standalone stages only, never a region (OW's streaming in a single-threaded tab is out of reach), never walking, people's schedules or
errands beyond what a solo stage has. Doing it at all is worth it only as a funnel:
a click on itch.io that starts a car is a much smaller step than a download past SmartScreen. It must never hold back the full game.

## What the browser can and cannot do (researched 2026-11-17; check again when the phase starts)
- **Renderer.** Godot 4.7's web export runs only the **Compatibility renderer (WebGL 2)**. Forward+ and Mobile do not run there. WebGPU is not in
  the official engine: an experimental WebGPU fork of 4.6.2 is in public beta (May 2026) and its own table lists Windows as still to do. Plan on
  WebGL 2. Revisit only if WebGPU lands in an official release.
- **What Compatibility lacks that RADDY uses** (the 4.7 renderer table): screen-space reflections (the wet road's and the water's mirror:
  `GraphicsQuality.SSR_STEPS`, the `wet_mirror` global), volumetric fog (`RaceLook`'s fog and dust: `GraphicsQuality.flatten_fog` already
  stands in for it on Low), **light projector textures** (the headlights' and the light pod's beam patterns, `CarLamps.beam_pattern`,
  `CarLightPod.beam_pattern`: without them the beams are plain spot cones and the night's road no longer reaches 80 m), SMAA and FXAA (MSAA 3D
  works, without alpha to coverage), FSR (plain scaling only), HDR (RGBA8, low dynamic range: glow, the lamps' glass, the sky's sun, the
  mirrors' "linear HDR picture" all clip earlier), depth of field (photo mode), particle trails and SDF collision (not used), compute (not
  used), contact shadows, PCSS. Omni and spot lights: **8 per mesh**, shadowed lights drawn in extra passes. SSAO, glow, tone mapping, fog,
  screen and depth textures in shaders, MultiMesh and GPU particles are there.
- **Threads.** Since 4.3 the default web export is single-threaded and needs no special headers; that is the right one for itch.io. The
  threaded export needs SharedArrayBuffer (itch.io has an experimental "SharedArrayBuffer support" checkbox using COEP credentialless, which
  Safari and Firefox for Android lack). Without threads, `WorkerThreadPool` work runs on the main thread (the crack bakes'
  ~11 ms happen in one frame), `Thread` cannot be used, and audio in Stream mode lags.
- **Audio.** Default on the web is Sample playback (Web Audio): low latency, but no bus effects, no doppler and positional audio "may behave
  incorrectly"; Stream playback has everything but more latency without threads. `AudioStreamGenerator` (the voice) needs Stream. A browser
  plays no sound before the player clicks or presses a key.
- **Networking.** No ENet and no UDP in the browser: only WebSocket (client), WebRTC and HTTP. `Net` (ENet), `PortOpener` (UPnP) and noray
  (phase J, UDP) cannot run there. Online play in the browser would need WebRTC on every peer (the desktop too, through the free
  webrtc-native GDExtension) plus a signalling server (a running service): **out of scope, the browser demo is solo.**
- **Other limits.** The microphone needs HTTPS and a permission prompt (and `AudioServer.set_input_device_active` is experimental on desktop
  already): no voice in the browser. Fullscreen and mouse capture (pointer lock) are allowed only from inside an input event. `user://` lives
  in IndexedDB and can be lost (private windows, blocked third-party storage inside itch.io's iframe). A background tab is paused. Gamepads show
  up only after a button is pressed. The `.wasm` must be served as `application/wasm`; itch.io does not compress on the fly.
- **itch.io HTML5 limits:** at most **500 MB** extracted, **1,000 files**, **200 MB per file**, 240 characters per path, names case
  sensitive. An `index.html` at the zip's root.
- **This PC has the templates:** `%APPDATA%\Godot\export_templates\4.7.2.stable\web_nothreads_release.zip` (godot.wasm 39.5 MB, 10.2 MB
  zipped) and the threaded and dlink ones. Jolt is a built-in module and is in the official web templates; whether it behaves the same in
  wasm is checked in item 1, not assumed.

Sources: Godot docs "Exporting for the Web" and "Overview of renderers" (latest, 4.7), itch.io "Uploading HTML5 games" docs, itch.io's
SharedArrayBuffer thread (itch.io/t/2025776), Godot's "Web export in 4.3" progress report, the godotwebgpu fork's README and the GodotCon
Boston 2026 talk listing.

## Read first
GAME_DESIGN §1 (why there was no browser build), §9 (the look gate), "Direction 2" (laws 7 and 8: budgets measured, the same world at every
graphics level); `docs/phases/d_demo.md` (solo and the credits: this phase reuses them; the desktop Demo
preset is A10's, `a9_a10.md`); CLAUDE.md on `GraphicsQuality`, `RaceLook`,
`CarLamps`/`CarLightPod`, `CarMirrors`, `RoadFxPool`, `WeatherFx`, `Voice`, `Net`, the export and the tools; `scripts/core/graphics_quality.gd`
(the one place a level becomes settings), `scripts/gameplay/race_look.gd` (the environment), `scripts/ui/ui_theme.gd` (`hud_font`),
`project.godot` and `tests/unit/test_project_settings.gd`, `export_presets.cfg`, `tools/export_windows.ps1`, `tools/perf.ps1` and
`tools/perf_probe.gd`.

## Traps the code holds
- **The renderer is a project setting per platform.** `project.godot` pins `rendering_device/driver.windows="d3d12"` and the feature list says
  "Forward Plus"; the web export must resolve `rendering/renderer/rendering_method.web` to `gl_compatibility` (set it explicitly and guard it
  in `test_project_settings.gd`, beside the existing guards, without touching the desktop's).
- **Nothing tells the game which renderer it runs on.** Every place that turns on a Forward+ feature (`GraphicsQuality.apply_look`,
  `apply_viewport`, `RaceLook` lines ~149-163 and ~210, `CarMirrors` ~259) must ask one function, `GraphicsQuality.compatibility()`
  (`RenderingServer.get_current_rendering_method() == "gl_compatibility"`), never `OS.has_feature("web")`: the same path then runs on the
  desktop with `--rendering-method gl_compatibility`, which is how most of this phase is tested.
- **`GraphicsQuality.detect()` uses `RenderingDevice.DEVICE_TYPE_*`** and `perf_probe.gd`/the adapter summary read RenderingDevice values;
  there is no RenderingDevice in Compatibility. The web's level is decided by the renderer, not by the adapter type.
- **The headlights are drawn through light projectors** (`CarLamps`, `CarLightPod`, `rendering/textures/light_projectors/filter`). In
  Compatibility the pattern is ignored and a plain cone remains, so dusk and night are unfit for the browser: the demo offers day and golden
  hour only (`RaceSettings.TimeOfDay`), and the room's Random never draws the others there.
- **Low dynamic range.** The mirrors render a linear HDR picture with no tone mapping for the main view to grade (`CarMirrors`,
  `mirror_glass.gdshader`); in RGBA8 that clips and bands. The lamps' glass (`car_lamp.gdshader`), the sun in `race_sky.gdshader`,
  `lamp_cap.gdshaderinc`'s caps and glow are all tuned on HDR values. Expect a flatter, harsher picture; fix what is ugly, do not chase
  Forward+.
- **Screen and depth reads cost more in Compatibility** (a copy of the frame): `windshield.gdshader` (the dirt's scatter), `speed_blur.gdshader`,
  `puddle.gdshader` (screen + depth + its own ray), `road_puff.gdshader` (soft particles from depth). Each needs a measured cost and, where it
  is dear, a Compatibility branch (a shader define set from the material, not a second shader file).
- **The font is a Windows system font.** `UiTheme.hud_font` asks `SystemFont` for Bahnschrift, Segoe UI, Arial: a browser has none of them, so
  the HUD falls to the engine's default font. Phase F moved the HUD to the shipped `assets/fonts/saira` and `inter`; check nothing still
  asks `SystemFont` (the livery's name picture may have kept Bahnschrift: give it the shipped fallback on the web).
- **Code-built content loads assets by path** (`RoadsideCatalog`: `res://assets/models/%s/%s_1k.gltf`, the Sketchfab packs; `RallyProps`,
  `CarAudio`, the sky's clouds). An export filter that keeps only what scenes reference drops them silently, and a stage then has no trees in
  the browser only. The demo's export keeps all resources and excludes by list; a test proves every path the demo's stages can load survives
  the filter.
- **The whole `.pck` is held in the tab's memory** (wasm memory, 32-bit, so 4 GB at most; Chrome kills a tab well before that on a small
  PC). Size is RAM as well as download.
- **Mouse look is captured at race start** (`race.gd`, `CockpitCamera.look`), outside an input event: the browser refuses the pointer lock.
  The web needs "click to look around" (capture inside the click) and Esc means two things there (the browser releases the pointer first).
- **Threads in code:** `PortOpener` starts a `Thread` (never reached in solo, but gate it); `map_sheet.gd` and the crack bakes use
  `WorkerThreadPool` (they still work, synchronously: measure the hitch on the first stone).
- **`Voice` is an autoload** and `audio/driver/enable_input=true`: on the web it must never ask for the microphone (no prompt on the page).
- **TTS voices load late in a browser** (the voice list is empty on the first frames in Chrome): D's co-driver must ask again before
  falling back to the large text, and a browser may have no Turkish voice at all.
- **Shaders compile when first seen**, and WebGL compiles through ANGLE into D3D11 on Windows, slowly: the first corner with a new material
  stutters. Compatibility has no ubershaders to hide it.
- **Command-line user args do not exist in a browser.** Everything `Flow.args` reads (`--autodrive`, `--flow-test`, `--stage`) has to come
  from the page for tests (a test shell, item 6).

## Deliver (each step leaves the game whole; the desktop build and every test stay as they are)

1. **Compatibility on the desktop, measured (the go/no-go).** Run the real game on this PC with `--rendering-method gl_compatibility
   --rendering-driver opengl3_angle` (ANGLE on D3D11: what Chrome uses on Windows). Add `-GodotArgs` to `tools/screenshot.ps1` and
   `tools/stage_shots.ps1` the way `perf.ps1` has it. Record: every shader error and warning (each of the ~40 shaders in `shaders/`), what is
   missing on screen, Red Canyon and Black Pine by day from the seat and the chase camera beside the Medium shots of the same places
   (`-Compare`), `perf.ps1 -Stage <n> -GodotArgs ...` with one car and with three crews, whether Jolt's handling tests pass under the
   Compatibility renderer (they are physics, they should). Write the result into DEVELOPMENT_PLAN with the shots' paths and a decision:
   **if the stage reads as a rally road and holds 60 fps with one car on this PC, go on; if not, stop here** and say what it would take.
2. **One switch for the renderer.** `GraphicsQuality.compatibility()` and a pure `RenderLimits` (RefCounted, tested) that says, for a renderer
   name, what is available (ssr, volumetric fog, projectors, smaa/fxaa, fsr, hdr, lights per mesh). `GraphicsQuality.apply_look`/`apply_viewport`,
   `RaceLook` and `CarMirrors` consult it: no SSR and `wet_mirror` 0, `flatten_fog` always, MSAA 2x in place of SMAA/FXAA, bilinear scaling,
   the RenderingDevice calls skipped. A **Web level** on top of Low's scenery numbers, chosen automatically in Compatibility (the settings
   menu shows it and hides the others there). `project.godot` gains `rendering_method.web="gl_compatibility"`, guarded by
   `test_project_settings.gd`. Unit tests: `RenderLimits` per renderer; `apply_look` on a fake environment in Compatibility turns on nothing
   the table lacks; law 8 holds (what collides is placed from the seed alone: the existing dresser tests run at the Web level too).
3. **Shaders that hold in Compatibility.** Fix every error item 1 found; for the screen/depth readers and the HDR-tuned shaders above, a
   `COMPAT` branch where the measured cost or the look needs it (one shader, a define or a uniform the material sets from
   `GraphicsQuality.compatibility()`). The mirrors: tone-mapped in their own picture in Compatibility so they do not clip. Lamps by day only
   (item 5 removes dusk and night from the demo). Evidence: stage shots of both stages, day and golden hour, each weather the stage has,
   `-Compare` sheets against Medium, in `reports/screenshots/stages/web_<date>/`.
4. **Platform gates.** One place (`Platform`, a small static class, tested where pure) answers `can_host()`, `can_voice()`, `can_threads()`
   and the like from `OS.has_feature("web")`/`"threads"`. `Voice` never opens the microphone and `audio/driver/enable_input` does not prompt
   on the web; `PortOpener` and the lobby's online buttons are not reachable there; `UiTheme.hud_font` falls back to the shipped font, never the
   engine's; mouse look captures on the first click in the race with a hint in both languages ("Click to look around" / "Etrafa bakmak için
   tıkla"), and Esc opens the pause menu after the browser has released the pointer; fullscreen from a button (inside its click). Audio:
   measure `CarAudio`'s engine cross-fade and pitch in Sample mode against Stream mode in the browser and pick per stream
   (`audio/general/default_playback_type.web` and per player); the first sound waits for the first key or click (the menu's "press any key"
   is that moment).
5. **The demo's content behind a feature tag.** The Web Demo preset sets the custom feature `web_demo` (A10's desktop demo sets `demo`; both read
   one list, `DemoRules`, pure, tested): stages Red Canyon first, Black Pine second (the forest is the dearer one: trees were 6-9 ms of a
   desktop frame), solo only (D's solo, both seats: driving with the bot co-driver calling the notes, or navigating while the bot drives),
   day and golden hour, the stage's weathers, the cabin's chaos as on the desktop (map, windows, cans, wipers, windshield, stones, the shock
   gun against one's own partner if the room rule is on), damage, recovery, results, D's share card (a PNG cannot be saved to a folder in a
   browser: offer it as a download through `JavaScriptBridge.download_buffer`), D's credits. The menu: Solo, Settings, Credits, and a
   prominent "Get the full game: online with friends, every stage" button opening the itch.io page (`OS.shell_open`, inside its click). Records
   in the browser are their own section and never shown as the full game's.
6. **Export, serve, test.** An export preset "Web Demo" (`platform="Web"`, `web_nothreads_release` template, `variant/thread_support=false`,
   VRAM compression for desktop (S3TC/BPTC) only: mobile is not a target, `script_export_mode=2`, exclude filter = the desktop preset's plus every
   biome and model the demo's stages do not load, export path `builds/web/index.html`), `tools/export_web.ps1` (like `export_windows.ps1`;
   prints the size of every file and fails over the budgets below), `tools/serve_web.py` (pure Python, `http.server` bound to 127.0.0.1,
   `application/wasm`, optional `-Threads` adding COOP/COEP for a threaded experiment, never a public bind), and a test shell
   `tools/web/test_shell.html` (export option `html/custom_html_shell` used only by a `-Test` export) that passes `?args=--a,--b` from the URL to
   `engine.startGame({args})`, so `--autodrive`, `--stage=` and D's solo flow test run in a browser and print their `FLOW`/`PERF` lines to the
   console. `tools/webtest.ps1`: export with `-Test`, serve, and tell the builder the URL; the builder opens it in the Claude app's built-in
   browser pane (`preview_start` with the URL), reads `read_console_messages` for the flow's lines, takes screenshots, reads fps from a
   `PERF` line the probe prints every 5 s in the browser too. A GUT test checks the preset (renderer, thread support off, feature tag, filters)
   and that every `res://` path `RoadsideCatalog`, `RallyProps` and the stages' builders can load for the demo's stages exists and is not
   excluded by the preset's filters.
7. **Loading and first frames.** A loading screen with real progress (the engine's own download bar while the `.pck` arrives, then the stage
   build in steps with `ResourceLoader.load_threaded_*` where it works single-threaded, and messages); a **shader warm-up**: before the countdown
   every material the stage uses is drawn once (a hidden row of meshes in front of the camera for a few frames, the car's damage and glass
   states included), so the first corners do not stutter; measured as the worst frame over the first 30 s of a bot run, before and after.
8. **Measure in a real browser, then decide on the second stage.** In Chrome and Edge on this PC (the RTX 5070 Laptop, then the owner sets
   Chrome to the integrated GPU once in Windows Settings > System > Display > Graphics > Chrome > Power saving and back): download size, time from
   click to menu and from menu to the countdown (cold and cached), the tab's memory (Chrome's task manager), fps p95 over a bot run of each stage.
   Firefox once (it must start and finish a stage). If Black Pine misses the budget after trimming trees at the Web level, the demo ships with
   Red Canyon alone.
9. **The itch.io page (the owner publishes).** `docs/ITCH_PAGE.md` gains the browser demo's part in Turkish and English: what it is (solo, one
   or two stages, the full game is the download with online co-op), the controls, "use Chrome or Edge on a computer; a gamepad works after one
   press", "headphones help: your co-driver talks". The settings to choose, written as exact clicks: Kind of project HTML; upload the zip of
   `builds/web/` and tick "This file will be played in the browser"; Embed options: "Click to launch in fullscreen" (the game sizes itself to any
   window), viewport 1280 x 720 for the embed, "Fullscreen button" on, "Mobile friendly" off, "Automatically start on page load" off,
   **"SharedArrayBuffer support" off** (single-threaded build); the downloadable Windows zip stays on the same page beside it. If the owner is
   signed in to itch.io in Chrome, prepare the upload as a draft through Claude in Chrome (never public: publishing is the owner's click) and list
   exactly what is left.

## Budgets
- **Download:** `index.pck` at most 150 MB and the whole `builds/web/` at most 200 MB (the wasm is 39.5 MB); far under itch.io's 500 MB / 200
  MB per file / 1,000 files. Expect the first load to take about 30 s on a 50 Mbit/s line and over a minute on 20 Mbit/s: the page says so.
  Red Canyon alone should fit in about 100 MB of `.pck`; item 6 reports the real number per stage.
- **Time to drive:** from the menu to the countdown under 30 s on this PC in Chrome (the desktop's stage build plus the crew and helmet bakes,
  about 0.55 s on the desktop, run slower in wasm: measure, then cache what can be cached in the `.pck`).
- **Frame:** 60 fps p95 at 1920 x 1080 in Chrome on this PC with one car (solo has one car); 30 fps at 1280 x 720 on this laptop's integrated
  GPU. One physics tick (120 Hz, Jolt, the car's own GDScript in `_integrate_forces`) under 2 ms in the browser, or the simulation falls behind:
  `PERF tick_ms` measures it. The desktop's budgets do not move: Medium stays over 60 fps with three crews on the dev laptop (law 7), checked by
  `perf.ps1` after items 2-4.
- **Memory:** the tab under 2 GB in Chrome's task manager during a stage.

## Tests and evidence
- GUT: `RenderLimits`, `DemoRules`, `Platform` (pure parts), the Web Demo preset's settings, the export filter against every loadable path, the
  project settings guard; the whole suite still passes (`tools\test.ps1`), nettest and the flow tests unchanged.
- Desktop Compatibility: stage shots and `-Compare` sheets (item 3), `perf.ps1` with `-GodotArgs` for Compatibility (one car, three crews).
- Browser: D's solo flow test run through the test shell in the built-in browser pane, its console lines quoted in DEVELOPMENT_PLAN; screenshots
  of menu, seat, map open, results, share card; the measurements of item 8 in a table with what ran beside them.
- TEST_PLAN: what only people can check (a friend on another PC and connection plays the itch.io page cold; Firefox; a laptop without a
  discrete GPU; a gamepad).

## Done means
The browser demo starts from `builds/web/index.html` served locally and on the itch.io draft, a solo stage is driven and navigated to the
results in Chrome on this PC within the budgets, the desktop build is unchanged in look and frame rate, GAME_DESIGN §1 records the decision
(the browser teaser exists, solo only, Compatibility), CLAUDE.md lists the new tools and traps, DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN,
`docs/ITCH_PAGE.md` and the strings are updated, commits on main.

## What will look and play worse in the browser (say it on the page, too)
No reflections on wet roads and water (the puddles keep their colour), fog and dust as flat fog (no shafts of light), no night and no dusk (the
beams cannot be drawn), harsher light and clipped highlights (low dynamic range), softer edges (MSAA only), fewer trees and a shorter view of
the scenery (Low's numbers), a long first load and a stutter-free start only after the warm-up, sound that may sit less well in space, no
voice chat, no online play, settings and records that the browser may forget. Mobile and Safari are not supported. Driving, the cabin, the map,
the co-driver and the stages themselves are the same as the download's.

## Out of scope
Online play in the browser (WebRTC, a signalling service, desktop-browser cross-play), voice in the browser, a threaded build (a later
experiment through itch.io's SharedArrayBuffer checkbox if the single-threaded one is too slow), WebGPU (revisit when an official Godot release
has it), mobile browsers, a custom-built smaller wasm (SCons and Emscripten are free, but it is a build system to keep; only if the 39.5 MB
template is the thing that breaks the budget), new content made for the web. The open world, missions and "GTA size" the owner asked for are
other phases' business; the browser can only ever show a slice of what the download has, and the slice is smaller and plainer.

## Size of the work
About **10-14 builder parts of 1-3 hours**: item 1 one or two parts (and it may end the phase), item 2 one, item 3 two to four (it depends on
what item 1 finds), item 4 one or two, item 5 one (D did the solo), item 6 two, item 7 one or two, item 8 one, item 9 one. A free, AI-built
version can honestly reach: one or two stages solo in Chrome and Edge on desktop, at about Low's look minus reflections, volumetric fog and
night, loading in half a minute to a minute and a half. It cannot reach the download's look, online play or anything on phones.

**Is it worth doing before the full game is out?** Only once the desktop build is the play-tested one, and only if item 1 says go. Before
that it ports a moving target and costs parts the full game needs. Then it is worth it as the itch.io page's first click: someone who tried the
car and the co-driver in a tab is far more likely to download past the SmartScreen warning and bring a friend.
