class_name WindshieldGlass
extends Node
## Puts the Cabin's dirt, cracks and wipers onto the real windshield (shaders/windshield.gdshader)
## instead of over the player's screen: mud gathers on the glass in blotches, the car's own two wipers
## sweep it (cut out of the model, each turning about its hinge), only where a blade really passes the glass
## comes clean, and a stone leaves a bullseye where it hit, then a crack from there (CrackPicture) that runs further
## with every stone after. Every peer sees every car's glass the same way.

const SHADER := preload("res://shaders/windshield.gdshader")
const WIPER_PERIOD := 1.1
## Wiper sweep, degrees from parked (flat along the bottom of the glass).
const WIPER_SWEEP := 95.0
## Further away than this nobody can make out a wiper.
const DRAW_RANGE := 60.0
## How quickly the corners lose dirt that the wipers do not reach (per second).
const EDGE_CLEAR_RATE := 0.015
## How fast a crack runs out to where the stones have spread it (of CrackPicture.spread per second).
const CRACK_RUN := 4.0
## The wipers' hinges in car space (the thin ends of the arms), with their cut parts (CarParts).
const WIPERS: Array[Dictionary] = [
	{"hinge": Vector3(0.007, 0.4125, -1.102), "arm": &"wiper_arm_a", "blade": &"wiper_blade_a"},
	{"hinge": Vector3(0.533, 0.4095, -1.0215), "arm": &"wiper_arm_b", "blade": &"wiper_blade_b"},
]

var cabin: Cabin
var glass: MeshInstance3D
## The car's cut parts (CarParts.cut).
var parts: Dictionary = {}

## The windshield's picture: dirt, wipers, bullseye and crack (CarModel sets where it is drawn among what is see-through).
var material := ShaderMaterial.new()
var _edge_dirt := 0.0
var _wipers: Array[Node3D] = []
var _wiper_time := 0.0
var _hinge_axis := Vector3.UP
## The glass's plane in its mesh space: bottom-left corner, unit axes (across, up, outward).
var _origin := Vector3.ZERO
var _u := Vector3.RIGHT
var _v := Vector3.UP
var _n := Vector3.BACK
var _size := Vector2.ONE
## The crack's picture is baked on a worker: -1 not yet asked for, -2 on the glass.
var _crack_task := -1
var _spread := 0.0
var _spread_to := 0.0


func _ready() -> void:
	if glass == null or cabin == null:
		return
	_measure_plane()
	material.shader = SHADER
	material.render_priority = CarModel.GLASS_PRIORITY
	material.set_shader_parameter(&"dirt_noise", dirt_noise())
	material.set_shader_parameter(&"plane_origin", _origin)
	material.set_shader_parameter(&"plane_u", _u)
	material.set_shader_parameter(&"plane_v", _v)
	material.set_shader_parameter(&"plane_size", _size)
	material.set_shader_parameter(&"wipe_sweep", deg_to_rad(WIPER_SWEEP))
	glass.material_override = material
	_build_wipers()
	cabin.dirt_changed.connect(_on_dirt)
	cabin.windshield_changed.connect(_on_windshield)
	cabin.stone_chipped.connect(_on_stone_chipped)
	_on_dirt(cabin.dirt)
	_on_windshield(cabin.windshield)
	_on_stone_chipped(cabin.stone_hits)


## The plane from the mesh's own triangles: its average normal (pointing out of the car), the
## direction across the car, the direction up the glass, and the extent along both.
func _measure_plane() -> void:
	var arrays := glass.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normal := Vector3.ZERO
	for n in normals:
		normal += n if n.dot(normals[0]) >= 0.0 else -n
	normal = normal.normalized() if normal.length_squared() > 0.0 else Vector3.BACK
	var to_local := glass.global_transform.affine_inverse()
	var car := cabin.get_parent() as Node3D
	var center := Vector3.ZERO
	for p in vertices:
		center += p
	center /= maxf(vertices.size(), 1)
	if car != null and (to_local * car.global_position - center).dot(normal) > 0.0:
		normal = -normal  # point out of the car
	var up := (to_local.basis * Vector3.UP).normalized()
	var across := up.cross(normal).normalized()
	var along := normal.cross(across).normalized()
	if along.dot(up) < 0.0:
		along = -along
		across = -across
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in vertices:
		var q := Vector2((p - center).dot(across), (p - center).dot(along))
		lo = lo.min(q)
		hi = hi.max(q)
	_u = across
	_v = along
	_n = normal
	_origin = center + across * lo.x + along * lo.y
	_size = hi - lo


func _on_dirt(level: float) -> void:
	_edge_dirt = maxf(_edge_dirt, level)
	material.set_shader_parameter(&"dirt", level)


func _on_windshield(state: int) -> void:
	if state == Cabin.Windshield.CRACKED:
		_bake_crack()
	if state == Cabin.Windshield.REMOVED:
		_edge_dirt = 0.0
	_on_stone_chipped(cabin.stone_hits)


## A stone leaves a bullseye, and from the one that cracks the glass on each spreads the crack further.
func _on_stone_chipped(hits: int) -> void:
	var cracked := cabin.windshield == Cabin.Windshield.CRACKED
	material.set_shader_parameter(&"chipped", 1.0 if hits > 0 or cracked else 0.0)
	material.set_shader_parameter(&"chip_at", crack_center(_seed()) * _size)
	_spread_to = maxf(CrackPicture.spread(hits), CrackPicture.FIRST_SPREAD) if cracked else 0.0
	if hits > 0:
		_bake_crack()


## Baked once the first stone has marked the glass: ready long before the one that cracks it.
func _bake_crack() -> void:
	if _crack_task != -1 or DisplayServer.get_name() == "headless":
		return
	var crack := CrackPicture.pieces(_seed(), _size, crack_center(_seed()) * _size)
	var size := _size
	_crack_task = WorkerThreadPool.add_task(func() -> void: _on_crack_baked.call_deferred(CrackPicture.bake(crack, size)))


func _on_crack_baked(picture: Image) -> void:
	WorkerThreadPool.wait_for_task_completion(_crack_task)
	_crack_task = -2
	material.set_shader_parameter(&"crack_map", ImageTexture.create_from_image(picture))
	material.set_shader_parameter(&"crack_metres", _size)


func _exit_tree() -> void:
	if _crack_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_crack_task)
		_crack_task = -1


## What makes this car's cracks its own.
func _seed() -> int:
	return cabin.team * 31 + 7


func _process(delta: float) -> void:
	if cabin == null or _wipers.is_empty():
		return
	if _spread != _spread_to and _crack_task == -2:
		_spread = move_toward(_spread, _spread_to, CRACK_RUN * delta)
		material.set_shader_parameter(&"crack_spread", _spread)
	_edge_dirt = maxf(_edge_dirt - EDGE_CLEAR_RATE * delta, cabin.dirt)
	material.set_shader_parameter(&"edge_dirt", _edge_dirt)
	if cabin.wipers_on:
		_wiper_time += delta
	elif _wiper_time > 0.0:
		# Finish the sweep, then park.
		var phase := fmod(_wiper_time, WIPER_PERIOD) / WIPER_PERIOD
		_wiper_time = 0.0 if phase < 0.04 or phase > 0.96 else _wiper_time + delta
	var sweep := (1.0 - cos(_wiper_time * TAU / WIPER_PERIOD)) * 0.5
	var angle := deg_to_rad(WIPER_SWEEP) * sweep
	for wiper in _wipers:
		wiper.basis = Basis(_hinge_axis, angle)


## The model's wipers, each turning about its hinge, square to the glass. What each blade passes on the glass
## goes to the shader: a ring round the hinge, from where the blade lies parked to the end of its sweep.
func _build_wipers() -> void:
	var car_space := (glass.get_parent() as Node3D).transform * glass.transform
	var to_mesh := car_space.affine_inverse()
	_hinge_axis = (car_space.basis * _n).normalized()
	var holder := get_parent() as Node3D
	for i in WIPERS.size():
		var spec: Dictionary = WIPERS[i]
		var hinge: Vector3 = spec.hinge
		var wiper := Node3D.new()
		wiper.name = "Wiper%d" % i
		wiper.position = hinge
		holder.add_child(wiper)
		var piece := MeshInstance3D.new()
		piece.name = "ArmAndBlade"
		piece.mesh = CarParts.joined(spec.arm, spec.blade)
		piece.position = -hinge
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visibility_range_end = DRAW_RANGE
		wiper.add_child(piece)
		_wipers.append(wiper)
		_tell_shader(i, parts[spec.blade], hinge, to_mesh)


## `blade` and `hinge` are in car space, `to_mesh` takes them to the glass's mesh space.
func _tell_shader(index: int, blade: Mesh, hinge: Vector3, to_mesh: Transform3D) -> void:
	var at_hinge := to_mesh * hinge - _origin
	var pivot := Vector2(at_hinge.dot(_u), at_hinge.dot(_v))
	var inner := INF
	var outer := 0.0
	var middle := Vector2.ZERO
	for vertex in blade.get_faces():
		var at := to_mesh * vertex - _origin
		var from_hinge := Vector2(at.dot(_u), at.dot(_v)) - pivot
		inner = minf(inner, from_hinge.length())
		outer = maxf(outer, from_hinge.length())
		middle += from_hinge
	var suffix := "a" if index == 0 else "b"
	material.set_shader_parameter(StringName("pivot_" + suffix), pivot)
	material.set_shader_parameter(StringName("wipe_" + suffix), Vector3(inner, outer, middle.angle()))


static var _noise_texture: NoiseTexture2D


static func dirt_noise() -> NoiseTexture2D:
	if _noise_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		_noise_texture = NoiseTexture2D.new()
		_noise_texture.width = 256
		_noise_texture.height = 256
		_noise_texture.seamless = true
		_noise_texture.generate_mipmaps = true
		_noise_texture.noise = noise
	return _noise_texture


## Where on the glass a car's first stone lands and its crack starts (0..1 across and up the glass), seeded per car.
static func crack_center(seed: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.45, 0.75))
