class_name RallyArch
## The gantry over the start and finish lines (TrackFeatures): two box-truss towers on steel plates, a
## concrete block guarding each, a truss across carrying a printed banner both ways (the word in strong
## type between the flag at each end) and a Turkish flag flying from each tower. All of the truss is one
## mesh. In its own space the road runs along -Z and the road's level is y = 0.

const HEIGHT := 5.0
const SECTION := 0.34
## A truss bay's length, the thick chords' and the thin lacing's radius (m).
const BAY := 0.46
const CHORD_RADIUS := 0.024
const LACE_RADIUS := 0.011
const CHORD_SIDES := 6
const LACE_SIDES := 4
const PLATE_SIZE := Vector3(0.9, 0.03, 0.9)
## The towers stand this far past the road's edge.
const TOWER_EDGE := RoadBuilder.POST_OFFSET + 0.5
## How far the towers' feet reach below the ground, so a slope never shows daylight.
const FOOT_SINK := 0.1
## The block in front of a tower: how far toward the road from the tower, and its collision box.
const BLOCK_MODEL := "res://assets/models/concrete_road_barrier_02/concrete_road_barrier_02_1k.gltf"
const BLOCK_OFFSET := 0.62
const BLOCK_SIZE := Vector3(0.44, 1.1, 1.56)
const POLE_HEIGHT := 2.6
const DRAW_RANGE := 700.0
const TEXT_RANGE := 320.0

## The banner in metres (always this long, so its print is never stretched; every road's towers stand
## wider apart) and its picture.
const BANNER_SIZE := Vector2(9.6, 1.25)
const BANNER_PIXELS := Vector2i(2048, 267)
## The flag on the banner: its height (m) and how far its near edge is from the banner's end. The word's
## size. A panel between the flag and the word closes the rest of the print.
const BANNER_FLAG := 0.85
const BANNER_FLAG_MARGIN := 0.2
const TEXT_PIXEL := 0.0062
const TEXT_FONT := 192
const FIELD := Color(0.075, 0.08, 0.095)
const STRIPE_SHARE := 0.05
const PANEL_CELL := 42
const PANEL_ROWS := 3
const PRINT_SUNLIT := 0.58

static var _banner_textures: Dictionary = {}


## The arch over `gate`, named Arch<kind>: "Start" or "Finish", with the word `text_key` on its banner.
static func build(graph: RouteGraph, gate: RouteGraph.Gate, terrain: TerrainField, kind: String, text_key: String) -> Node3D:
	var arch := Node3D.new()
	arch.name = "Arch" + kind
	var edge := graph.edges[gate.edge_id]
	var dir := gate.direction
	arch.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP),
		Vector3(gate.position.x, edge.heights[gate.point_index], gate.position.y))
	var half := edge.width * 0.5 + TOWER_EDGE
	var body := StaticBody3D.new()
	body.name = "Posts"
	body.set_meta(&"surface", Surface.TARMAC)
	arch.add_child(body)
	var truss := SurfaceTool.new()
	truss.begin(Mesh.PRIMITIVE_TRIANGLES)
	var batches := {}
	for side: float in [-1.0, 1.0]:
		var ground := _ground_at(arch, terrain, Vector3(side * half, 0.0, 0.0))
		var foot := Vector3(side * half, ground - FOOT_SINK, 0.0)
		var top := Vector3(side * half, HEIGHT, 0.0)
		_add_truss(truss, foot, top, Vector3.RIGHT)
		_add_box(truss, Vector3(side * half, ground + PLATE_SIZE.y * 0.5, 0.0), PLATE_SIZE)
		_add_collision(body, Vector3(side * half, (foot.y + top.y) * 0.5, 0.0), Vector3(SECTION, top.y - foot.y, SECTION))
		var block := Vector3(side * (half - BLOCK_OFFSET), 0.0, 0.0)
		block.y = _ground_at(arch, terrain, block)
		_add_block(body, block)
		RoadsideDresser._add_to_batches(batches, {"id": "arch_flag", "range": DRAW_RANGE, "shadows": true},
			RallyProps.flag_parts(POLE_HEIGHT), Transform3D(Basis.IDENTITY, top))
	var beam_y := HEIGHT - SECTION * 0.5
	_add_truss(truss, Vector3(-half, beam_y, 0.0), Vector3(half, beam_y, 0.0), Vector3.BACK)
	truss.set_material(_steel())
	var mesh := MeshInstance3D.new()
	mesh.name = "Truss"
	mesh.mesh = truss.commit()
	mesh.visibility_range_end = DRAW_RANGE
	arch.add_child(mesh)
	arch.add_child(_banner(kind))
	var banner_y := _banner_y()
	for face: float in [1.0, -1.0]:
		arch.add_child(_word(TranslationServer.translate(text_key), banner_y, face))
	RoadsideDresser._build_batches(arch, batches)
	return arch


## How high the banner's middle hangs: its top just above the truss, hiding it.
static func _banner_y() -> float:
	return HEIGHT + 0.03 - BANNER_SIZE.y * 0.5


static func _ground_at(arch: Node3D, terrain: TerrainField, local: Vector3) -> float:
	var world := arch.transform * local
	return terrain.height(Vector2(world.x, world.z)) - arch.position.y


# --- the truss ---

## A box truss from `a` to `b` with `face` the direction of one of its sides: four chords, a tie and a
## diagonal in every bay of every side.
static func _add_truss(surface: SurfaceTool, a: Vector3, b: Vector3, face: Vector3) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var other := along.cross(face).normalized()
	var offset := SECTION * 0.5 - CHORD_RADIUS
	var corners: Array[Vector3] = [(face + other) * offset, (other - face) * offset, -(face + other) * offset, (face - other) * offset]
	for corner in corners:
		_add_tube(surface, a + corner, b + corner, CHORD_RADIUS, CHORD_SIDES)
	var bays := maxi(roundi(length / BAY), 1)
	for n in bays:
		var p0 := a + along * length * n / bays
		var p1 := a + along * length * (n + 1) / bays
		for k in corners.size():
			var from := corners[k]
			var to := corners[(k + 1) % corners.size()]
			_add_tube(surface, p0 + from, p0 + to, LACE_RADIUS, LACE_SIDES)
			if n % 2 == 0:
				_add_tube(surface, p0 + from, p1 + to, LACE_RADIUS, LACE_SIDES)
			else:
				_add_tube(surface, p0 + to, p1 + from, LACE_RADIUS, LACE_SIDES)
	# The bay after the last closes the truss at its far end.
	for k in corners.size():
		_add_tube(surface, b + corners[k], b + corners[(k + 1) % corners.size()], LACE_RADIUS, LACE_SIDES)


## A round tube from `a` to `b` with `sides` flat sides, normals smooth round it.
static func _add_tube(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides: int) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		# Origin -> +X -> +Z seen from outside: wound so the outside is the front.
		_add_quad(surface, [a + n0 * radius, a + n1 * radius, b + n1 * radius, b + n0 * radius], [n0, n1, n1, n0])


## A flat box round `center`.
static func _add_box(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var faces: Array = [
		[Vector3.UP, Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.RIGHT, Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)],
		[Vector3.LEFT, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z)],
		[Vector3.BACK, Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)],
		[Vector3.FORWARD, Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z)],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		_add_quad(surface, [center + (face[1] as Vector3), center + (face[2] as Vector3), center + (face[3] as Vector3), center + (face[4] as Vector3)], [n, n, n, n])


## Two triangles a -> b -> c, a -> c -> d (seen from the normal's side, turning the way Godot's front faces do).
static func _add_quad(surface: SurfaceTool, p: Array, n: Array) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(n[i])
		surface.add_vertex(p[i])


static var _steel_material: StandardMaterial3D


static func _steel() -> StandardMaterial3D:
	if _steel_material == null:
		_steel_material = StandardMaterial3D.new()
		_steel_material.albedo_color = Color(0.74, 0.75, 0.77)
		_steel_material.metallic = 0.35
		_steel_material.roughness = 0.5
		_steel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _steel_material


# --- what stands round it ---

static func _add_collision(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


## A concrete block lying along the road, its foot at `at`.
static func _add_block(body: StaticBody3D, at: Vector3) -> void:
	var turn := Transform3D(Basis(Vector3.UP, PI * 0.5), at)
	for part in RoadsideDresser._parts_of({"id": "arch_block", "path": BLOCK_MODEL}):
		var mesh := MeshInstance3D.new()
		mesh.mesh = part.mesh
		mesh.transform = turn * (part.transform as Transform3D)
		mesh.visibility_range_end = TEXT_RANGE
		body.add_child(mesh)
	_add_collision(body, at + Vector3.UP * BLOCK_SIZE.y * 0.5, BLOCK_SIZE)


# --- the banner ---

## The banner's two faces, one in front of the truss each way.
static func _banner(kind: String) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := BANNER_SIZE * 0.5
	var y := _banner_y()
	var z := SECTION * 0.5 + 0.015
	for face: float in [1.0, -1.0]:
		var normal := Vector3.BACK * face
		var corners: Array = [Vector3(-half.x * face, y + half.y, z * face), Vector3(half.x * face, y + half.y, z * face),
			Vector3(half.x * face, y - half.y, z * face), Vector3(-half.x * face, y - half.y, z * face)]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i: int in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(normal)
			surface.set_uv(uvs[i])
			surface.add_vertex(corners[i])
	var material := StandardMaterial3D.new()
	material.albedo_texture = banner_texture(kind)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Matte print: the sun on it must not pale the red or lift the dark field to grey. It stays readable
	# in a dark forest.
	material.albedo_color = Color.WHITE * PRINT_SUNLIT
	material.roughness = 0.9
	material.metallic_specular = 0.1
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = material.albedo_texture
	material.emission_energy_multiplier = 0.08
	surface.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = "Banner"
	mesh.mesh = surface.commit()
	mesh.visibility_range_end = DRAW_RANGE
	return mesh


static func banner_texture(kind: String) -> Texture2D:
	if not _banner_textures.has(kind):
		var image := banner_image(kind)
		image.generate_mipmaps()
		_banner_textures[kind] = ImageTexture.create_from_image(image)
	return _banner_textures[kind]


## The print: a dark field between two red stripes, the flag at each end, then a white chevron panel
## (start) or a chequered one (finish); the middle stays free for the word.
static func banner_image(kind: String) -> Image:
	var image := Image.create(BANNER_PIXELS.x, BANNER_PIXELS.y, false, Image.FORMAT_RGB8)
	image.fill(FIELD)
	var stripe := roundi(BANNER_PIXELS.y * STRIPE_SHARE)
	image.fill_rect(Rect2i(0, 0, BANNER_PIXELS.x, stripe), TurkishFlag.RED)
	image.fill_rect(Rect2i(0, BANNER_PIXELS.y - stripe, BANNER_PIXELS.x, stripe), TurkishFlag.RED)
	var flag_rect := flag_rects()[0]
	var flag := TurkishFlag.image(TurkishFlag.TEXTURE_HEIGHT)
	flag.resize(flag_rect.size.x, flag_rect.size.y, Image.INTERPOLATE_LANCZOS)
	for rect in flag_rects():
		image.blit_rect(flag, Rect2i(Vector2i.ZERO, flag.get_size()), rect.position)
	var panel_width := PANEL_CELL * 6
	var panel_height := PANEL_CELL * PANEL_ROWS
	var panel_top := (BANNER_PIXELS.y - panel_height) / 2
	var near := flag_rect.position.x + flag_rect.size.x + PANEL_CELL
	for left: int in [near, BANNER_PIXELS.x - near - panel_width]:
		for y in panel_height:
			for x in panel_width:
				var white := false
				if kind == "Finish":
					white = (x / PANEL_CELL + y / PANEL_CELL) % 2 == 0
				else:
					# Chevrons pointing down the road's way out, away from the middle on neither side.
					var pointing := absf(y - panel_height * 0.5) + (x if left < BANNER_PIXELS.x / 2 else panel_width - x)
					white = int(pointing) % (PANEL_CELL * 2) < PANEL_CELL
				if white:
					image.set_pixel(left + x, panel_top + y, Color.WHITE)
	return image


## Where the two flags lie on the banner's picture.
static func flag_rects() -> Array[Rect2i]:
	var per_metre := BANNER_PIXELS.x / BANNER_SIZE.x
	var height := roundi(BANNER_FLAG * per_metre)
	var width := roundi(height * TurkishFlag.LENGTH)
	var top := (BANNER_PIXELS.y - height) / 2
	var margin := roundi(BANNER_FLAG_MARGIN * per_metre)
	return [Rect2i(margin, top, width, height), Rect2i(BANNER_PIXELS.x - margin - width, top, width, height)]


static func _word(text: String, y: float, face: float) -> Label3D:
	var label := Label3D.new()
	label.name = "Word" if face > 0.0 else "WordBack"
	label.text = text
	label.font = UiTheme.hud_font(800, 100)
	label.font_size = TEXT_FONT
	label.pixel_size = TEXT_PIXEL
	label.modulate = Color(0.97, 0.97, 0.95)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.position = Vector3(0.0, y, (SECTION * 0.5 + 0.03) * face)
	label.rotation.y = 0.0 if face > 0.0 else PI
	label.visibility_range_end = TEXT_RANGE
	return label
