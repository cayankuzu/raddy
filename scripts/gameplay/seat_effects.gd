class_name SeatEffects
extends CanvasLayer
## What the local player feels through their own eyes (spec §9): a short stylised flash when
## gravel or muddy water hits the face through an open window, and the fade of a faint. Dirt,
## cracks and the wipers are on the real windshield (WindshieldGlass), where both seats and the
## other crews see them. Pure presentation driven by Cabin signals; intensity is a player setting.

const FLASH_COLOR := Color(0.6, 0.05, 0.05)

var cabin: Cabin
var role := RosterRules.Role.NONE
## Player setting (spec §17.4): 0 hides flashes and fades, 1 is the default look.
var intensity := 1.0

var _flash: ColorRect
var _faint: ColorRect
var _flash_left := 0.0


func _ready() -> void:
	layer = 5
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
	if has_node("/root/Settings"):
		_read_intensity()
		get_node("/root/Settings").changed.connect(_read_intensity)
	if cabin != null:
		cabin.face_hit.connect(_on_face_hit)
		cabin.faint_changed.connect(_on_faint)


func _read_intensity() -> void:
	intensity = float(get_node("/root/Settings").get_value("effects_intensity"))


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
