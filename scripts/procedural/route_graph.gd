class_name RouteGraph
extends RefCounted
## The road network of one race: nodes (start/finish, junctions, dead ends) joined by edges
## (road segments as polylines in the XZ plane, with a height per point). RouteGenerator builds it
## from a seed, RouteValidator checks it, RoadBuilder turns it into geometry and the paper map and
## pace notes (P2) read the same data, so the map always matches the world.

const VERSION := 1

enum NodeKind { START, JUNCTION, DEAD_END }
enum EdgeKind { MAIN, SHORTCUT, DETOUR, SPUR }


class RouteNode:
	var id := 0
	var kind := NodeKind.JUNCTION
	var position := Vector2.ZERO
	var height := 0.0
	var edge_ids: Array[int] = []


class RouteEdge:
	var id := 0
	var kind := EdgeKind.MAIN
	var from_node := 0
	var to_node := 0
	## XZ polyline from from_node to to_node, roughly evenly spaced.
	var points := PackedVector2Array()
	## Road height at each point (Y).
	var heights := PackedFloat32Array()
	var width := 7.0
	var surface := Surface.GRAVEL
	var length := 0.0

	func direction_at(index: int) -> Vector2:
		var a := points[maxi(index - 1, 0)]
		var b := points[mini(index + 1, points.size() - 1)]
		return (b - a).normalized()

	func point_3d(index: int) -> Vector3:
		return Vector3(points[index].x, heights[index], points[index].y)


class Gate:
	var index := 0
	var edge_id := 0
	var point_index := 0
	var position := Vector2.ZERO
	var direction := Vector2.ZERO


var seed := 0
var attempt := 0
var biome := &"forest"
var nodes: Array[RouteNode] = []
var edges: Array[RouteEdge] = []
## Edge ids in lap order, starting and ending at the START node.
var main_route: Array[int] = []
## Checkpoint 0 is the start/finish line; the rest follow the lap order.
var checkpoints: Array[Gate] = []
var center := Vector2.ZERO


func add_node(kind: int, position: Vector2) -> RouteNode:
	var node := RouteNode.new()
	node.id = nodes.size()
	node.kind = kind
	node.position = position
	nodes.append(node)
	return node


func add_edge(kind: int, from_node: int, to_node: int, points: PackedVector2Array, width: float, surface: StringName) -> RouteEdge:
	var edge := RouteEdge.new()
	edge.id = edges.size()
	edge.kind = kind
	edge.from_node = from_node
	edge.to_node = to_node
	edge.points = points
	edge.heights = PackedFloat32Array()
	edge.heights.resize(points.size())
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


## The whole lap as one polyline (3D), start to start.
func main_route_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for edge_id in main_route:
		var edge := edges[edge_id]
		for i in edge.points.size():
			if i == 0 and not out.is_empty():
				continue
			out.append(edge.point_3d(i))
	return out


## Where the race starts: a point on the first main edge and the direction of travel.
func start_pose(distance_along := 12.0) -> Transform3D:
	var edge := edges[main_route[0]]
	var travelled := 0.0
	for i in range(1, edge.points.size()):
		travelled += edge.points[i].distance_to(edge.points[i - 1])
		if travelled >= distance_along or i == edge.points.size() - 1:
			var origin := edge.point_3d(i)
			var dir := edge.direction_at(i)
			return Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), origin)
	return Transform3D.IDENTITY


## Edges that are not part of the lap: the choices the navigator reads off the map.
func alternative_edges() -> Array[RouteEdge]:
	var out: Array[RouteEdge] = []
	for edge in edges:
		if edge.kind != EdgeKind.MAIN:
			out.append(edge)
	return out


## Stable text form, for determinism tests and for sending a graph instead of a seed.
func to_dict() -> Dictionary:
	var node_list := []
	for node in nodes:
		node_list.append({"id": node.id, "kind": node.kind, "x": node.position.x, "z": node.position.y, "h": node.height})
	var edge_list := []
	for edge in edges:
		edge_list.append({"id": edge.id, "kind": edge.kind, "from": edge.from_node, "to": edge.to_node,
			"width": edge.width, "surface": String(edge.surface), "points": edge.points, "heights": edge.heights})
	var checkpoint_list := []
	for checkpoint in checkpoints:
		checkpoint_list.append({"index": checkpoint.index, "edge": checkpoint.edge_id, "point": checkpoint.point_index})
	return {"version": VERSION, "seed": seed, "attempt": attempt, "biome": String(biome), "center": center,
		"nodes": node_list, "edges": edge_list, "main_route": main_route, "checkpoints": checkpoint_list}


static func polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total
