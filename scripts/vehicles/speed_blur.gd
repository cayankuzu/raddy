class_name SpeedBlur
extends MeshInstance3D
## Hangs a full-screen motion-blur pass on a cockpit camera (shaders/speed_blur.gdshader). Strength
## grows with the car's speed above BLUR_START and follows the "effects_intensity" setting.

const SHADER := preload("res://shaders/speed_blur.gdshader")
const BLUR_START := 12.0
const BLUR_FULL := 40.0
const MAX_STRENGTH := 1.0

var car: RallyCar
var intensity := 1.0

var _material := ShaderMaterial.new()


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	_material.shader = SHADER
	# Draw before every other transparent surface (windshield mud and cracks, side glass, water):
	# the screen copy it blurs predates them, so drawing after them would erase them.
	_material.render_priority = Material.RENDER_PRIORITY_MIN
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Only the main view: in a mirror it would smear the picture and pay for a screen copy.
	layers = CarMirrors.SELF_LAYER
	# The quad is moved in clip space by the shader: never let culling drop it.
	extra_cull_margin = 16384.0
	custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	if has_node("/root/Settings"):
		_read_intensity()
		get_node("/root/Settings").changed.connect(_read_intensity)


func _read_intensity() -> void:
	intensity = float(get_node("/root/Settings").get_value("effects_intensity"))


func _process(_delta: float) -> void:
	if car == null:
		return
	var camera := get_parent() as Camera3D
	visible = camera != null and camera.current
	var speed := absf(car.forward_speed)
	var amount := clampf((speed - BLUR_START) / (BLUR_FULL - BLUR_START), 0.0, 1.0)
	_material.set_shader_parameter(&"strength", amount * amount * MAX_STRENGTH * intensity)
