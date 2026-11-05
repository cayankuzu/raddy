class_name RallyProps
## How the rally furniture looks (RallyDressing says where it goes): boards on posts, straw bales,
## stakes and tape, flags (TurkishFlag) and what stands in a spectators' place. Signs, straw and tape
## are drawn here once, so nothing is shipped and no text needs translating except the words on the
## boards. Each prop is a list of parts ({mesh, transform, material}) for RoadsideDresser's batches:
## in its own space a prop stands on y = 0 and looks along +Z.

const BOARD_SHADER := preload("res://shaders/board.gdshader")
const CLOTH_SHADER := preload("res://shaders/cloth.gdshader")
const COVERED_CAR_MODEL := "res://assets/models/covered_car/covered_car_1k.gltf"
const CIVILIAN_CAR_MODEL := "res://assets/vehicles/milano95/milano95.glb"

## Board sizes (m). A chevron is taller than wide; the official boards are round.
const BOARD_SIZES := {
	"km": Vector2(0.9, 1.15), "time_control": Vector2(1.0, 1.0), "start": Vector2(1.0, 1.0),
	"finish_warning": Vector2(1.0, 1.0), "finish": Vector2(1.0, 1.0), "stop": Vector2(1.1, 1.1),
	"chevron_left": Vector2(1.0, 1.25), "chevron_right": Vector2(1.0, 1.25), "caution": Vector2(1.2, 1.2),
	"split": Vector2(1.2, 0.8),
}
const POST_RADIUS := 0.035
## A post's centre stands this far behind its board's face, clear of it.
const POST_BEHIND := POST_RADIUS + 0.012
## Posts reach this far into the ground (it slopes under them).
const POST_SINK := 0.3
## A round bale lying on its side (its axis is local X).
const BALE_RADIUS := 0.75
const BALE_LENGTH := 1.2
## Bales sink a little into the ground under their weight.
const BALE_SINK := 0.05
const STAKE_HEIGHT := 1.25
const TAPE_HEIGHT := 1.0
const TAPE_WIDTH := 0.07
const TAPE_SAG := 0.06
const FLAG_HEIGHT := 3.6
## The cloth, always in the flag's own proportions (TurkishFlag).
const FLAG_SIZE := Vector2(0.8 * TurkishFlag.LENGTH, 0.8)
## The flag on the start's round board: its length on the sign (share of the sign's width).
const BOARD_FLAG_SHARE := 0.56
## The parked cars' collision box and footprint (m).
const CAR_SIZE := Vector3(1.8, 1.35, 4.4)
## Seats: the scanned model, its collision box and footprint (m) and how far it stands from anything else.
const SEATS := {
	"bench": {"model": "res://assets/models/painted_wooden_bench/painted_wooden_bench_1k.gltf", "size": Vector3(1.2, 0.9, 0.5), "room": 1.4},
	"table": {"model": "res://assets/models/wooden_picnic_table/wooden_picnic_table_1k.gltf", "size": Vector3(2.25, 0.75, 3.05), "room": 2.2},
	"chair": {"model": "res://assets/models/plastic_monobloc_chair_01/plastic_monobloc_chair_01_1k.gltf", "size": Vector3(0.65, 0.88, 0.65), "room": 0.7},
}
## Paints a parked car may have (a stage's crowd drives ordinary cars).
const CIVILIAN_PAINTS: Array[Color] = [Color(0.62, 0.64, 0.66), Color(0.1, 0.13, 0.2), Color(0.86, 0.86, 0.84), Color(0.32, 0.08, 0.07), Color(0.13, 0.22, 0.16)]
const SIGN_SIZE := 128

static var _textures: Dictionary = {}
static var _meshes: Dictionary = {}


## A board's post and face, its middle `panel` metres above the ground.
static func board_parts(kind: String, panel: float) -> Array:
	var size: Vector2 = BOARD_SIZES[kind]
	var top := panel + size.y * 0.35
	return [_part(_face_mesh(kind), Transform3D(Basis.IDENTITY, Vector3.UP * panel)),
		_part(_post_mesh(), Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, top + POST_SINK, 1.0)), Vector3(0.0, -POST_SINK, -POST_BEHIND)))]


## A sign on a post as nodes (a junction's barrier), its face toward +Z of the parent, its middle `at`.
static func board(kind: String, at: Vector3, size := 0.8) -> Node3D:
	var node := Node3D.new()
	node.name = "Board"
	node.position = at
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _board_material(kind)
	face.mesh = quad
	node.add_child(face)
	var post := MeshInstance3D.new()
	post.mesh = _post_mesh()
	post.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, at.y + 0.5, 1.0)), Vector3(0.0, -at.y - 0.5, -POST_BEHIND))
	node.add_child(post)
	return node


static func bale_parts() -> Array:
	return [_part(_cached("bale", _bale_mesh), Transform3D(Basis.IDENTITY, Vector3.UP * (BALE_RADIUS - BALE_SINK)))]


static func stake_parts() -> Array:
	return [_part(_cached("stake", _stake_mesh))]


## A Turkish flag on its pole, `height` metres from its foot to the top.
static func flag_parts(height := FLAG_HEIGHT) -> Array:
	return [_part(_cached("flag_pole", _flag_pole_mesh), Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, height / FLAG_HEIGHT, 1.0)), Vector3.ZERO)),
		_part(_cached("flag", _flag_mesh), Transform3D(Basis.IDENTITY, Vector3.UP * (height - FLAG_SIZE.y * 0.5 - 0.09)))]


## A scanned prop from its file, by RoadsideDresser's loader (it caches them per stage).
static func model_parts(path: String) -> Array:
	return RoadsideDresser._parts_of({"id": path.get_file(), "path": path})


## A car under its cover, or (`paint` >= 0) the painted body of an ordinary one in that
## CIVILIAN_PAINTS colour. What every ordinary car shares is car_rest_parts (fewer draw calls).
static func car_parts(paint: int) -> Array:
	if paint < 0:
		return [_part(_cached("covered_car", _covered_car_mesh))]
	return [_part(_cached("civilian_body_%d" % paint, _civilian_mesh.bind(paint)))]


## An ordinary car's wheels, windows and lights.
static func car_rest_parts() -> Array:
	return [_part(_cached("civilian_rest", _civilian_mesh.bind(-1)))]


## The tape round a place for spectators: one ribbon through `posts` (their feet, closed), sagging
## between them.
static func tape_mesh(posts: PackedVector3Array) -> ArrayMesh:
	const STEPS := 4
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_tape_material())
	var along := 0.0
	var count := 0
	for i in posts.size():
		var a := posts[i]
		var b := posts[(i + 1) % posts.size()]
		var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var normal := Vector3(-flat.z, 0.0, flat.x).normalized()
		for k in STEPS + 1:
			var t := float(k) / STEPS
			var p := a.lerp(b, t) + Vector3.UP * (TAPE_HEIGHT - TAPE_SAG * 4.0 * t * (1.0 - t))
			for row in 2:
				surface.set_normal(normal)
				surface.set_uv(Vector2((along + flat.length() * t) / 0.8, float(row)))
				surface.add_vertex(p + Vector3.UP * (TAPE_WIDTH * (float(row) - 0.5)))
		for k in STEPS:
			var v := count + k * 2
			surface.add_index(v)
			surface.add_index(v + 2)
			surface.add_index(v + 1)
			surface.add_index(v + 1)
			surface.add_index(v + 2)
			surface.add_index(v + 3)
		count += (STEPS + 1) * 2
		along += flat.length()
	return surface.commit()


static func _part(mesh: Mesh, transform := Transform3D.IDENTITY) -> Dictionary:
	return {"mesh": mesh, "transform": transform, "material": null}


static func _cached(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


# --- boards ---

static func _face_mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		var quad := QuadMesh.new()
		quad.size = BOARD_SIZES[kind]
		quad.material = _board_material(kind)
		_meshes[kind] = quad
	return _meshes[kind]


static func _board_material(kind: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BOARD_SHADER
	material.set_shader_parameter(&"face", texture(kind))
	return material


## A unit-high steel post with its foot at y = 0 (each board stretches it).
static func _post_mesh() -> Mesh:
	if not _meshes.has("post"):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = POST_RADIUS
		cylinder.bottom_radius = POST_RADIUS
		cylinder.height = 1.0
		cylinder.radial_segments = 8
		cylinder.rings = 1
		cylinder.cap_top = true
		cylinder.cap_bottom = false
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.36, 0.37, 0.39)
		steel.metallic = 0.6
		steel.roughness = 0.5
		var surface := SurfaceTool.new()
		surface.append_from(cylinder, 0, Transform3D(Basis.IDENTITY, Vector3.UP * 0.5))
		surface.set_material(steel)
		_meshes["post"] = surface.commit()
	return _meshes["post"]


## Generated sign textures, made once: "tape", "green_tape", "no_entry" and every board of BOARD_SIZES.
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		_textures[kind] = ImageTexture.create_from_image(_draw(kind))
	return _textures[kind]


static func _draw(kind: String) -> Image:
	const BLACK := Color(0.05, 0.05, 0.05)
	const WHITE := Color(0.95, 0.95, 0.92)
	const RED := Color(0.78, 0.07, 0.06)
	const YELLOW := Color(0.98, 0.78, 0.08)
	match kind:
		"tape":
			return _tape_image(Color(0.8, 0.08, 0.06), Color(0.95, 0.95, 0.93))
		"green_tape":
			return _tape_image(Color(0.05, 0.55, 0.2), Color(0.93, 0.95, 0.9))
		"no_entry":
			return _sign(func(u: Vector2) -> Color:
				var d := u.length()
				if d > 1.0:
					return Color(0, 0, 0, 0)
				if d > 0.93 or (absf(u.y) < 0.2 and absf(u.x) < 0.68):
					return WHITE
				return RED)
		"km":
			return _sign(func(u: Vector2) -> Color:
				if absf(u.x) > 0.9 or absf(u.y) > 0.92:
					return BLACK
				# "KM" small at the top; RallyDressing writes the number under it.
				return BLACK if u.y < -0.4 and _on_km(u) else WHITE)
		"split":
			return _sign(func(u: Vector2) -> Color:
				return BLACK if absf(u.x) > 0.94 or absf(u.y) > 0.91 else YELLOW)
		"time_control":
			return _sign(func(u: Vector2) -> Color:
				var d := u.length()
				if d > 1.0:
					return Color(0, 0, 0, 0)
				if d > 0.9 or (d > 0.62 and d < 0.72):
					return BLACK
				if _on_stroke(u, Vector2.ZERO, Vector2(0.0, -0.5), 0.07) or _on_stroke(u, Vector2.ZERO, Vector2(0.34, 0.14), 0.07):
					return BLACK
				return YELLOW)
		"start":
			return _start_board()
		"finish_warning":
			return _round_checker(YELLOW)
		"finish":
			return _round_checker(RED)
		"stop":
			return _sign(func(u: Vector2) -> Color:
				var octagon := maxf(maxf(absf(u.x), absf(u.y)), (absf(u.x) + absf(u.y)) * 0.7071)
				if octagon > 0.98:
					return Color(0, 0, 0, 0)
				return WHITE if octagon > 0.9 else RED)
		"chevron_right", "chevron_left":
			var pointing := 1.0 if kind == "chevron_right" else -1.0
			return _sign(func(u: Vector2) -> Color:
				if absf(u.x) > 0.93 or absf(u.y) > 0.95:
					return YELLOW
				var t := u.x * pointing + absf(u.y) * 0.85
				return YELLOW if t > -0.2 and t < 0.42 else BLACK)
		"caution":
			return _sign(func(u: Vector2) -> Color:
				if u.y > 0.85 or absf(u.x) > 1.02 - (1.0 - u.y) * 0.5:
					return Color(0, 0, 0, 0)
				if u.y < 0.68 and absf(u.x) < 0.8 - (1.0 - u.y) * 0.45:
					var mark: bool = absf(u.x) < 0.09 and ((u.y > -0.3 and u.y < 0.28) or (u.y > 0.38 and u.y < 0.54))
					return BLACK if mark else Color(0.97, 0.9, 0.3)
				return RED)
	return Image.create(2, 2, false, Image.FORMAT_RGBA8)


## The start's round white board: the flag on its staff.
static func _start_board() -> Image:
	const BLACK := Color(0.05, 0.05, 0.05)
	var board := _sign(func(u: Vector2) -> Color:
		var d := u.length()
		if d > 1.0:
			return Color(0, 0, 0, 0)
		if d > 0.92 or (absf(u.x + 0.52) < 0.04 and absf(u.y) < 0.66):
			return BLACK
		return Color(0.95, 0.95, 0.92))
	var flag_width := roundi(SIGN_SIZE * BOARD_FLAG_SHARE)
	var flag := TurkishFlag.image(TurkishFlag.TEXTURE_HEIGHT)
	flag.resize(flag_width, roundi(flag_width / TurkishFlag.LENGTH), Image.INTERPOLATE_LANCZOS)
	flag.convert(Image.FORMAT_RGBA8)
	board.clear_mipmaps()
	board.blit_rect(flag, Rect2i(Vector2i.ZERO, flag.get_size()), Vector2i(roundi(SIGN_SIZE * 0.26), roundi(SIGN_SIZE * 0.2)))
	board.generate_mipmaps()
	return board


## A round board with a chequered band across it, the sport's sign for the finish.
static func _round_checker(ground: Color) -> Image:
	const BLACK := Color(0.05, 0.05, 0.05)
	const WHITE := Color(0.95, 0.95, 0.92)
	return _sign(func(u: Vector2) -> Color:
		var d := u.length()
		if d > 1.0:
			return Color(0, 0, 0, 0)
		if d > 0.92:
			return BLACK
		if absf(u.y) < 0.4:
			return WHITE if (floori(u.x * 2.5 + 8.0) + floori(u.y * 2.5 + 8.0)) % 2 == 0 else BLACK
		return ground)


## On the letters K and M at the top of a km board.
static func _on_km(u: Vector2) -> bool:
	const TOP := -0.8
	const BOTTOM := -0.45
	const WIDTH := 0.05
	const MIDDLE := (TOP + BOTTOM) * 0.5
	return _on_stroke(u, Vector2(-0.46, TOP), Vector2(-0.46, BOTTOM), WIDTH) or _on_stroke(u, Vector2(-0.46, MIDDLE), Vector2(-0.14, TOP), WIDTH) \
		or _on_stroke(u, Vector2(-0.46, MIDDLE), Vector2(-0.14, BOTTOM), WIDTH) or _on_stroke(u, Vector2(0.06, BOTTOM), Vector2(0.06, TOP), WIDTH) \
		or _on_stroke(u, Vector2(0.06, TOP), Vector2(0.26, MIDDLE), WIDTH) or _on_stroke(u, Vector2(0.26, MIDDLE), Vector2(0.46, TOP), WIDTH) \
		or _on_stroke(u, Vector2(0.46, TOP), Vector2(0.46, BOTTOM), WIDTH)


static func _on_stroke(u: Vector2, a: Vector2, b: Vector2, width: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(u, a, b).distance_to(u) < width


## A SIGN_SIZE square sign from `paint`: its colour at u in -1..1 (y down).
static func _sign(paint: Callable) -> Image:
	var image := Image.create(SIGN_SIZE, SIGN_SIZE, false, Image.FORMAT_RGBA8)
	for y in SIGN_SIZE:
		for x in SIGN_SIZE:
			image.set_pixel(x, y, paint.call(Vector2(x + 0.5, y + 0.5) / (SIGN_SIZE * 0.5) - Vector2.ONE))
	image.generate_mipmaps()
	return image


# --- tape and stakes ---

static func _tape_image(stripe: Color, gap: Color) -> Image:
	var image := Image.create(32, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 32:
			image.set_pixel(x, y, stripe if (x + y * 2) % 32 < 16 else gap)
	image.generate_mipmaps()
	return image


static func _tape_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture("green_tape")
	material.roughness = 0.7
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func _stake_mesh() -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.022
	cylinder.bottom_radius = 0.028
	cylinder.height = STAKE_HEIGHT + POST_SINK
	cylinder.radial_segments = 6
	cylinder.rings = 1
	cylinder.cap_bottom = false
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.56, 0.45, 0.3)
	wood.roughness = 0.9
	var surface := SurfaceTool.new()
	surface.append_from(cylinder, 0, Transform3D(Basis.IDENTITY, Vector3.UP * ((STAKE_HEIGHT - POST_SINK) * 0.5)))
	surface.set_material(wood)
	return surface.commit()


# --- flags ---

## A steel staff (a ball on its top), its foot at y = 0.
static func _flag_pole_mesh() -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.018
	cylinder.bottom_radius = 0.028
	cylinder.height = FLAG_HEIGHT + POST_SINK
	cylinder.radial_segments = 8
	cylinder.rings = 1
	cylinder.cap_bottom = false
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.08
	ball.radial_segments = 8
	ball.rings = 4
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.73, 0.75)
	steel.metallic = 0.5
	steel.roughness = 0.45
	var surface := SurfaceTool.new()
	surface.append_from(cylinder, 0, Transform3D(Basis.IDENTITY, Vector3.UP * ((FLAG_HEIGHT - POST_SINK) * 0.5)))
	surface.append_from(ball, 0, Transform3D(Basis.IDENTITY, Vector3.UP * (FLAG_HEIGHT + 0.03)))
	surface.set_material(steel)
	return surface.commit()


## A cloth along +X from the pole, fine enough to wave (shaders/cloth.gdshader); UV.x 0 at the pole.
static func _flag_mesh() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = FLAG_SIZE
	plane.orientation = PlaneMesh.FACE_Z
	plane.subdivide_width = 18
	plane.subdivide_depth = 6
	var material := ShaderMaterial.new()
	material.shader = CLOTH_SHADER
	material.set_shader_parameter(&"cloth", TurkishFlag.texture())
	material.set_shader_parameter(&"size", FLAG_SIZE)
	var surface := SurfaceTool.new()
	surface.append_from(plane, 0, Transform3D(Basis.IDENTITY, Vector3.RIGHT * FLAG_SIZE.x * 0.5))
	surface.set_material(material)
	return surface.commit()


# --- straw bales ---

## A round bale: a bulging barrel round X with soft shoulders and slightly domed ends, one texture
## (the wrapped side on the left half, the rolled end on the right half).
static func _bale_mesh() -> Mesh:
	const SEGMENTS := 20
	# Across the barrel: position along the axis (-1..1), radius factor.
	const PROFILE: Array[Vector2] = [Vector2(-1.0, 0.86), Vector2(-0.96, 0.95), Vector2(-0.82, 0.99), Vector2(-0.4, 1.0),
		Vector2(0.4, 1.0), Vector2(0.82, 0.99), Vector2(0.96, 0.95), Vector2(1.0, 0.86)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := BALE_LENGTH * 0.5
	for k in SEGMENTS + 1:
		# The seam of the texture lies underneath.
		var a := TAU * k / SEGMENTS - PI * 0.5
		var round_dir := Vector3(0.0, sin(a), cos(a))
		for row in PROFILE.size():
			var p := PROFILE[row]
			var before := PROFILE[maxi(row - 1, 0)]
			var after := PROFILE[mini(row + 1, PROFILE.size() - 1)]
			var slope := (after.y - before.y) * BALE_RADIUS / maxf((after.x - before.x) * half, 0.001)
			surface.set_normal((round_dir - Vector3.RIGHT * slope).normalized())
			surface.set_uv(Vector2(float(k) / SEGMENTS * 0.5, float(row) / (PROFILE.size() - 1)))
			surface.add_vertex(Vector3.RIGHT * p.x * half + round_dir * p.y * BALE_RADIUS)
	var stride := PROFILE.size()
	for k in SEGMENTS:
		for row in stride - 1:
			var v := k * stride + row
			surface.add_index(v)
			surface.add_index(v + stride)
			surface.add_index(v + 1)
			surface.add_index(v + 1)
			surface.add_index(v + stride)
			surface.add_index(v + stride + 1)
	# The two domed ends.
	var base := (SEGMENTS + 1) * stride
	for end: float in [-1.0, 1.0]:
		var centre_uv := Vector2(0.75, 0.5)
		surface.set_normal(Vector3.RIGHT * end)
		surface.set_uv(centre_uv)
		surface.add_vertex(Vector3.RIGHT * end * (half + 0.03))
		for k in SEGMENTS + 1:
			var a := TAU * k / SEGMENTS
			var round_dir := Vector3(0.0, sin(a), cos(a))
			surface.set_normal((Vector3.RIGHT * end + round_dir * 0.25).normalized())
			surface.set_uv(centre_uv + Vector2(cos(a) * 0.245, sin(a) * 0.49))
			surface.add_vertex(Vector3.RIGHT * end * half + round_dir * BALE_RADIUS * PROFILE[0].y)
		for k in SEGMENTS:
			surface.add_index(base)
			surface.add_index(base + k + (2 if end < 0.0 else 1))
			surface.add_index(base + k + (1 if end < 0.0 else 2))
		base += SEGMENTS + 2
	surface.generate_tangents()
	var material := StandardMaterial3D.new()
	var maps := _straw_textures()
	material.albedo_texture = maps[0]
	material.normal_enabled = true
	material.normal_texture = maps[1]
	material.normal_scale = 1.2
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	surface.set_material(material)
	return surface.commit()


## [albedo, normal] of straw: long fibres round the side (left half, seamless round), a rolled
## spiral of them on the end (right half).
static func _straw_textures() -> Array:
	const SIZE := 256
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.55
	noise.fractal_octaves = 2
	# Noise stretched along x: fine fibres; a second, coarser layer for tufts.
	var fibres := noise.get_seamless_image(SIZE / 8, SIZE, false, false, 0.15)
	fibres.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	noise.frequency = 0.16
	var tufts := noise.get_seamless_image(SIZE / 4, SIZE / 2, false, false, 0.15)
	tufts.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	var albedo := Image.create(SIZE * 2, SIZE, false, Image.FORMAT_RGB8)
	var height := Image.create(SIZE * 2, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			# The side: two layers of fibres at a slight slant to each other.
			var a_value := fibres.get_pixel(x, (y + x / 4) % SIZE).r
			var b_value := fibres.get_pixel((x + 90) % SIZE, (y + SIZE - x / 6) % SIZE).r
			var tuft := tufts.get_pixel(x, y).r
			_straw_pixel(albedo, height, x, y, maxf(a_value, b_value) * 1.25 - 0.35 + (tuft - 0.5) * 0.5)
			# The end: the same fibres following a spiral, tight in the middle.
			var u := Vector2(x + 0.5, y + 0.5) / (SIZE * 0.5) - Vector2.ONE
			var r := minf(u.length() + (tuft - 0.5) * 0.12, 1.0)
			var around := fposmod(u.angle() / TAU, 1.0)
			var coil := sin((r * 6.0 + around) * TAU) * 0.5 + 0.5
			var strand := fibres.get_pixel(int(around * (SIZE - 1)), int(r * 0.6 * (SIZE - 1))).r
			_straw_pixel(albedo, height, x + SIZE, y, strand * 1.2 - 0.05 + (coil - 0.5) * 0.3 + (tuft - 0.5) * 0.5)
	albedo.generate_mipmaps()
	height.bump_map_to_normal_map(2.5)
	height.generate_mipmaps(true)
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(height)]


## One pixel of straw from `value` (0 = a dark gap between fibres, 1 = a sunlit fibre).
static func _straw_pixel(albedo: Image, height: Image, x: int, y: int, value: float) -> void:
	const GAP := Color(0.27, 0.19, 0.08)
	const STRAW := Color(0.68, 0.54, 0.27)
	const LIT := Color(0.93, 0.81, 0.52)
	var v := clampf(value, 0.0, 1.0)
	albedo.set_pixel(x, y, GAP.lerp(STRAW, v * 2.0) if v < 0.5 else STRAW.lerp(LIT, v * 2.0 - 1.0))
	height.set_pixel(x, y, Color(v, v, v))


# --- cars ---

## The covered-car scan as one mesh (body and wheels share a material), looking along +Z.
static func _covered_car_mesh() -> Mesh:
	var surface := SurfaceTool.new()
	var material: Material = null
	for part in model_parts(COVERED_CAR_MODEL):
		var mesh := part.mesh as Mesh
		for s in mesh.get_surface_count():
			surface.append_from(mesh, s, part.transform)
			material = mesh.surface_get_material(s)
	surface.set_material(material)
	return surface.commit()


## The rally car's model as an ordinary parked car: its body in CIVILIAN_PAINTS[paint], or with
## `paint` < 0 everything else, one surface per kind of material, the windows dark and opaque with
## nothing inside.
static func _civilian_mesh(paint: int) -> Mesh:
	const BODY := "Milano95_Bodymat"
	const GLASS := "UCB_Lights_and_Glass_Transperent"
	const SKIPPED := ["UCB_Interiors_2", "Numberplates_Misk_U", "Carbadges_misc_U"]
	# The model looks along +X with its ground at y = 0; centred on its footprint.
	var turn := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.0856, 0.0, -0.03))
	var tools := {}
	for part in model_parts(CIVILIAN_CAR_MODEL):
		var mesh := part.mesh as Mesh
		for s in mesh.get_surface_count():
			var source := mesh.surface_get_material(s)
			var material_name: String = source.resource_name if source != null else ""
			if material_name in SKIPPED or (material_name == BODY) != (paint >= 0):
				continue
			if not tools.has(material_name):
				var tool := SurfaceTool.new()
				tools[material_name] = tool
				match material_name:
					BODY:
						var body := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
						body.albedo_color = CIVILIAN_PAINTS[paint]
						body.metallic = 0.35
						body.roughness = 0.35
						tool.set_material(body)
					GLASS:
						var glass := StandardMaterial3D.new()
						glass.albedo_color = Color(0.03, 0.04, 0.05)
						glass.metallic = 0.7
						glass.roughness = 0.12
						tool.set_material(glass)
					_:
						tool.set_material(source)
			(tools[material_name] as SurfaceTool).append_from(mesh, s, turn * (part.transform as Transform3D))
	var out := ArrayMesh.new()
	for material_name in tools:
		(tools[material_name] as SurfaceTool).commit(out)
	return out
