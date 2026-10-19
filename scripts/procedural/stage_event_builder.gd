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
## The tree falls this far over (degrees): it comes to rest on the road, not under it.
const TREE_FALL_ANGLE := 84.0
## The fir as it stands (the model at 0.9 scale).
const TREE_LENGTH := 13.0
const TRUNK_RADIUS := 0.35
## The trunk ends this far past the centre line; the crown beyond it has no collision.
const TRUNK_PAST_CENTRE := 0.5
## How far from the road's edge the fir stands, beyond the verge.
const TREE_SETBACK := 2.5


static func build(graph: RouteGraph, terrain: TerrainField) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for feature in graph.features:
		match feature.kind:
			&"falling_tree":
				out.append(_tree(graph, terrain, feature, out.size()))
			&"rockfall":
				out.append(_rocks(graph, terrain, feature, out.size()))
	return out


static func _tree(graph: RouteGraph, terrain: TerrainField, feature: Dictionary, n: int) -> StaticBody3D:
	var spot := graph.sample(feature.at)
	var dir: Vector2 = spot.direction
	var side := float(feature.side)
	var right := Vector2(-dir.y, dir.x) * side
	var half: float = graph.edges[spot.edge].width * 0.5
	var setback := half + RoadBuilder.VERGE + TREE_SETBACK
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
	var fallen := Basis(axis, deg_to_rad(TREE_FALL_ANGLE))
	# The trunk's length so that, lying, it ends TRUNK_PAST_CENTRE beyond the centre line.
	var across := fall.dot(toward_road) * sin(deg_to_rad(TREE_FALL_ANGLE))
	var reach := minf((setback + TRUNK_PAST_CENTRE) / across, TREE_LENGTH)
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
		var p := Vector2(here.position.x, here.position.z) + right * (half + TerrainField.SHOULDER + 9.0 + k % 2 * 3.0)
		spots.append(Vector3(p.x, terrain.height(p) + 2.5, p.y))
		toward += Vector3(-right.x, 0.0, -right.y)
	event.set_meta(&"spots", spots)
	event.set_meta(&"toward_road", toward.normalized())
	event.add_child(_trigger(graph, feature.at - ROCK_TRIGGER_BEFORE, spot.position))
	return event


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
