extends GutTest
## How a crew member's head swings with the car (CrewSway, pure): out of a corner, forward under braking, a jolt on a hit that settles,
## nothing from a car first seen already moving, and the same from a car played back from snapshots, whose velocity changes a frame's
## ticks at once.

const TICK := 1.0 / 120.0


## Follows a car through `seconds` of `motion` (a Callable: time -> [velocity, turn]) and returns the head's tilt over each tick. With
## `ticks_a_frame` above 1 the car is a snapshot's: what it does is known once a frame, and that many ticks see the same.
func _ride(sway: CrewSway, seconds: float, motion: Callable, ticks_a_frame := 1) -> Array[Vector2]:
	var tilts: Array[Vector2] = []
	var state: Array = []
	for tick in roundi(seconds / TICK):
		if tick % ticks_a_frame == 0:
			state = motion.call(tick * TICK)
		sway.follow(state[0], state[1], TICK)
		tilts.append(sway.tilt)
	return tilts


## The mean of the last `count` tilts: a snapshot's car pushes the head once a frame, it trembles a little round where it is held.
func _settled(tilts: Array[Vector2], count := 60) -> Vector2:
	var sum := Vector2.ZERO
	for tilt: Vector2 in tilts.slice(-count):
		sum += tilt / count
	return sum


## A left turn at `speed` at a steady g, round a centre on the car's left.
func _left_turn(speed: float) -> Callable:
	var radius := speed * speed / 9.81
	return func(time: float) -> Array:
		var turn := Basis(Vector3.UP, time * speed / radius)
		return [turn * Vector3(0.0, 0.0, -speed), turn]


## Along -Z from 25 m/s, slowing (`way` 1) or speeding up (-1) at 0.8 g.
func _braking(way: float) -> Callable:
	return func(time: float) -> Array:
		return [Vector3(0.0, 0.0, -(25.0 - way * 0.8 * 9.81 * time)), Basis.IDENTITY]


func test_a_corner_tilts_the_head_out_of_it() -> void:
	for looseness: float in [1.0, 1.3]:
		var tilts := _ride(CrewSway.new(looseness), 3.0, _left_turn(20.0))
		gut.p("a 1 g left turn, neck %.1f: the head %.2f degrees to the right, %.2f up" % [looseness, tilts[-1].x, tilts[-1].y])
		assert_almost_eq(tilts[-1].x, CrewSway.TILT_PER_G.x * looseness, 0.3, "out of the corner, by its g")
		assert_almost_eq(tilts[-1].y, 0.0, 0.3)


func test_braking_nods_the_head_and_pulling_away_presses_it_back() -> void:
	for way: float in [1.0, -1.0]:
		var tilts := _ride(CrewSway.new(), 1.5, _braking(way))
		gut.p("%s at 0.8 g: the head %.2f degrees up" % ["braking" if way > 0.0 else "pulling away", tilts[-1].y])
		assert_almost_eq(tilts[-1].y, -way * 0.8 * CrewSway.TILT_PER_G.y, 0.3)


func test_a_hit_jolts_the_head_and_it_settles() -> void:
	# At 20 m/s along -Z, then stopped dead by a wall in one tick.
	var crash := func(time: float) -> Array:
		return [Vector3(0.0, 0.0, -20.0 if time < 0.5 else 0.0), Basis.IDENTITY]
	var tilts := _ride(CrewSway.new(), 3.0, crash)
	var most := 0.0
	for tilt in tilts:
		most = minf(most, tilt.y)
	gut.p("stopped dead from 20 m/s: the head nods %.1f degrees, %.2f after 2.5 s" % [most, tilts[-1].y])
	assert_lt(most, -4.0, "a jolt to see")
	assert_gt(most, -CrewSway.MOST_TILT - 0.01, "not thrown about")
	assert_lt(absf(tilts[-1].y), 0.3, "settled")


func test_nothing_to_feel_from_a_car_first_seen_moving() -> void:
	var sway := CrewSway.new()
	var cruising := func(_time: float) -> Array:
		return [Vector3(0.0, 0.0, -30.0), Basis.IDENTITY]
	for tilt in _ride(sway, 1.0, cruising):
		assert_lt(tilt.length(), 0.01, "first seen at 30 m/s and keeping it: no jolt")
	sway.tilt = Vector2(5.0, 5.0)
	sway.settle()
	assert_eq(sway.tilt, Vector2.ZERO, "unseen, the head rests upright")
	for tilt in _ride(sway, 0.5, cruising):
		assert_lt(tilt.length(), 0.01, "seen again at speed: no jolt either")


func test_a_car_played_back_from_snapshots_swings_the_head_the_same() -> void:
	# At 60, 40 and 30 frames a second the engine runs 2, 3 and 4 ticks in a frame, and a snapshot's car changes once in them.
	for ticks_a_frame: int in [2, 3, 4]:
		var corner := _settled(_ride(CrewSway.new(), 3.0, _left_turn(20.0), ticks_a_frame))
		var braking := _settled(_ride(CrewSway.new(), 1.5, _braking(1.0), ticks_a_frame))
		var cruise := _ride(CrewSway.new(), 3.0, func(_time: float) -> Array: return [Vector3(0.0, 0.0, -20.0), Basis.IDENTITY], ticks_a_frame)
		var most := 0.0
		for tilt in cruise:
			most = maxf(most, tilt.length())
		gut.p("%d ticks a frame: a 1 g left turn holds the head %.2f degrees right, braking at 0.8 g %.2f up, a steady 20 m/s moves it %.2f at most" % [
			ticks_a_frame, corner.x, braking.y, most])
		assert_almost_eq(corner.x, CrewSway.TILT_PER_G.x, 0.5, "out of the corner by its g, whatever the frame rate")
		assert_almost_eq(corner.y, 0.0, 0.5)
		assert_almost_eq(braking.y, -0.8 * CrewSway.TILT_PER_G.y, 0.5, "and nodding under braking")
		assert_lt(most, 0.01, "a steady speed swings nothing")
