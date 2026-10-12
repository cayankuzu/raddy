class_name SeatEffects
extends CanvasLayer
## What the local player sees through their own eyes (spec §9): dirt on the windshield, crack
## lines, the wipers sweeping, a short stylised flash when gravel hits the face, and the fade of
## a faint. Pure presentation driven by Cabin signals; intensity is a player setting.

const DIRT_COLOR := Color(0.36, 0.28, 0.18)
const CRACK_COLOR := Color(0.92, 0.95, 1.0, 0.85)
const FLASH_COLOR := Color(0.6, 0.05, 0.05)
const WIPER_PERIOD := 1.1

var cabin: Cabin
var role := RosterRules.Role.NONE
## Player setting (spec §17.4): 0 hides flashes and fades, 1 is the default look.
var intensity := 1.0

var _dirt: ColorRect
var _cracks: Node2D
var _flash: ColorRect
var _faint: ColorRect
var _wiper: Line2D
var _wiper_time := 0.0
var _flash_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 5
	_dirt = ColorRect.new()
	_dirt.name = "Dirt"
	_dirt.color = DIRT_COLOR
	_dirt.modulate.a = 0.0
	_dirt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dirt)
	_cracks = Node2D.new()
	_cracks.name = "Cracks"
	add_child(_cracks)
	_wiper = Line2D.new()
	_wiper.name = "Wiper"
	_wiper.width = 6.0
	_wiper.default_color = Color(0.08, 0.08, 0.09, 0.9)
	_wiper.visible = false
	add_child(_wiper)
	_flash = ColorRect.new()
	_flash.name = "FaceHit"
	_flash.color = FLASH_COLOR
	_flash.modulate.a = 0.0
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_faint = ColorRect.new()
	_faint.name = "Faint"
	_faint.color = Color.BLACK
	_faint.modulate.a = 0.0
	_faint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_faint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_faint)
	if cabin != null:
		cabin.dirt_changed.connect(_on_dirt)
		cabin.windshield_changed.connect(_on_windshield)
		cabin.wipers_changed.connect(func(on: bool) -> void: _wiper.visible = on)
		cabin.face_hit.connect(_on_face_hit)
		cabin.faint_changed.connect(_on_faint)
		_on_dirt(cabin.dirt)
		_on_windshield(cabin.windshield)
		_wiper.visible = cabin.wipers_on


func _on_dirt(level: float) -> void:
	_dirt.modulate.a = clampf(level, 0.0, 1.0) * 0.7


func _on_windshield(state: int) -> void:
	for child in _cracks.get_children():
		child.queue_free()
	if state != Cabin.Windshield.CRACKED:
		return
	# A star of jagged lines from a random point on the glass.
	var size := get_viewport().get_visible_rect().size
	var center := Vector2(_rng.randf_range(0.25, 0.75) * size.x, _rng.randf_range(0.3, 0.6) * size.y)
	for i in _rng.randi_range(5, 8):
		var line := Line2D.new()
		line.width = 2.5
		line.default_color = CRACK_COLOR
		var points := PackedVector2Array([center])
		var angle := TAU * i / 7.0 + _rng.randf_range(-0.3, 0.3)
		var p := center
		for step in 4:
			p += Vector2(cos(angle), sin(angle)) * _rng.randf_range(25.0, 70.0)
			angle += _rng.randf_range(-0.5, 0.5)
			points.append(p)
		line.points = points
		_cracks.add_child(line)


func _on_face_hit(hit_role: int) -> void:
	if hit_role == role:
		_flash_left = 0.5


func _on_faint(faint_role: int, fainted: bool) -> void:
	if faint_role != role:
		return
	var tween := create_tween()
	tween.tween_property(_faint, "modulate:a", 0.92 * intensity if fainted else 0.0, 0.6 if fainted else 1.2)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_flash.modulate.a = clampf(_flash_left / 0.5, 0.0, 1.0) * 0.55 * intensity
	elif _flash.modulate.a > 0.0:
		_flash.modulate.a = 0.0
	if _wiper.visible:
		_wiper_time += delta
		var size := get_viewport().get_visible_rect().size
		var sweep := sin(_wiper_time * TAU / WIPER_PERIOD)
		var pivot := Vector2(size.x * 0.55, size.y * 1.05)
		var angle := -PI * 0.5 + sweep * 0.9
		_wiper.points = PackedVector2Array([pivot, pivot + Vector2(cos(angle), sin(angle)) * size.y * 0.95])
