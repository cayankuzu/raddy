class_name RallyDressing
## What says "rally" on a stage, beyond the road and the forest. The furniture of its junctions: a
## log pile closing a dead end, concrete blocks, tape and a no-entry board across a closed road, and
## no warning at the mouth (only the map tells which way). Signs use small textures generated here,
## so nothing is shipped and no text needs translating.

const BARRIER_MODEL := "res://assets/models/concrete_road_barrier_02/concrete_road_barrier_02_1k.gltf"
const LOG_NODE := "Coniferous Dead Log_5"
const TAPE_HEIGHT := 1.05
const LOG_PILE_SIZE := Vector3(6.0, 1.4, 2.4)
const BOARD_HEIGHT := 1.5

static var _textures: Dictionary = {}


## Junction<id> for every wrong way.
static func junction_furniture(graph: RouteGraph, terrain: TerrainField) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for spur in graph.spurs:
		var node := Node3D.new()
		node.name = "Junction%d" % spur.id
		node.set_meta(&"spur_id", spur.id)
		if spur.end == &"barrier":
			_build_barrier(node, spur)
		else:
			_build_log_pile(node, spur, terrain)
		out.append(node)
	return out


## Point and direction of a spur `distance` metres from its junction.
static func _spur_pose(spur: RouteGraph.Spur, distance: float) -> Dictionary:
	var points := spur.points_3d()
	var along := spur.distances()
	var i := 0
	while i < along.size() - 2 and along[i + 1] < distance:
		i += 1
	var dir := Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).normalized()
	var t := clampf((distance - along[i]) / maxf(along[i + 1] - along[i], 0.001), 0.0, 1.0)
	return {"position": points[i].lerp(points[i + 1], t), "direction": dir}


## A stack of logs across the end of a dead-end track, just beyond its turning area.
static func _build_log_pile(node: Node3D, spur: RouteGraph.Spur, terrain: TerrainField) -> void:
	var pose := _spur_pose(spur, spur.length)
	var dir: Vector2 = pose.direction
	var at: Vector2 = spur.landing + dir * (spur.landing_radius + 1.5)
	var body := StaticBody3D.new()
	body.name = "LogPile"
	body.set_meta(&"surface", Surface.TARMAC)
	body.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), Vector3(at.x, terrain.height(at), at.y))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = LOG_PILE_SIZE
	shape.shape = box
	shape.position = Vector3.UP * LOG_PILE_SIZE.y * 0.5
	body.add_child(shape)
	var parts := RoadsideDresser._parts_of({"id": "log", "path": RoadsideCatalog.CONIFERS, "node": LOG_NODE, "foliage": true})
	for row in 3:
		for k in 3 - row:
			var across := (k - (2 - row) * 0.5) * 0.75
			var placed := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 + 41.8) + k * 0.05), Vector3(0.0, 0.28 + row * 0.5, across))
			for part in parts:
				var mesh := MeshInstance3D.new()
				mesh.mesh = part.mesh
				mesh.transform = placed * (part.transform as Transform3D)
				if part.material != null:
					mesh.material_override = part.material
				body.add_child(mesh)
	node.add_child(body)


## Concrete blocks and tape across a closed road, deep enough in the track to be out of sight from
## the junction; the road carries on beyond them. The box closes its shoulders and ditches too.
static func _build_barrier(node: Node3D, spur: RouteGraph.Spur) -> void:
	var pose := _spur_pose(spur, spur.barrier_at)
	var dir: Vector2 = pose.direction
	var half: float = spur.edges[0].width * 0.5
	var span := half * 2.0 + RoadBuilder.ROADSIDE * 2.0
	var body := StaticBody3D.new()
	body.name = "Barrier"
	body.set_meta(&"surface", Surface.TARMAC)
	body.set_meta(&"span", span)
	body.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), pose.position)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, 1.6, 1.0)
	shape.shape = box
	shape.position = Vector3.UP * 0.5
	body.add_child(shape)
	if ResourceLoader.exists(BARRIER_MODEL):
		var parts := RoadsideDresser._parts_of({"id": "barrier", "path": BARRIER_MODEL})
		for x: float in [-half * 0.55, half * 0.55]:
			for part in parts:
				var mesh := MeshInstance3D.new()
				mesh.mesh = part.mesh
				mesh.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.0, 0.0)) * (part.transform as Transform3D)
				if part.material != null:
					mesh.material_override = part.material
				body.add_child(mesh)
	body.add_child(_tape(span, TAPE_HEIGHT))
	body.add_child(_tape(span, TAPE_HEIGHT - 0.35))
	body.add_child(board("no_entry", Vector3(0.0, BOARD_HEIGHT, 0.2)))
	node.add_child(body)


## A strip of red and white marshal tape across `span` metres at `height`.
static func _tape(span: float, height: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Tape"
	var quad := QuadMesh.new()
	quad.size = Vector2(span, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture("tape")
	material.uv1_scale = Vector3(span / 0.6, 1.0, 1.0)
	quad.material = material
	mesh.mesh = quad
	mesh.position = Vector3.UP * height
	return mesh


## A sign on a post, its face toward the approach (+Z of the parent), its middle `at`.
static func board(kind: String, at: Vector3, size := 0.8) -> Node3D:
	var node := Node3D.new()
	node.name = "Board"
	node.position = at
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture(kind)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.6
	quad.material = material
	face.mesh = quad
	node.add_child(face)
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, at.y + 0.5, 0.07)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.3, 0.32)
	box.material = steel
	post.mesh = box
	post.position = Vector3(0.0, -(at.y + 0.5) * 0.5, -0.05)
	node.add_child(post)
	return node


## Generated sign textures, made once: "tape", "no_entry", "chevron", "caution".
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		_textures[kind] = ImageTexture.create_from_image(_draw(kind))
	return _textures[kind]


static func _draw(kind: String) -> Image:
	match kind:
		"tape":
			var image := Image.create(32, 4, false, Image.FORMAT_RGBA8)
			for y in 4:
				for x in 32:
					image.set_pixel(x, y, Color(0.8, 0.08, 0.06) if (x + y * 2) % 32 < 16 else Color(0.95, 0.95, 0.93))
			image.generate_mipmaps()
			return image
		"no_entry":
			return _sign(func(u: Vector2) -> Color:
				var d := u.length()
				if d > 1.0:
					return Color(0, 0, 0, 0)
				if d > 0.93 or (absf(u.y) < 0.2 and absf(u.x) < 0.68):
					return Color(0.95, 0.95, 0.93)
				return Color(0.75, 0.07, 0.06))
		"chevron":
			return _sign(func(u: Vector2) -> Color:
				var band := fposmod(u.x * 1.3 + absf(u.y) * 0.9, 1.0)
				return Color(0.97, 0.76, 0.1) if band < 0.5 else Color(0.08, 0.08, 0.08))
		"caution":
			return _sign(func(u: Vector2) -> Color:
				if u.y > 0.85 or absf(u.x) > 1.02 - (1.0 - u.y) * 0.5:
					return Color(0, 0, 0, 0)
				if u.y < 0.68 and absf(u.x) < 0.8 - (1.0 - u.y) * 0.45:
					var mark: bool = absf(u.x) < 0.09 and ((u.y > -0.3 and u.y < 0.28) or (u.y > 0.38 and u.y < 0.54))
					return Color(0.08, 0.08, 0.08) if mark else Color(0.97, 0.9, 0.3)
				return Color(0.75, 0.07, 0.06))
	return Image.create(2, 2, false, Image.FORMAT_RGBA8)


## A 96 x 96 sign from `paint`: its colour at u in -1..1 (y down).
static func _sign(paint: Callable) -> Image:
	const SIZE := 96
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, paint.call(Vector2(x + 0.5, y + 0.5) / (SIZE * 0.5) - Vector2.ONE))
	image.generate_mipmaps()
	return image
