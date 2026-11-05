class_name GraphicsQuality
## The player's graphics level (Settings "graphics_quality"): what each level changes and how
## Auto picks one. Only looks change: anything that collides (the trees and rocks you can hit) is
## the same at every level, so every peer still drives through the same world.
##
## The forest's cost is mostly draw calls on the CPU, not triangles: the levels cut the scenery
## nobody can hit (backdrop forest, ground cover) and the shadow cascades first.

enum Level { LOW, MEDIUM, HIGH }
const AUTO := -1

## Share of the visual-only scenery that is placed, and how far all scenery is drawn.
const SCENERY := {Level.LOW: 0.45, Level.MEDIUM: 0.75, Level.HIGH: 1.0}
const RANGE := {Level.LOW: 0.6, Level.MEDIUM: 0.8, Level.HIGH: 1.0}
## Sun shadows: cascades and how far they reach (metres).
const SHADOW_DISTANCE := {Level.LOW: 70.0, Level.MEDIUM: 110.0, Level.HIGH: 150.0}
## Screen-space reflections from Medium up (water and wet roads mirror trees and cars; the GPU has room for them,
## the frame's cost is draw submission): how far the ray marches. Water marches its own ray, this many steps.
const SSR_STEPS := {Level.MEDIUM: 40, Level.HIGH: 64}
const WATER_RAY_STEPS := {Level.LOW: 0, Level.MEDIUM: 24, Level.HIGH: 36}
## The render layer of what the mirrors leave out: ground cover and the far forest. Their cost is draw calls and
## triangles; in a small picture of the road behind nobody misses them.
const FINE_SCENERY_LAYER := 1 << 16
## Mirrors (CarMirrors): picture height in pixels, interior and door mirror.
const MIRROR_HEIGHT := {Level.LOW: Vector2i(96, 96), Level.MEDIUM: Vector2i(132, 136), Level.HIGH: Vector2i(200, 208)}
## ...and whose turn it is on each frame, one mirror per frame at most: CarMirrors.Slot, -1 = none.
const MIRROR_TURNS := {Level.LOW: [0, 1, -1, 0, 2, -1], Level.MEDIUM: [0, 1, 0, 2], Level.HIGH: [0, 1, 0, 2]}
## How much of its own light flat fog keeps when it stands in for a volume of fog.
const FLAT_FOG_LIGHT := 0.45
## 3D resolution scale (FSR upscales the rest) per level.
const RENDER_SCALE := {Level.LOW: 0.77, Level.MEDIUM: 1.0, Level.HIGH: 1.0}
## Edges. SMAA keeps the detail FXAA blurs away, and neither leaves the trails TAA would round a cabin that stands
## still while the world flies past. Only multisampling catches what is thinner than a pixel: a gantry's truss, far rails.
const SCREEN_AA := {Level.LOW: Viewport.SCREEN_SPACE_AA_FXAA, Level.MEDIUM: Viewport.SCREEN_SPACE_AA_SMAA, Level.HIGH: Viewport.SCREEN_SPACE_AA_SMAA}
const MSAA := {Level.LOW: Viewport.MSAA_DISABLED, Level.MEDIUM: Viewport.MSAA_DISABLED, Level.HIGH: Viewport.MSAA_2X}
## How sharp a texture stays at a low angle, which is how a driver sees the road.
const ANISOTROPY := {Level.LOW: Viewport.ANISOTROPY_4X, Level.MEDIUM: Viewport.ANISOTROPY_8X, Level.HIGH: Viewport.ANISOTROPY_16X}


## Dev scenes (--quality) force a level here, whatever the player's setting says.
static var forced := AUTO


## The level in force: the setting, or Auto's pick (integrated graphics -> Low, otherwise High;
## headless runs count as High so tests see the full world).
static func current() -> int:
	if forced != AUTO:
		return forced
	var tree := Engine.get_main_loop() as SceneTree
	var chosen := AUTO
	if tree != null and tree.root.has_node(^"Settings"):
		chosen = int(tree.root.get_node(^"Settings").get_value("graphics_quality"))
	if chosen != AUTO:
		return clampi(chosen, Level.LOW, Level.HIGH)
	return detect()


static func detect() -> int:
	if DisplayServer.get_name() == "headless":
		return Level.HIGH
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return Level.LOW
	return Level.HIGH


static func scenery_density(level: int) -> float:
	return SCENERY.get(level, 1.0)


static func range_scale(level: int) -> float:
	return RANGE.get(level, 1.0)


static func water_ray_steps(level: int) -> int:
	return WATER_RAY_STEPS.get(level, WATER_RAY_STEPS[Level.HIGH])


static func mirror_height(level: int, interior: bool) -> int:
	var heights: Vector2i = MIRROR_HEIGHT.get(level, MIRROR_HEIGHT[Level.HIGH])
	return heights.x if interior else heights.y


static func mirror_turns(level: int) -> Array:
	return MIRROR_TURNS.get(level, MIRROR_TURNS[Level.HIGH])


## Shadows, ambient occlusion and glow for the race's sun and environment.
static func apply_look(env: Environment, sun: DirectionalLight3D, level: int) -> void:
	sun.directional_shadow_max_distance = SHADOW_DISTANCE.get(level, 150.0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if level == Level.HIGH \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	env.ssr_enabled = SSR_STEPS.has(level)
	RenderingServer.global_shader_parameter_set(&"wet_mirror", 1.0 if env.ssr_enabled else 0.0)
	if env.ssr_enabled:
		env.ssr_max_steps = SSR_STEPS[level]
		env.ssr_fade_in = 0.1
		env.ssr_fade_out = 1.6
		env.ssr_depth_tolerance = 0.35
	if level == Level.LOW:
		env.ssao_enabled = false
		env.glow_enabled = false
		# Volumetric fog is part of how far you see in fog and dust: Low must never see further than High.
		if env.volumetric_fog_enabled:
			flatten_fog(env)


## Depth fog in place of a volume of fog (Low, a mirror's small picture): as dense, and as dim. A volume scatters only
## the sun behind the clouds into the view and covers the sky as well; flat fog with its own light and the sky's would shine.
static func flatten_fog(env: Environment) -> void:
	env.fog_density += env.volumetric_fog_density
	env.fog_light_energy *= FLAT_FOG_LIGHT
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 1.0
	env.volumetric_fog_enabled = false


## The main view at `level`: its 3D resolution (FSR 1 when below native), edges and texture sharpness.
static func apply_viewport(viewport: Viewport, level: int) -> void:
	var scale: float = RENDER_SCALE.get(level, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
	viewport.screen_space_aa = SCREEN_AA.get(level, Viewport.SCREEN_SPACE_AA_SMAA)
	viewport.msaa_3d = MSAA.get(level, Viewport.MSAA_DISABLED)
	viewport.anisotropic_filtering_level = ANISOTROPY.get(level, Viewport.ANISOTROPY_4X)
