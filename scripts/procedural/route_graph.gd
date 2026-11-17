class_name RouteGraph
extends RefCounted
## The road of one rally stage: a single point-to-point road from the start (node 0) to the
## finish, split into edges where its surface or width changes (polylines in the XZ plane, with a
## height per point), plus the stage's features (crests, jumps, dips, water, cliffs, banks) by
## distance along the road. StageBuilder makes it from a named stage, RouteValidator checks it,
## RoadBuilder turns it into geometry, and the paper map and pace notes read the same data, so the
## map always matches the world. Wrong ways (`spurs`: dead-end tracks and closed roads leaving the
## stage road) are kept apart from `edges`: everything that follows the stage ignores them, and only
## what builds the world reads road_edges(). Bypasses (`bypasses`: a shortcut or a long way that leaves
## the stage and joins it again ahead) are roads a crew may take instead of a stretch of the stage: they
## live on the stage's one coordinate, along_of() puts any point of one on the stretch it replaces, and
## followed_roads() gives the stage and every bypass to whatever follows a car (tracker, recovery).

const VERSION := 4
## Spur and bypass edge ids start here: they never index `edges`.
const SPUR_EDGE_BASE := 1000
const BYPASS_EDGE_BASE := 2000
## The stage's own road in along_of() and followed_roads(); a bypass is its id.
const STAGE := -1

enum NodeKind { START, FINISH, WAYPOINT }


class RouteNode:
	var id := 0
	var kind := NodeKind.WAYPOINT
	var position := Vector2.ZERO
	var height := 0.0
	var edge_ids: Array[int] = []


class RouteEdge:
	var id := 0
	var from_node := 0
	var to_node := 0
	## XZ polyline from from_node to to_node, evenly spaced.
	var points := PackedVector2Array()
	## Road height at each point (Y).
	var heights := PackedFloat32Array()
	var width := 4.4
	var surface := Surface.GRAVEL
	var length := 0.0
	## The road point just before this edge's first and just after its last (on the neighbouring
	## edges; INF at the stage's ends), so both edges use the same cross-section at a shared node.
	var before := Vector2.INF
	var after := Vector2.INF

	func direction_at(index: int) -> Vector2:
		var a := before if index == 0 and before.is_finite() else points[maxi(index - 1, 0)]
		var b := after if index == points.size() - 1 and after.is_finite() else points[mini(index + 1, points.size() - 1)]
		return (b - a).normalized()

	func point_3d(index: int) -> Vector3:
		return Vector3(points[index].x, heights[index], points[index].y)


## A road that leaves the stage road at a junction: a wrong way (Spur) or a bypass.
class SideRoad:
	var id := 0
	## Metres along the stage road of its junction, always a vertex of main_route_points().
	var at := 0.0
	## The side of the stage road it leaves on (-1 left, 1 right).
	var road_side := 1
	var edges: Array[RouteEdge] = []

	## The whole centreline.
	func points_3d() -> PackedVector3Array:
		var out := PackedVector3Array()
		for edge in edges:
			for i in edge.points.size():
				if i == 0 and not out.is_empty():
					continue
				out.append(edge.point_3d(i))
		return out

	## Metres from the junction of every points_3d() point.
	func distances() -> PackedFloat32Array:
		var points := points_3d()
		var out := PackedFloat32Array([0.0])
		for i in range(1, points.size()):
			out.append(out[i - 1] + Vector2(points[i].x, points[i].z).distance_to(Vector2(points[i - 1].x, points[i - 1].z)))
		return out

	## {"position": Vector3, "direction": Vector2 (XZ)} at `distance` metres from the junction.
	func pose_at(distance: float) -> Dictionary:
		var points := points_3d()
		var along := distances()
		var i := 0
		while i < along.size() - 2 and along[i + 1] < distance:
			i += 1
		var dir := Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).normalized()
		var t := clampf((distance - along[i]) / maxf(along[i + 1] - along[i], 0.001), 0.0, 1.0)
		return {"position": points[i].lerp(points[i + 1], t), "direction": dir}


## A wrong way off the stage road: a track that ends in a dead end with room to turn, or a closed
## road with a barrier across it (it carries on past the barrier, out of sight).
class Spur extends SideRoad:
	## Where the wrong way goes from the road: &"straight" | &"left" | &"right".
	var side := &"straight"
	var end := &"dead_end"
	## Junction -> dead end or barrier (m along the spur).
	var length := 0.0
	var barrier_at := -1.0
	## The turning area: centre (XZ), height, radius, and its distance along the spur.
	var landing := Vector2.ZERO
	var landing_height := 0.0
	var landing_radius := 0.0
	var landing_at := 0.0

	func side_sign() -> int:
		return 0 if side == &"straight" else (-1 if side == &"left" else 1)


## A road a crew may take instead of the stretch of the stage from its mouth (`at`) to its rejoin: a
## shortcut (clearly shorter, with a price) or a long way (longer and safe, round a hard piece of the
## stage). Points on it map linearly onto that stretch (along_of): the stage's one coordinate.
class Bypass extends SideRoad:
	## &"shortcut" | &"long".
	var kind := &"shortcut"
	## What the shortcut costs: &"ford" (water to wade), &"gate" (a farm gate across it), &"rough" (a rutted
	## track), &"narrow" (a lane between banks); &"" for a long way (its price is the distance).
	var price := &""
	## Metres along the stage where it joins the stage again (a vertex of main_route_points()).
	var rejoin := 0.0
	## The side of the stage road it joins from (-1 left, 1 right).
	var rejoin_side := 1
	## Its own length, mouth to rejoin.
	var length := 0.0
	## Where its price is, metres along it (the ford's middle, the gate).
	var price_at := 0.0
	## Its own features by metres along it, as RouteGraph.features (the ford's water).
	var features: Array[Dictionary] = []

	## The metres along the stage of the point `distance` metres along the bypass.
	func along_of(distance: float) -> float:
		return lerpf(at, rejoin, clampf(distance / maxf(length, 0.001), 0.0, 1.0))


class Gate:
	var index := 0
	var edge_id := 0
	var point_index := 0
	var position := Vector2.ZERO
	var direction := Vector2.ZERO
	## Metres from the start along the road.
	var distance := 0.0


var seed := 0
var stage_id := &""
var biome := &"forest"
var nodes: Array[RouteNode] = []
var edges: Array[RouteEdge] = []
## Edge ids from the start to the finish (every edge of the stage, in order).
var main_route: Array[int] = []
## Gate 0 is the start line, the last one the finish line; splits in between.
var checkpoints: Array[Gate] = []
## The wrong ways, in stage order (see Spur).
var spurs: Array[Spur] = []
## The bypasses, in stage order (see Bypass).
var bypasses: Array[Bypass] = []
## Features by distance along the road: {"kind": StringName, "from": m, "to": m, "at": m,
## "side": -1 left / 1 right / 0, "value": metres (height, depth or drop)}.
var features: Array[Dictionary] = []
## Middle of the stage's bounding box (XZ) and its half size.
var center := Vector2.ZERO
var half_extent := Vector2.ZERO

var _route_points := PackedVector3Array()
var _route_distances := PackedFloat32Array()
var _route_edges := PackedInt32Array()
var _route_indices := PackedInt32Array()
var _indexed_edges := -1
## edge id -> route index of the edge's first point.
var _edge_starts: Dictionary = {}


func add_node(kind: int, position: Vector2) -> RouteNode:
	var node := RouteNode.new()
	node.id = nodes.size()
	node.kind = kind
	node.position = position
	nodes.append(node)
	return node


func add_edge(from_node: int, to_node: int, points: PackedVector2Array, heights: PackedFloat32Array,
		width: float, surface: StringName) -> RouteEdge:
	var edge := RouteEdge.new()
	edge.id = edges.size()
	edge.from_node = from_node
	edge.to_node = to_node
	edge.points = points
	edge.heights = heights
	edge.width = width
	edge.surface = surface
	edge.length = polyline_length(points)
	edges.append(edge)
	nodes[from_node].edge_ids.append(edge.id)
	nodes[to_node].edge_ids.append(edge.id)
	return edge


## Every road there is, as a map prints it: {"kind" (&"stage", &"wrong_way", &"bypass"), "points" (its centreline, XZ), "width", "surface",
## "end" (&"through": it joins another road at both ends; &"dead_end": a log pile across it past its turning place; &"barrier": closed
## by a barrier), "end_at" (XZ) and "end_turn" (the way it runs there) for what closes it, "landing" and "landing_radius" where it has a
## turning place. The stage gives one per edge (a surface each), every wrong way one up to where a car can go, every bypass one
## (with "bypass", the Bypass, for its price).
func roads() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for edge_id in main_route:
		var edge := edges[edge_id]
		out.append({"kind": &"stage", "points": edge.points, "width": edge.width, "surface": edge.surface, "end": &"through"})
	for spur in spurs:
		var flat := spur.points_3d()
		var along := spur.distances()
		var reach := spur.length if spur.end == &"dead_end" else float(along[-1])
		var points := PackedVector2Array()
		for i in flat.size():
			if along[i] <= reach + 0.01:
				points.append(Vector2(flat[i].x, flat[i].z))
		var road := {"kind": &"wrong_way", "points": points, "width": spur.edges[0].width, "surface": spur.edges[0].surface, "end": spur.end}
		var closed := spur.pose_at(spur.barrier_at if spur.end == &"barrier" else spur.length)
		var turn: Vector2 = closed.direction
		road.end_turn = turn
		if spur.landing_radius > 0.0:
			road.landing = spur.landing
			road.landing_radius = spur.landing_radius
		if spur.end == &"barrier":
			road.end_at = Vector2(closed.position.x, closed.position.z)
		else:
			road.end_at = spur.landing + turn * (spur.landing_radius + 1.5)
		out.append(road)
	for bypass in bypasses:
		for edge in bypass.edges:
			out.append({"kind": &"bypass", "points": edge.points, "width": edge.width, "surface": edge.surface, "end": &"through", "bypass": bypass})
	return out


## Every road surface: the stage road's edges, then each spur's and each bypass's.
func road_edges() -> Array[RouteEdge]:
	var out: Array[RouteEdge] = []
	out.append_array(edges)
	for road in side_roads():
		out.append_array(road.edges)
	return out


## The wrong ways, then the bypasses.
func side_roads() -> Array[SideRoad]:
	var out: Array[SideRoad] = []
	out.append_array(spurs)
	out.append_array(bypasses)
	return out


## The edge with `id`, whichever road it is on.
func edge_by_id(id: int) -> RouteEdge:
	if id < SPUR_EDGE_BASE:
		return edges[id]
	var road: SideRoad = spurs[(id - SPUR_EDGE_BASE) / 10] if id < BYPASS_EDGE_BASE else bypasses[(id - BYPASS_EDGE_BASE) / 10]
	return road.edges[id % 10]


## Metres along the stage of the point `distance` metres along `road` (STAGE or a bypass's id): the one
## coordinate everything that follows a car thinks in (GAME_DESIGN, Direction 2, law 2).
func along_of(road: int, distance: float) -> float:
	return distance if road == STAGE else bypasses[road].along_of(distance)


## Every road a car may follow from the start to the finish: {"road": STAGE or a bypass's id, "points" (3D), "own" (metres
## along that road of each point), "along" (metres along the stage of each point, along_of), "from" and "to" (the stretch of
## the stage it covers)}. The stage first.
func followed_roads() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"road": STAGE, "points": main_route_points(), "own": route_distances(), "along": route_distances(),
		"from": 0.0, "to": main_route_length()}]
	for bypass in bypasses:
		var own := bypass.distances()
		var along := PackedFloat32Array()
		for d in own:
			along.append(bypass.along_of(d))
		out.append({"road": bypass.id, "points": bypass.points_3d(), "own": own, "along": along, "from": bypass.at, "to": bypass.rejoin})
	return out


## The whole way from the start to the finish taking the bypasses whose ids are in `taken`: the stage's points up to each
## one's mouth, the bypass, then the stage again past its rejoin.
func path_through(taken: Array[int]) -> PackedVector3Array:
	var points := main_route_points()
	var along := route_distances()
	var out := PackedVector3Array()
	var i := 0
	for bypass in bypasses:
		if not bypass.id in taken:
			continue
		while i < points.size() and along[i] < bypass.at - 0.01:
			out.append(points[i])
			i += 1
		out.append_array(bypass.points_3d())
		while i < points.size() and along[i] <= bypass.rejoin + 0.01:
			i += 1
	while i < points.size():
		out.append(points[i])
		i += 1
	return out


func main_route_length() -> float:
	var total := 0.0
	for edge_id in main_route:
		total += edges[edge_id].length
	return total


## The whole stage as one polyline (3D), start to finish.
func main_route_points() -> PackedVector3Array:
	_index_route()
	return _route_points


## Distance from the start of every main_route_points() point.
func route_distances() -> PackedFloat32Array:
	_index_route()
	return _route_distances


## {"position": Vector3, "direction": Vector2, "edge": id, "index": point index} at `distance`
## metres from the start (clamped to the road).
func sample(distance: float) -> Dictionary:
	_index_route()
	var i := route_index_at(distance)
	var edge := edges[_route_edges[i]]
	return {"position": _route_points[i], "direction": edge.direction_at(_route_indices[i]),
		"edge": edge.id, "index": _route_indices[i]}


## `sample` at exactly `distance`, between the road's points, for what stands along the road at a spacing of its own:
## `sample` stops at the points, 2 m apart.
func sample_exact(distance: float) -> Dictionary:
	var at := sample(distance)
	var i := route_index_at(distance)
	if i + 1 < _route_points.size():
		var t := clampf((distance - _route_distances[i]) / (_route_distances[i + 1] - _route_distances[i]), 0.0, 1.0)
		var next_direction := edges[_route_edges[i + 1]].direction_at(_route_indices[i + 1])
		at.position = _route_points[i].lerp(_route_points[i + 1], t)
		at.direction = (at.direction as Vector2).lerp(next_direction, t).normalized()
	return at


## Index into main_route_points() of the last point at or before `distance`.
func route_index_at(distance: float) -> int:
	_index_route()
	var lo := 0
	var hi := _route_distances.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if _route_distances[mid] <= distance:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Index into main_route_points() of point `index` of `edge_id`.
func route_index_of(edge_id: int, index: int) -> int:
	_index_route()
	return int(_edge_starts[edge_id]) + index


## Distance from the start of point `index` of `edge_id`.
func distance_of(edge_id: int, index: int) -> float:
	_index_route()
	for i in _route_edges.size():
		if _route_edges[i] == edge_id and _route_indices[i] >= index:
			return _route_distances[i]
	return _route_distances[-1] if not _route_distances.is_empty() else 0.0


## Where the race starts: a point on the road and the direction of travel.
func start_pose(distance_along := 12.0) -> Transform3D:
	return _pose_at(distance_along)


## Just past the finish line, facing on.
func finish_pose() -> Transform3D:
	return _pose_at(checkpoints[-1].distance + 15.0 if not checkpoints.is_empty() else main_route_length())


func _pose_at(distance: float) -> Transform3D:
	if edges.is_empty():
		return Transform3D.IDENTITY
	var spot := sample(distance)
	var dir: Vector2 = spot.direction
	return Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), spot.position)


## Features of `kind` (all when empty), in stage order.
func features_of(kind: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for feature in features:
		if kind == &"" or feature.kind == kind:
			out.append(feature)
	return out


## Stable text form, for determinism tests.
func to_dict() -> Dictionary:
	var node_list := []
	for node in nodes:
		node_list.append({"id": node.id, "kind": node.kind, "x": node.position.x, "z": node.position.y, "h": node.height})
	var edge_list := []
	for edge in edges:
		edge_list.append({"id": edge.id, "from": edge.from_node, "to": edge.to_node,
			"width": edge.width, "surface": String(edge.surface), "points": edge.points, "heights": edge.heights})
	var checkpoint_list := []
	for checkpoint in checkpoints:
		checkpoint_list.append({"index": checkpoint.index, "edge": checkpoint.edge_id, "point": checkpoint.point_index})
	var spur_list := []
	for spur in spurs:
		var spur_edges := []
		for edge in spur.edges:
			spur_edges.append({"id": edge.id, "width": edge.width, "surface": String(edge.surface), "points": edge.points, "heights": edge.heights})
		spur_list.append({"id": spur.id, "at": spur.at, "side": String(spur.side), "end": String(spur.end), "length": spur.length,
			"barrier_at": spur.barrier_at, "landing": [spur.landing, spur.landing_height, spur.landing_radius], "edges": spur_edges})
	var bypass_list := []
	for bypass in bypasses:
		var edge := bypass.edges[0]
		bypass_list.append({"id": bypass.id, "kind": String(bypass.kind), "price": String(bypass.price), "at": bypass.at, "rejoin": bypass.rejoin,
			"price_at": bypass.price_at, "width": edge.width, "surface": String(edge.surface), "points": edge.points, "heights": edge.heights,
			"features": bypass.features})
	return {"version": VERSION, "seed": seed, "stage": String(stage_id), "biome": String(biome), "center": center,
		"nodes": node_list, "edges": edge_list, "main_route": main_route, "checkpoints": checkpoint_list,
		"features": features, "spurs": spur_list, "bypasses": bypass_list}


func _index_route() -> void:
	if _indexed_edges == main_route.size():
		return
	_indexed_edges = main_route.size()
	_route_points = PackedVector3Array()
	_route_distances = PackedFloat32Array()
	_route_edges = PackedInt32Array()
	_route_indices = PackedInt32Array()
	_edge_starts = {}
	var total := 0.0
	for edge_id in main_route:
		var edge := edges[edge_id]
		_edge_starts[edge_id] = maxi(_route_points.size() - 1, 0)
		for i in edge.points.size():
			if i == 0 and not _route_points.is_empty():
				continue
			var p := edge.point_3d(i)
			if not _route_points.is_empty():
				total += Vector2(p.x, p.z).distance_to(Vector2(_route_points[-1].x, _route_points[-1].z))
			_route_points.append(p)
			_route_distances.append(total)
			_route_edges.append(edge.id)
			_route_indices.append(i)


static func polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## The width of the narrowest road of the stage (m).
func narrowest_width() -> float:
	var narrowest := INF
	for edge in edges:
		narrowest = minf(narrowest, edge.width)
	return narrowest if narrowest != INF else 0.0
