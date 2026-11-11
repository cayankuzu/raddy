# Phase A9a: a frame rate worthy of the game

The owner wants it "butter-smooth" (GAME_DESIGN §9: 60 fps and more). Today the dev laptop (i7-13650HX, RTX 5070 Laptop, hybrid graphics, 1080p,
other programs loading the CPU) gives 30-37 fps on Medium with three crews, 21-35 on High: `tools\perf.ps1` prints `fps_avg p95_ms p99_ms draw_calls
primitives physics_ms process_ms` (about 900 draw calls, 2.7-3.2 M primitives, physics 1.3-2 ms; its cpu/gpu render times read 0). Older findings
(DEVELOPMENT_PLAN, TEST_PLAN): an empty scene already floors at about 8.5-12 ms here; a lower render scale changes nothing; without scenery 81 fps,
without shadows 65; Vulkan was unusable (17 fps on an empty scene), so the project pins D3D12. Nobody has ever profiled where a frame goes. Read first:
`scripts/core/graphics_quality.gd`, `scripts/gameplay/race_look.gd`, `scripts/procedural/roadside_dresser.gd`, `tools/perf.ps1`, `tools/perf_probe.gd`.

## 1. Measure before touching anything (and write the method down in CLAUDE.md)
- Which adapter renders: print `RenderingServer.get_video_adapter_name()` and its type at start (perf probe and the game's log). On a hybrid laptop
  the dGPU must be the one; if the integrated GPU renders, that is the first finding.
- Before any measurement, list the running Godot processes (`Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'"`): the owner sometimes runs
  another project's Godot (C:\Users\Cayan\Desktop\haluk-7-gunu) at the same time, which takes 10 fps and more. Never touch it; measure costs inside one
  process, and judge the absolute fps targets only in a run with no other Godot (say which in every number you report).
- `tools/perf_probe.gd` already shows and hides one thing every S seconds of the same run (`--flip-<what>=S`: road-fx, marks, crew, crew-motion, kit,
  livery, pod, crowd; `FLIP ... cost_ms median_cost_ms work_cost_ms`, the last steady to 0.03 ms, `cost_ms` wanders by 0.3 ms: run twice). Extend it.
- Where a frame goes, in one process: make `tools/perf_probe.gd` break the frame down for real: `RenderingServer.viewport_set_measure_render_time`
  + `viewport_get_measured_render_time_cpu/gpu` (find out why they read 0: per viewport, the right frame, D3D12 timestamp support),
  `Performance` monitors (TIME_PROCESS includes the draw: say so), `RenderingServer.get_frame_setup_time_cpu`, the mirrors' and the map's
  SubViewports apart, and a switch-off matrix inside one run (the `--flip` pattern): shadows, scenery by class (trees, low plants, backdrop),
  road fx, mirrors, SSR, SSAO, glow, volumetric fog, MSAA/SMAA, the crowd, crews, tyre marks, the HUD. A table of what each costs on Low, Medium, High.
- The floor: an empty 3D scene with the game's environment in a window, fullscreen and exclusive fullscreen, vsync off: why 8.5 ms? (present path
  on hybrid graphics, DWM, a hidden frame cap, `Engine.max_fps`, physics at 120 Hz in the main loop, the window mode.) Try
  `rendering/driver/threads/thread_model` (separate render thread) and report what it does to the frame and to stability (the flow test, the mirrors).
- CPU: Godot's own profiler is not available headless-less: use `Performance` custom monitors round the game's own `_process` work (crew rigs, road
  fx, tyre marks, cabin, HUD, dresser streaming) and `OS.get_ticks_usec` brackets, and report the top ten.

## 2. Cut what the measurements name (expected candidates, confirm each by its number)
- Shadows: cascades and their distance per level, which meshes cast (far trees and low plants cast nothing; a blob or baked shade there), the
  shadow atlas sizes, `directional_shadow` update only when needed is not possible for a moving camera: so fewer casters and splits.
- Draw submission: bigger MultiMesh chunks where the visibility range allows, fewer distinct meshes/materials per chunk, `visibility_range` fades that
  do not double-draw, far trees as impostors (cards baked in code from the tree meshes at load or as a tool-made atlas; no downloads), the backdrop
  as one mesh, occlusion culling only if a cheap generated occluder really removes work (measure).
- Foliage overdraw and alpha-scissor cost: depth prepass settings, `alpha_scissor` thresholds, card counts by distance (LODs: `ImporterMesh.generate_lods`
  exists and works here), mesh LOD bias per level.
- Post: SSR, SSAO, glow, volumetric fog, SMAA/MSAA by what they cost against what they give; the mirrors' budget; half-rate updates where invisible.
- The game's scripts: anything per frame that can be per tick, per distance, or event-driven.
- Quality levels must really differ: Low is for integrated graphics (aim: the same scene at a third of the vertex load and half the draw calls,
  no SSR/SSAO/volumetrics, 0.75 render scale by default on an iGPU), High is the showcase; AUTO picks by adapter. Dust on Low must still blind
  (gameplay), sightlines must not get longer on any level (`Sightline` tests).

## 3. Smoothness, not only the average
- No hitch when a chunk appears or a shader is first used: pipeline precompilation/ubershaders (project settings in 4.7), a warm-up pass behind the
  loading screen that draws every material once, particles pre-warmed; measure spikes over 33 ms across a whole stage (target: none after the first 2 s).
- Frame pacing: p99 under 20 ms where the average is over 60.

## Targets on this laptop (report honestly if the laptop's own floor prevents them, with the numbers that show it)
Medium, 1080p, Black Pine, three crews: at least 60 fps average (75 if the floor allows) and p99 under 20 ms; High at least 45; Low at least 90.
Nothing may look worse from the seat: before/after contact sheets (`tools\stage_shots.ps1 -Compare`), every stage, day and night, reviewed by eye.

Tests: whatever rule decides LODs, casters or levels is pure and unit-tested; existing tests stay green (the mirrors, sightlines, dresser).
Done means: the table of costs and the before/after numbers in DEVELOPMENT_PLAN, the method in CLAUDE.md, TEST_PLAN updated, full GUT, nettest and
a flow test pass, commits on main.
