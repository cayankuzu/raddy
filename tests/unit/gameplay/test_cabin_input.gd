extends GutTest
## The local seat's keys on the real car (CabinInput, ShockInput): a gesture and the shock gun are held as long as their key is, and are
## let go when the key came up while the window had lost the keyboard (the engine then lets every key go without an event).

const DRIVER := RosterRules.Role.DRIVER

var _car: RallyCar
var _cabin: Cabin


func before_each() -> void:
	InputMap.load_from_project_settings()
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_car.set_simulated(false)
	_cabin = _car.get_node(^"Cabin") as Cabin
	_cabin.local_role = DRIVER


func after_each() -> void:
	for action: StringName in CrewRules.GESTURE_ACTIONS:
		Input.action_release(action)
	Input.action_release(&"shock_aim")


func test_a_gesture_ends_when_its_key_came_up_unseen() -> void:
	var input := CabinInput.new()
	input.cabin = _cabin
	input.role = DRIVER
	add_child_autofree(input)
	var seat: CrewRules.Seat = _cabin.seats[DRIVER]
	var press := InputEventAction.new()
	press.action = &"gesture_left"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(3)
	assert_eq(seat.gesture, CrewRules.Gesture.LEFT, "the key went down: the hand points")
	await wait_seconds(CrewRules.GESTURE_SECONDS + 0.3)
	assert_eq(seat.gesture, CrewRules.Gesture.LEFT, "held, it stays")
	assert_true(CrewRules.one_handed(DRIVER, _cabin.hands_of(DRIVER)), "and the driver steers with one hand")
	# The window loses the keyboard: the key is up, and no event says so.
	Input.action_release(&"gesture_left")
	await wait_process_frames(3)
	assert_eq(seat.gesture, CrewRules.Gesture.NONE, "the key is up: the hand goes back, shown long enough as it was")
	assert_false(CrewRules.one_handed(DRIVER, _cabin.hands_of(DRIVER)), "both hands on the wheel again")
	# A gesture a script holds (route_test --gesture) is no key's: it stays.
	seat.point(CrewRules.Gesture.RIGHT)
	await wait_seconds(CrewRules.GESTURE_SECONDS + 0.3)
	assert_eq(seat.gesture, CrewRules.Gesture.RIGHT)


func test_the_gun_comes_down_when_its_button_came_up_unseen() -> void:
	var input := ShockInput.new()
	input.cabin = _cabin
	input.role = DRIVER
	add_child_autofree(input)
	var seat: CrewRules.Seat = _cabin.seats[DRIVER]
	# As the button going down leaves it (no race here to show the darts of).
	Input.action_press(&"shock_aim")
	input.aiming = true
	seat.aiming = true
	await wait_physics_frames(3)
	assert_true(input.aiming and seat.aiming, "held, the gun stays up")
	Input.action_release(&"shock_aim")
	await wait_physics_frames(3)
	assert_false(input.aiming, "the button is up: the gun comes down")
	assert_false(seat.aiming)
	assert_false(CrewRules.one_handed(DRIVER, _cabin.hands_of(DRIVER)), "and the driver has both hands on the wheel")
