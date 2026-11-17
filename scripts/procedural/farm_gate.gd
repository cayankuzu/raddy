class_name FarmGate
extends Node3D
## A shortcut's farm gate (GateRules): a galvanised five-bar gate across the track between two wooden posts, a fence
## of rails running off into the trees on both sides. Closed it is a solid bar a car stops on; a car that comes at it
## fast enough bursts it (on the peer that simulates that car, at once: the car loses speed and takes the hit), and a
## standing crew may open it by holding the job (CabinInput). Either way `wanted` asks for it to open everywhere
## (StageEvents: the host's word); open() swings it. Two draw calls: the leaf, the posts and fence.

## Asks for the gate to be opened on every peer: `rammed` (burst by a car) or opened by a crew.
signal wanted(rammed: bool)

const GROUP := &"farm_gate"
## The leaf: its height, the height of its bottom rail, its tubes; the posts and the fence beside it.
const LEAF_HEIGHT := 1.12
const LEAF_FOOT := 0.16
const TUBE := 0.028
const POST := 0.085
const POST_HEIGHT := 1.45
const FENCE_BAYS := 3
const FENCE_BAY := 2.6
const RAIL := 0.035
## How far it swings and how fast: by a crew and burst by a car.
const SWING := deg_to_rad(105.0)
const SWING_SECONDS := 1.6
const BURST_SECONDS := 0.3

var open := false
## Seconds of the local crew's job done so far (CabinInput sets it, the HUD shows it).
var held := 0.0
## Its width between the posts (m) and the way the track runs through it.
var span := 6.0
var forward := Vector3.FORWARD

var _leaf: Node3D
var _leaf_body: StaticBody3D


## The gate of `bypass` at its price, across its track.
static func build(bypass: RouteGraph.Bypass) -> FarmGate:
	var gate := FarmGate.new()
	gate.name = "Gate%d" % bypass.id
	var pose := bypass.pose_at(bypass.price_at)
	var dir: Vector2 = pose.direction
	gate.forward = Vector3(dir.x, 0.0, dir.y)
	gate.span = bypass.edges[0].width + 2.0 * RoadBuilder.SHOULDER
	gate.transform = Transform3D(Basis.looking_at(gate.forward, Vector3.UP), pose.position)
	gate._build()
	return gate


func _ready() -> void:
	add_to_group(GROUP)


## The nearest closed gate within `reach` of `position` in `tree`, or null.
static func nearest_closed(tree: SceneTree, position: Vector3, reach: float) -> FarmGate:
	var best: FarmGate = null
	var best_distance := reach
	for node in tree.get_nodes_in_group(GROUP):
		var gate := node as FarmGate
		var d := gate.global_position.distance_to(position)
		if not gate.open and d <= best_distance:
			best = gate
			best_distance = d
	return best


## Swings it open (every peer, once: the host's broadcast, or at once on the peer whose car burst it).
func swing_open(rammed: bool) -> void:
	if open:
		return
	open = true
	_leaf_body.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK if rammed else Tween.TRANS_SINE)
	tween.tween_property(_leaf, "rotation:y", SWING, BURST_SECONDS if rammed else SWING_SECONDS)
	print("STAGE gate %s %s" % [name, "rammed" if rammed else "opened"])


## The crew finished the job.
func request_open() -> void:
	if not open:
		wanted.emit(false)


func _physics_process(_delta: float) -> void:
	if open:
		return
	for node in get_tree().get_nodes_in_group(RallyCar.GROUP):
		var car := node as RallyCar
		if not car.simulated:
			continue
		var offset := car.global_position - global_position
		var lateral := absf(offset.dot(global_basis.x))
		var along := offset.dot(forward)
		var speed := car.linear_velocity.dot(forward)
		# From either side: metres before the line and the speed toward it.
		var ahead := -along if speed >= 0.0 else along
		if lateral < span * 0.5 + 0.5 and GateRules.rams(ahead, absf(speed)):
			_burst(car, speed)
			return


## A car burst it, on the peer that simulates the car: open at once, the car loses speed and feels the hit.
func _burst(car: RallyCar, speed: float) -> void:
	swing_open(true)
	car.linear_velocity -= forward * speed * (1.0 - GateRules.RAM_KEEP)
	car.last_impact_struck = CrashRules.Struck.METAL
	car.last_impact_at = Vector3(0.0, 0.3, -1.9)
	car.impact.emit(GateRules.ram_hit(absf(speed)), (car.global_basis.inverse() * forward * signf(speed)).normalized())
	wanted.emit(true)


func _build() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.6, 0.62, 0.61)
	steel.metallic = 0.8
	steel.roughness = 0.42
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.33, 0.25, 0.17)
	wood.roughness = 0.92
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	var half := span * 0.5
	# The leaf hangs on the left post and closes on the right one.
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	_leaf.position = Vector3(-half, 0.0, 0.0)
	add_child(_leaf)
	var leaf := SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaf.set_material(steel)
	var length := span - 0.12
	for k in 5:
		var y := LEAF_FOOT + LEAF_HEIGHT * k / 4.0
		_tube(leaf, Vector3(0.05, y, 0.0), Vector3(length, y, 0.0), TUBE * (1.25 if k == 0 or k == 4 else 1.0))
	for x in [0.05, length * 0.5, length]:
		_tube(leaf, Vector3(x, LEAF_FOOT, 0.0), Vector3(x, LEAF_FOOT + LEAF_HEIGHT, 0.0), TUBE * 1.25)
	_tube(leaf, Vector3(0.05, LEAF_FOOT, 0.0), Vector3(length * 0.5, LEAF_FOOT + LEAF_HEIGHT, 0.0), TUBE)
	_tube(leaf, Vector3(length * 0.5, LEAF_FOOT, 0.0), Vector3(length, LEAF_FOOT + LEAF_HEIGHT, 0.0), TUBE)
	var leaf_mesh := MeshInstance3D.new()
	leaf_mesh.name = "Mesh"
	leaf_mesh.mesh = leaf.commit()
	_leaf.add_child(leaf_mesh)
	_leaf_body = StaticBody3D.new()
	_leaf_body.name = "Body"
	_leaf_body.set_meta(CrashRules.META, CrashRules.Struck.METAL)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, LEAF_HEIGHT + 0.1, 0.14)
	shape.shape = box
	shape.position = Vector3(length * 0.5, LEAF_FOOT + LEAF_HEIGHT * 0.5, 0.0)
	_leaf_body.add_child(shape)
	_leaf.add_child(_leaf_body)
	# The posts, then the fence off to each side.
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	posts.set_material(wood)
	var post_body := StaticBody3D.new()
	post_body.name = "Posts"
	post_body.set_meta(CrashRules.META, CrashRules.Struck.WOOD)
	for side in [-1.0, 1.0]:
		var previous := Vector3.ZERO
		for k in FENCE_BAYS + 1:
			var x: float = side * (half + 0.12 + FENCE_BAY * k)
			var top := POST_HEIGHT * (1.0 if k == 0 else 0.82)
			var at := Vector3(x, 0.0, 0.0)
			_tube(posts, at + Vector3.DOWN * 0.4, at + Vector3.UP * top, POST * (1.0 if k == 0 else 0.7), 7)
			if k > 0:
				for y in [0.45, 0.95]:
					_tube(posts, previous + Vector3.UP * y, at + Vector3.UP * y, RAIL, 5)
			var post_shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = POST
			cylinder.height = top + 0.4
			post_shape.shape = cylinder
			post_shape.position = at + Vector3.UP * (top - 0.4) * 0.5
			post_body.add_child(post_shape)
			previous = at
	var post_mesh := MeshInstance3D.new()
	post_mesh.name = "Mesh"
	post_mesh.mesh = posts.commit()
	post_body.add_child(post_mesh)
	add_child(post_body)


## A round tube of `radius` from `a` to `b` (`sides` round), capped.
static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, sides := 8) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var n0 := side * cos(a0) + up * sin(a0)
		var n1 := side * cos(a1) + up * sin(a1)
		for corner in [[a, n0], [b, n0], [b, n1], [a, n0], [b, n1], [a, n1]]:
			st.set_normal(corner[1])
			st.add_vertex(corner[0] + corner[1] * radius)
		for end in [[b, axis, n0, n1], [a, -axis, n1, n0]]:
			st.set_normal(end[1])
			st.add_vertex(end[0])
			st.set_normal(end[1])
			st.add_vertex(end[0] + end[2] * radius)
			st.set_normal(end[1])
			st.add_vertex(end[0] + end[3] * radius)
