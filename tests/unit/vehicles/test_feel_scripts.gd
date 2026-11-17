extends PhysicsTestCase
## The feel probe's kit (tools/feel_scripts.gd, feel_run.gd, feel_camera_log.gd): every script it names exists and plays headless on the
## pad (all but those that need a window), a row a tick with every column, and the camera's jerk measured the way the phase reads it.

const FeelScripts := preload("res://tools/feel_scripts.gd")
const FeelRun := preload("res://tools/feel_run.gd")
const FeelCameraLog := preload("res://tools/feel_camera_log.gd")
const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")
const TICKS := 120
const ORIGIN := Vector3(0.0, 0.0, 0.0)

var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)


func test_the_brief_names_every_script() -> void:
	for script_name in ["step", "slalom", "liftoff", "trail", "power", "hairpin", "catch", "crash15", "crash45", "crash90", "land", "flick"]:
		var drive := FeelScripts.script(script_name)
		assert_false(drive.is_empty(), script_name)
		assert_gt(FeelScripts.seconds(drive), 1.0, script_name)
	assert_true(FeelScripts.script("nothing").is_empty())


func test_inputs_follow_the_phases() -> void:
	var step := FeelScripts.script("step")
	assert_eq(FeelScripts.phase_at(step, 0.1), 0)
	assert_eq(float(FeelScripts.inputs(step, 0.1).steer), 0.0, "the run-up is straight")
	assert_eq(float(FeelScripts.inputs(step, 0.6).steer), 0.5, "half lock")
	assert_eq(FeelScripts.phase_at(step, 100.0), -1)
	var slalom := FeelScripts.script("slalom")
	assert_almost_eq(float(FeelScripts.inputs(slalom, FeelScripts.RUN_UP + 0.5).steer), 0.5, 0.001, "the sine's crest a quarter period in")
	assert_almost_eq(float(FeelScripts.inputs(slalom, FeelScripts.RUN_UP + 1.5).steer), -0.5, 0.001, "and its trough")


func test_a_crash_starts_at_its_angle_to_the_wall() -> void:
	for angle: float in [15.0, 45.0, 90.0]:
		var start := FeelScripts.crash_start(angle)
		var way := -start.basis.z
		assert_almost_eq(rad_to_deg(asin(-way.z)), angle, 0.01, "the angle to the wall's face")
		assert_almost_eq((start.origin + way * FeelScripts.CRASH_RUN_UP).length(), 0.0, 0.001, "it runs into the wall's point")


func test_the_camera_jerk_is_the_second_difference_of_its_turn() -> void:
	var turn := FeelCameraLog.turn(Basis(), Basis(Vector3.UP, deg_to_rad(2.0)))
	assert_almost_eq(turn.y, 2.0, 0.0001, "two degrees to the left about up")
	assert_almost_eq(FeelCameraLog.turn(Basis(), Basis(Vector3.RIGHT, deg_to_rad(0.05))).x, 0.05, 0.0005, "a twentieth of a degree")
	assert_almost_eq(FeelCameraLog.turn(Basis(Vector3.UP, deg_to_rad(179.0)), Basis(Vector3.UP, deg_to_rad(-179.0))).y, 2.0, 0.001,
		"the short way round")
	var values := PackedFloat32Array()
	for i in 100:
		values.append(float(i + 1))
	assert_eq(FeelCameraLog.percentile(values, 0.5), 50.0)
	assert_eq(FeelCameraLog.percentile(values, 0.99), 99.0)
	assert_eq(FeelCameraLog.percentile(PackedFloat32Array(), 0.99), 0.0)
	# A camera that turns at a steady rate has no jerk; one that stops dead has the rate it lost.
	var camera := Camera3D.new()
	_world.add_child(camera)
	var logger: Node = FeelCameraLog.new()
	logger.camera = camera
	_world.add_child(logger)
	for i in 6:
		camera.global_basis = Basis(Vector3.UP, deg_to_rad(1.0 * i))
		logger._process(1.0 / 60.0)
	for i in 3:
		logger._process(1.0 / 60.0)
	assert_eq(logger.jerks.size(), 7)
	assert_almost_eq(logger.jerks[0], 0.0, 0.001, "steady")
	assert_almost_eq(logger.summary().p99, 1.0, 0.001, "the stop")


## Each script headless on the pad, as the probe plays it: a row every tick with every column, and what each is for happens.
func test_every_script_plays_headless() -> void:
	FeelRun.build_pad(_world, ORIGIN)
	var car: RallyCar = CAR_SCENE.instantiate()
	car.position = ORIGIN + Vector3.UP
	_world.add_child(car)
	var columns := FeelRun.TICK_HEADER.split(",").size()
	var folder := OS.get_user_data_dir().path_join("feel_test")
	for script_name in FeelScripts.NAMES:
		if script_name in FeelScripts.NEEDS_WINDOW:
			continue
		var run := FeelRun.new(car, script_name, ORIGIN, SteeringInput.Device.KEYBOARD if script_name == "step" else -1)
		while not run.done:
			run.tick(1.0 / TICKS)
			await wait_ticks(1)
		var expected := roundi(FeelScripts.seconds(run.drive) * TICKS)
		assert_almost_eq(run.rows.size() - 1, expected, 2, "%s: a row a tick" % script_name)
		assert_eq(run.rows[-1].split(",").size(), columns, "%s: every column" % script_name)
		var path := folder.path_join(script_name + ".csv")
		assert_eq(run.write(path), OK)
		assert_true(FileAccess.file_exists(path), "%s: its CSV" % script_name)
		DirAccess.remove_absolute(path)
		var peaks := _peaks(run.rows)
		gut.p("%s: peak yaw %.0f deg/s, slip %.1f deg, impact %.1f m/s, airborne ticks %d" % [script_name, peaks.yaw_dps, peaks.slip_deg,
			peaks.impact, peaks.airborne])
		if script_name.begins_with("crash"):
			assert_gt(peaks.impact, 3.0, "%s hits the wall" % script_name)
		elif script_name == "land":
			assert_gt(peaks.airborne, 10, "off the ledge")
		elif script_name == "catch":
			assert_gt(peaks.slip_deg, 15.0, "the slide begins")
		else:
			assert_eq(peaks.impact, 0.0, "%s: the pad is clear" % script_name)
	DirAccess.remove_absolute(folder)  # empty by now


func _peaks(rows: PackedStringArray) -> Dictionary:
	var columns := FeelRun.TICK_HEADER.split(",")
	var peaks := {"yaw_dps": 0.0, "slip_deg": 0.0, "impact": 0.0, "airborne": 0}
	for i in range(1, rows.size()):
		var cells := rows[i].split(",")
		for column: String in ["yaw_dps", "slip_deg", "impact"]:
			peaks[column] = maxf(peaks[column], absf(float(cells[columns.find(column)])))
		if int(cells[columns.find("wheels")]) == 0:
			peaks.airborne += 1
	return peaks
