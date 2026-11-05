extends SceneTree
## Bakes the car's instrument face (assets/vehicles/milano95/gauge_face.png): the dials the needles of
## shaders/gauge_panel.gdshader sweep over, in the same layout (keep the two in step). Text in Godot's own default
## font. It needs a window to render:
##   Godot_v4.7.2-stable_win64_console.exe --path . -s tools/make_gauge_face.gd --accessibility disabled

const OUT := "res://assets/vehicles/milano95/gauge_face.png"
const SIZE := Vector2i(2048, 680)
const SPEED_CENTER := Vector2(640, 340)
const RPM_CENTER := Vector2(1408, 340)
const BIG_RADIUS := 285.0
## The big dials sweep from 225 degrees (down left) clockwise to -45 (down right).
const SWEEP_FROM := 225.0
const SWEEP_TO := -45.0
## Small gauges hinge at the panel's edges: their arcs face the middle, +-38 degrees.
const SMALL_RADIUS := 190.0
const SMALL_ANGLE := 38.0
const TEMP_HINGE := Vector2(92, 175)
const OIL_HINGE := Vector2(92, 505)
const FUEL_HINGE := Vector2(1956, 175)
const VOLTS_HINGE := Vector2(1956, 505)
## The six warning lamps, three a row, in the middle between the dials, low enough to show through the rim.
const LAMP_ORIGIN := Vector2(932, 330)
const LAMP_CELL := 64.0
const LAMP_LEVEL := 0.26
const WHITE := Color(0.95, 0.95, 0.92)
const DIM := Color(0.62, 0.63, 0.62)
const RED := Color(0.86, 0.14, 0.08)
const AMBER := Color(0.9, 0.62, 0.12)
const GROUND := Color(0.018, 0.019, 0.021)


class Face extends Control:
	var font: Font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), GROUND)
		_big_dial(SPEED_CENTER, 200.0, 10.0, 20.0, 20.0, "km/h", 1000.0)
		_big_dial(RPM_CENTER, 8000.0, 500.0, 1000.0, 1000.0, "x1000 rpm", 7200.0)
		_small(TEMP_HINGE, false, "C", "H", "TEMP", 0.82)
		_small(OIL_HINGE, false, "0", "5", "OIL", 2.0)
		_small(FUEL_HINGE, true, "F", "E", "FUEL", 2.0)
		_small(VOLTS_HINGE, true, "16", "8", "VOLT", 2.0)
		_lamps()

	func _text(at: Vector2, text: String, size: int, color: Color) -> void:
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, at + Vector2(-width * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func _polar(center: Vector2, degrees: float, radius: float) -> Vector2:
		return center + Vector2(cos(deg_to_rad(degrees)), -sin(deg_to_rad(degrees))) * radius

	## Ticks and numbers round a big dial. `red_from` starts the red part of the scale.
	func _big_dial(center: Vector2, scale_max: float, minor: float, major: float, label_step: float, unit: String, red_from: float) -> void:
		var value := 0.0
		while value <= scale_max + 0.01:
			var t := value / scale_max
			var angle := lerpf(SWEEP_FROM, SWEEP_TO, t)
			var is_major := is_zero_approx(fmod(value, major))
			var color := RED if value >= red_from else (WHITE if is_major else DIM)
			var inner := BIG_RADIUS - (34.0 if is_major else 18.0)
			draw_line(_polar(center, angle, inner), _polar(center, angle, BIG_RADIUS), color, 9.0 if is_major else 4.0, true)
			if is_zero_approx(fmod(value, label_step)):
				var shown := str(roundi(value)) if scale_max < 1000.0 else str(roundi(value / 1000.0))
				_text(_polar(center, angle, BIG_RADIUS - 84.0), shown, 46, color if value >= red_from else WHITE)
			value += minor
		if red_from < scale_max:
			var from := lerpf(SWEEP_FROM, SWEEP_TO, red_from / scale_max)
			draw_arc(center, BIG_RADIUS + 1.0, deg_to_rad(-from), deg_to_rad(-SWEEP_TO), 32, RED, 10.0, true)
		_text(center + Vector2(0.0, 120.0), unit, 36, DIM)

	## An edge gauge hinged at `hinge`, its arc to the right of it (or the left when `flipped`). `red_above` of
	## the scale, from its start, begins a red part.
	func _small(hinge: Vector2, flipped: bool, low: String, high: String, label: String, red_above: float) -> void:
		var middle := 180.0 if flipped else 0.0
		for i in 9:
			var t := i / 8.0
			var angle := middle + lerpf(-SMALL_ANGLE, SMALL_ANGLE, t)
			var major := i % 4 == 0
			var from_low := t if not flipped else 1.0 - t
			var color := RED if from_low >= red_above else (WHITE if major else DIM)
			draw_line(_polar(hinge, angle, SMALL_RADIUS - (26.0 if major else 14.0)), _polar(hinge, angle, SMALL_RADIUS), color, 8.0 if major else 4.0, true)
		_text(_polar(hinge, middle - SMALL_ANGLE, SMALL_RADIUS - 56.0), low, 36, WHITE)
		_text(_polar(hinge, middle + SMALL_ANGLE, SMALL_RADIUS - 56.0), high, 36, WHITE)
		_text(_polar(hinge, middle, SMALL_RADIUS - 92.0), label, 26, DIM)

	## Dim symbols: the shader lights them by their brightness.
	func _lamps() -> void:
		var ink := Color(LAMP_LEVEL, LAMP_LEVEL, LAMP_LEVEL)
		_handbrake(_cell(0, 0), ink)
		_battery(_cell(1, 0), ink)
		_oil_can(_cell(2, 0), ink)
		_engine(_cell(0, 1), ink)
		_beam(_cell(1, 1), ink)
		_hazard(_cell(2, 1), ink)

	func _cell(column: int, row: int) -> Vector2:
		return LAMP_ORIGIN + Vector2((column + 0.5) * LAMP_CELL, (row + 0.5) * LAMP_CELL)

	func _handbrake(c: Vector2, ink: Color) -> void:
		draw_arc(c, 24.0, 0.0, TAU, 28, ink, 5.0, true)
		_text(c, "P", 34, ink)

	func _battery(c: Vector2, ink: Color) -> void:
		draw_rect(Rect2(c + Vector2(-25, -14), Vector2(50, 32)), ink, false, 5.0)
		draw_rect(Rect2(c + Vector2(-20, -21), Vector2(10, 7)), ink)
		draw_rect(Rect2(c + Vector2(10, -21), Vector2(10, 7)), ink)
		draw_line(c + Vector2(-17, 2), c + Vector2(-7, 2), ink, 4.0)
		draw_line(c + Vector2(7, 2), c + Vector2(17, 2), ink, 4.0)
		draw_line(c + Vector2(12, -3), c + Vector2(12, 7), ink, 4.0)

	func _oil_can(c: Vector2, ink: Color) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(-26, -8), c + Vector2(-8, -8), c + Vector2(4, 0), c + Vector2(24, -12),
			c + Vector2(6, 14), c + Vector2(-20, 14), c + Vector2(-20, -8)]), ink, 5.0, true)
		draw_line(c + Vector2(-8, -8), c + Vector2(-8, -16), ink, 5.0)
		draw_circle(c + Vector2(26, 8), 3.5, ink)

	func _engine(c: Vector2, ink: Color) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(-24, -6), c + Vector2(-12, -6), c + Vector2(-12, -14), c + Vector2(8, -14),
			c + Vector2(8, -8), c + Vector2(18, -8), c + Vector2(18, -2), c + Vector2(26, -2), c + Vector2(26, 12), c + Vector2(18, 12),
			c + Vector2(18, 16), c + Vector2(-14, 16), c + Vector2(-20, 6), c + Vector2(-24, 6), c + Vector2(-24, -6)]), ink, 5.0, true)

	func _beam(c: Vector2, ink: Color) -> void:
		draw_arc(c + Vector2(-6, 0), 16.0, -PI * 0.5, PI * 0.5, 14, ink, 5.0, true)
		draw_line(c + Vector2(-6, -16), c + Vector2(-6, 16), ink, 5.0)
		for y: float in [-12.0, 0.0, 12.0]:
			draw_line(c + Vector2(-28, y), c + Vector2(-13, y), ink, 4.0)

	func _hazard(c: Vector2, ink: Color) -> void:
		for size: float in [28.0, 13.0]:
			draw_polyline(PackedVector2Array([c + Vector2(0, -size), c + Vector2(size * 0.95, size * 0.72),
				c + Vector2(-size * 0.95, size * 0.72), c + Vector2(0, -size)]), ink, 4.5, true)


var _viewport: SubViewport
var _frames := 0


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var face := Face.new()
	face.font = ThemeDB.fallback_font
	face.size = SIZE
	_viewport.add_child(face)
	root.add_child(_viewport)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT)
	print("wrote ", OUT)
	return true
