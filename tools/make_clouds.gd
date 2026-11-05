extends SceneTree
## Bakes the sky's clouds (assets/sky/clouds_clear.png, clouds_overcast.png): equirectangular pictures of noise, white
## with the cover in their alpha, made once here instead of at every race. Towards the zenith the cover fades
## away: all of a picture's top row is one point of the sky, and clouds there meet in a star, which paint mirrors.
## Square, so that spread over twice as many degrees across as up they lie flat like clouds.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/make_clouds.gd

const SIZE := 1024
## The noise up to where the clouds begin and where they are thick (clear sky, overcast).
const FROM := {"clear": 0.53, "overcast": 0.3}
const THICK := {"clear": 0.72, "overcast": 0.8}
## Share of the picture's height, from the top: no cover yet, and where it is whole.
const ZENITH_CLEAR := 0.07
const ZENITH_WHOLE := 0.22


func _initialize() -> void:
	for kind: String in FROM:
		_bake(kind)
	quit()


func _bake(kind: String) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0085
	noise.fractal_octaves = 6
	noise.fractal_gain = 0.55
	var source := noise.get_seamless_image(SIZE, SIZE)
	source.convert(Image.FORMAT_L8)
	var from: float = FROM[kind]
	var thick: float = THICK[kind]
	var cover := PackedByteArray()
	cover.resize(SIZE * SIZE * 2)
	var bytes := source.get_data()
	for y in SIZE:
		var fade := smoothstep(ZENITH_CLEAR, ZENITH_WHOLE, float(y) / SIZE)
		for x in SIZE:
			var value := bytes[y * SIZE + x] / 255.0
			cover[(y * SIZE + x) * 2] = 255
			cover[(y * SIZE + x) * 2 + 1] = int(clampf((value - from) / (thick - from), 0.0, 1.0) * fade * 255.0)
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_LA8, cover)
	var path := "res://assets/sky/clouds_%s.png" % kind
	DirAccess.make_dir_recursive_absolute("res://assets/sky")
	image.save_png(path)
	print("wrote ", path)
