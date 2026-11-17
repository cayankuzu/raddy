class_name RoadBuilder
## Turns a stage's RouteGraph into drivable geometry: a height-map terrain (TerrainField's grid) lying
## under the road, one road ribbon with its shoulders and ditches per edge, the start/split/finish
## gates, and the stage furniture from TrackFeatures (water splashes, barriers on cliff edges, the invisible walls that
## keep cars inside the stage). Surfaces use the CC0 PBR texture sets through SurfaceMaterials
## (terrain, road and verge shaders); roadside props are placed by RoadsideDresser.
## Winding: a face that points up (seen by cameras above it, hit by wheel rays) goes
## origin -> +X -> +Z; trimesh collision is one-sided, so every face here keeps that order.

## The road's cross-section beyond its edge (metres from the edge; TerrainField.cross_section):
## a drivable gravel shoulder, a V ditch (bottom from DITCH_IN to DITCH_OUT), a lip, and a gentle
## bank down to the ground at ROADSIDE (gentle: a car in the trees can drive back up onto the road).
## Heights: SHOULDER_DROP at the shoulder's edge, DITCH_DEPTH at the bottom and LIP_DROP at the lip,
## all below the road. POST_OFFSET: where anything standing beside the road starts (just past the lip).
const SHOULDER := 0.8
const DITCH_IN := 1.3
const DITCH_OUT := 1.6
const DITCH_END := 2.1
const ROADSIDE := 4.6
const POST_OFFSET := 2.6
const SHOULDER_DROP := 0.05
const DITCH_DEPTH := 0.4
const LIP_DROP := 0.15
## The road's ends slope down to the ground over this many metres.
const APRON := 2.0
const ROAD_LIFT := 0.02
const GATE_HEIGHT := 14.0
## Wrong ways lie just under the stage road where they meet it, and the mouth's filler under both.
const SPUR_LIFT := 0.008
const MOUTH_LIFT := 0.004
## The junction's filler reaches this far past the road's edge, then falls away into the ditch.
const MOUTH_REACH := 3.0
const MOUTH_SKIRT := 0.7
const DISC_SEGMENTS := 24

static var _palette: Dictionary = {}
static var _biome := 0
static var _weather := 0


## Builds the whole track under one node. `terrain` must be the field set up for this graph.
## `palette` (optional, from BiomeRules.palette) picks the biome's ground and verges.
static func build(graph: RouteGraph, terrain: TerrainField, palette := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Track"
	_palette = palette
	_biome = int(palette.get("biome", RaceSettings.Biome.FOREST))
	_weather = int(palette.get("weather", RaceSettings.Weather.CLEAR))
	root.add_child(_build_terrain(graph, terrain))
	var roads := Node3D.new()
	roads.name = "Roads"
	root.add_child(roads)
	for edge in graph.edges:
		roads.add_child(_build_road(edge, terrain))
	if not graph.main_route.is_empty():
		_add_apron(roads.get_node("Road%d" % graph.main_route[0]), graph.edges[graph.main_route[0]], false)
		_add_apron(roads.get_node("Road%d" % graph.main_route[-1]), graph.edges[graph.main_route[-1]], true)
	var spurs := Node3D.new()
	spurs.name = "Spurs"
	root.add_child(spurs)
	for spur in graph.spurs:
		spurs.add_child(_build_spur(graph, spur, terrain))
	var bypasses := Node3D.new()
	bypasses.name = "Bypasses"
	root.add_child(bypasses)
	for bypass in graph.bypasses:
		var node := Node3D.new()
		node.name = "Bypass%d" % bypass.id
		node.set_meta(&"bypass_id", bypass.id)
		node.add_child(_build_road(bypass.edges[0], terrain, SPUR_LIFT))
		for at in [bypass.at, bypass.rejoin]:
			var mouth := _build_mouth(graph, at, terrain)
			mouth.name = "Mouth" if at == bypass.at else "Rejoin"
			node.add_child(mouth)
		bypasses.add_child(node)
	var gates := Node3D.new()
	gates.name = "Checkpoints"
	root.add_child(gates)
	var index := RouteIndex.new(graph)
	for checkpoint in graph.checkpoints:
		gates.add_child(_build_gate(graph, checkpoint, index))
	root.add_child(TrackFeatures.build(graph, terrain, _biome))
	return root


# --- terrain ---

static func _build_terrain(graph: RouteGraph, terrain: TerrainField) -> StaticBody3D:
	# A rectangle over the stage plus a margin; HeightMapShape3D wants odd-free whole cells.
	var grid := terrain.grid()
	var cells: Vector2i = grid.cells
	var width := cells.x + 1
	var depth := cells.y + 1
	var heights: PackedFloat32Array = grid.heights
	var origin: Vector2 = grid.origin
	const CELL := TerrainField.CELL

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.set_meta(&"surface", Surface.DIRT)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = width
	height_shape.map_depth = depth
	height_shape.map_data = heights
	shape.shape = height_shape
	# HeightMapShape3D is centred and 1 unit per cell: scale and place it over the grid.
	shape.scale = Vector3(CELL, 1.0, CELL)
	shape.position = Vector3(origin.x + cells.x * CELL * 0.5, 0.0, origin.y + cells.y * CELL * 0.5)
	body.add_child(shape)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(SurfaceMaterials.terrain(_biome))
	for z in depth:
		for x in width:
			var h := heights[z * width + x]
			var hx0 := heights[z * width + maxi(x - 1, 0)]
			var hx1 := heights[z * width + mini(x + 1, width - 1)]
			var hz0 := heights[maxi(z - 1, 0) * width + x]
			var hz1 := heights[mini(z + 1, depth - 1) * width + x]
			surface.set_normal(Vector3(hx0 - hx1, 2.0 * CELL, hz0 - hz1).normalized())
			surface.set_uv(Vector2(x, z) * 0.25)
			surface.add_vertex(Vector3(origin.x + x * CELL, h, origin.y + z * CELL))
	for z in cells.y:
		for x in cells.x:
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

## One wrong way: its road, the turning area, and the filler in the junction's corners.
static func _build_spur(graph: RouteGraph, spur: RouteGraph.Spur, terrain: TerrainField) -> Node3D:
	var node := Node3D.new()
	node.name = "Spur%d" % spur.id
	node.set_meta(&"spur_id", spur.id)
	for edge in spur.edges:
		node.add_child(_build_road(edge, terrain, SPUR_LIFT))
	node.add_child(_build_landing(spur))
	node.add_child(_build_mouth(graph, spur.at, terrain))
	if spur.end == &"barrier":
		var last := spur.edges[-1]
		_add_apron(node.get_node("Road%d" % last.id), last, true)
	return node


## The turning area at a track's end: a disc of road, its side the road's own profile (no ditch).
static func _build_landing(spur: RouteGraph.Spur) -> StaticBody3D:
	var edge := spur.edges[-1]
	var body := StaticBody3D.new()
	body.name = "Landing"
	body.set_meta(&"surface", edge.surface)
	var r := spur.landing_radius
	var center := Vector3(spur.landing.x, spur.landing_height, spur.landing.y)
	var disc := SurfaceTool.new()
	disc.begin(Mesh.PRIMITIVE_TRIANGLES)
	disc.set_material(SurfaceMaterials.road(edge.surface))
	disc.set_normal(Vector3.UP)
	disc.set_uv(Vector2.ZERO)
	disc.set_uv2(Vector2(r, 0.0))
	disc.add_vertex(center + Vector3.UP * SPUR_LIFT)
	for k in DISC_SEGMENTS + 1:
		var a := TAU * k / DISC_SEGMENTS
		var offset := Vector3(cos(a), 0.0, sin(a)) * r
		disc.set_normal(Vector3.UP)
		disc.set_uv(Vector2(offset.x, offset.z))
		disc.set_uv2(Vector2(r, 0.0))
		disc.add_vertex(center + offset + Vector3.UP * SPUR_LIFT)
	for k in DISC_SEGMENTS:
		disc.add_index(0)
		disc.add_index(k + 1)
		disc.add_index(k + 2)
	disc.generate_tangents()
	_add_surface(body, disc.commit())
	# The side: rings at the road's profile columns.
	var columns := PackedFloat32Array([0.0, SHOULDER, DITCH_END, ROADSIDE])
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	ring.set_material(SurfaceMaterials.verge(edge.surface, _biome))
	for k in DISC_SEGMENTS + 1:
		var a := TAU * k / DISC_SEGMENTS
		var out := Vector3(cos(a), 0.0, sin(a))
		for e in columns:
			ring.set_normal(Vector3.UP)
			ring.set_uv(Vector2(e, a * r))
			ring.set_uv2(Vector2(r, 0.0))
			ring.add_vertex(center + out * (r + e) + Vector3.UP * TerrainField.cross_section(e, 0.0))
	var stride := columns.size()
	for k in DISC_SEGMENTS:
		for c in stride - 1:
			var inner0 := k * stride + c
			var inner1 := inner0 + stride
			ring.add_index(inner0)
			ring.add_index(inner0 + 1)
			ring.add_index(inner1)
			ring.add_index(inner1)
			ring.add_index(inner0 + 1)
			ring.add_index(inner1 + 1)
	ring.generate_tangents()
	_add_surface(body, ring.commit())
	return body


## Fills the corners where a side road leaves the stage road `at` metres along it: a low disc at road level, under
## both ribbons, its rim falling away into the ditches.
static func _build_mouth(graph: RouteGraph, at: float, terrain: TerrainField) -> StaticBody3D:
	var spot := graph.sample(at)
	var edge := graph.edges[spot.edge]
	var body := StaticBody3D.new()
	body.name = "Mouth"
	body.set_meta(&"surface", edge.surface)
	var center: Vector3 = spot.position
	var r := edge.width * 0.5 + MOUTH_REACH
	var radii := PackedFloat32Array([0.0, r * 0.5, r, r + MOUTH_SKIRT])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(SurfaceMaterials.road(edge.surface))
	for k in DISC_SEGMENTS + 1:
		var a := TAU * k / DISC_SEGMENTS
		var out := Vector3(cos(a), 0.0, sin(a))
		for n in radii.size():
			var p := center + out * radii[n]
			var y := terrain.road_height_near(Vector2(p.x, p.z)) + MOUTH_LIFT
			if n == radii.size() - 1:
				y -= DITCH_DEPTH + SHOULDER_DROP
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(p.x - center.x, p.z - center.z))
			surface.set_uv2(Vector2(r, 0.0))
			surface.add_vertex(Vector3(p.x, y, p.z))
	var stride := radii.size()
	for k in DISC_SEGMENTS:
		for n in stride - 1:
			var a0 := k * stride + n
			var a1 := a0 + stride
			surface.add_index(a0)
			surface.add_index(a0 + 1)
			surface.add_index(a1)
			surface.add_index(a1)
			surface.add_index(a0 + 1)
			surface.add_index(a1 + 1)
	surface.generate_tangents()
	_add_surface(body, surface.commit())
	return body


static func _build_road(edge: RouteGraph.RouteEdge, terrain: TerrainField, lift := ROAD_LIFT) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Road%d" % edge.id
	body.set_meta(&"surface", edge.surface)
	body.set_meta(&"edge_id", edge.id)
	var first := 0
	var last := edge.points.size() - 1
	var half := edge.width * 0.5
	var road := _ribbon(edge, first, last, -half, half, lift, lift,
		SurfaceMaterials.road(edge.surface), -half, half, true)
	# The shoulder is part of the road (its surface, drivable); the ditch is ground of its own.
	var verge_material := SurfaceMaterials.verge(edge.surface, _biome)
	var shoulder_columns := PackedFloat32Array([0.0, SHOULDER])
	for mesh in [road, _side_strip(edge, terrain, -1.0, shoulder_columns, verge_material), _side_strip(edge, terrain, 1.0, shoulder_columns, verge_material)]:
		_add_surface(body, mesh)
	var ditch := StaticBody3D.new()
	ditch.name = "Ditch"
	ditch.set_meta(&"surface", BiomeRules.surface_for(Surface.DIRT, _weather))
	var ditch_columns := PackedFloat32Array([SHOULDER, DITCH_IN, DITCH_OUT, DITCH_END, ROADSIDE])
	for side in [-1.0, 1.0]:
		_add_surface(ditch, _side_strip(edge, terrain, side, ditch_columns, verge_material))
	body.add_child(ditch)
	return body


static func _add_surface(body: StaticBody3D, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)


## A strip along the road on `side` (-1 left, 1 right) following the cross-section across `columns`
## (metres from the road edge). UV = (metres from the road edge, metres along the road), UV2 = (half
## the road's width, the side): shaders/verge.gdshader carries the road's surface on from there.
static func _side_strip(edge: RouteGraph.RouteEdge, terrain: TerrainField, side: float, columns: PackedFloat32Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var half := edge.width * 0.5
	var along := 0.0
	var count := edge.points.size()
	var uv2 := Vector2(half, side)
	for i in count:
		if i > 0:
			along += edge.points[i].distance_to(edge.points[i - 1])
		var dir := edge.direction_at(i)
		var right := Vector3(-dir.y, 0.0, dir.x)
		var center := edge.point_3d(i)
		var ahead := edge.point_3d(mini(i + 1, count - 1)) - edge.point_3d(maxi(i - 1, 0))
		var d := terrain.ditch_at(edge.id, i, side)
		var foot := terrain.foot_at(edge.id, i)
		for c in columns.size():
			var e := columns[c]
			# The normal from the slope of the profile across and the road's grade along.
			var inner := columns[maxi(c - 1, 0)]
			var outer := columns[mini(c + 1, columns.size() - 1)]
			var across := right * side * (outer - inner) + Vector3.UP * (TerrainField.cross_section(outer, d, foot) - TerrainField.cross_section(inner, d, foot))
			var normal := across.cross(ahead).normalized() if ahead.length_squared() > 0.0001 else Vector3.UP
			if normal.y < 0.0:
				normal = -normal
			surface.set_normal(normal)
			surface.set_uv(Vector2(e, along))
			surface.set_uv2(uv2)
			surface.add_vertex(center + right * side * (half + e) + Vector3.UP * TerrainField.cross_section(e, d, foot))
	var stride := columns.size()
	for section in count - 1:
		for c in stride - 1:
			var inner0 := section * stride + c
			var outer0 := inner0 + 1
			var inner1 := inner0 + stride
			var outer1 := inner1 + 1
			# Origin -> +X -> +Z, seen from above: on the right side outer is the road's right.
			var l0 := inner0 if side > 0.0 else outer0
			var r0 := outer0 if side > 0.0 else inner0
			var l1 := inner1 if side > 0.0 else outer1
			var r1 := outer1 if side > 0.0 else inner1
			surface.add_index(l0)
			surface.add_index(l1)
			surface.add_index(r0)
			surface.add_index(r0)
			surface.add_index(l1)
			surface.add_index(r1)
	surface.generate_tangents()
	return surface.commit()


## Closes one end of the stage road: its last cross-section slopes down to the ground over APRON m
## (the road's end is not a wall of air). `at_end` = the finish side, otherwise the start side.
static func _add_apron(road: StaticBody3D, edge: RouteGraph.RouteEdge, at_end: bool) -> void:
	var i := edge.points.size() - 1 if at_end else 0
	var center := edge.point_3d(i)
	var dir := edge.direction_at(i)
	var out := dir if at_end else -dir
	var right := Vector3(-dir.y, 0.0, dir.x)
	var half := edge.width * 0.5
	var laterals := PackedFloat32Array([-half - ROADSIDE, -half - DITCH_END, -half - SHOULDER, -half, half, half + SHOULDER, half + DITCH_END, half + ROADSIDE])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(SurfaceMaterials.verge(edge.surface, _biome))
	for row in 2:
		for l in laterals:
			var e := absf(l) - half
			var y := TerrainField.cross_section(e, 0.0) if row == 0 else -TerrainField.FLOOR_DROP - 0.1
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(maxf(e, 0.0), row * APRON))
			surface.set_uv2(Vector2(half, 0.0))
			surface.add_vertex(center + right * l + Vector3(out.x, 0.0, out.y) * row * APRON + Vector3.UP * y)
	var stride := laterals.size()
	for c in stride - 1:
		# Rows run outward: toward +dir at the finish end (same winding as the road), -dir at the start.
		var a := c if at_end else c + stride
		var b := c + stride if at_end else c
		surface.add_index(a)
		surface.add_index(b)
		surface.add_index(a + 1)
		surface.add_index(a + 1)
		surface.add_index(b)
		surface.add_index(b + 1)
	surface.generate_tangents()
	var ditch := road.get_node(^"Ditch") as StaticBody3D
	_add_surface(ditch, surface.commit())


## A strip between two lateral offsets of the edge, from polyline index `first` to `last`,
## as a triangle list (collision shapes are built from the same mesh). UV is in metres:
## x = `u_left`..`u_right` across, y = distance along; UV2 = (half road width, ruts on/off).
static func _ribbon(edge: RouteGraph.RouteEdge, first: int, last: int, left_offset: float, right_offset: float,
		left_lift: float, right_lift: float, material: Material, u_left := 0.0, u_right := 1.0, ruts := false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var along := 0.0
	var uv2 := Vector2(edge.width * 0.5, 1.0 if ruts else 0.0)
	for i in range(first, last + 1):
		if i > first:
			along += edge.points[i].distance_to(edge.points[i - 1])
		var dir := edge.direction_at(i)
		var right := Vector3(-dir.y, 0.0, dir.x)
		var center := edge.point_3d(i)
		# The normal tilts with the grade (the road is level across its width).
		var ahead := edge.point_3d(mini(i + 1, edge.points.size() - 1)) - edge.point_3d(maxi(i - 1, 0))
		var normal := ahead.cross(right).normalized() if ahead.length_squared() > 0.0001 else Vector3.UP
		if normal.y < 0.0:
			normal = -normal
		surface.set_normal(normal)
		surface.set_uv(Vector2(u_left, along))
		surface.set_uv2(uv2)
		surface.add_vertex(center + right * left_offset + Vector3.UP * left_lift)
		surface.set_normal(normal)
		surface.set_uv(Vector2(u_right, along))
		surface.set_uv2(uv2)
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
	surface.generate_tangents()
	return surface.commit()


# --- checkpoints ---

## A gate is as wide as the stage (a car off the road still crosses it) but stops where another
## part of the road is nearer, so no gate can be crossed from an earlier or later stretch.
static func _build_gate(graph: RouteGraph, checkpoint: RouteGraph.Gate, index: RouteIndex) -> Checkpoint:
	var edge := graph.edges[checkpoint.edge_id]
	var gate := Checkpoint.new()
	gate.name = "Checkpoint%d" % checkpoint.index
	gate.index = checkpoint.index
	var dir := checkpoint.direction
	var center := Vector3(checkpoint.position.x, edge.heights[checkpoint.point_index], checkpoint.position.y)
	gate.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), center)
	var right := Vector2(-dir.y, dir.x)
	var reach := [0.0, 0.0]
	for s in 2:
		var lateral := 2.0
		while lateral <= TrackFeatures.CORRIDOR + 2.0:
			var near := index.nearest(checkpoint.position + right * lateral * (1.0 if s == 1 else -1.0))
			if absf(float(near.along) - checkpoint.distance) > 40.0:
				break
			reach[s] = lateral
			lateral += 2.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(reach[0] + reach[1] + 2.0, GATE_HEIGHT, 3.0)
	shape.shape = box
	shape.position = Vector3((reach[1] - reach[0]) * 0.5, GATE_HEIGHT * 0.5 - 2.0, 0.0)
	gate.add_child(shape)
	return gate
