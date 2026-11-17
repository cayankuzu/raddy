extends GutTest
## The feel presets (VehicleConfig.FEEL_A2): phase F's changes are config values, A2's feel one arg away (--feel-preset=a2), the car's
## own config left as it is.

const CONFIG := preload("res://data/vehicles/rally_hatch.tres")


func test_a2_puts_back_every_value_phase_f_changed() -> void:
	var a2 := CONFIG.with_feel("a2")
	assert_ne(a2, CONFIG, "a copy")
	for key: String in VehicleConfig.FEEL_A2:
		assert_eq(a2.get(key), VehicleConfig.FEEL_A2[key], key)
		assert_ne(CONFIG.get(key), VehicleConfig.FEEL_A2[key], "%s: the new feel differs" % key)
	assert_eq(a2.mass, CONFIG.mass, "the rest is the car's")


func test_no_preset_is_the_config_itself() -> void:
	assert_eq(CONFIG.with_feel(""), CONFIG)
	assert_eq(CONFIG.with_feel("nonsense"), CONFIG)
	assert_eq(VehicleConfig.preset_from_args(), "", "the test run asks for none")
