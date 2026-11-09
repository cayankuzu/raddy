class_name HudCluster
extends Control
## The instrument cluster in the corner of the race HUD: a rev counter arc with a red zone and a
## shift light, the gear in large figures and the speed below. Drawn in code; it reads the car's
## Gearbox (CarAudio) every frame, so the needle moves with the engine you hear.

const RPM_MAX := 8000.0
const RED_FROM := 6800.0
const SWEEP_FROM := deg_to_rad(140.0)
const SWEEP := deg_to_rad(260.0)
const RING := Color(1, 1, 1, 0.16)
const FILL := Color("f3efe6")
const HOT := Color("ff7a2f")
const RED := Color("e8322b")
const BACK := Color(0.05, 0.05, 0.06, 0.55)
## How much of it shows while the right door mirror lies under it (HUD pixels round the glass's middle).
const OVER_A_MIRROR := 0.18
const MIRROR_REACH := 46.0

var car: RallyCar

var _rpm := 0.0
var _speed := 0.0
var _gear := 1
var _blink := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(250, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How much of the cluster, whose rectangle is `rect`, shows over a mirror whose glass has its middle at `glass`.
static func alpha_over(glass: Vector2, rect: Rect2) -> float:
	return OVER_A_MIRROR if rect.grow(MIRROR_REACH).has_point(glass) else 1.0


func _process(delta: float) -> void:
	if car == null or not is_instance_valid(car):
		return
	var audio := car.get_node_or_null(^"Audio") as CarAudio
	if audio != null:
		_rpm = lerpf(_rpm, audio.gearbox.rpm, 1.0 - exp(-18.0 * delta))
		_gear = audio.gearbox.gear
	_speed = absf(car.forward_speed) * 3.6
	_blink += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 14.0
	draw_circle(center, radius + 10.0, BACK)
	draw_arc(center, radius, SWEEP_FROM, SWEEP_FROM + SWEEP, 72, RING, 12.0, true)
	var red_start := SWEEP_FROM + SWEEP * RED_FROM / RPM_MAX
	draw_arc(center, radius, red_start, SWEEP_FROM + SWEEP, 24, Color(RED, 0.45), 12.0, true)
	var t := clampf(_rpm / RPM_MAX, 0.0, 1.0)
	if t > 0.002:
		var color := FILL if _rpm < 6000.0 else (HOT if _rpm < RED_FROM else RED)
		draw_arc(center, radius, SWEEP_FROM, SWEEP_FROM + SWEEP * t, 72, color, 12.0, true)
	var font := UiTheme.hud_font()
	for k in range(0, 9):
		var a := SWEEP_FROM + SWEEP * k * 1000.0 / RPM_MAX
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius - 14.0), center + dir * (radius - 6.0), Color(1, 1, 1, 0.7), 2.0, true)
		var label := str(k)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, center + dir * (radius - 28.0) - Vector2(text_size.x * 0.5, -5.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	# The needle.
	var needle := SWEEP_FROM + SWEEP * t
	var tip := center + Vector2(cos(needle), sin(needle)) * (radius - 4.0)
	draw_line(center + Vector2(cos(needle), sin(needle)) * (radius * 0.55), tip, Color(RED, 0.95), 4.0, true)
	# Shift light: on near the limiter, blinking on it.
	var lit := _rpm >= RED_FROM and (fmod(_blink, 0.12) < 0.06 or _rpm < 7200.0)
	draw_circle(center + Vector2(0.0, -radius * 0.62), 7.0, RED if lit else Color(0.25, 0.08, 0.07, 0.9))
	# Gear and speed.
	var gear_text := "R" if _gear < 0 else str(_gear)
	_centered(font, gear_text, center + Vector2(0.0, 18.0), 92, FILL)
	_centered(font, "%d" % roundi(_speed), center + Vector2(0.0, 66.0), 34, FILL)
	_centered(font, "km/h", center + Vector2(0.0, 88.0), 14, Color(1, 1, 1, 0.6))


func _centered(font: Font, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
