extends GutTest
## What a crew member's hands and head do (CrewRules, pure): a seat's state on the wire, a gesture shown long enough to be seen, jobs that
## end, which hand holds what for each seat, when the driver steers with one hand, and the gestures' own keys and buttons.

const Hand := CrewRules.Hand
const DRIVER := RosterRules.Role.DRIVER
const NAVIGATOR := RosterRules.Role.NAVIGATOR


func _hands(role: int, seat: CrewRules.Seat, fainted := false, map_open := false, horn := false, handbrake := false) -> Array:
	return Array(CrewRules.hands(role, seat, fainted, map_open, horn, handbrake))


func test_a_seat_crosses_the_wire_in_four_bytes() -> void:
	var seat := CrewRules.Seat.new()
	seat.look = Vector2(37.4, -22.6)
	seat.point(CrewRules.Gesture.RIGHT)
	seat.start_job(CrewRules.Job.THROW)
	seat.aiming = true
	var packed := seat.pack()
	assert_eq(packed.size(), 4)
	var mirror := CrewRules.Seat.new()
	assert_true(mirror.unpack(packed))
	assert_eq(mirror.look, Vector2(37.0, -23.0), "the look in whole degrees")
	assert_eq(mirror.gesture, CrewRules.Gesture.RIGHT)
	assert_eq(mirror.job, CrewRules.Job.THROW)
	assert_eq(mirror.jobs, 1)
	assert_true(mirror.aiming)
	seat.look = Vector2(300.0, -300.0)
	seat.aiming = false
	assert_true(mirror.unpack(seat.pack()))
	assert_eq(mirror.look, Vector2(127.0, -127.0), "a look past a byte is held at its end")
	assert_false(mirror.aiming)


func test_what_is_not_a_seat_is_dropped() -> void:
	var mirror := CrewRules.Seat.new()
	mirror.look = Vector2(5.0, 5.0)
	for bad: PackedByteArray in [PackedByteArray([1, 2, 3]), PackedByteArray([1, 2, 0, 0, 0]), PackedByteArray([0, 0, 7, 0]),
			PackedByteArray([0, 0, 15 << 3, 0])]:
		assert_false(mirror.unpack(bad), "%s" % bad)
	assert_eq(mirror.look, Vector2(5.0, 5.0), "and nothing changes")


func test_a_gesture_lasts_while_held_and_long_enough_to_be_seen() -> void:
	var seat := CrewRules.Seat.new()
	seat.point(CrewRules.Gesture.LEFT)
	seat.release(CrewRules.Gesture.LEFT)
	seat.step(CrewRules.GESTURE_SECONDS - 0.1)
	assert_eq(seat.gesture, CrewRules.Gesture.LEFT, "a tap still shows")
	seat.step(0.2)
	assert_eq(seat.gesture, CrewRules.Gesture.NONE)
	seat.point(CrewRules.Gesture.SLOW)
	seat.step(CrewRules.GESTURE_SECONDS * 3.0)
	assert_eq(seat.gesture, CrewRules.Gesture.SLOW, "held, it stays")
	seat.release(CrewRules.Gesture.LEFT)
	seat.step(0.1)
	assert_eq(seat.gesture, CrewRules.Gesture.SLOW, "another key coming up does not end it")
	seat.release(CrewRules.Gesture.SLOW)
	seat.step(0.01)
	assert_eq(seat.gesture, CrewRules.Gesture.NONE, "let go after its moment, it ends")


func test_a_job_ends_and_each_one_counts() -> void:
	var seat := CrewRules.Seat.new()
	seat.start_job(CrewRules.Job.THROW)
	seat.step(float(CrewRules.JOB_SECONDS[CrewRules.Job.THROW]) - 0.05)
	assert_eq(seat.job, CrewRules.Job.THROW)
	seat.step(0.1)
	assert_eq(seat.job, CrewRules.Job.NONE)
	seat.start_job(CrewRules.Job.THROW)
	assert_eq(seat.jobs, 2, "a second can is a new job")
	assert_eq(CrewRules.JOB_SECONDS[CrewRules.Job.WINDOW_LEFT], Cabin.PANE_SECONDS, "a window is wound while its pane moves")
	seat.jobs = 255
	seat.start_job(CrewRules.Job.KICK)
	assert_eq(seat.jobs, 0, "the count fits a byte")


func test_the_drivers_hands() -> void:
	var seat := CrewRules.Seat.new()
	assert_eq(_hands(DRIVER, seat), [Hand.WHEEL, Hand.WHEEL], "both on the wheel")
	assert_eq(_hands(DRIVER, seat, false, false, false, true), [Hand.WHEEL, Hand.HANDBRAKE], "the right pulls the handbrake")
	assert_eq(_hands(DRIVER, seat, false, false, true, false), [Hand.WHEEL, Hand.HORN], "and presses the horn")
	assert_eq(_hands(DRIVER, seat, false, false, true, true), [Hand.WHEEL, Hand.HANDBRAKE], "the handbrake first")
	seat.start_job(CrewRules.Job.WINDOW_LEFT)
	assert_eq(_hands(DRIVER, seat), [Hand.WINDOW, Hand.WHEEL], "the left winds the window")
	seat.start_job(CrewRules.Job.WIPERS)
	assert_eq(_hands(DRIVER, seat), [Hand.WHEEL, Hand.WIPERS], "the right flicks the wipers' stalk")
	seat.job = CrewRules.Job.NONE
	seat.point(CrewRules.Gesture.STRAIGHT)
	assert_eq(_hands(DRIVER, seat), [Hand.WHEEL, Hand.POINT], "the driver points with the hand nearer the navigator")
	seat.aiming = true
	assert_eq(_hands(DRIVER, seat), [Hand.WHEEL, Hand.GUN], "the gun before a gesture")
	assert_eq(_hands(DRIVER, seat, true), [Hand.LAP, Hand.LAP], "out cold, both drop")


func test_the_navigators_hands() -> void:
	var seat := CrewRules.Seat.new()
	assert_eq(_hands(NAVIGATOR, seat), [Hand.LAP, Hand.LAP], "on the lap")
	assert_eq(_hands(NAVIGATOR, seat, false, true), [Hand.MAP, Hand.MAP], "the map takes both hands")
	assert_eq(_hands(NAVIGATOR, seat, false, false, true, true), [Hand.LAP, Hand.LAP], "the horn and the handbrake are the driver's")
	seat.point(CrewRules.Gesture.LEFT)
	assert_eq(_hands(NAVIGATOR, seat, false, true), [Hand.POINT, Hand.LAP], "a gesture with the hand nearer the driver: the map folds")
	seat.start_job(CrewRules.Job.THROW)
	assert_eq(_hands(NAVIGATOR, seat), [Hand.POINT, Hand.THROW], "one hand points while the other throws")
	seat.start_job(CrewRules.Job.WINDOW_LEFT)
	assert_eq(_hands(NAVIGATOR, seat), [Hand.WINDOW, Hand.LAP], "reaching across for the driver's window: no gesture meanwhile")
	seat.release(CrewRules.Gesture.LEFT)
	seat.step(CrewRules.GESTURE_SECONDS)
	seat.start_job(CrewRules.Job.WINDOW_RIGHT)
	assert_eq(_hands(NAVIGATOR, seat, false, true), [Hand.LAP, Hand.WINDOW], "the own window with the right")
	seat.job = CrewRules.Job.NONE
	seat.aiming = true
	assert_eq(_hands(NAVIGATOR, seat, false, true), [Hand.LAP, Hand.GUN], "the gun in the right hand")


func test_the_driver_steers_with_one_hand_while_the_other_is_busy() -> void:
	for held: Array in [[Hand.WHEEL, Hand.GUN], [Hand.WHEEL, Hand.POINT], [Hand.WINDOW, Hand.WHEEL], [Hand.WHEEL, Hand.WIPERS], [Hand.WHEEL, Hand.HORN]]:
		assert_true(CrewRules.one_handed(DRIVER, PackedInt32Array(held)), "%s" % [held])
	for held: Array in [[Hand.WHEEL, Hand.WHEEL], [Hand.WHEEL, Hand.HANDBRAKE], [Hand.LAP, Hand.LAP]]:
		assert_false(CrewRules.one_handed(DRIVER, PackedInt32Array(held)), "%s" % [held])
	assert_false(CrewRules.one_handed(NAVIGATOR, PackedInt32Array([Hand.LAP, Hand.GUN])), "the navigator does not steer")


func test_no_gesture_out_cold_or_with_the_gun_up() -> void:
	var seat := CrewRules.Seat.new()
	assert_true(CrewRules.can_gesture(seat, false))
	assert_false(CrewRules.can_gesture(seat, true))
	seat.aiming = true
	assert_false(CrewRules.can_gesture(seat, false))


func test_the_gestures_have_keys_and_buttons_of_their_own_and_can_be_rebound() -> void:
	InputMap.load_from_project_settings()
	for action: StringName in CrewRules.GESTURE_ACTIONS:
		assert_true(Settings.REBINDABLE.has(action), "%s is rebindable" % action)
		for locale in ["tr", "en"]:
			var text := TranslationServer.get_translation_object(locale).get_message("ACTION_%s" % action)
			assert_ne(String(text), "", "%s named in %s" % [action, locale])
		var keys := 0
		var buttons := 0
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys += 1
			elif event is InputEventJoypadButton:
				buttons += 1
			for other in InputMap.get_actions():
				if other == action or String(other).begins_with("ui_"):
					continue
				for theirs in InputMap.action_get_events(other):
					assert_false(event.is_match(theirs, true), "%s shares %s with %s" % [action, event.as_text(), other])
		assert_eq(keys, 1, "%s has a key" % action)
		assert_eq(buttons, 1, "%s has a gamepad button" % action)
