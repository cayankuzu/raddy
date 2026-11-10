extends SceneTree
## Bakes what road dirt looks like on a car (assets/fx/car_dirt.png, shaders/car_body.gdshader): a tile that repeats without a seam, in
## three channels. Red: big soft patches. Green: drops of all sizes, 1 in the heart of a drop and 0 outside it, so that a threshold picks
## how many and how big. Blue: long streaks along x, which the shader lays along the car, the way the wind draws dirt down a flank.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/make_car_dirt.gd

const SIZE := 512
const PATH := "res://assets/fx/car_dirt.png"
const DROPS := 2600
## Radius of a drop in pixels, smallest to largest, and how much longer than wide a drop flies.
const DROP_RADIUS := Vector2(1.3, 13.0)
const DROP_STRETCH := 1.5
const STREAKS := 1100
const STREAK_LENGTH := Vector2(50.0, 340.0)
const STREAK_HALF_WIDTH := Vector2(0.8, 4.5)

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 2204
	var patches := _patches()
	var drops := _drops()
	var streaks := _streaks()
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			image.set_pixel(x, y, Color(patches[i], drops[i], streaks[i]))
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	image.save_png(PATH)
	print("wrote ", PATH)
	quit()


func _patches() -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.008
	noise.fractal_octaves = 5
	var image := noise.get_seamless_image(SIZE, SIZE)
	var field := PackedFloat32Array()
	field.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			field[y * SIZE + x] = image.get_pixel(x, y).r
	return field


## Every drop lays a cone: a threshold on the field cuts round, hard-edged drops out of it, and a lower one lets them run together.
func _drops() -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(SIZE * SIZE)
	for n in DROPS:
		# Many small ones, few big ones.
		var r := lerpf(DROP_RADIUS.x, DROP_RADIUS.y, pow(_rng.randf(), 3.2))
		var at := Vector2(_rng.randf() * SIZE, _rng.randf() * SIZE)
		var strength := _rng.randf_range(0.55, 1.0)
		var reach := Vector2(r * DROP_STRETCH, r)
		for j in range(int(at.y - reach.y) - 1, int(at.y + reach.y) + 2):
			for i in range(int(at.x - reach.x) - 1, int(at.x + reach.x) + 2):
				var d := Vector2((i - at.x) / reach.x, (j - at.y) / reach.y).length()
				if d < 1.0:
					var k := posmod(j, SIZE) * SIZE + posmod(i, SIZE)
					field[k] = maxf(field[k], (1.0 - d) * strength)
	return field


func _streaks() -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(SIZE * SIZE)
	for n in STREAKS:
		var length := _rng.randf_range(STREAK_LENGTH.x, STREAK_LENGTH.y)
		var half := _rng.randf_range(STREAK_HALF_WIDTH.x, STREAK_HALF_WIDTH.y)
		var from := Vector2(_rng.randf() * SIZE, _rng.randf() * SIZE)
		var strength := _rng.randf_range(0.25, 0.7)
		var drift := _rng.randf_range(-0.04, 0.04)
		for s in int(length):
			var y := from.y + s * drift
			# Thin at both ends.
			var along := sin(PI * s / length)
			for j in range(int(y - half) - 1, int(y + half) + 2):
				var across := absf(j - y) / half
				if across < 1.0:
					var k := posmod(j, SIZE) * SIZE + posmod(int(from.x) + s, SIZE)
					field[k] += strength * along * (1.0 - across * across) * 0.22
	var most := 0.0
	for v in field:
		most = maxf(most, v)
	for i in field.size():
		field[i] = minf(field[i] / most * 1.5, 1.0)
	return field
