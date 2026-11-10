class_name CarModel
extends Node3D
## Dresses a RallyCar with the "Milano '95" model (Daniel Zhabotinsky, CC BY 4.0; see
## ASSET_LICENSES.md): the body, interior and glass replace the placeholder boxes, the tyres move
## into the car's wheel nodes (so suspension and spin animate them), the side and front glass become
## the Cabin's windows (opening, breaking and kicking out work on the real glass), the steering wheel
## turns with the steering and the body paint takes the team colour. The parts that move on their own are cut
## out of the model (CarParts): CarMirrors, CarCockpit (needles, pedals, levers), WindshieldGlass (wipers);
## CarLamps lights its lamps, at dusk and at night those of a light pod too, which goes on the bonnet (CarDamageFx.mount). Remote
## cars do it all too: the pedals come with the snapshots.
## Must sit before the Cabin node in the scene: it swaps the glass in before Cabin._ready runs.

const MODEL := preload("res://assets/vehicles/milano95/milano95.glb")
const GLASS_SHADER := preload("res://shaders/car_glass.gdshader")
## The model is built along +X with its ground at y = 0; the car drives along -Z with its body
## origin above the ground. Turning +90 deg about Y maps the model's front (+X) onto -Z; the
## 8.5 cm shift puts the axles symmetric about the body origin (wheels at z = +-1.21), which the
## tyre model's equal per-wheel holding forces assume (otherwise the parked car creeps).
const MODEL_TRANSFORM := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, -0.517, -0.085))
## Model node name -> car wheel node.
const WHEELS := {
	"Milano95_WheelStock_FL": "WheelFL", "Milano95_WheelStock_FR": "WheelFR",
	"Milano95_WheelStock_RL": "WheelRL", "Milano95_WheelStock_RR": "WheelRR",
}
## Model glass node name -> Cabin window node it becomes.
const GLASS := {
	"Milano95_Glass_Driver": "WindowLeft", "Milano95_Glass_Passanger": "WindowRight",
	"Milano95_Windshield": "Windshield",
}
const FIXED_GLASS: Array[String] = ["Milano95_Glass_Rear", "Milano95_Glass"]
## The metres of a side pane the glass shader's crack picture spans (car_glass.gdshader: PANE_UV), and how far a can's crack spreads.
const PANE_METRES := Vector2(1.0 / 1.02, 1.0 / 2.18)
const PANE_SPREAD := 0.45
## Where glass is drawn among what is see-through: another car's before the dust round it (RoadFxPool.PUFF_PRIORITY), the seat's own
## car's with the rest, after the dust it looks out at.
const GLASS_PRIORITY := RoadFxPool.PUFF_PRIORITY - 1
const SEAT_GLASS_PRIORITY := 0
## Placeholder meshes hidden once the model is in.
const PLACEHOLDERS: Array[NodePath] = [^"Body", ^"CabinShell", ^"Interior"]
## How far the steering wheel turns for full steering lock (radians).
const STEERING_RATIO := 2.4
## The column the wheel turns about (square to the rim, measured from the model), and where the driver has set it: higher than the
## model has it, so the dials show in the opening above the hub from the driver's eye (tests/unit/vehicles/test_seat_view.gd) and the
## hands reach it with the elbows bent.
const WHEEL_AXIS := Vector3(0.0, 0.353, 0.936)
const WHEEL_SET_IN := Vector3(0.0, 0.045, 0.0)

var car: RallyCar
## What the road has left on this car (its skins are the body's materials).
var dirt: CarDirt
## The door and interior mirrors: plain glass until a seat is bound (bind_seat).
var mirrors: CarMirrors
var cockpit: CarCockpit
var lamps: CarLamps
var heat: CarHeat
var rally_kit: CarRallyKit
## Who sits in the car: Role -> CrewBody, for the seats players have taken.
var crew: Dictionary = {}

var _steering: Node3D
var _glass_panes: Array[MeshInstance3D] = []
## This car's clear glass, and a side pane's once a can has cracked it (Cabin.Side), with the worker baking its crack (-1: none).
var _clear := ShaderMaterial.new()
var _cracked: Array[ShaderMaterial] = [null, null]
var _crack_tasks: Array[int] = [-1, -1]
## Headlights on (bad weather); set before or after the car enters the tree.
var headlights := false
## The seat the local player sits in, in this car (bind_seat), or null.
var _seat: CockpitCamera


func _ready() -> void:
	car = get_parent() as RallyCar
	var model: Node3D = MODEL.instantiate()
	model.name = "Milano95"
	model.transform = MODEL_TRANSFORM
	add_child(model)
	_setup_paint(model)
	if car == null:
		return
	for path in PLACEHOLDERS:
		var node := car.get_node_or_null(path) as Node3D
		if node != null:
			node.visible = false
	_clear.resource_name = "ClearGlass"
	_clear.shader = GLASS_SHADER
	_clear.render_priority = GLASS_PRIORITY
	var parts := CarParts.cut(model, _car_space)
	mirrors = CarMirrors.new()
	mirrors.name = "Mirrors"
	add_child(mirrors)
	mirrors.build(parts)
	_move_wheels(model)
	_move_glass(model, parts)
	_clear_fixed_glass(model)
	(model.find_child(CarParts.INTERIOR, true, false) as MeshInstance3D).layers = GraphicsQuality.CABIN_LAYER
	_setup_steering(model)
	_add_cabin_light()
	rally_kit = CarRallyKit.new()
	rally_kit.name = "RallyKit"
	add_child(rally_kit)
	rally_kit.build(car.paint_color)
	cockpit = CarCockpit.new()
	cockpit.name = "Cockpit"
	add_child(cockpit)
	cockpit.build(parts)
	lamps = CarLamps.new()
	lamps.name = "Lamps"
	lamps.headlights = headlights
	add_child(lamps)
	lamps.build(model)
	var cabin := car.get_node_or_null(^"Cabin") as Cabin
	if cabin != null:
		cabin.dome_changed.connect(_on_dome)
		cabin.window_state_changed.connect(_on_window)
	heat = CarHeat.new()
	heat.name = "Heat"
	add_child(heat)
	heat.build()
	var damage_fx := CarDamageFx.new()
	damage_fx.name = "DamageFx"
	add_child(damage_fx)
	damage_fx.setup(model, _car_space)
	damage_fx.mirrors = mirrors
	if lamps.pod != null:
		damage_fx.mount(&"hood", lamps.pod, [lamps.pod.body])


## A soft, shadowless fill inside the cabin so the dashboard and the hands read in daylight
## (the roof otherwise leaves the cockpit nearly black against the bright windows).
func _add_cabin_light() -> void:
	var light := OmniLight3D.new()
	light.name = "CabinFill"
	light.position = Vector3(0.0, 0.62, 0.05)
	light.omni_range = 1.9
	light.light_energy = 0.55 * RaceLook.daylight
	light.light_color = Color(1.0, 0.95, 0.88)
	light.shadow_enabled = false
	light.light_specular = 0.2
	add_child(light)


## The body, its trim and the wheels get skins of this car's own: each team has its colour, and the road leaves what it leaves (CarDirt).
func _setup_paint(model: Node3D) -> void:
	dirt = CarDirt.new()
	dirt.name = "Dirt"
	add_child(dirt)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		for s in mesh_instance.mesh.get_surface_count():
			var skin := dirt.skin_of(mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D, _car_space(mesh_instance))
			if skin != null:
				mesh_instance.set_surface_override_material(s, skin)


func set_paint(color: Color) -> void:
	for skin in dirt.paints:
		skin.set_shader_parameter(&"albedo", color)
	if lamps != null:
		lamps.set_paint(color)
	if rally_kit != null:
		rally_kit.set_paint(color)
	for body: CrewBody in crew.values():
		body.set_paint(car.paint_color)


## Each tyre mesh goes into its wheel's Visual node, centred, so RallyCar's suspension travel,
## steering and spin move it. The placeholder tyre there is removed.
func _move_wheels(model: Node3D) -> void:
	for model_name in WHEELS:
		var holder := model.find_child(model_name, true, false) as Node3D
		var wheel := car.get_node_or_null(NodePath(WHEELS[model_name])) as Node3D
		if holder == null or wheel == null:
			continue
		var visual := wheel.get_node_or_null(^"Visual") as Node3D
		if visual == null:
			continue
		for old in visual.get_children():
			old.queue_free()
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mi as MeshInstance3D
			var in_car := _car_space(mesh_instance)
			var centre := in_car * mesh_instance.mesh.get_aabb().get_center()
			mesh_instance.get_parent().remove_child(mesh_instance)
			visual.add_child(mesh_instance)
			# Keep the mesh's orientation, put its centre on the wheel's spin axis.
			mesh_instance.transform = Transform3D(in_car.basis, in_car.origin - centre)


## The model's side windows and windshield replace the Cabin's placeholder panes (same names),
## so Cabin shows/hides and cracks the real glass.
func _move_glass(model: Node3D, parts: Dictionary) -> void:
	var cabin := car.get_node_or_null(^"Cabin") as Node3D
	if cabin == null:
		return
	for model_name in GLASS:
		var holder := model.find_child(model_name, true, false) as Node3D
		if holder == null:
			continue
		var meshes := holder.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			continue
		var glass := meshes[0] as MeshInstance3D
		var in_car := _car_space(glass)
		var placeholder := cabin.get_node_or_null(NodePath(GLASS[model_name]))
		if placeholder != null:
			# Model sits before Cabin, so Cabin's @onready panes pick up the real glass; the
			# placeholder is out of the tree and referenced by nothing, so it goes now.
			cabin.remove_child(placeholder)
			placeholder.free()
		glass.get_parent().remove_child(glass)
		glass.name = GLASS[model_name]
		cabin.add_child(glass)
		glass.transform = (cabin.transform.affine_inverse()) * in_car
		# The model's glass is a dark 80 % tint from its texture atlas: seen from the seats it
		# darkened the whole world. The panes the crew looks through get clear glass instead.
		var clear_mesh := glass.mesh.duplicate() as Mesh
		for s in clear_mesh.get_surface_count():
			clear_mesh.surface_set_material(s, _clear)
		glass.mesh = clear_mesh
		_add_pane(glass, in_car)
		if GLASS[model_name] == "Windshield":
			# Dirt, cracks and wipers live on the real windshield.
			var windshield := WindshieldGlass.new()
			windshield.name = "WindshieldGlass"
			windshield.cabin = cabin as Cabin
			windshield.glass = glass
			windshield.parts = parts
			add_child(windshield)
			mirrors.windshield = windshield


## The rear window and the small side windows stay where they are, but they are clear too: they are what the
## interior mirror looks through.
func _clear_fixed_glass(model: Node3D) -> void:
	for model_name in FIXED_GLASS:
		for mi in model.find_child(model_name, true, false).find_children("*", "MeshInstance3D", true, false):
			var pane := mi as MeshInstance3D
			pane.material_override = _clear
			_add_pane(pane, _car_space(pane))


## A side pane a can has cracked (spec §9.2) takes a crack star, seeded per pane: the glass at once, the picture of the crack from a worker a
## frame or two later (baking it takes 10-20 ms, too long for the frame the can hits on every peer).
func _on_window(side: int, _state: int, cracked: bool) -> void:
	if not cracked or _cracked[side] != null:
		return
	var cabin := car.get_node(^"Cabin") as Cabin
	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	material.render_priority = _clear.render_priority
	material.set_shader_parameter(&"crack_metres", PANE_METRES)
	material.set_shader_parameter(&"crack_spread", PANE_SPREAD)
	_cracked[side] = material
	(cabin.get_node(^"WindowLeft" if side == Cabin.Side.LEFT else ^"WindowRight") as MeshInstance3D).material_override = material
	var seed := cabin.team * 17 + side + 1
	var crack := CrackPicture.pieces(seed, PANE_METRES, PANE_METRES * WindshieldGlass.crack_center(seed))
	_crack_tasks[side] = WorkerThreadPool.add_task(func() -> void: _on_crack_baked.call_deferred(side, CrackPicture.bake(crack, PANE_METRES)))


func _on_crack_baked(side: int, picture: Image) -> void:
	if _crack_tasks[side] >= 0:
		WorkerThreadPool.wait_for_task_completion(_crack_tasks[side])
		_crack_tasks[side] = -1
	_cracked[side].set_shader_parameter(&"crack_map", ImageTexture.create_from_image(picture))


func _exit_tree() -> void:
	for side in _crack_tasks.size():
		if _crack_tasks[side] >= 0:
			WorkerThreadPool.wait_for_task_completion(_crack_tasks[side])
			_crack_tasks[side] = -1


## The dome lamp lights the cabin, and the cabin mirrors in its own glass (shaders/glass_ghost.gdshaderinc): a real
## rally detail, reading the map at night half blinds the driver.
func _on_dome(on: bool) -> void:
	lamps.set_dome(on)
	for pane in _glass_panes:
		pane.set_instance_shader_parameter(&"cabin_glow", 1.0 if on else 0.0)


## Tells a pane where the dome lamp is, in the pane's own mesh space.
func _add_pane(pane: MeshInstance3D, in_car: Transform3D) -> void:
	_glass_panes.append(pane)
	pane.set_instance_shader_parameter(&"lamp_position", in_car.affine_inverse() * CarLamps.DOME_LENS_AT)


## The steering wheel turns about its column with the car's steering angle. It is set where the driver reads the dials
## through the rim (WHEEL_SET_IN; CarCockpit moves the column's end with it).
func _setup_steering(model: Node3D) -> void:
	var holder := model.find_child("Milano95_Steering", true, false) as Node3D
	if holder == null:
		return
	var meshes := holder.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	mesh_instance.layers = GraphicsQuality.CABIN_LAYER
	var in_car := _car_space(mesh_instance)
	var centre := in_car * mesh_instance.mesh.get_aabb().get_center()
	_steering = Node3D.new()
	_steering.name = "SteeringPivot"
	# This node shares the car's space (identity transform); the car itself is busy in _ready.
	add_child(_steering)
	_steering.position = centre + WHEEL_SET_IN
	mesh_instance.get_parent().remove_child(mesh_instance)
	_steering.add_child(mesh_instance)
	mesh_instance.transform = Transform3D(in_car.basis, in_car.origin - centre)
	# Hide the placeholder torus wheel if it is still around.
	var old_wheel := car.get_node_or_null(^"Interior/SteeringWheel") as Node3D
	if old_wheel != null:
		old_wheel.visible = false


func set_headlights(on: bool) -> void:
	headlights = on
	if lamps != null:
		lamps.set_headlights(on)


func _process(_delta: float) -> void:
	if _steering == null or car == null or car.config == null:
		return
	var steer := car.steer_angle / maxf(car.config.max_steer_angle, 0.001)
	# The axis points at the driver: clockwise as he sees it is a negative turn.
	_steering.basis = Basis(WHEEL_AXIS.normalized(), -steer * STEERING_RATIO)


## The steering wheel's middle and how it is turned now (car space): the driver's hands ride the rim, the horn is in the hub (CrewRig).
func steering() -> Transform3D:
	return _steering.transform if _steering != null else Transform3D.IDENTITY


## A crew member sits in `role`'s seat (`seated`) or it is empty: RaceSession says so for every car from the roster.
func seat_crew(role: int, seated: bool) -> void:
	if seated == crew.has(role):
		return
	rally_kit.seat_taken(role, seated)
	if not seated:
		(crew[role] as CrewBody).queue_free()
		crew.erase(role)
		return
	var body := CrewBody.new()
	body.name = "Driver" if role == RosterRules.Role.DRIVER else "Navigator"
	add_child(body)
	body.build(role, (car.get_node(NodePath(seat_camera(role))) as CockpitCamera).seat_position(), car.paint_color)
	crew[role] = body
	body.set_own(_seat != null and _seat.name == seat_camera(role))


## The name of a seat's camera.
static func seat_camera(role: int) -> StringName:
	return &"DriverCamera" if role == RosterRules.Role.DRIVER else &"NavigatorCamera"


## The local player sits in this car behind `seat`: what only that player sees comes alive for that seat, on High its
## headlights cast shadows, and its glass is drawn after the dust beyond it (GLASS_PRIORITY). They see their own body but not their own
## head (CrewBody.OWN_HEAD_LAYER).
func bind_seat(seat: CockpitCamera) -> void:
	_seat = seat
	if seat != null:
		seat.cull_mask &= ~CrewBody.OWN_HEAD_LAYER
	for crew_role: int in crew:
		(crew[crew_role] as CrewBody).set_own(seat != null and seat.name == seat_camera(crew_role))
	if mirrors != null:
		mirrors.bind_seat(seat)
	if lamps != null:
		lamps.cast_shadows(seat != null and GraphicsQuality.current() == GraphicsQuality.Level.HIGH)
	var priority := SEAT_GLASS_PRIORITY if seat != null else GLASS_PRIORITY
	_clear.render_priority = priority
	for material in _cracked:
		if material != null:
			material.render_priority = priority
	var windshield := get_node_or_null(^"WindshieldGlass") as WindshieldGlass
	if windshield != null:
		windshield.material.render_priority = priority


## A node's transform in the car body's space.
func _car_space(node: Node3D) -> Transform3D:
	var t := node.transform
	var current := node.get_parent()
	while current != null and current != car:
		if current is Node3D:
			t = (current as Node3D).transform * t
		current = current.get_parent()
	return t
