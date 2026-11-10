extends GutTest
## How a crew member's head swings with the car (CrewSway, pure): out of a corner, forward under braking, a jolt on a hit that settles,
## nothing when the car is put somewhere else or is first seen already moving.

const TICK := 1.0 / 120.0


## Follows a car through `seconds` of `motion` (a Callable: time -> [place, turn]) and returns the head's tilt over each tick.
func _ride(sway: CrewSway, seconds: float, motion: Callable) -> Array[Vector2]:
	var tilts: Array[Vector2] = []
	for tick in roundi(seconds / TICK):
		var state: Array = motion.call(tick * TICK)
		sway.follow(state[0], state[1], TICK)
		tilts.append(sway.tilt)
	return tilts


func test_a_corner_tilts_the_head_out_of_it() -> void:
	var speed := 20.0
	var radius := speed * speed / 9.81
	# A left turn at a steady g, round a centre on the car's left.
	var left_turn := func(time: float) -> Array:
		var angle := time * speed / radius
		return [Vector3(-radius, 0.0, 0.0) + Basis(Vector3.UP, angle) * Vector3(radius, 0.0, 0.0), Basis(Vector3.UP, angle)]
	for looseness: float in [1.0, 1.3]:
		var tilts := _ride(CrewSway.new(looseness), 3.0, left_turn)
		gut.p("a 1 g left turn, neck %.1f: the head %.2f degrees to the right, %.2f up" % [looseness, tilts[-1].x, tilts[-1].y])
		assert_almost_eq(tilts[-1].x, CrewSway.TILT_PER_G.x * looseness, 0.3, "out of the corner, by its g")
		assert_almost_eq(tilts[-1].y, 0.0, 0.3)


func test_braking_nods_the_head_and_pulling_away_presses_it_back() -> void:
	for way: float in [1.0, -1.0]:
		# Along -Z at 25 m/s, slowing (or speeding up) at 0.8 g.
		var driving := func(time: float) -> Array:
			return [Vector3(0.0, 0.0, -(25.0 * time - way * 0.5 * 0.8 * 9.81 * time * time)), Basis.IDENTITY]
		var tilts := _ride(CrewSway.new(), 1.5, driving)
		gut.p("%s at 0.8 g: the head %.2f degrees up" % ["braking" if way > 0.0 else "pulling away", tilts[-1].y])
		assert_almost_eq(tilts[-1].y, -way * 0.8 * CrewSway.TILT_PER_G.y, 0.3)


func test_a_hit_jolts_the_head_and_it_settles() -> void:
	# At 20 m/s along -Z, then stopped dead by a wall in one tick.
	var crash := func(time: float) -> Array:
		return [Vector3(0.0, 0.0, -20.0 * minf(time, 0.5)), Basis.IDENTITY]
	var tilts := _ride(CrewSway.new(), 3.0, crash)
	var most := 0.0
	for tilt in tilts:
		most = minf(most, tilt.y)
	gut.p("stopped dead from 20 m/s: the head nods %.1f degrees, %.2f after 2.5 s" % [most, tilts[-1].y])
	assert_lt(most, -4.0, "a jolt to see")
	assert_gt(most, -CrewSway.MOST_TILT - 0.01, "not thrown about")
	assert_lt(absf(tilts[-1].y), 0.3, "settled")


func test_nothing_to_feel_from_a_recovery_or_a_car_first_seen_moving() -> void:
	var sway := CrewSway.new()
	var cruising := func(time: float) -> Array:
		return [Vector3(0.0, 0.0, -30.0 * time) + (Vector3(400.0, 0.0, 0.0) if time > 0.5 else Vector3.ZERO), Basis.IDENTITY]
	var tilts := _ride(sway, 1.0, cruising)
	for tilt in tilts:
		assert_lt(tilt.length(), 0.01, "first seen at 30 m/s, then put 400 m away: no jolt")
	sway.tilt = Vector2(5.0, 5.0)
	sway.settle()
	assert_eq(sway.tilt, Vector2.ZERO, "unseen, the head rests upright")
