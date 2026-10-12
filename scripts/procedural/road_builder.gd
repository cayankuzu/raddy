class_name RoadBuilder
## Turns a RouteGraph into drivable geometry: a height-map terrain flattened under the roads,
## one road ribbon (with verges) per edge, a pad at every junction, and checkpoint gates.
## Visual assets (trees, rocks, signs) are added on top in the art phase; this is the blocking.
## Winding: a face that points up (seen by cameras above it, hit by wheel rays) goes
## origin -> +X -> +Z; trimesh collision is one-sided, so every face here keeps that order.

const CELL := 4.0
const MARGIN := 140.0
const VERGE := 2.5
const ROAD_LIFT := 0.02
const PAD_LIFT := 0.03
## Ribbons stop this far from a junction; the pad polygon fills the gap.
const SETBACK := 7.5
const GATE_HEIGHT := 6.0

const SURFACE_COLORS := {
	Surface.GRAVEL: Color("8d8273"),
	Surface.DIRT: Color("7b5b3d"),
	Surface.MUD: Color("4b3b2b"),
	Surface.WET: Color("5a5550"),
	Surface.SAND: Color("c9b17b"),
	Surface.SNOW: Color("e4eaee"),
	Surface.TARMAC: Color("4a4a4c"),
}
const VERGE_COLOR := Color("5c6b3c")
const GROUND_COLOR := Color("4f6136")

static var _palette: Dictionary = {}


## Builds the whole track under one node. `terrain` must be the field for graph.seed.
## `palette` (optional, from BiomeRules.palette) colours the ground and verges for the biome.
static func build(graph: RouteGraph, terrain: TerrainField, palette := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Track"
	_palette = palette
	root.add_child(_build_terrain(graph, terrain))
	var roads := Node3D.new()
	roads.name = "Roads"
	root.add_child(roads)
	for edge in graph.edges:
		roads.add_child(_build_road(graph, edge))
	var pads := Node3D.new()
	pads.name = "Junctions"
	root.add_child(pads)
	for node in graph.nodes:
		if node.kind == RouteGraph.NodeKind.JUNCTION:
			pads.add_child(_build_pad(graph, node))
	var gates := Node3D.new()
	gates.name = "Checkpoints"
	root.add_child(gates)
	for checkpoint in graph.checkpoints:
		gates.add_child(_build_gate(graph, checkpoint))
	return root


static func _material(color: Color, roughness := 0.95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


# --- terrain ---

static func _build_terrain(graph: RouteGraph, terrain: TerrainField) -> StaticBody3D:
	var extent := 0.0
	for edge in graph.edges:
		for p in edge.points:
			extent = maxf(extent, (p - graph.center).length())
	var half := extent + MARGIN
	var cells := int(ceil(half * 2.0 / CELL))
	var width := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(width * width)
	var origin := graph.center - Vector2(half, half)
	for z in width:
		for x in width:
			heights[z * width + x] = terrain.height(origin + Vector2(x, z) * CELL)

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.set_meta(&"surface", Surface.DIRT)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = width
	height_shape.map_depth = width
	height_shape.map_data = heights
	shape.shape = height_shape
	# HeightMapShape3D is centred and 1 unit per cell: scale and place it over the grid.
	shape.scale = Vector3(CELL, 1.0, CELL)
	shape.position = Vector3(graph.center.x, 0.0, graph.center.y)
	body.add_child(shape)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_material(_palette.get("ground", GROUND_COLOR)))
	for z in width:
		for x in width:
			var h := heights[z * width + x]
			var hx0 := heights[z * width + maxi(x - 1, 0)]
			var hx1 := heights[z * width + mini(x + 1, width - 1)]
			var hz0 := heights[maxi(z - 1, 0) * width + x]
			var hz1 := heights[mini(z + 1, width - 1) * width + x]
			surface.set_normal(Vector3(hx0 - hx1, 2.0 * CELL, hz0 - hz1).normalized())
			surface.set_uv(Vector2(x, z) * 0.25)
			surface.add_vertex(Vector3(origin.x + x * CELL, h, origin.y + z * CELL))
	for z in cells:
		for x in cells:
			var i := z * width + x
			surface.add_index(i)
			surface.add_index(i + 1)
			surface.add_index(i + width)
			surface.add_index(i + 1)
			surface.add_index(i + width + 1)
			surface.add_index(i + width)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = surface.commit()
	body.add_child(mesh)
	return body


# --- roads ---

static func _build_road(graph: RouteGraph, edge: RouteGraph.RouteEdge) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Road%d" % edge.id
	body.set_meta(&"surface", edge.surface)
	body.set_meta(&"edge_id", edge.id)
	var first := ribbon_start(graph, edge)
	var last := ribbon_end(graph, edge)
	var road := _ribbon(edge, first, last, -edge.width * 0.5, edge.width * 0.5, ROAD_LIFT, ROAD_LIFT,
		_material(SURFACE_COLORS.get(edge.surface, SURFACE_COLORS[Surface.GRAVEL])))
	var verge_left := _ribbon(edge, first, last, -edge.width * 0.5 - VERGE, -edge.width * 0.5, -TerrainField.TRENCH, ROAD_LIFT, _material(_palette.get("verge", VERGE_COLOR)))
	var verge_right := _ribbon(edge, first, last, edge.width * 0.5, edge.width * 0.5 + VERGE, ROAD_LIFT, -TerrainField.TRENCH, _material(_palette.get("verge", VERGE_COLOR)))
	for mesh in [road, verge_left, verge_right]:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		body.add_child(instance)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
	return body


## First polyline index whose arc length from the start node exceeds the junction setback.
static func ribbon_start(graph: RouteGraph, edge: RouteGraph.RouteEdge) -> int:
	if graph.nodes[edge.from_node].kind != RouteGraph.NodeKind.JUNCTION:
		return 0  # the start line and dead ends: the ribbons simply meet
	var travelled := 0.0
	for i in range(1, edge.points.size() - 1):
		travelled += edge.points[i].distance_to(edge.points[i - 1])
		if travelled >= SETBACK:
			return i
	return 0


static func ribbon_end(graph: RouteGraph, edge: RouteGraph.RouteEdge) -> int:
	var last := edge.points.size() - 1
	if graph.nodes[edge.to_node].kind != RouteGraph.NodeKind.JUNCTION:
		return last
	var travelled := 0.0
	for i in range(last - 1, 0, -1):
		travelled += edge.points[i].distance_to(edge.points[i + 1])
		if travelled >= SETBACK:
			return i
	return last


## A strip between two lateral offsets of the edge, from polyline index `first` to `last`,
## as a triangle list (collision shapes are built from the same mesh).
static func _ribbon(edge: RouteGraph.RouteEdge, first: int, last: int, left_offset: float, right_offset: float,
		left_lift: float, right_lift: float, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var along := 0.0
	for i in range(first, last + 1):
		if i > first:
			along += edge.points[i].distance_to(edge.points[i - 1])
		var dir := edge.direction_at(i)
		var right := Vector3(-dir.y, 0.0, dir.x)
		var center := edge.point_3d(i)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(0.0, along * 0.1))
		surface.add_vertex(center + right * left_offset + Vector3.UP * left_lift)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(1.0, along * 0.1))
		surface.add_vertex(center + right * right_offset + Vector3.UP * right_lift)
	for section in range(last - first):
		var l0 := section * 2
		var r0 := l0 + 1
		var l1 := l0 + 2
		var r1 := l0 + 3
		surface.add_index(l0)
		surface.add_index(l1)
		surface.add_index(r0)
		surface.add_index(r0)
		surface.add_index(l1)
		surface.add_index(r1)
	return surface.commit()


# --- junction pads ---

## A pad joining the ribbon ends that meet at `node`: a fan from the node centre over the end
## cross-sections, sorted by angle so the polygon never folds.
static func _build_pad(graph: RouteGraph, node: RouteGraph.RouteNode) -> StaticBody3D:
	var corners: Array[Vector3] = []
	var widest := 0.0
	var pad_surface := Surface.GRAVEL
	for edge_id in node.edge_ids:
		var edge := graph.edges[edge_id]
		widest = maxf(widest, edge.width)
		if edge.kind == RouteGraph.EdgeKind.MAIN:
			pad_surface = edge.surface
		var index := ribbon_start(graph, edge) if edge.from_node == node.id else ribbon_end(graph, edge)
		var dir := edge.direction_at(index)
		var right := Vector3(-dir.y, 0.0, dir.x)
		var center := edge.point_3d(index)
		var half := edge.width * 0.5 + VERGE
		corners.append(center - right * half)
		corners.append(center + right * half)
	var middle := Vector3(node.position.x, node.height, node.position.y)
	corners.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2(a.z - middle.z, a.x - middle.x) < atan2(b.z - middle.z, b.x - middle.x))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_material(SURFACE_COLORS.get(pad_surface, SURFACE_COLORS[Surface.GRAVEL])))
	for i in corners.size():
		var a := corners[i] + Vector3.UP * PAD_LIFT
		var b := corners[(i + 1) % corners.size()] + Vector3.UP * PAD_LIFT
		surface.set_normal(Vector3.UP)
		surface.add_vertex(middle + Vector3.UP * PAD_LIFT)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(a)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(b)
	var mesh := surface.commit()
	var body := StaticBody3D.new()
	body.name = "Pad%d" % node.id
	body.set_meta(&"surface", pad_surface)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	return body


# --- checkpoints ---

static func _build_gate(graph: RouteGraph, checkpoint: RouteGraph.Gate) -> Checkpoint:
	var edge := graph.edges[checkpoint.edge_id]
	var gate := Checkpoint.new()
	gate.name = "Checkpoint%d" % checkpoint.index
	gate.index = checkpoint.index
	var dir := checkpoint.direction
	var center := Vector3(checkpoint.position.x, edge.heights[checkpoint.point_index], checkpoint.position.y)
	gate.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), center)
	var span := edge.width + VERGE * 2.0 + 4.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span, GATE_HEIGHT, 3.0)
	shape.shape = box
	shape.position = Vector3(0.0, GATE_HEIGHT * 0.5, 0.0)
	gate.add_child(shape)
	# Two posts so the gate reads from the road; the art pass dresses them.
	var color := Color("f1ece2") if checkpoint.index == 0 else Color("ffd23f")
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.3, 3.5, 0.3)
		post_mesh.material = _material(color, 0.6)
		post.mesh = post_mesh
		post.position = Vector3(side * (edge.width * 0.5 + VERGE + 0.5), 1.75, 0.0)
		gate.add_child(post)
	return gate
