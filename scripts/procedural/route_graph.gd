class_name RouteGraph
extends RefCounted
## The road of one rally stage: a single point-to-point road from the start (node 0) to the
## finish, split into edges where its surface or width changes (polylines in the XZ plane, with a
## height per point), plus the stage's features (crests, jumps, dips, water, cliffs, banks) by
## distance along the road. StageBuilder makes it from a named stage, RouteValidator checks it,
## RoadBuilder turns it into geometry, and the paper map and pace notes read the same data, so the
## map always matches the world.

const VERSION := 2

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
	var width := 7.0
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
	return {"version": VERSION, "seed": seed, "stage": String(stage_id), "biome": String(biome), "center": center,
		"nodes": node_list, "edges": edge_list, "main_route": main_route, "checkpoints": checkpoint_list,
		"features": features}


func _index_route() -> void:
	if _indexed_edges == main_route.size():
		return
	_indexed_edges = main_route.size()
	_route_points = PackedVector3Array()
	_route_distances = PackedFloat32Array()
	_route_edges = PackedInt32Array()
	_route_indices = PackedInt32Array()
	var total := 0.0
	for edge_id in main_route:
		var edge := edges[edge_id]
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
