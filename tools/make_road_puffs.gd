extends SceneTree
## Bakes what a puff thrown off the road looks like (assets/fx/road_puffs.png, shaders/road_puff.gdshader): eight cells, four
## billowing clouds on the top row and four bursts of flying drops below, drawn up the cell the way they fly. Red is how thick the puff is there, green and blue the way
## its surface faces (x and y of a normal, 0.5 = square to the view), so the sun models a flat card like a round cloud.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/make_road_puffs.gd

const CELL := 256
const COLUMNS := 4
const ROWS := 2
const PATH := "res://assets/fx/road_puffs.png"
## How much of the height of a puff shows in its normals, and how much the normal of a round ball does.
const RELIEF := 3.0
const ROUNDNESS := 0.6


func _initialize() -> void:
	var image := Image.create_empty(CELL * COLUMNS, CELL * ROWS, false, Image.FORMAT_RGB8)
	for row in ROWS:
		for column in COLUMNS:
			_bake(image, column, row)
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	image.save_png(PATH)
	print("wrote ", PATH)
	quit()


func _bake(image: Image, column: int, row: int) -> void:
	var shape := _noise(column * 11 + row * 37 + 5, 1.5, 3, FastNoiseLite.FRACTAL_FBM)
	var billows := _noise(column * 13 + row * 41 + 9, 2.4, 3, FastNoiseLite.FRACTAL_FBM)
	var grain := _noise(column * 17 + row * 43 + 3, 1.0, 2, FastNoiseLite.FRACTAL_FBM)
	var thick := PackedFloat32Array()
	thick.resize(CELL * CELL)
	for y in CELL:
		for x in CELL:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / CELL * 2.0 - Vector2.ONE
			thick[y * CELL + x] = _billow(p, shape, billows) if row == 0 else _drops(p, shape, grain)
	for y in CELL:
		for x in CELL:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / CELL * 2.0 - Vector2.ONE
			var slope := Vector2(_at(thick, x + 2, y) - _at(thick, x - 2, y), _at(thick, x, y + 2) - _at(thick, x, y - 2))
			var ball := p * ROUNDNESS
			var normal := (ball - slope * RELIEF).limit_length(1.0)
			# The texture's y runs down the picture, a normal's up.
			image.set_pixel(column * CELL + x, row * CELL + y, Color(thick[y * CELL + x], normal.x * 0.5 + 0.5, -normal.y * 0.5 + 0.5))


## A rounded cloud: its outline broken by slow noise, its inside in lumps, nothing left at the edge of the cell.
func _billow(p: Vector2, shape: FastNoiseLite, billows: FastNoiseLite) -> float:
	var radius := p.length() + shape.get_noise_2dv(p) * 0.24
	var body := 1.0 - smoothstep(0.0, 0.94, radius)
	var lumps := billows.get_noise_2dv(p) * 0.5 + 0.5
	var window := 1.0 - smoothstep(0.8, 1.0, p.length())
	return clampf(pow(body, 1.3) * (0.68 + lumps * 0.6) * window, 0.0, 1.0)


## Flying drops: thin lines along the cell's height, thick in the middle and thinning out towards both ends.
func _drops(p: Vector2, shape: FastNoiseLite, grain: FastNoiseLite) -> float:
	var radius := Vector2(p.x * 1.15, p.y).length() + shape.get_noise_2dv(p) * 0.18
	var body := 1.0 - smoothstep(0.05, 0.95, radius)
	var lines := smoothstep(-0.25, 0.45, grain.get_noise_2d(p.x * 11.0, p.y * 1.1))
	var window := 1.0 - smoothstep(0.86, 1.0, p.length())
	return clampf(body * (0.55 + lines * 0.45) * window, 0.0, 1.0)


func _at(thick: PackedFloat32Array, x: int, y: int) -> float:
	return thick[clampi(y, 0, CELL - 1) * CELL + clampi(x, 0, CELL - 1)]


func _noise(seed_value: int, frequency: float, octaves: int, kind: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = kind
	noise.fractal_octaves = octaves
	return noise
