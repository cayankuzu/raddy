extends GutTest
## The mirrors on the real car (CarMirrors, headless: no viewports, but the aim and the damage are the same):
## aimed for the seat that is bound, the interior one frames the rear window, a door mirror the flank and
## the road behind; a hard side hit breaks a door mirror and a recovery restores it.

var _car: RallyCar
var _model: CarModel
var _mirrors: CarMirrors


func before_each() -> void:
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	add_child_autofree(_car)
	_model = _car.get_node(^"Model") as CarModel
	_mirrors = _model.mirrors


## The glass as it stands now, in car space.
func _now(slot: int) -> MirrorMath:
	var mirror: CarMirrors.Mirror = _mirrors._mirrors[slot]
	var pose := _car.global_transform.affine_inverse() * mirror.glass.global_transform
	var now := MirrorMath.new(pose * mirror.rest.center, pose.basis * mirror.rest.normal, mirror.rest.half_size, Vector3.UP, mirror.rest.convex)
	return now


func _seat(seat_name: NodePath) -> CockpitCamera:
	return _car.get_node(seat_name) as CockpitCamera


func _bounce(mirror: MirrorMath, eye: Vector3) -> Vector3:
	var incoming := (mirror.center - eye).normalized()
	return incoming - mirror.normal * 2.0 * incoming.dot(mirror.normal)


func _side_damage(zone: int, points: float) -> VehicleDamage:
	var damage := VehicleDamage.new()
	damage.zones[zone] = points
	return damage


func test_no_viewports_headless() -> void:
	_model.bind_seat(_seat(^"DriverCamera"))
	assert_eq(_mirrors.find_children("*", "SubViewport", true, false).size(), 0)


func test_the_interior_mirror_frames_the_rear_window_from_either_seat() -> void:
	for seat_name: NodePath in [^"DriverCamera", ^"NavigatorCamera"]:
		var seat := _seat(seat_name)
		_model.bind_seat(seat)
		var glass := _now(CarMirrors.Slot.INTERIOR)
		var look := _bounce(glass, seat.seat_position())
		var rear := glass.center + look * ((CarMirrors.REAR_WINDOW.z - glass.center.z) / look.z)
		gut.p("%s: the mirror's middle sees the rear window at %s" % [seat_name, str(rear.snappedf(0.01))])
		assert_almost_eq(rear.distance_to(CarMirrors.REAR_WINDOW), 0.0, 0.01, "the middle of the glass sees the middle of the window")


func test_a_door_mirror_shows_the_flank_at_its_inner_edge_and_the_road_behind() -> void:
	for seat_name: NodePath in [^"DriverCamera", ^"NavigatorCamera"]:
		var seat := _seat(seat_name)
		_model.bind_seat(seat)
		var eye := seat.seat_position()
		for slot: int in [CarMirrors.Slot.LEFT, CarMirrors.Slot.RIGHT]:
			var glass := _now(slot)
			var look := _bounce(glass, eye)
			assert_gt(look.z, 0.97, "looks back along the car")
			assert_gt(look.x * signf(glass.center.x), 0.0, "out from the car's side, not into it")
			var corner: Vector3 = CarMirrors.FLANK_CORNER[slot]
			# How far across the glass the car's rear corner shows, 0 at the outer edge, 1 at the inner.
			var u := glass.seen_at(corner, eye).x
			var inner := 0.5 + (u - 0.5) / glass.convex
			inner = inner if slot == CarMirrors.Slot.LEFT else 1.0 - inner
			gut.p("%s %s: flank at %.2f across the picture, look %s" % [seat_name, CarMirrors.Slot.keys()[slot], inner, str(look.snappedf(0.01))])
			assert_between(inner, 0.6, 0.85, "the inner part of the picture is the car, the rest the road behind")


func test_a_hard_side_hit_breaks_that_door_mirror_and_a_recovery_restores_it() -> void:
	var left: Node3D = _mirrors.get_node(^"DoorMirrorLeft")
	assert_false(_mirrors.is_broken(CarMirrors.Slot.LEFT))
	_car.apply_damage(_side_damage(VehicleDamage.Zone.LEFT, CarDamageFx.MIRROR_BREAK - 1.0))
	assert_false(_mirrors.is_broken(CarMirrors.Slot.LEFT), "a scrape leaves it")
	_car.apply_damage(_side_damage(VehicleDamage.Zone.LEFT, CarDamageFx.MIRROR_BREAK + 1.0))
	assert_true(_mirrors.is_broken(CarMirrors.Slot.LEFT), "a hard hit on the left breaks the left mirror")
	assert_false(_mirrors.is_broken(CarMirrors.Slot.RIGHT), "not the right one")
	assert_eq(_mirrors._mirrors[CarMirrors.Slot.LEFT].glass.material_override, CarMirrors._broken(), "black cracked glass")
	_mirrors._process(0.016)
	assert_lt(left.basis.y.dot(Vector3.UP), 0.8, "it hangs from its arm")
	var damage := _side_damage(VehicleDamage.Zone.LEFT, 60.0)
	damage.repair_after_recovery()
	_car.apply_damage(damage)
	assert_false(_mirrors.is_broken(CarMirrors.Slot.LEFT), "a recovery restores it")
	assert_almost_eq(left.basis.y.dot(Vector3.UP), 1.0, 0.0001, "back on its arm")
	assert_eq(_mirrors._mirrors[CarMirrors.Slot.LEFT].glass.material_override, CarMirrors._plain())


func test_a_map_held_up_hides_what_is_behind_it() -> void:
	var cabin: Cabin = _car.get_node(^"Cabin")
	var map: PaperMap = cabin.paper_map
	var sheet: MeshInstance3D = map.get_node(^"Sheet")
	var eye := _car.global_transform * Vector3(0.33, 0.64, 0.215)
	var behind := sheet.global_transform * Vector3(0.0, 0.0, -0.5)
	assert_false(map.covers(eye, behind), "folded away it hides nothing")
	cabin.request_map(true)
	sheet.position = PaperMap.HELD_POSITION
	sheet.rotation_degrees = PaperMap.HELD_ROTATION_DEG
	sheet.scale = Vector3.ONE
	behind = eye + (sheet.global_position - eye) * 2.0
	assert_true(map.covers(eye, behind), "held up it does")
	assert_false(map.covers(eye, eye + Vector3(0.0, 1.0, 0.0)), "not what is beside it")
	cabin.request_map(false)


func test_a_look_to_the_side_moves_the_eyes_and_so_the_picture() -> void:
	var seat := _seat(^"DriverCamera")
	seat.look = Vector2.ZERO
	seat._since_look = -1000.0
	seat._process(0.016)
	var ahead := seat.global_position
	seat.look = Vector2(60.0, 0.0)
	seat._process(0.016)
	var aside := seat.global_position
	assert_gt(ahead.distance_to(aside), 0.05, "the eyes turn about the neck")
	var glass := _now(CarMirrors.Slot.INTERIOR)
	assert_gt(glass.seen_at(Vector3(0.0, 0.6, 9.0), _car.to_local(ahead)).distance_to(glass.seen_at(Vector3(0.0, 0.6, 9.0), _car.to_local(aside))), 0.05,
		"what the mirror shows moves across the glass")


## A volume of fog in the main view shows dim; the flat fog a mirror has instead may not shine, nor see the sky through it.
func test_a_mirror_sees_a_volume_of_fog_as_dim_flat_fog() -> void:
	var look := RaceLook.create(RaceSettings.Biome.FOREST, RaceSettings.Weather.FOG)
	add_child_autofree(look)
	var world: Environment = (look.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	assert_true(world.volumetric_fog_enabled, "headless counts as High")
	var mirror := _mirrors._mirror_environment()
	assert_false(mirror.volumetric_fog_enabled, "no volume in a small picture")
	assert_almost_eq(mirror.fog_density, world.fog_density + world.volumetric_fog_density, 0.0001, "as far as the main view sees")
	assert_lt(mirror.fog_light_energy, world.fog_light_energy)
	assert_eq(mirror.fog_aerial_perspective, 0.0)
	assert_eq(mirror.fog_sky_affect, 1.0)
	SurfaceMaterials.set_weather(RaceSettings.Weather.CLEAR)
