extends PhysicsTestCase
## What each seat sees at rest, on the real car: rays from the seat's eye against the car's own triangles. The road is the
## star: the windshield takes about half the frame height straight ahead, little of the roof shows, the roll cage hides no more of it
## than a real one does; the interior mirror and the near door mirror are in view and the far one a glance away; the driver reads the
## dials through the wheel.

const ASPECT := 16.0 / 9.0
const ROWS := 108
const COLUMNS := 96
const CAST_LAYER := 1 << 25
const CAGE_LAYER := 1 << 26
## What a ray can meet, by where the mesh is in the car.
const PARTS := {"Cabin/Windshield": &"windshield", "MirrorHead/Glass": &"interior_mirror", "DoorMirrorLeft/Pane/Glass": &"left_mirror",
	"DoorMirrorRight/Pane/Glass": &"right_mirror", "SteeringPivot": &"wheel", "InstrumentPanel": &"dials", "RallyKit": &"cage"}
## The dials' hubs on the panel's face (shaders/gauge_panel.gdshader: SPEED_CENTER, RPM_CENTER on a 2048 x 680 face), the big
## needles' length on it and their sweep (degrees, from 0 to full scale); where they are on a stage: 40 to 150 km/h, 3000 rpm to the
## red line.
const SPEED_HUB := Vector2(640.0, 340.0)
const RPM_HUB := Vector2(1408.0, 340.0)
const FACE_PIXELS := Vector2(2048.0, 680.0)
const NEEDLE_PIXELS := 262.0
const SWEEP := Vector2(225.0, -45.0)
const STAGE_SPEEDS: Array[float] = [40.0, 60.0, 80.0, 100.0, 120.0, 150.0]
const STAGE_REVS: Array[float] = [3000.0, 4000.0, 5000.0, 6000.0, 7000.0, Gearbox.REDLINE]

var _car: RallyCar


## The car and its triangles as bodies the rays can meet, each with the part it is.
func _build() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_car.freeze = true
	_car.collision_layer = 0
	var by_part := {}
	for node in _car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var path := String(_car.get_path_to(mesh_instance))
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree() or path.contains("Camera") \
				or mesh_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var part := &"solid"
		for key: String in PARTS:
			if path.contains(key):
				part = PARTS[key]
		# Side and rear glass is clear: the rays go through it.
		if part == &"solid" and (path.contains("Window") or path.contains("Glass")):
			continue
		var faces: PackedVector3Array = by_part.get(part, PackedVector3Array())
		var to_car := _car.global_transform.affine_inverse() * mesh_instance.global_transform
		for v in mesh_instance.mesh.get_faces():
			faces.append(to_car * v)
		by_part[part] = faces
	for part: StringName in by_part:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(by_part[part])
		var body := StaticBody3D.new()
		body.collision_layer = CAGE_LAYER if part == &"cage" else CAST_LAYER
		body.set_meta(&"part", part)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		world.add_child(body)
	await wait_ticks(2)


## The part a ray from `from` along `direction` meets first ("" for nothing), the cage too unless `cage` is false.
func _first(from: Vector3, direction: Vector3, cage := true) -> StringName:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * 30.0, CAST_LAYER | (CAGE_LAYER if cage else 0))
	var hit := _car.get_world_3d().direct_space_state.intersect_ray(query)
	return &"" if hit.is_empty() else (hit.collider as Node).get_meta(&"part")


func _eye(seat_name: NodePath) -> Vector3:
	return (_car.get_node(seat_name) as CockpitCamera).seat_position()


## Where a point (car space) falls in the seat's frame at rest, -1..1 across and up; past 1 is out of the frame.
func _in_frame(eye: Vector3, point: Vector3) -> Vector2:
	var half_height := tan(deg_to_rad(CockpitCamera.BASE_FOV) * 0.5)
	var to := point - eye
	return Vector2(to.x / -to.z / (half_height * ASPECT), to.y / -to.z / half_height)


func test_the_windshield_takes_about_half_the_frame_height() -> void:
	await _build()
	var half_height := tan(deg_to_rad(CockpitCamera.BASE_FOV) * 0.5)
	for seat_name: NodePath in [^"DriverCamera", ^"NavigatorCamera"]:
		var through := 0
		var first_row := -1
		for row in ROWS:
			var up := (1.0 - (row + 0.5) / ROWS * 2.0) * half_height
			if _first(_eye(seat_name), Vector3(0.0, up, -1.0)) == &"windshield":
				through += 1
				first_row = row if first_row < 0 else first_row
		var share := through / float(ROWS)
		var roof := first_row / float(ROWS)
		gut.p("%s: the windshield is %.2f of the frame height straight ahead, the roof above it %.2f" % [seat_name, share, roof])
		assert_between(share, 0.45, 0.6, "%s: the road is the star" % seat_name)
		assert_lt(roof, 0.2, "%s: no great headliner over it" % seat_name)


func test_the_cage_hides_little_of_the_road() -> void:
	await _build()
	var half_height := tan(deg_to_rad(CockpitCamera.BASE_FOV) * 0.5)
	for seat_name: NodePath in [^"DriverCamera", ^"NavigatorCamera"]:
		var glass := 0
		var hidden := 0
		for row in ROWS / 2:
			for column in COLUMNS:
				var way := Vector3(((column + 0.5) / COLUMNS * 2.0 - 1.0) * half_height * ASPECT, (1.0 - (row * 2 + 0.5) / ROWS * 2.0) * half_height, -1.0)
				if _first(_eye(seat_name), way, false) == &"windshield":
					glass += 1
					if _first(_eye(seat_name), way) != &"windshield":
						hidden += 1
		gut.p("%s: the cage hides %.1f%% of the windshield's view" % [seat_name, 100.0 * hidden / glass])
		assert_lt(hidden / float(glass), 0.02, "%s: the A pillars' tubes hug the pillars" % seat_name)


func test_the_navigator_reads_the_trip_meter() -> void:
	await _build()
	var eye := _eye(^"NavigatorCamera")
	var display := CarRallyKit.trip_display().origin
	var at := _in_frame(eye, display)
	gut.p("the trip meter's display at %s of the navigator's frame" % str(at.snappedf(0.01)))
	assert_lt(maxf(absf(at.x), absf(at.y)), 0.9, "in view at rest")
	assert_eq(_first(eye, display - eye), &"cage", "and nothing in front of it: the box itself is what the eye meets")


func test_the_mirrors_are_in_view_or_a_glance_away() -> void:
	await _build()
	var mirrors := (_car.get_node(^"Model") as CarModel).mirrors
	# A glance: the head turned 30 degrees towards it brings it into the frame.
	var glance := deg_to_rad(30.0) + atan(tan(deg_to_rad(CockpitCamera.BASE_FOV) * 0.5) * ASPECT)
	for seat_name: NodePath in [^"DriverCamera", ^"NavigatorCamera"]:
		var eye := _eye(seat_name)
		var near := CarMirrors.Slot.LEFT if eye.x < 0.0 else CarMirrors.Slot.RIGHT
		var far := CarMirrors.Slot.RIGHT if near == CarMirrors.Slot.LEFT else CarMirrors.Slot.LEFT
		for slot: int in [CarMirrors.Slot.INTERIOR, near]:
			var centre := _car.to_local(mirrors.glass_center(slot))
			var at := _in_frame(eye, centre)
			gut.p("%s: %s mirror at %s of the frame" % [seat_name, CarMirrors.Slot.keys()[slot], str(at.snappedf(0.01))])
			assert_lt(maxf(absf(at.x), absf(at.y)), 1.0, "%s: in view at rest" % seat_name)
			assert_ne(_first(eye, centre - eye), &"solid", "%s: and nothing of the car in front of it" % seat_name)
		var to_far := _car.to_local(mirrors.glass_center(far)) - eye
		assert_lt(atan2(absf(to_far.x), -to_far.z), glance, "%s: the far door mirror is a glance away" % seat_name)


func test_the_dials_read_through_the_wheel() -> void:
	await _build()
	var eye := _eye(^"DriverCamera")
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in CarCockpit.PANEL_OUTLINE:
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	var face_z := CarCockpit.PANEL_OUTLINE[0].z + CarCockpit.PANEL_LIFT
	# Each hub (a scale of 0), then the needles' tips where they are on a stage.
	var readings := {SPEED_HUB: [-1.0], RPM_HUB: [-1.0]}
	for kmh in STAGE_SPEEDS:
		readings[SPEED_HUB].append(CockpitRules.speed_needle(kmh / 3.6))
	for rpm in STAGE_REVS:
		readings[RPM_HUB].append(CockpitRules.rpm_needle(rpm))
	var seen := 0
	var points := 0
	for hub: Vector2 in readings:
		for scale: float in readings[hub]:
			var angle := deg_to_rad(lerpf(SWEEP.x, SWEEP.y, scale))
			var pixel := hub + (Vector2(cos(angle), -sin(angle)) * NEEDLE_PIXELS if scale >= 0.0 else Vector2.ZERO)
			var point := Vector3(lerpf(low.x, high.x, pixel.x / FACE_PIXELS.x), lerpf(high.y, low.y, pixel.y / FACE_PIXELS.y), face_z)
			var part := _first(eye, point - eye)
			points += 1
			if part == &"dials":
				seen += 1
			elif scale < 0.0:
				fail_test("a dial's hub is behind %s" % part)
	gut.p("the driver sees %d of %d points: the hubs and the needles' tips on a stage" % [seen, points])
	assert_gte(seen / float(points), 0.85, "the dials read through the wheel")
