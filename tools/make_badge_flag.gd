extends SceneTree
## Bakes the flag on the car's badges into the model's badge atlas (assets/vehicles/milano95/milano95_12.png): the
## model came with another country's colours beside its FIDA and MILANO badges, and every flag in the game is the flag of
## Turkey (TurkishFlag). An upright 3:2 flag in a chrome rim, on the one tile both badges share; the rest of the atlas stays.
## Headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/make_badge_flag.gd

const ATLAS := "res://assets/vehicles/milano95/milano95_12.png"
## The tile the two badge quads are mapped to, in atlas pixels (their UVs: 0.5985..0.6505, 0.7879..0.8239).
const TILE := Rect2i(1226, 1614, 106, 73)
## How wide an atlas pixel of that tile comes out on the car against how high (the two badges' average): the flag must
## be 3:2 on the car, not on the atlas.
const PIXEL_ASPECT := 0.86
const RIM := 3
const RIM_TOP := Color(0.24, 0.24, 0.25)
const RIM_BOTTOM := Color(0.8, 0.78, 0.78)


func _initialize() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	var inner_width := TILE.size.x - RIM * 2
	var inner_height := roundi(inner_width * PIXEL_ASPECT / TurkishFlag.LENGTH)
	var top := TILE.position.y + (TILE.size.y - inner_height - RIM * 2) / 2
	for y in range(TILE.position.y, TILE.end.y):
		for x in range(TILE.position.x, TILE.end.x):
			atlas.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	for y in inner_height + RIM * 2:
		var shade := RIM_TOP.lerp(RIM_BOTTOM, float(y) / (inner_height + RIM * 2 - 1))
		for x in TILE.size.x:
			atlas.set_pixel(TILE.position.x + x, top + y, shade)
	var pixel := 1.0 / inner_height
	for y in inner_height:
		for x in inner_width:
			# In units of the flag's height, from the hoist along its centre line.
			var at := Vector2((x + 0.5) / inner_width * TurkishFlag.LENGTH, (y + 0.5) / inner_height - 0.5)
			atlas.set_pixel(TILE.position.x + RIM + x, top + RIM + y, TurkishFlag.color_at(at, pixel))
	atlas.save_png(ProjectSettings.globalize_path(ATLAS))
	print("BADGE flag %d x %d pixels in %s" % [inner_width, inner_height, TILE])
	quit()
