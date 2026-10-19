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
## 3D resolution scale (FSR upscales the rest) per level.
const RENDER_SCALE := {Level.LOW: 0.77, Level.MEDIUM: 1.0, Level.HIGH: 1.0}


## The level in force: the setting, or Auto's pick (integrated graphics -> Low, otherwise High;
## headless runs count as High so tests see the full world).
static func current() -> int:
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


## Shadows, ambient occlusion and glow for the race's sun and environment.
static func apply_look(env: Environment, sun: DirectionalLight3D, level: int) -> void:
	sun.directional_shadow_max_distance = SHADOW_DISTANCE.get(level, 150.0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if level == Level.HIGH \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if level == Level.LOW:
		env.ssao_enabled = false
		env.glow_enabled = false
		env.volumetric_fog_enabled = false


## The 3D resolution for `viewport` at `level` (FSR 1 when below native).
static func apply_viewport(viewport: Viewport, level: int) -> void:
	var scale: float = RENDER_SCALE.get(level, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale
