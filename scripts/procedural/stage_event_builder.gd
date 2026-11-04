class_name StageEventBuilder
## Builds the props and triggers of a stage's surprise events (StageEvents plays them):
## - "falling_tree": a big fir standing just off the road that falls across it, with the trigger
##   before it so the first crew sees it come down in front of them. The trunk is a moving body
##   (it shoves whatever it falls on) and blocks the near half of the road; the crown covers the
##   rest, and a car can push through its branches;
## - "rockfall": spots up on the bank where boulders are thrown down onto the road.
## Each event is a StaticBody3D named Event<n> carrying its kind and geometry as metadata.

## Far enough that a crew at stage speed (20-25 m/s) sees it land ahead with room to brake or to
## pick the open side.
const TREE_TRIGGER_BEFORE := 60.0
const ROCK_TRIGGER_BEFORE := 38.0
## A boulder starts on ground at least this far above the road, found by walking out from the
## shoulder; the slope in between must not dip below the road (a hollow would swallow it).
const ROCK_MIN_RISE := 4.0
const ROCK_SEARCH_END := 32.0
## The fir as it stands (the model at 0.9 scale).
const TREE_LENGTH := 13.0
const TRUNK_RADIUS := 0.35
## The trunk ends this far short of the centre line, on its own half: the far half stays open.
## The crown beyond it has no collision.
const TRUNK_SHORT_OF_CENTRE := 0.3
## How far from the road's edge the fir stands: just past the skirt, on the low ground.
const TREE_BASE := RoadBuilder.ROADSIDE + 0.4


static func build(graph: RouteGraph, terrain: TerrainField) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for feature in graph.features:
		match feature.kind:
			&"falling_tree":
				out.append(_tree(graph, terrain, feature, out.size()))
			&"rockfall":
				var rocks := _rocks(graph, terrain, feature, out.size())
				if rocks != null:
					out.append(rocks)
	return out


static func _tree(graph: RouteGraph, terrain: TerrainField, feature: Dictionary, n: int) -> StaticBody3D:
	var spot := graph.sample(feature.at)
	var dir: Vector2 = spot.direction
	var side := float(feature.side)
	var right := Vector2(-dir.y, dir.x) * side
	var half: float = graph.edges[spot.edge].width * 0.5
	var setback := half + TREE_BASE
	var base_xz := Vector2(spot.position.x, spot.position.z) + right * setback
	var base := Vector3(base_xz.x, terrain.height(base_xz), base_xz.y)
	var event := StaticBody3D.new()
	event.name = "Event%d" % n
	event.position = base
	event.set_meta(&"event_kind", &"falling_tree")
	# It falls toward the road, slightly along it so it lies at an angle across the lane.
	var toward_road := Vector3(-right.x, 0.0, -right.y)
	var fall := (toward_road + Vector3(dir.x, 0.0, dir.y) * 0.25).normalized()
	var axis := Vector3.UP.cross(fall).normalized()
	# It comes to rest with its trunk on the road's level (the base stands lower, in the ditch's
	# ground), and ends TRUNK_SHORT_OF_CENTRE before the centre line.
	var horizontal := (setback - TRUNK_SHORT_OF_CENTRE) / fall.dot(toward_road)
	var climb: float = spot.position.y + TRUNK_RADIUS - base.y
	var angle := PI * 0.5 - atan2(climb, horizontal)
	var fallen := Basis(axis, angle)
	var reach := minf(Vector2(horizontal, climb).length(), TREE_LENGTH)
	event.set_meta(&"fallen_basis", fallen)
	event.set_meta(&"trunk_reach", reach)
	event.set_meta(&"crash_point", base + fallen * (Vector3.UP * reach))
	var tree := AnimatableBody3D.new()
	tree.name = "Tree"
	tree.sync_to_physics = true
	tree.set_meta(&"surface", Surface.TARMAC)
	event.add_child(tree)
	for part in RoadsideDresser._parts_of({"id": "event_fir", "path": RoadsideCatalog.CONIFERS, "node": "FirTree_0", "foliage": true}):
		var mesh := MeshInstance3D.new()
		mesh.mesh = part.mesh
		mesh.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), Vector3.ZERO) * (part.transform as Transform3D)
		if part.material != null:
			mesh.material_override = part.material
		tree.add_child(mesh)
	var trunk := CollisionShape3D.new()
	trunk.name = "Trunk"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TRUNK_RADIUS
	cylinder.height = reach
	trunk.shape = cylinder
	trunk.position = Vector3.UP * reach * 0.5
	tree.add_child(trunk)
	# The crown beyond the trunk: cars push through it (StageEvents plays the branches and throws
	# needles on the glass); it listens only once the tree lies on the road.
	var crown := Area3D.new()
	crown.name = "Crown"
	crown.monitoring = false
	crown.monitorable = false
	var crown_shape := CollisionShape3D.new()
	var crown_box := BoxShape3D.new()
	var crown_length := maxf(TREE_LENGTH - reach, 2.0) + 1.0
	crown_box.size = Vector3(4.0, crown_length, 4.0)
	crown_shape.shape = crown_box
	crown_shape.position = Vector3.UP * (reach + crown_length * 0.5 - 0.5)
	crown.add_child(crown_shape)
	tree.add_child(crown)
	event.add_child(_trigger(graph, feature.at - TREE_TRIGGER_BEFORE, base))
	return event


static func _rocks(graph: RouteGraph, terrain: TerrainField, feature: Dictionary, n: int) -> StaticBody3D:
	var spot := graph.sample(feature.at)
	var event := StaticBody3D.new()
	event.name = "Event%d" % n
	event.position = spot.position
	event.set_meta(&"event_kind", &"rockfall")
	var side := float(feature.side)
	var spots: Array[Vector3] = []
	var toward := Vector3.ZERO
	for k in StageEvents.BOULDERS:
		var here := graph.sample(float(feature.at) + k * 7.0)
		var dir: Vector2 = here.direction
		var right := Vector2(-dir.y, dir.x) * side
		var half: float = graph.edges[here.edge].width * 0.5
		var ground := high_ground(terrain, Vector2(here.position.x, here.position.z), here.position.y, right, half)
		if ground != Vector3.INF:
			spots.append(ground + Vector3.UP * 2.5)
			toward += Vector3(-right.x, 0.0, -right.y)
	if spots.size() < 2:
		event.free()
		return null  # no bank above the road here: no rockfall
	event.set_meta(&"spots", spots)
	event.set_meta(&"toward_road", toward.normalized())
	event.add_child(_trigger(graph, feature.at - ROCK_TRIGGER_BEFORE, spot.position))
	return event


## The first ground at least ROCK_MIN_RISE above the road walking out from the shoulder along
## `right`, with no dip below the road on the way; Vector3.INF when there is none.
static func high_ground(terrain: TerrainField, road_xz: Vector2, road_y: float, right: Vector2, half: float) -> Vector3:
	var offset := half + RoadBuilder.ROADSIDE
	while offset <= ROCK_SEARCH_END:
		var p := road_xz + right * offset
		var h := terrain.height(p)
		if h < road_y - TerrainField.FLOOR_DROP - 1.0:
			return Vector3.INF
		if h >= road_y + ROCK_MIN_RISE:
			return Vector3(p.x, h, p.y)
		offset += 1.0
	return Vector3.INF


## A box across the road at `distance`, in the event's space (`origin` is the event).
static func _trigger(graph: RouteGraph, distance: float, origin: Vector3) -> Area3D:
	var here := graph.sample(maxf(distance, 0.0))
	var dir: Vector2 = here.direction
	var area := Area3D.new()
	area.name = "Trigger"
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(26.0, 14.0, 4.0)  # the road and a bit: never reaches another stretch
	shape.shape = box
	area.add_child(shape)
	area.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.y), Vector3.UP), here.position + Vector3.UP * 5.0 - origin)
	return area
