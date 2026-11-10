extends GutTest
## How dirty a car gets from the road (CarDirtRules): pure numbers. Spec A4 item 3: readable at the start, visibly filthy by the end of a stage,
## by surface, by speed; a splash rinses part of it.

const TICK := 1.0 / 120.0
const STAGE_SPEED := 20.0


## The level of `surface`'s layer after `metres` at `speed`, from `level`.
func _drive(surface: StringName, metres: float, speed := STAGE_SPEED, level := 0.0) -> float:
	for tick in int(metres / (speed * TICK)):
		level = CarDirtRules.gathered(level, surface, speed, TICK)
	return level


func test_a_stage_of_gravel_leaves_the_car_filthy_but_its_start_clean() -> void:
	var start := _drive(Surface.GRAVEL, 300.0)
	var half := _drive(Surface.GRAVEL, 1500.0)
	var whole := _drive(Surface.GRAVEL, 3000.0)
	gut.p("dust at %.0f m/s: %.2f after 300 m, %.2f after 1.5 km, %.2f after 3 km" % [STAGE_SPEED, start, half, whole])
	assert_lt(start, 0.25, "only the sills after the first bends")
	assert_between(whole, 0.85, 0.96, "filthy at the finish, never more than the car can hold")
	assert_gt(_drive(Surface.GRAVEL, 2200.0, 17.0), 0.75, "a short stage at a bot's pace too")


func test_each_surface_leaves_its_own_layer_and_tarmac_nothing() -> void:
	for surface: StringName in [Surface.GRAVEL, Surface.DIRT, Surface.SAND]:
		assert_eq(CarDirtRules.layer_of(surface), CarDirtRules.Layer.DUST, String(surface))
	assert_eq(CarDirtRules.layer_of(Surface.MUD), CarDirtRules.Layer.MUD)
	assert_eq(CarDirtRules.layer_of(Surface.WET), CarDirtRules.Layer.MUD, "a wet road throws muddy water")
	assert_eq(CarDirtRules.layer_of(Surface.SNOW), CarDirtRules.Layer.SNOW)
	assert_eq(CarDirtRules.layer_of(Surface.TARMAC), -1)
	assert_eq(_drive(Surface.TARMAC, 2000.0), 0.0)


func test_mud_covers_a_car_far_sooner_than_dust() -> void:
	var mud := _drive(Surface.MUD, 300.0)
	gut.p("mud after a 300 m stretch: %.2f, dust %.2f" % [mud, _drive(Surface.GRAVEL, 300.0)])
	assert_gt(mud, 0.5, "one muddy stretch is enough")
	assert_gt(mud, _drive(Surface.GRAVEL, 300.0) * 2.5)


func test_a_crawl_throws_less_at_the_car_than_rally_speed() -> void:
	assert_lt(_drive(Surface.GRAVEL, 500.0, 4.0), _drive(Surface.GRAVEL, 500.0) * 0.5, "per metre driven")
	assert_eq(CarDirtRules.gathered(0.3, Surface.GRAVEL, 0.0, 1.0), 0.3, "standing still")


func test_it_slows_down_as_the_car_fills_up_and_never_passes_one() -> void:
	var first := _drive(Surface.GRAVEL, 500.0)
	var later := _drive(Surface.GRAVEL, 500.0, STAGE_SPEED, 0.7) - 0.7
	assert_lt(later, first * 0.5)
	assert_lte(_drive(Surface.MUD, 20000.0), 1.0)


func test_a_splash_washes_the_lower_half_and_the_road_brings_it_back() -> void:
	var washed := 0.0
	for tick in 120:
		washed = CarDirtRules.rinsed(washed, 14.0, TICK)
	gut.p("a second through a splash at 50 km/h washes %.2f of the lower half" % washed)
	assert_gt(washed, 0.8)
	for tick in int(CarDirtRules.WASH_LASTS * 0.5 / (STAGE_SPEED * TICK)):
		washed = CarDirtRules.soiled(washed, Surface.GRAVEL, STAGE_SPEED, TICK)
	assert_between(washed, 0.2, 0.7, "half way back after half the distance")
	assert_eq(CarDirtRules.soiled(0.5, Surface.TARMAC, STAGE_SPEED, 10.0), 0.5, "tarmac does not soil it again")
