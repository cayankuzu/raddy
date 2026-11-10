extends GutTest
## The light pod a car wears for a stage at dusk or at night (CarLightPod), on the real car (headless): only then, bolted to the
## bonnet (it lifts with a loose one and goes, dark, with a torn-off one), lit with the headlights, its beam one of theirs (the
## time of day's strength, shadows for the seat's car on High), its fairing in the team colour, its light long in the middle and
## wide at the sides.

var _car: RallyCar
var _lamps: CarLamps
var _fx: CarDamageFx


func before_each() -> void:
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, RaceSettings.TimeOfDay.NIGHT).free()
	_spawn()


func after_each() -> void:
	RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR).free()


func _spawn() -> void:
	# The car makes the scene's RoadFxPool beside itself: it goes with this world after each test.
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	world.add_child(_car)
	_lamps = (_car.get_node(^"Model") as CarModel).lamps
	_fx = _car.get_node(^"Model/DamageFx") as CarDamageFx


func _damage(front: float) -> VehicleDamage:
	var damage := VehicleDamage.new()
	damage.zones[VehicleDamage.Zone.FRONT] = front
	return damage


## The bonnet's triangles in car space.
func _bonnet() -> PackedVector3Array:
	var to_car := _car.global_transform.affine_inverse()
	var triangles := PackedVector3Array()
	for node in _car.get_node(^"Model/DamageFx/Hood").get_children():
		var part := node as MeshInstance3D
		if part == null:
			continue
		for v in part.mesh.get_faces():
			triangles.append(to_car * part.global_transform * v)
	return triangles


## The bonnet's height under `at` (car space), or -INF where it is not.
func _bonnet_under(triangles: PackedVector3Array, at: Vector3) -> float:
	var top := -INF
	for i in range(0, triangles.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(at.x, 3.0, at.z), Vector3.DOWN, triangles[i], triangles[i + 1], triangles[i + 2])
		if hit != null:
			top = maxf(top, (hit as Vector3).y)
	return top


func test_a_car_wears_one_for_a_stage_at_dusk_or_at_night_only() -> void:
	for time in RaceSettings.TimeOfDay.values():
		RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.CLEAR, time).free()
		_spawn()
		assert_eq(_lamps.pod != null, time >= RaceSettings.TimeOfDay.DUSK, "time of day %d" % time)
	RaceLook.create(RaceSettings.Biome.MOUNTAIN, RaceSettings.Weather.SNOW, RaceSettings.TimeOfDay.NIGHT).free()
	_spawn()
	assert_not_null(_lamps.pod, "in snow too")
	assert_almost_eq(_lamps.pod.beam.light_energy, CarLightPod.BEAM_ENERGY * RaceLook.LAMP_IN_SNOW, 0.01, "its light as weak as the headlights' there")


func test_it_is_bolted_to_the_bonnet() -> void:
	var pod := _lamps.pod
	assert_eq(pod.get_parent(), _car.get_node(^"Model/DamageFx/Hood"), "it rides on the bonnet's hinge")
	var to_car := _car.global_transform.affine_inverse() * pod.body.global_transform
	assert_true(to_car.basis.is_equal_approx(Basis.IDENTITY), "level, its lamps along the car")
	assert_true(to_car.origin.is_equal_approx(CarLightPod.MOUNT), "where it was measured to sit")
	var bonnet := _bonnet()
	var lowest_gap := INF
	var legs: Array[float] = []
	for v in pod.body.mesh.get_faces():
		var at := to_car * v
		var under := _bonnet_under(bonnet, at)
		if under == -INF:
			continue
		if absf(absf(at.x) - CarLightPod.LEG_X) <= CarLightPod.LEG_SIZE.x * 0.5 + 0.001 and v.y < -CarLightPod.HALF_HEIGHT:
			legs.append(at.y - under)
		else:
			lowest_gap = minf(lowest_gap, at.y - under)
	gut.p("the pod clears the bonnet by %.1f cm at least; its legs end %.1f to %.1f cm from it" % [lowest_gap * 100.0, legs.min() * 100.0, legs.max() * 100.0])
	assert_gt(lowest_gap, 0.005, "nothing of it sinks into the bonnet")
	assert_lt(lowest_gap, 0.04, "it sits on it, not above it")
	assert_lt(legs.min(), 0.0, "the legs reach the bonnet")
	assert_gt(legs.min(), -0.04, "and are bolted to it, not through it")


func test_it_lights_with_the_headlights_and_its_beam_is_one_of_theirs() -> void:
	var pod := _lamps.pod
	_lamps.set_headlights(true)
	assert_true(pod.beam.visible, "on with the headlights")
	assert_eq(pod.material.get_shader_parameter(&"lit"), 1.0, "its glass glows")
	assert_almost_eq(pod.beam.light_energy, CarLightPod.BEAM_ENERGY * RaceLook.lamp_light, 0.01)
	assert_eq(pod.beam.light_projector, CarLightPod.beam_texture(), "its pattern through a projector, as the headlights'")
	assert_eq(pod.beam.shadow_caster_mask, CarLamps.HULL_LAYER, "the other cars' hulls stop it")
	assert_eq(pod.beam.light_cull_mask, CarLamps.OUTSIDE_THE_CABINS, "it lights no cabin")
	_lamps.cast_shadows(true)
	assert_ne(pod.beam.shadow_caster_mask & 1, 0, "the seat's own car on High: real shadows, as its headlights'")
	_lamps.cast_shadows(false)
	_lamps.set_headlights(false)
	assert_false(pod.beam.visible)
	assert_eq(pod.material.get_shader_parameter(&"lit"), 0.0)
	assert_eq(pod.body.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "nothing it could shade at night")


func test_a_loose_bonnet_lifts_it_and_a_torn_off_one_takes_it_away_dark() -> void:
	var pod := _lamps.pod
	_lamps.set_headlights(true)
	var aimed := -pod.beam.global_basis.z
	_car.apply_damage(_damage(CarDamageFx.HOOD_LOOSE + 1.0))
	_car.forward_speed = 25.0
	_fx._process(0.016)
	var lifted := -pod.beam.global_basis.z
	gut.p("a loose bonnet at 90 km/h aims the pod %.0f degrees up" % rad_to_deg(aimed.angle_to(lifted)))
	assert_gt(lifted.y, aimed.y + 0.5, "the wind lifts the bonnet and the pod shines into the sky")
	assert_true(_fx._parts[&"hood"].meshes.has(pod.body), "the bonnet that tears off takes the pod with it")
	_car.apply_damage(_damage(CarDamageFx.HOOD_GONE + 1.0))
	_lamps._process(0.016)
	assert_false(pod.beam.is_visible_in_tree(), "no light left on the car")
	assert_eq(pod.material.get_shader_parameter(&"lit"), 0.0, "and the glass that flies off is dark: its wires are torn")
	_car.apply_damage(_damage(0.0))
	_lamps._process(0.016)
	assert_true(pod.beam.is_visible_in_tree(), "a recovery bolts it back on")
	assert_eq(pod.material.get_shader_parameter(&"lit"), 1.0, "lit again")


func test_its_fairing_takes_the_team_colour() -> void:
	_car.set_paint(TeamColors.paint(2))
	assert_eq(_lamps.pod.material.get_shader_parameter(&"paint"), TeamColors.paint(2))


func test_a_copy_played_back_from_snapshots_wears_one_too() -> void:
	_car.set_simulated(false)
	_lamps.set_headlights(true)
	assert_true(_lamps.pod.beam.visible, "every peer sees every car's pod")


## The pattern: the spot lamps reach far in the middle, the wide lamps light a corner's side; the near road and the sky get little.
func test_its_light_is_long_in_the_middle_and_wide_at_the_sides() -> void:
	var pod := CarLightPod.beam_pattern()
	var at := func(across: float, up: float) -> float:
		var reach := tan(deg_to_rad(CarLightPod.BEAM_ANGLE))
		var x := clampi(int((tan(deg_to_rad(across)) / reach * 0.5 + 0.5) * pod.get_width()), 0, pod.get_width() - 1)
		var y := clampi(int((0.5 - tan(deg_to_rad(up)) / reach * 0.5) * pod.get_height()), 0, pod.get_height() - 1)
		return pod.get_pixel(x, y).srgb_to_linear().r
	# From a lamp 0.8 m up: the road 100 m ahead lies 0.5 degrees under it, a corner's side 40 m off 35 degrees across and 1.2 down.
	var far: float = at.call(0.0, -0.5)
	var side: float = at.call(35.0, -1.2)
	var edge := 0.8 / tan(deg_to_rad(-CarLightPod.LONG_BAND.x))
	var near: float = at.call(0.0, -rad_to_deg(atan(0.8 / 15.0)))
	gut.p("the pod's pattern: %.2f 100 m ahead, %.3f on a corner's side 40 m off, %.3f 15 m ahead" % [far, side, near])
	assert_gt(far, 0.95, "the spot lamps' band lies on the road far ahead")
	assert_gt(side, 0.05, "the wide lamps light a corner's side")
	assert_lt(CarLamps.BEAM_ANGLE, 35.0, "where the headlights' cone does not reach")
	assert_lt(at.call(0.0, 8.0), 0.05, "little into the sky")
	assert_eq(at.call(0.0, -20.0), 0.0, "nothing under the nose")
	# The light on the road goes as the pattern over the square of the distance (the falloff, and the angle it meets the road at).
	assert_lt(near / (15.0 * 15.0), 2.0 / (edge * edge), "the road 15 m ahead no blaze beside the far road: the pattern falls as the square of the angle")
