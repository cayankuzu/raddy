class_name CarDirt
extends Node
## The road on the car, on every peer and never sent: each works it out from how it sees the car drive (CarDirtRules says how much).
## The body, its trim and the wheels get a skin of this car's own in place of the model's materials (shaders/car_body.gdshader): clean it is the
## model's material, so the dirt costs no draw call of its own, is lit and shadowed like the paint and takes the shine off it where it
## lies. A recovery does not clean a car; a water splash rinses part of it. The glass stays apart: what is on it is the Cabin's.
## The badges with the flag of Turkey are not skins: dirt never covers a flag.

const SHADER := preload("res://shaders/car_body.gdshader")
const DIRT_MAP := preload("res://assets/fx/car_dirt.png")
const PAINT := "Milano95_Bodymat"
const TRIM := "UCB_BOTTOM"
const TYRES := "RB1c_Tire_1k"
## The paint is the model's mirror-like metal turned into a car paint with a clear coat.
const PAINT_METALLIC := 0.35
const PAINT_ROUGHNESS := 0.32
const PAINT_CLEARCOAT := 0.8
const PAINT_CLEARCOAT_ROUGHNESS := 0.12
## The picture is only brought up to date when a layer has grown by this much.
const SHOW_STEP := 0.004

var car: RallyCar
## CarDirtRules.Layer -> how far it has climbed.
var levels := PackedFloat32Array([0.0, 0.0, 0.0])
## How much of the lower half a water splash has washed clean.
var washed := 0.0

## The colour of what lies on the car as dust: the ground it came from.
var _dust_color := Color(0.63, 0.58, 0.49)
var _skins: Dictionary = {}
var _shown := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## The player's effects setting: how much of the dirt shows.
var _strength := 1.0


func _ready() -> void:
	car = get_parent().get_parent() as RallyCar
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.changed.connect(_read_settings)
	_read_settings()
	set_physics_process(car != null)


func _read_settings() -> void:
	var settings := get_node_or_null(^"/root/Settings")
	_strength = float(settings.get_value("effects_intensity")) if settings != null else 1.0
	for skin: ShaderMaterial in _skins.values():
		skin.set_shader_parameter(&"strength", _strength)


func _physics_process(delta: float) -> void:
	var speed := absf(car.forward_speed)
	if car.water_contacts > 0:
		washed = CarDirtRules.rinsed(washed, speed, delta)
	elif car.wheels_in_contact() > 0:
		_gather(car.wheel_surface(0), speed, delta)
	_show_when_changed()


func _gather(surface: StringName, speed: float, delta: float) -> void:
	var layer := CarDirtRules.layer_of(surface)
	if layer < 0:
		return
	var level := CarDirtRules.gathered(levels[layer], surface, speed, delta)
	if layer == CarDirtRules.Layer.DUST and level > levels[layer]:
		# What came last counts for as much as it adds.
		_dust_color = _dust_color.lerp(_tint_of(surface), (level - levels[layer]) / maxf(level, 0.02))
	levels[layer] = level
	washed = CarDirtRules.soiled(washed, surface, speed, delta)


func _tint_of(surface: StringName) -> Color:
	return RoadFxRules.throws(surface).tint * RaceLook.dust_tint


func _show_when_changed() -> void:
	var now := PackedFloat32Array([levels[0], levels[1], levels[2], washed])
	for i in now.size():
		if absf(now[i] - _shown[i]) >= SHOW_STEP:
			show_now()
			return


## Puts the levels on the skins.
func show_now() -> void:
	_shown = PackedFloat32Array([levels[0], levels[1], levels[2], washed])
	for skin: ShaderMaterial in _skins.values():
		skin.set_shader_parameter(&"dust", levels[CarDirtRules.Layer.DUST])
		skin.set_shader_parameter(&"mud", levels[CarDirtRules.Layer.MUD])
		skin.set_shader_parameter(&"snow", levels[CarDirtRules.Layer.SNOW])
		skin.set_shader_parameter(&"washed", washed)
		skin.set_shader_parameter(&"dust_color", _dust_color)


## This car's skin in place of the model's `material` (null when dirt has no business on it). `to_car` takes a mesh that wears it into the car's
## space; a wheel's own space is what counts on a wheel.
func skin_of(material: StandardMaterial3D, to_car: Transform3D) -> ShaderMaterial:
	if material == null or material.resource_name not in [PAINT, TRIM, TYRES]:
		return null
	if not _skins.has(material.resource_name):
		_skins[material.resource_name] = _make_skin(material, to_car)
	return _skins[material.resource_name]


func paint() -> ShaderMaterial:
	return _skins.get(PAINT)


func _make_skin(material: StandardMaterial3D, to_car: Transform3D) -> ShaderMaterial:
	var skin := ShaderMaterial.new()
	skin.resource_name = material.resource_name + "Dirty"
	skin.shader = SHADER
	var is_paint := material.resource_name == PAINT
	skin.set_shader_parameter(&"albedo", material.albedo_color)
	skin.set_shader_parameter(&"albedo_map", material.albedo_texture)
	skin.set_shader_parameter(&"metal_rough_map", material.metallic_texture)
	skin.set_shader_parameter(&"metallic", PAINT_METALLIC if is_paint else material.metallic)
	skin.set_shader_parameter(&"roughness", PAINT_ROUGHNESS if is_paint else material.roughness)
	skin.set_shader_parameter(&"clearcoat", PAINT_CLEARCOAT if is_paint else 0.0)
	skin.set_shader_parameter(&"clearcoat_roughness", PAINT_CLEARCOAT_ROUGHNESS)
	skin.set_shader_parameter(&"dirt_map", DIRT_MAP)
	skin.set_shader_parameter(&"strength", _strength)
	skin.set_shader_parameter(&"is_wheel", material.resource_name == TYRES)
	skin.set_shader_parameter(&"to_car", to_car)
	return skin
