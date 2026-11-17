extends GutTest
## The seat's camera (phase F): on a car played back from the driver's snapshots the head leans with the car as it does on the driver's
## own peer and feels the road, and the mouse turns the head in proportion to the hand however fast it flicks.

var _car: RallyCar
var _start := Transform3D.IDENTITY
var _ticks := 0


func before_each() -> void:
	# The car makes the scene's RoadFxPool beside itself: it goes with this world after each test.
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_car.set_simulated(false)


func test_the_head_leans_and_feels_the_road_in_a_car_played_back_from_snapshots() -> void:
	var camera := _car.get_node(^"NavigatorCamera") as CockpitCamera
	_start = _car.global_transform
	get_tree().physics_frame.connect(_drive)
	await wait_physics_frames(240)
	get_tree().physics_frame.disconnect(_drive)
	var lean := camera.lean()
	gut.p("a copy in a 1 g left turn: the head %.1f cm to the right, %.2f g of lean; road roughness %.2f" % [lean.x * 100.0, lean.y,
		camera.road_roughness()])
	assert_almost_eq(lean.x, CockpitCamera.LEAN_PER_G.x, 0.01, "pushed out of the corner by its g")
	assert_almost_eq(absf(lean.y), 1.0, 0.15, "and rolled by it")
	assert_almost_eq(camera.road_roughness(), 4.0 * 0.3 / CockpitCamera.ROUGH_FULL, 0.05, "the wheels' travel a second, as on the driver's")


func test_the_mouse_turns_the_head_in_proportion_however_fast() -> void:
	var camera := _car.get_node(^"DriverCamera") as CockpitCamera
	camera.turn_head(Vector2(100.0, 0.0))
	var per_100 := -camera.look.x
	assert_gt(per_100, 1.0, "a hand's motion turns the head")
	# Ten flicks of 400 px a frame, one way and back: each turns the head four times as far as 100 px did.
	for i in 10:
		var before := camera.look.x
		camera.turn_head(Vector2(400.0 if i % 2 == 0 else -400.0, 0.0))
		assert_almost_eq(absf(camera.look.x - before), 4.0 * per_100, 0.001, "flick %d in proportion" % i)
	gut.p("100 px turn the head %.2f deg, 400 px %.2f deg" % [per_100, 4.0 * per_100])
	# Only the first motion after the mouse is captured is held to CAPTURE_JUMP (the cursor's jump to the centre).
	camera.look = Vector2.ZERO
	camera.turn_head(Vector2(-2000.0, 0.0), true)
	assert_almost_eq(camera.look.x, per_100 * CockpitCamera.CAPTURE_JUMP / 100.0, 0.001, "the capture's jump is held to a flick")


## A left turn at 1 g, the car told the driver's velocity every tick and put where the snapshots have it once in the three ticks of a 40 fps
## frame (as the wall clock did, before the playback clock: the body's own velocity then is a jolt and two stops); each wheel's spring works
## 0.3 m a second (a 2 cm swing, 7.5 times a second).
func _drive() -> void:
	if not is_instance_valid(_car):
		return  # the last tick's signal can outlive the test
	_ticks += 1
	var speed := 20.0
	var radius := speed * speed / 9.81
	var turn := Basis(Vector3.UP, _ticks / 120.0 * speed / radius)
	var centre := _start.origin - _start.basis.x * radius
	if _ticks % 3 == 0:
		_car.global_transform = Transform3D(turn * _start.basis, centre + turn * (_start.origin - centre))
	var swing := pingpong(_ticks / 120.0 * 0.3, 0.02) + 0.05
	_car.apply_net_extra(PackedFloat32Array([0.0, swing, swing, swing, swing]), turn * _start.basis * Vector3(0.0, 0.0, -speed))
