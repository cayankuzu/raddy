class_name StageEvents
extends Node
## Surprises a stage springs on the first crew to reach them (the chaos the crews laugh about
## afterwards): a fir that topples across the road in front of you, and boulders that come down a
## bank onto the road. TrackFeatures builds each event's trigger and props from the stage's
## features; this node fires them once. Online, the host decides (`triggered` -> RaceSession
## broadcasts) and every peer plays the same tree fall; boulders are host-simulated bodies that
## RaceSession spawns and syncs like the cans. Offline (dev scenes) everything happens here.
## `obstacles()` tells bots (RouteFollower) where the fallen trunks and boulders are.

signal triggered(index: int)

## Boulders per rockfall and how hard they are thrown off the bank toward the road.
const BOULDERS := 4
const BOULDER_PUSH := Vector2(5.0, 9.0)
const TREE_FALL_TIME := 1.7
const BOULDER_MESH := "res://assets/models/boulder_01/boulder_01_1k.gltf"
## Pushing through the crown throws needles and twigs over the windshield (0..1 dirt).
const CROWN_DIRT := 0.5
## One car sets the branches off at most this often (seconds).
const CROWN_COOLDOWN := 2.0
const CRASH_SOUNDS: Array[String] = [
	"res://assets/audio/impacts/impactWood_heavy_0.ogg",
	"res://assets/audio/impacts/impactWood_heavy_1.ogg",
	"res://assets/audio/impacts/impactWood_heavy_2.ogg",
]

## When false (a peer that is not the host) triggers are ignored: the host's word arrives by RPC.
var decides := true
## Spawns one boulder: Callable(origin: Vector3, velocity: Vector3, radius: float). Defaults to
## a local body (offline); RaceSession replaces it with its synced spawn on the host.
var spawn_boulder: Callable

## Events actually played here (each plays once).
var plays := 0

var _events: Array[Node3D] = []
var _fired: Dictionary = {}
## Circles (x, y, z, radius) along each fallen trunk, by event index.
var _trunks: Dictionary = {}
## Boulder bodies and their radii.
var _boulders: Array[Dictionary] = []
## Car instance id -> time (s) its last pass through a crown may play again.
var _crown_ready: Dictionary = {}
var _time := 0.0


## Finds the events TrackFeatures built under `track` and listens to their triggers.
func setup(track: Node) -> void:
	if not spawn_boulder.is_valid():
		spawn_boulder = _spawn_local_boulder
	for node in track.find_children("Event*", "Node3D", true, false):
		if not node.has_meta(&"event_kind"):
			continue
		var index := _events.size()
		_events.append(node as Node3D)
		var area := node.get_node_or_null(^"Trigger") as Area3D
		if area != null:
			area.body_entered.connect(func(body: Node3D) -> void: _on_trigger(index, body))
		var crown := node.get_node_or_null(^"Tree/Crown") as Area3D
		if crown != null:
			crown.body_entered.connect(func(body: Node3D) -> void: _on_crown(node as Node3D, body))


func _process(delta: float) -> void:
	_time += delta


func event_count() -> int:
	return _events.size()


func fired(index: int) -> bool:
	return _fired.has(index)


## Where a bot must not drive: circles (x, y, z, radius) along every tree that fell (from the
## moment it starts falling: it lands before a car gets there) and around every boulder.
func obstacles() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for circles in _trunks.values():
		out.append_array(circles)
	for i in range(_boulders.size() - 1, -1, -1):
		var body = _boulders[i].body
		if not is_instance_valid(body):
			_boulders.remove_at(i)
			continue
		var p: Vector3 = (body as Node3D).global_position
		out.append(Vector4(p.x, p.y, p.z, _boulders[i].radius))
	return out


## A boulder now on the stage (any peer; RaceSession calls this for the synced ones).
func track_boulder(body: Node3D, radius: float) -> void:
	_boulders.append({"body": body, "radius": radius})


func _on_trigger(index: int, body: Node3D) -> void:
	if not decides or _fired.has(index) or not body is RallyCar:
		return
	if triggered.get_connections().is_empty():
		play(index)  # offline: nobody to ask
	else:
		triggered.emit(index)


## Plays event `index` here (every peer calls this once, the host's broadcast or offline).
func play(index: int) -> void:
	if index < 0 or index >= _events.size() or _fired.has(index):
		return
	_fired[index] = true
	plays += 1
	var event := _events[index]
	match event.get_meta(&"event_kind"):
		&"falling_tree":
			_trunks[index] = _trunk_circles(event)
			_fell_tree(event)
		&"rockfall":
			if decides:
				_drop_rocks(event)
	print("STAGE event %d %s" % [index, event.get_meta(&"event_kind")])


## The fallen trunk as a row of circles about a metre apart, from the base to the tip.
static func _trunk_circles(event: Node3D) -> Array[Vector4]:
	var fallen: Basis = event.get_meta(&"fallen_basis")
	var reach: float = event.get_meta(&"trunk_reach", StageEventBuilder.TREE_LENGTH)
	var base := event.global_position
	var out: Array[Vector4] = []
	var steps := ceili(reach)
	for k in steps + 1:
		var p := base + fallen * (Vector3.UP * (reach * k / steps))
		out.append(Vector4(p.x, p.y, p.z, StageEventBuilder.TRUNK_RADIUS))
	return out


## The tree swings down about its base onto the road (a moving body: it shoves what it falls
## on), then lies there; its crown starts listening for cars pushing through.
func _fell_tree(event: Node3D) -> void:
	var tree := event.get_node_or_null(^"Tree") as Node3D
	if tree == null:
		return
	var fallen: Basis = event.get_meta(&"fallen_basis")
	var tween := event.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(t: float) -> void:
		tree.basis = Basis.IDENTITY.slerp(fallen, t), 0.0, 1.0, TREE_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		var crown := tree.get_node_or_null(^"Crown") as Area3D
		if crown != null:
			crown.monitoring = true
		_play_wood(event, event.get_meta(&"crash_point"), 0))


## A car pushing through the branches: crack, and needles over the windshield.
func _on_crown(event: Node3D, body: Node3D) -> void:
	if not body is RallyCar:
		return
	var id := body.get_instance_id()
	if _time < float(_crown_ready.get(id, 0.0)):
		return
	_crown_ready[id] = _time + CROWN_COOLDOWN
	_play_wood(event, body.global_position + Vector3.UP, 1 + id % 2)
	if decides:
		var cabin := body.get_node_or_null(^"Cabin") as Cabin
		if cabin != null:
			cabin.host_add_dirt(CROWN_DIRT)


func _play_wood(event: Node3D, at: Vector3, sound: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = load(CRASH_SOUNDS[sound % CRASH_SOUNDS.size()])
	audio.bus = &"Game"
	audio.unit_size = 14.0
	audio.max_distance = 300.0
	event.add_child(audio)
	audio.global_position = at
	audio.finished.connect(audio.queue_free)
	audio.play()


## A handful of boulders thrown off the bank toward the road, a little ahead of the trigger.
func _drop_rocks(event: Node3D) -> void:
	var spots: Array = event.get_meta(&"spots")
	var toward: Vector3 = event.get_meta(&"toward_road")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(event.name)
	for spot in spots:
		var push := rng.randf_range(BOULDER_PUSH.x, BOULDER_PUSH.y)
		spawn_boulder.call(spot, toward * push + Vector3.DOWN * 1.0, rng.randf_range(0.75, 1.2))


func _spawn_local_boulder(origin: Vector3, velocity: Vector3, radius: float) -> void:
	var body := make_boulder(radius)
	get_parent().add_child(body)
	body.global_position = origin
	body.linear_velocity = velocity
	track_boulder(body, radius)


## A rolling boulder: a sphere body with the Poly Haven boulder scan on it.
static func make_boulder(radius: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Boulder"
	body.mass = 900.0 * radius * radius * radius
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.9
	body.physics_material_override.bounce = 0.15
	body.set_meta(&"surface", Surface.TARMAC)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	body.add_child(shape)
	if ResourceLoader.exists(BOULDER_MESH):
		var model: Node3D = (load(BOULDER_MESH) as PackedScene).instantiate()
		# The scan is about 1.5 m across at scale 1.
		model.scale = Vector3.ONE * radius * 1.3
		model.position = Vector3.DOWN * radius * 0.35
		body.add_child(model)
	return body
