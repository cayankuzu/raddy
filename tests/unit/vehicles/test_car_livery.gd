extends GutTest
## A rally car's livery on the real car (CarLivery): the number on the door panels and the plate printed on the paint's own skins, the names
## and the rear window's number cut from vinyl on the glass's own triangles, a mud flap behind each wheel that the road covers like the
## body, and a picture that keeps every part inside its own place.

const RED := Color(0.78, 0.1, 0.08)

var _car: RallyCar
var _model: CarModel


func before_each() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	_car = load("res://scenes/vehicles/rally_car.tscn").instantiate()
	_car.set_paint(RED)
	world.add_child(_car)
	_car.set_simulated(false)
	_model = _car.get_node(^"Model") as CarModel


## How much of `rect` (pixels) of `image` is near `color` (a share 0..1).
func _share(image: Image, rect: Rect2i, color: Color) -> float:
	var near := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and Vector3(pixel.r - color.r, pixel.g - color.g, pixel.b - color.b).length() < 0.12:
				near += 1
	return near / float(ceili(rect.size.x / 2.0) * ceili(rect.size.y / 2.0))


func test_the_picture_carries_the_number_the_event_and_the_names() -> void:
	var image := CarLivery.draw_picture("2", PackedStringArray(["ALİ ŞİMŞEK", "DENİZ KAYA"]), RED)
	image.clear_mipmaps()
	var door := CarLivery._rect(CarLivery.DOOR)
	var field := Rect2i(door.position.x, door.position.y + door.size.y * 2 / 5, door.size.x, door.size.y * 3 / 5)
	gut.p("door panel: %.2f white, the number's field %.2f black" % [_share(image, door, CarLivery.WHITE), _share(image, field, CarLivery.BLACK)])
	assert_gt(_share(image, door, CarLivery.WHITE), 0.35, "a white panel")
	assert_gt(_share(image, field, CarLivery.BLACK), 0.025, "a big black number on it")
	assert_gt(_share(image, Rect2i(door.position, Vector2i(door.size.x, door.size.y / 4)), CarLivery.BLACK), 0.4, "the event on its black band")
	assert_gt(_share(image, Rect2i(door.position.x, door.position.y + roundi(door.size.y * 0.29), door.size.x, 6), RED), 0.8,
		"a stripe of the team's colour")
	var plate := CarLivery._rect(CarLivery.PLATE)
	assert_gt(_share(image, plate, RED), 0.05, "the plate framed in the team's colour")
	assert_gt(_share(image, plate, CarLivery.BLACK), 0.05, "lettered in black")
	var names := CarLivery._rect(CarLivery.NAMES)
	for line in 2:
		var row := Rect2i(names.position.x, names.position.y + names.size.y / 2 * line, names.size.x, names.size.y / 2)
		gut.p("name line %d: %.2f white letters, %.3f the flag's red" % [line, _share(image, row, Color.WHITE), _share(image, row, TurkishFlag.RED)])
		assert_gt(_share(image, row, Color(0.93, 0.93, 0.9)) + _share(image, row, Color.WHITE), 0.04, "white letters")
		assert_gt(_share(image, row, TurkishFlag.RED), 0.02, "after a flag of Turkey")
	var rear := CarLivery._rect(CarLivery.REAR)
	assert_gt(_share(image, rear, Color.WHITE), 0.05, "the rear window's number in white")
	assert_gt(_share(image, rear, Color.BLACK), 0.02, "with a black rim")


func test_a_names_marks_are_whole_and_every_name_the_same_size() -> void:
	var marked := CarLivery.name_picture("ÖZGÜR ÇAĞLAR İŞLİ")
	var ink := marked.get_used_rect()
	gut.p("the name's ink: rows %d to %d of %d" % [ink.position.y, ink.end.y, marked.get_height()])
	assert_gt(ink.position.y, 0, "nothing in the top row: the marks over Ö, Ü, Ğ, İ are whole")
	assert_lt(ink.end.y, marked.get_height(), "nor in the bottom row: Ç's and Ş's")
	assert_eq(CarLivery.name_picture("ALİ").get_used_rect().end.y, CarLivery.name_picture("ALI").get_used_rect().end.y,
		"a dot over a capital changes nothing of the letters' size")


func test_nothing_strays_out_of_its_part() -> void:
	var image := CarLivery.draw_picture("3", PackedStringArray(["ABCDEFGHİJKLMNOPQRST", "WWWWWWWWWWWWWWWWWWWW"]), RED)
	image.clear_mipmaps()
	var parts: Array[Rect2i] = [CarLivery._rect(CarLivery.DOOR), CarLivery._rect(CarLivery.PLATE), CarLivery._rect(CarLivery.NAMES),
		CarLivery._rect(CarLivery.REAR)]
	var stray := 0
	for y in range(0, CarLivery.PICTURE.y, 2):
		for x in range(0, CarLivery.PICTURE.x, 2):
			if image.get_pixel(x, y).a > 0.01 and not parts.any(func(part: Rect2i) -> bool: return part.has_point(Vector2i(x, y))):
				stray += 1
	assert_eq(stray, 0, "the longest names fit their window")
	assert_true(CarLivery.draw_picture("", PackedStringArray(), RED).is_invisible(), "no crew, no livery")


func test_the_paint_carries_it_and_the_glass_wears_the_vinyl() -> void:
	_model.livery.show_crew("1", PackedStringArray(["ECE", "MERT"]))
	assert_false(_model.dirt.paints.is_empty())
	for skin in _model.dirt.paints:
		assert_true(skin.get_shader_parameter(&"livery"), "every skin of the paint is printed on (the bonnet's and the bumpers' too)")
		assert_eq(skin.get_shader_parameter(&"livery_map"), _model.livery.picture)
	var stickers := _model.livery.get_node(^"Stickers") as MeshInstance3D
	assert_true(stickers.visible)
	var faces := stickers.mesh.get_faces()
	var sides := {"left": 0, "right": 0, "rear": 0}
	for v in faces:
		if v.z > CarLivery.REAR_GLASS_BEHIND:
			sides.rear += 1
		elif v.x < 0.0:
			sides.left += 1
		else:
			sides.right += 1
	gut.p("vinyl on the glass: %d triangles (%s)" % [faces.size() / 3, sides])
	assert_gt(sides.left, 0, "the names on the left rear side window")
	assert_gt(sides.right, 0, "and on the right")
	assert_gt(sides.rear, 0, "the number on the rear window")
	_model.livery.show_crew("", PackedStringArray())
	assert_false(stickers.visible, "no crew, nothing on the glass")
	assert_false(_model.dirt.paints[0].get_shader_parameter(&"livery"))


func test_a_mud_flap_behind_each_wheel_takes_the_road() -> void:
	var flaps := _model.livery.get_node(^"MudFlaps") as MeshInstance3D
	var skin := flaps.get_surface_override_material(0) as ShaderMaterial
	assert_not_null(skin, "a skin of the car's own")
	assert_eq(skin.shader, CarDirt.SHADER, "the road covers it as it covers the body")
	var box := flaps.mesh.get_aabb()
	gut.p("mud flaps from %s to %s" % [box.position, box.end])
	assert_lt(box.end.x, 0.81, "within the body's width")
	assert_gt(box.position.x, -0.81)
	for wheel_name: String in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var wheel := (_car.get_node(NodePath(wheel_name)) as Node3D).position
		var behind := 0
		for v in flaps.mesh.get_faces():
			if signf(v.x) == signf(wheel.x) and v.z > wheel.z and v.z < wheel.z + 0.5:
				behind += 1
		assert_gt(behind, 0, "a flap behind %s" % wheel_name)
	_model.dirt.levels[CarDirtRules.Layer.MUD] = 0.6
	_model.dirt.show_now()
	assert_almost_eq(float(skin.get_shader_parameter(&"mud")), 0.6, 0.001, "mud on the flaps with the rest")
