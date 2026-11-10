class_name RoadFxPool
extends Node3D
## What the cars throw into the air, in world-space pools every car shares: soft puffs that hang where they were thrown
## (dust, powder, spray) and hard bits that fly and bounce (stones, clods). One draw call each however many cars there are, and the
## puffs of different cars are sorted among themselves when one drives through another's cloud. What a crash throws besides (flakes of
## glass, bark, wood and straw, leaves, sparks: Flake) has two pools more, shown only while something of it is in the air: no draw call
## between crashes. Only script emits into them (CarRoadFx from the rules in RoadFxRules and CrashRules); the graphics card moves what flies.
## A headless peer draws nothing and only counts.

const GROUP := &"road_fx_pool"
## Room for three crews' dust at once: a puff thrown into a full pool is lost, and it would be the youngest, right behind a car (three bots
## on Black Pine: up to 1240 thrown within a dust puff's longest life).
const PUFFS := 1280
const BITS := 192
const FLAKES := 192
const SPARKS := 128
## What a crash throws that is no puff and no stone (the flake shaders read it).
enum Flake { MATTE, GLASS, LEAF, SPARK }
## How long the longest flake lives (s): a pool is hidden that long after the last one was thrown into it.
const FLAKE_LIFE := 7.0
## How long the longest puff lives: the pool stops running this long after the last one was thrown.
const LONGEST_LIFE := 8.0
const ATLAS := preload("res://assets/fx/road_puffs.png")
const PUFF_PICTURE := preload("res://shaders/road_puff.gdshader")
const PUFF_MOTION := preload("res://shaders/road_puff_motion.gdshader")
const BIT_MOTION := preload("res://shaders/road_bit_motion.gdshader")
const FLAKE_MOTION := preload("res://shaders/road_flake_motion.gdshader")
const FLAKE_PICTURE := preload("res://shaders/road_flake.gdshader")
const SPARK_PICTURE := preload("res://shaders/road_spark.gdshader")
## Drawn before the seat's own glass and whatever else is see-through and nearer the eye (a puff behind a window must not hide what is on
## the pane), after the glass of the other cars in the cloud (CarModel.GLASS_PRIORITY).
const PUFF_PRIORITY := -1
## They stay where they are thrown and the camera may be anywhere: never culled.
const EVERYWHERE := AABB(Vector3(-5000.0, -2000.0, -5000.0), Vector3(10000.0, 4000.0, 10000.0))
const EMIT_ALL := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY \
	| GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM

## Dev: no road effects at all (perf comparisons, tools\perf.ps1 -ExtraArgs --no-road-fx).
static var off := false

## Share of puffs and of bits to throw (RoadFxRules.cloud_share, bit_share).
var cloud_share := 1.0
var bit_share := 1.0
## What was thrown so far, also on a headless peer.
var puffs_thrown := 0
var bits_thrown := 0
var flakes_thrown := 0

var _puffs: GPUParticles3D
var _bits: GPUParticles3D
## Sparks (true) and the other flakes (false) -> their pool, and until when (ms) it has something in the air.
var _flake_pools: Dictionary = {}
var _shown_until: Dictionary = {true: 0, false: 0}


## The scene's pool, made beside `car` if it has none yet (and null when road effects are off).
static func of(car: Node) -> RoadFxPool:
	if off:
		return null
	var pool := car.get_tree().get_first_node_in_group(GROUP) as RoadFxPool
	if pool == null:
		pool = RoadFxPool.new()
		pool.name = "RoadFxPool"
		pool.add_to_group(GROUP)
		car.get_parent().add_child(pool)
	return pool


func _ready() -> void:
	top_level = true
	set_process(false)
	_read_settings()
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.changed.connect(_read_settings)
	if DisplayServer.get_name() != "headless":
		_puffs = _make_puffs()
		_bits = _make_bits()
		add_child(_puffs)
		add_child(_bits)
		for sparks: bool in [true, false]:
			_flake_pools[sparks] = _make_flakes(sparks)
			_flake_pools[sparks].visible = false
			add_child(_flake_pools[sparks])


func _read_settings() -> void:
	var settings := get_node_or_null(^"/root/Settings")
	var effects := float(settings.get_value("effects_intensity")) if settings != null else 1.0
	var quality := GraphicsQuality.road_fx_share(GraphicsQuality.current())
	cloud_share = RoadFxRules.cloud_share(quality, effects)
	bit_share = RoadFxRules.bit_share(quality, effects)


## A soft puff of `cloud` (RoadFxRules.Cloud) from `at`, going `velocity`, its size growing from `sizes.x` to `sizes.y` over its
## `life`, `color.a` how thick it is when young.
func puff(cloud: int, at: Vector3, velocity: Vector3, color: Color, sizes: Vector2, life: float) -> void:
	puffs_thrown += 1
	if _puffs != null:
		_puffs.emit_particle(Transform3D(Basis(), at), velocity, color, Color(sizes.x, sizes.y, life, float(cloud)), EMIT_ALL)


## A hard bit from `at` on the road (whose normal there is `up`), going `velocity`: `bounce` is what a bounce leaves of its speed.
func bit(at: Vector3, velocity: Vector3, up: Vector3, color: Color, size: float, life: float, bounce: float) -> void:
	bits_thrown += 1
	if _bits != null:
		_bits.emit_particle(Transform3D(Basis(Vector3.RIGHT, up, Vector3.BACK), at), velocity, color, Color(size, life, bounce, 0.0), EMIT_ALL)


## A flake of `kind` (Flake) from `at`, going `velocity`; the ground under it has the normal `up` and lies `ground` metres below `at`.
## `bounce` is what a bounce off the ground leaves of its speed (0: it stays where it lands).
func flake(kind: int, at: Vector3, velocity: Vector3, up: Vector3, ground: float, color: Color, size: float, life: float, bounce: float) -> void:
	flakes_thrown += 1
	if _puffs == null:
		return
	var sparks := kind == Flake.SPARK
	var pool: GPUParticles3D = _flake_pools[sparks]
	pool.visible = true
	_shown_until[sparks] = Time.get_ticks_msec() + int(FLAKE_LIFE * 1000.0)
	set_process(true)
	color.a = kind / 4.0
	pool.emit_particle(Transform3D(Basis(Vector3.RIGHT, up, Vector3.BACK), at), velocity, color, Color(size, life, bounce, ground), EMIT_ALL)


## Hides a crash's pools once nothing of them is in the air: no draw call between crashes.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var showing := false
	for sparks: bool in _flake_pools:
		var pool: GPUParticles3D = _flake_pools[sparks]
		pool.visible = now < int(_shown_until[sparks])
		showing = showing or pool.visible
	set_process(showing)


func _make_flakes(sparks: bool) -> GPUParticles3D:
	var motion := ShaderMaterial.new()
	motion.shader = FLAKE_MOTION
	motion.set_shader_parameter(&"wind", RaceLook.wind)
	var picture := ShaderMaterial.new()
	picture.shader = SPARK_PICTURE if sparks else FLAKE_PICTURE
	var card := QuadMesh.new()
	card.material = picture
	return _pool("Sparks" if sparks else "Flakes", SPARKS if sparks else FLAKES, motion, card)


func _make_puffs() -> GPUParticles3D:
	var motion := ShaderMaterial.new()
	motion.shader = PUFF_MOTION
	motion.set_shader_parameter(&"wind", RaceLook.wind)
	var picture := ShaderMaterial.new()
	picture.shader = PUFF_PICTURE
	picture.render_priority = PUFF_PRIORITY
	picture.set_shader_parameter(&"puffs", ATLAS)
	var card := QuadMesh.new()
	card.material = picture
	var puffs := _pool("Puffs", PUFFS, motion, card)
	puffs.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	return puffs


func _make_bits() -> GPUParticles3D:
	var motion := ShaderMaterial.new()
	motion.shader = BIT_MOTION
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.roughness = 0.85
	var rock := _rock()
	rock.surface_set_material(0, surface)
	return _pool("Bits", BITS, motion, rock)


func _pool(pool_name: String, amount: int, motion: ShaderMaterial, mesh: Mesh) -> GPUParticles3D:
	var pool := GPUParticles3D.new()
	pool.name = pool_name
	pool.amount = amount
	pool.lifetime = LONGEST_LIFE
	pool.local_coords = false
	pool.emitting = false
	pool.fixed_fps = 0
	pool.visibility_aabb = EVERYWHERE
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.process_material = motion
	pool.draw_pass_1 = mesh
	return pool


## A low stone of flat facets: a dozen points of a ball, each pushed in or out.
static func _rock() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.radius = 0.5
	sphere.height = 1.0
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pushed := {}
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for index in indices:
		var key := vertices[index].snapped(Vector3.ONE * 0.001)
		if not pushed.has(key):
			pushed[key] = vertices[index] * rng.randf_range(0.72, 1.18)
		tool.add_vertex(pushed[key])
	tool.generate_normals()
	return tool.commit()


## A round, soft-edged picture for small glows and smoke, made once.
static var _soft: Texture2D


static func soft_puff() -> Texture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.55))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_soft = texture
	return _soft
