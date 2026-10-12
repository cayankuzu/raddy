class_name PaperMap
extends Node3D
## The navigator's big folded paper map as a thing in the cabin (spec §11): a sheet that unfolds
## from the lap up in front of the navigator's face, shows the MapCanvas drawing, zooms with the
## wheel and pans by dragging, shakes when the wind is about to take it and flies out of the
## window when it does. The Cabin owns the state (host authority); this node shows it on every
## peer and turns the local navigator's mouse into zoom/pan.

const SHEET_SIZE := Vector2(0.62, 0.40)
## Poses relative to the car: held up in front of the navigator's seat, and folded on the lap.
const HELD_POSITION := Vector3(0.38, 0.59, -0.33)
const HELD_ROTATION_DEG := Vector3(-24.0, 0.0, 0.0)
const LAP_POSITION := Vector3(0.38, 0.42, -0.18)
const LAP_ROTATION_DEG := Vector3(-72.0, 0.0, 0.0)
const FOLDED_SCALE := Vector3(0.12, 1.0, 0.9)
const UNFOLD_TIME := 0.45
const FLY_TIME := 4.0
const ZOOM_STEP := 1.18
## Sheet pixels moved per screen pixel dragged.
const DRAG_SPEED := 2.2

var cabin: Cabin
var canvas: MapCanvas
## Player setting: show the team's car on the map (spec §11.2 makes this optional).
var show_car_marker := true

var _sheet: MeshInstance3D
var _material: StandardMaterial3D
var _tween: Tween
var _shake_time := 0.0


func _ready() -> void:
	canvas = MapCanvas.new()
	canvas.name = "Canvas"
	add_child(canvas)
	_material = StandardMaterial3D.new()
	_material.albedo_texture = canvas.get_texture()
	_material.roughness = 1.0
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = SHEET_SIZE
	quad.material = _material
	_sheet = MeshInstance3D.new()
	_sheet.name = "Sheet"
	_sheet.mesh = quad
	_sheet.visible = false
	add_child(_sheet)
	_sheet.position = LAP_POSITION
	_sheet.rotation_degrees = LAP_ROTATION_DEG
	_sheet.scale = FOLDED_SCALE
	if cabin != null:
		cabin.map_changed.connect(_on_map_changed)
		cabin.map_lost.connect(_on_map_lost)


## Draws the race's network on the sheet. `contour` is the shared terrain shading image.
func setup(graph: RouteGraph, notes: Array[Dictionary], contour: Image) -> void:
	canvas.build(graph, notes, contour)


func is_open() -> bool:
	return cabin != null and cabin.map_state == Cabin.MapState.OPEN


func _on_map_changed(state: int) -> void:
	match state:
		Cabin.MapState.OPEN:
			_unfold()
		Cabin.MapState.CLOSED:
			if _sheet.visible:
				_fold()
		_:
			_sheet.visible = false
			canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _unfold() -> void:
	_sheet.visible = true
	_sheet.position = LAP_POSITION
	_sheet.rotation_degrees = LAP_ROTATION_DEG
	_sheet.scale = FOLDED_SCALE
	canvas.reset_view()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_animate(HELD_POSITION, HELD_ROTATION_DEG, Vector3.ONE)


func _fold() -> void:
	_animate(LAP_POSITION, LAP_ROTATION_DEG, FOLDED_SCALE)
	_tween.tween_callback(func() -> void:
		_sheet.visible = false
		canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED)


func _animate(to_position: Vector3, to_rotation_deg: Vector3, to_scale: Vector3) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sheet, "position", to_position, UNFOLD_TIME)
	_tween.tween_property(_sheet, "rotation_degrees", to_rotation_deg, UNFOLD_TIME)
	_tween.tween_property(_sheet, "scale", to_scale, UNFOLD_TIME)
	_tween.set_parallel(false)


## The sheet leaves through the window on `side` and tumbles away; purely visual, every peer
## plays it from the same host event.
func _on_map_lost(side: int) -> void:
	_sheet.visible = false
	canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var car := cabin.get_parent() as RigidBody3D
	if car == null or not is_inside_tree():
		return
	var sign_x := -1.0 if side == Cabin.Side.LEFT else 1.0
	var body := RigidBody3D.new()
	body.name = "FlyingMap"
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass = 0.05
	body.gravity_scale = 0.3
	body.linear_damp = 0.9
	body.angular_damp = 0.4
	var mesh := MeshInstance3D.new()
	mesh.mesh = _sheet.mesh
	body.add_child(mesh)
	body.transform = car.global_transform * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-30.0), 0.0, 0.0)), Vector3(sign_x * 1.15, 0.8, 0.1))
	get_tree().root.add_child(body)
	body.linear_velocity = car.linear_velocity * 0.85 + car.global_basis.x * sign_x * 3.0 + Vector3.UP * 2.5
	body.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))
	get_tree().create_timer(FLY_TIME).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free())


func _process(delta: float) -> void:
	if not _sheet.visible or cabin == null:
		return
	var car := cabin.get_parent() as Node3D
	if car != null and canvas.graph != null:
		var heading := -car.global_basis.z
		canvas.set_car(Vector2(car.global_position.x, car.global_position.z), Vector2(heading.x, heading.z), show_car_marker)
	# The paper flutters before the wind takes it (spec §11.3: a warning, never a surprise).
	if cabin.map_warning_active and (_tween == null or not _tween.is_running()):
		_shake_time += delta
		var amount := clampf(cabin.map_risk, 0.3, 1.0)
		_sheet.rotation_degrees = HELD_ROTATION_DEG + Vector3(sin(_shake_time * 37.0) * 2.5, sin(_shake_time * 29.0) * 3.5, cos(_shake_time * 41.0) * 2.0) * amount
		_sheet.position = HELD_POSITION + Vector3(sin(_shake_time * 31.0), cos(_shake_time * 23.0), 0.0) * 0.006 * amount
	elif _shake_time > 0.0 and (_tween == null or not _tween.is_running()):
		_shake_time = 0.0
		_sheet.rotation_degrees = HELD_ROTATION_DEG
		_sheet.position = HELD_POSITION


## Zoom and pan for the local map holder; nothing else reads the mouse while the map is open.
func _unhandled_input(event: InputEvent) -> void:
	if cabin == null or not cabin.local_may_hold_map() or not is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			canvas.zoom_by(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			canvas.zoom_by(1.0 / ZOOM_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		canvas.pan_by(event.relative * DRAG_SPEED)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"map_reset"):
		canvas.reset_view()
		get_viewport().set_input_as_handled()
