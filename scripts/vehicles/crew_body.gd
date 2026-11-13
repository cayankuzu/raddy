class_name CrewBody
extends Node3D
## A crew member in a seat, on every peer, for every seat a player has taken (RaceSession seats them from the roster; an empty seat has
## nobody): Quaternius's mannequin (Universal Animation Library, CC0) posed in the seat by CrewPose with its eyes where the seat's camera
## rests, in a race suit of the team's colour (shaders/crew_suit.gdshader: dark boots, gloves with dark palms and their backs in the
## suit's colour, white stripes down the sleeves and on over the backs of the gloves, down the legs and the sides, by the bones a vertex
## hangs on), a full-face helmet on its head (CrewHelmet) and the seat's six-point harness
## buckled over it in the team colour (CarRallyKit.strap). It sits inside the cabin (its layer), lit by the cabin's fill and the dome
## lamp, seen through the windows and in the mirrors. Round the neck, under the shoulder straps, the carbon collar of a HANS device.
## The player in the seat sees their own arms and knees but not their own head: the seat's camera leaves OWN_HEAD_LAYER out, the suit
## folds the head away from such a camera and the helmet sits on that layer; the mirrors see both. What the body does from moment to
## moment (the hands, the head, a gesture, a faint) is its CrewRig's.

const MANNEQUIN := preload("res://assets/characters/crew_mannequin.glb")
const SUIT_SHADER := preload("res://shaders/crew_suit.gdshader")
## The render layer of the local player's own head (their seat's camera leaves it out).
const OWN_HEAD_LAYER := 1 << 13
## The crew's size against the mannequin's 1.83 m.
const BODY_SCALE := 0.95
## How each seat is sat in (car space, CrewPose.sit): the driver upright with the feet on the clutch and the throttle and the hands at
## a quarter to three on the wheel; the navigator leaning back a little more, feet on the floor, hands on the thighs.
const SEATS := {
	RosterRules.Role.DRIVER: {"recline": deg_to_rad(16.0),
		"feet": [Vector3(-0.405, -0.17, -0.9), Vector3(-0.22, -0.185, -0.89)],
		"hands": [Vector3(-0.52, 0.33, -0.28), Vector3(-0.13, 0.33, -0.28)],
		"palms": [Vector3(-0.325, 0.351, -0.337), Vector3(-0.325, 0.351, -0.337)],
		"knee_pole": Vector3(-0.25, 1.0, -0.35), "elbow_pole": Vector3(-0.7, -1.0, 0.2)},
	RosterRules.Role.NAVIGATOR: {"recline": deg_to_rad(18.0),
		"feet": [Vector3(0.25, -0.255, -0.84), Vector3(0.42, -0.255, -0.83)],
		"hands": [Vector3(0.24, 0.035, -0.18), Vector3(0.41, 0.035, -0.17)],
		"palms": [Vector3(0.24, -0.3, -0.18), Vector3(0.41, -0.3, -0.17)],
		"knee_pole": Vector3(-0.25, 1.0, -0.35), "elbow_pole": Vector3(-0.5, -1.0, 0.6)},
}
## Further away than this nobody makes out who sits in a car.
const DRAW_RANGE := 60.0
## The HANS collar's thickness (radius); a harness strap bends over the body in this many pieces between two of its points.
const HANS_RADIUS := 0.011
const STRAP_STEPS := 4
## The suit's regions by the bones a vertex hangs on (parts of their names) and how high a boot comes (metres, the mannequin standing).
const GLOVE_BONES: Array[String] = ["hand", "f_", "thumb"]
const HEAD_BONES: Array[String] = ["head", "neck"]
const BOOT_TOP := Vector2(0.15, 0.19)
## A glove's back (the mannequin standing in its T-pose, palms down): how far up its surface faces from where the back begins to where it
## is all back; its cuff stays dark this far out along the arm (from, to); the sleeve's stripe runs on over the back as far as the knuckles.
const GLOVE_BACK := Vector2(0.2, 0.55)
const GLOVE_CUFF := Vector2(0.757, 0.772)
const KNUCKLES := 0.862
## Where the stripes run (the mannequin standing in its T-pose): along the top of each arm (its axis: y, z) from past the shoulder's
## ball (x), down the outside of each leg (its axis: x, z) from under the hip's ball, down the sides of the body (z) from the belt up to
## under the arms (heights). None over a shoulder or a hip: the mannequin's limbs end in balls inside the body, which turn out into view
## as it sits, and a player looks at their own shoulder from a hand's width.
const ARM_LINE := Vector2(1.441, -0.067)
const ARM_STRIPE_FROM := 0.24
const LEG_LINE := Vector2(0.089, -0.01)
const LEG_STRIPE_TOP := 0.84
const BODY_LINE := -0.03
const BODY_STRIPE := Vector2(1.05, 1.3)
## The trunk, which the suit's body spans as one piece: from under the collarbones down to the hips (m up, the mannequin standing).
const TRUNK := Vector2(1.42, 0.92)
## The flag patch on the upper left sleeve (the left arm lies along +x, the mannequin standing in its T-pose, palms down): its middle, how
## far out along the arm (m) and how far round it from the top towards the front (radians), and its size (m: 3:2 like every flag), the
## hoist towards the wearer's front.
const PATCH_AT := Vector2(0.315, 0.3)
const PATCH_SIZE := Vector2(0.069, 0.046)
## The name embroidered on the right of the chest, beside the harness's shoulder strap: its middle, how far round the body from the
## front's middle (m along the cloth, the right side negative) and how high (m), and the box it is fitted into (m, NAME_PICTURE's shape).
const NAME_AT := Vector2(-0.152, 1.36)
const NAME_SIZE := Vector2(0.072, 0.012)

var role := RosterRules.Role.DRIVER
var skeleton: Skeleton3D
var pose: CrewPose
var helmet: MeshInstance3D
var harness: MeshInstance3D
var rig: CrewRig
## The name this crew member wears (wear_name) and its picture (CarLivery.name_picture; null with no name), for whatever else carries it.
var worn_name := ""
var name_picture: ImageTexture

var _suit: MeshInstance3D
var _material := ShaderMaterial.new()
var _harness_material := ShaderMaterial.new()


## Sits the body in `role`'s seat with its eyes at `eye` (car space), in `paint`'s colours.
func build(seat_role: int, eye: Vector3, paint: Color) -> void:
	role = seat_role
	var mannequin: Node3D = MANNEQUIN.instantiate()
	mannequin.name = "Mannequin"
	add_child(mannequin)
	skeleton = mannequin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_suit = skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_suit.mesh = race_suit(_suit.mesh, skeleton)
	_material.shader = SUIT_SHADER
	_material.set_shader_parameter(&"flag", TurkishFlag.texture())
	_material.set_shader_parameter(&"patch_box", Vector4(PATCH_AT.x, PATCH_AT.y, PATCH_SIZE.x, PATCH_SIZE.y))
	_material.set_shader_parameter(&"name_box", Vector4(NAME_AT.x, NAME_AT.y, NAME_SIZE.x, NAME_SIZE.y))
	_suit.material_override = _material
	_suit.layers = GraphicsQuality.CABIN_LAYER
	_suit.visibility_range_end = DRAW_RANGE
	_suit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pose = CrewPose.new(skeleton)
	pose.sit(eye, BODY_SCALE, SEATS[role])
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(bone, pose.rotations[bone])
	transform = pose.to_car
	var on_head := BoneAttachment3D.new()
	on_head.name = "Head"
	on_head.bone_name = CrewPose.HEAD
	skeleton.add_child(on_head)
	helmet = MeshInstance3D.new()
	helmet.name = "Helmet"
	helmet.mesh = CrewHelmet.mesh()
	helmet.layers = GraphicsQuality.CABIN_LAYER
	helmet.visibility_range_end = DRAW_RANGE
	helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	on_head.add_child(helmet)
	harness = MeshInstance3D.new()
	harness.name = "Harness"
	harness.mesh = harness_mesh()
	_harness_material.shader = CarRallyKit.SHADER
	harness.material_override = _harness_material
	harness.layers = GraphicsQuality.CABIN_LAYER
	harness.visibility_range_end = DRAW_RANGE
	# The webbing lies on what it would shade.
	harness.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(harness)
	# The harness is made in car space.
	harness.transform = pose.to_car.affine_inverse()
	set_paint(paint)
	var car_model := get_parent() as CarModel
	if car_model != null and car_model.car != null:
		rig = CrewRig.new()
		rig.name = "Rig"
		add_child(rig)
		rig.build(self, car_model, eye)


## The suit and the helmet in the team's colour.
func set_paint(paint: Color) -> void:
	_material.set_shader_parameter(&"suit", paint)
	helmet.material_override = CrewHelmet.material(paint)


## The name the player in this seat goes by, lettered (LiveryRules.seat_name), embroidered on the chest; nothing for an empty one.
func wear_name(lettered: String) -> void:
	if lettered == worn_name:
		return
	worn_name = lettered
	name_picture = null if lettered.is_empty() else ImageTexture.create_from_image(CarLivery.name_picture(lettered))
	_material.set_shader_parameter(&"name_map", name_picture)
	_material.set_shader_parameter(&"named", name_picture != null)


## The harness buckled over the body as it sits (car space): each shoulder strap from its slot in the seat's back over the shoulder and
## down the chest, each lap belt from its anchor by the hip over it, each crotch strap up between the thighs, all to the buckle on the belly;
## under the shoulder straps the HANS collar, from one side of the chest over the shoulders and behind the neck to the other.
func harness_mesh() -> ArrayMesh:
	var to_car := pose.to_car
	var low := to_car * pose.global_of(CrewPose.HIPS).origin
	var neck := to_car * pose.global_of(CrewPose.NECK).origin
	var chest := pose.global_of(CrewPose.CHEST)
	var ahead := (to_car.basis * chest.basis.z).normalized()
	var belly := (to_car.basis * pose.global_of(CrewPose.BELLY).basis.z).normalized()
	var hips := (to_car * pose.global_of(CrewPose.LEGS[CrewPose.Side.LEFT][0]).origin + to_car * pose.global_of(CrewPose.LEGS[CrewPose.Side.RIGHT][0]).origin) * 0.5
	var buckle := hips + belly * 0.13 + Vector3.UP * 0.06
	var seat_x: float = CarRallyKit.SEAT_X[role]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collar: Array[Vector3] = []
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		var shoulder := to_car * pose.global_of(CrewPose.ARMS[side][1]).origin
		var over := neck.lerp(shoulder, 0.32) + Vector3.UP * 0.055
		var down := [chest_point(chest, to_car, ahead, signf(shoulder.x - neck.x)) + Vector3.UP * 0.07 + ahead * 0.005, over + ahead * 0.045, over]
		if side == CrewPose.Side.RIGHT:
			down.reverse()
		collar.append_array(down)
		if side == CrewPose.Side.LEFT:
			collar.append(neck - ahead * 0.075 + Vector3.UP * 0.06)
	CarRallyKit.tube(tool, collar, HANS_RADIUS, CarRallyKit.CARBON)
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		var shoulder := to_car * pose.global_of(CrewPose.ARMS[side][1]).origin
		var hip := to_car * pose.global_of(CrewPose.LEGS[side][0]).origin
		var outward := signf(shoulder.x - neck.x)
		var top := neck.lerp(shoulder, 0.5) + Vector3.UP * 0.07
		var slot := CarRallyKit.seat_surface(role, CarRallyKit.SLOT, top.x - seat_x)
		var anchor := CarRallyKit.seat_surface(role, 4.6, outward * 0.19)
		var under := CarRallyKit.seat_surface(role, 1.6, outward * 0.03)
		_strap(tool, [slot[0] + slot[1] * 0.008, top - ahead * 0.05, top, top + ahead * 0.07 - Vector3.UP * 0.045,
			chest_point(chest, to_car, ahead, outward), buckle], low, neck, CarRallyKit.WEBBING)
		_strap(tool, [anchor[0] + anchor[1] * 0.01, hip + Vector3(outward * 0.05, 0.08, 0.0) + belly * 0.03, buckle.lerp(hip, 0.4) + belly * 0.05,
			buckle], low, neck, CarRallyKit.WEBBING)
		_strap(tool, [under[0] + under[1] * 0.008, hips + belly * 0.1 + Vector3(outward * 0.02, -0.05, 0.0), buckle], low, neck, CarRallyKit.WEBBING * 0.85)
	CarRallyKit.buckle(tool, buckle + belly * 0.01, belly)
	return tool.commit()


## Where a shoulder strap crosses the chest, `outward` (+1 or -1 along x) of the middle.
static func chest_point(chest: Transform3D, to_car: Transform3D, ahead: Vector3, outward: float) -> Vector3:
	return to_car * chest.origin + ahead * 0.14 + Vector3(outward * 0.065, 0.0, 0.0)


## A strap through `points`, lying on the body and bending over it as webbing does (a curve through them, STRAP_STEPS pieces from one
## to the next, not a fold at each): each point's face looks away from the spine (from `low` to `neck`).
static func _strap(tool: SurfaceTool, points: Array, low: Vector3, neck: Vector3, width: float) -> void:
	var on: Array[Vector3] = []
	for i in points.size() - 1:
		var from: Vector3 = points[i]
		for step in STRAP_STEPS:
			on.append(from.cubic_interpolate(points[i + 1], points[maxi(i - 1, 0)], points[mini(i + 2, points.size() - 1)], float(step) / STRAP_STEPS))
	on.append(points[-1])
	var faces: Array[Vector3] = []
	var along := (neck - low).normalized()
	for point in on:
		faces.append((point - (low + along * clampf((point - low).dot(along), 0.0, low.distance_to(neck)))).normalized())
	CarRallyKit.strap(tool, on, faces, width, CarRallyKit.HARNESS)


## The body and its helmet shade the cabin the local player sits in (`on`: their own arms on their knees, the partner beside them); a
## rival's crew sits in the dark of its own bodywork, and each shadow would be a draw call in every shadow map the car is in.
func cast_shadows(on: bool) -> void:
	var casting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_suit.cast_shadow = casting
	helmet.cast_shadow = casting


## The local player sits here (`own` true): their seat's camera, which leaves OWN_HEAD_LAYER out, sees no head; the mirrors do.
func set_own(own: bool) -> void:
	_suit.set_instance_shader_parameter(&"own_head", 1.0 if own else 0.0)
	helmet.layers = OWN_HEAD_LAYER if own else GraphicsQuality.CABIN_LAYER


static var _suits: Dictionary = {}  # source mesh -> suit mesh


## The mannequin's two surfaces as one (one draw call), each vertex telling the suit's shader what it is: COLOR.r glove, .g boot,
## .b head, .a the back of a glove; UV2.x how far it is from the stripe's line on its limb or the body (metres), UV2.y 1 where a stripe
## runs. Every body shares it.
static func suit_mesh(source: Mesh, rig: Skeleton3D) -> ArrayMesh:
	if _suits.has(source):
		return _suits[source]
	var groups := {}
	for bone in rig.get_bone_count():
		groups[bone] = bone_group(rig.get_bone_name(bone))
	var merged := []
	merged.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var colours := PackedColorArray()
	var stripes := PackedVector2Array()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var offset := vertices.size()
		var surface_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var surface_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var surface_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var surface_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var per := surface_bones.size() / surface_vertices.size()
		for v in surface_vertices.size():
			var shares := {}
			for k in per:
				var group: StringName = groups[surface_bones[v * per + k]]
				shares[group] = float(shares.get(group, 0.0)) + surface_weights[v * per + k]
			colours.append(suit_region(surface_vertices[v], shares, surface_normals[v]))
			stripes.append(stripe_coordinate(surface_vertices[v], shares, surface_normals[v]))
		vertices.append_array(surface_vertices)
		normals.append_array(surface_normals)
		if arrays[Mesh.ARRAY_TANGENT] != null:
			tangents.append_array(arrays[Mesh.ARRAY_TANGENT])
		uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		# Four bones a vertex in both surfaces (UAL's export).
		bones.append_array(surface_bones)
		weights.append_array(surface_weights)
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			indices.append(index + offset)
	merged[Mesh.ARRAY_VERTEX] = vertices
	merged[Mesh.ARRAY_NORMAL] = normals
	merged[Mesh.ARRAY_TANGENT] = tangents if tangents.size() == vertices.size() * 4 else null
	merged[Mesh.ARRAY_TEX_UV] = uvs
	merged[Mesh.ARRAY_TEX_UV2] = stripes
	merged[Mesh.ARRAY_COLOR] = colours
	merged[Mesh.ARRAY_BONES] = bones
	merged[Mesh.ARRAY_WEIGHTS] = weights
	merged[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
	_suits[source] = mesh
	return mesh


static var _race_suits: Dictionary = {}  # source mesh -> the crew's suit


## The crew's race suit: the mannequin's one surface (suit_mesh) cut as cloth over it (CrewSuit.cut: a sleeve spans the elbow's groove, a
## leg the knee's, the body its blocks), each vertex also saying where on the suit it is for the shader's panels, seams and patches
## (CUSTOM0: its place on the cut suit as the mannequin stands, m, and in w the piece it is of, CrewSuit.Part; UV.x how far it is from
## where its piece meets another, CrewSuit.meeting, the seam round a shoulder and a hip; UV.y how much it is of a glove's back, COLOR.a
## but a finger's by CrewSuit.finger_backs). Every body shares it.
static func race_suit(source: Mesh, rig: Skeleton3D) -> ArrayMesh:
	if _race_suits.has(source):
		return _race_suits[source]
	var arrays := suit_mesh(source, rig).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var regions: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var per := bones.size() / vertices.size()
	var of_bone: Array[StringName] = []
	for bone in rig.get_bone_count():
		of_bone.append(bone_group(rig.get_bone_name(bone)))
	var groups: Array[StringName] = []
	var cloth := PackedByteArray()
	for v in vertices.size():
		var heaviest := 0
		for k in range(1, per):
			if weights[v * per + k] > weights[v * per + heaviest]:
				heaviest = k
		groups.append(of_bone[bones[v * per + heaviest]])
		cloth.append(1 if maxf(regions[v].r, maxf(regions[v].g, regions[v].b)) < 0.5 else 0)
	var parts := CrewSuit.parts(vertices, indices, groups)
	var limbs := [[CrewSuit.Part.BODY, Vector3(0.0, TRUNK.x, BODY_LINE), Vector3(0.0, TRUNK.y, BODY_LINE), Vector2(0.06, 0.08)]]
	var balls := []
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		var shoulder := _rest(rig, CrewPose.ARMS[side][1])
		var hip := _rest(rig, CrewPose.LEGS[side][0])
		var ankle := _rest(rig, CrewPose.LEGS[side][2])
		limbs.append([CrewSuit.Part.ARM, shoulder, _rest(rig, CrewPose.ARMS[side][3]), Vector2(0.05, 0.04)])
		limbs.append([CrewSuit.Part.LEG, hip, hip.lerp(ankle, (hip.y - BOOT_TOP.y) / (hip.y - ankle.y)), Vector2(0.08, 0.04)])
		balls.append([shoulder, CrewSuit.SHOULDER_BALL])
		balls.append([hip, CrewSuit.HIP_BALL])
	var cut := CrewSuit.cut(vertices, normals, indices, parts, cloth, limbs, balls)
	var cut_normals := CrewSuit.normals(cut, indices, cloth, normals)
	var meeting := CrewSuit.meeting(cut, cut_normals, parts)
	var backs := PackedFloat32Array()
	for v in vertices.size():
		backs.append(regions[v].a)
	backs = CrewSuit.finger_backs(vertices, parts, CrewSuit.islands(vertices, indices), backs)
	var places := PackedFloat32Array()
	var seams := PackedVector2Array()
	var stripes: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for v in cut.size():
		places.append_array(PackedFloat32Array([cut[v].x, cut[v].y, cut[v].z, parts[v]]))
		seams.append(Vector2(meeting[v], backs[v]))
		# A stripe is measured front to back (stripe_coordinate): it moves with the cloth.
		stripes[v] += Vector2(cut[v].z - vertices[v].z, 0.0)
	arrays[Mesh.ARRAY_VERTEX] = cut
	arrays[Mesh.ARRAY_NORMAL] = cut_normals
	# The mannequin's tangents are the body's, not the cloth's, and nothing reads them.
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_TEX_UV] = seams
	arrays[Mesh.ARRAY_TEX_UV2] = stripes
	arrays[Mesh.ARRAY_CUSTOM0] = places
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	_race_suits[source] = mesh
	return mesh


## Where a bone's joint is on the mannequin as it stands at rest.
static func _rest(rig: Skeleton3D, bone_name: StringName) -> Vector3:
	return rig.get_bone_global_rest(rig.find_bone(bone_name)).origin


## Which part of the body a bone carries: the hands, the head, the arms, the legs, the feet or the body.
static func bone_group(bone_name: String) -> StringName:
	for part in GLOVE_BONES:
		if bone_name.contains(part):
			return &"hand"
	for part in HEAD_BONES:
		if bone_name.contains(part):
			return &"head"
	if bone_name.contains("arm"):
		return &"arm"
	if bone_name.contains("thigh") or bone_name.contains("shin"):
		return &"leg"
	if bone_name.contains("foot") or bone_name.contains("toe"):
		return &"foot"
	return &"body"


## What a vertex of the suit is, from where it is on the standing mannequin, how much each bone group carries it and which way its
## surface faces there (`normal`): r glove, g boot, b head (the balaclava, folded away from the own seat's camera), a the back of a glove
## (past its cuff: in the suit's colour, where the palm is dark leather, so a hand shows on a black wheel and against a dark dash).
static func suit_region(at: Vector3, shares: Dictionary, normal := Vector3.ZERO) -> Color:
	var boot := maxf(float(shares.get(&"foot", 0.0)), 1.0 - smoothstep(BOOT_TOP.x, BOOT_TOP.y, at.y))
	var glove := float(shares.get(&"hand", 0.0))
	var back := glove * smoothstep(GLOVE_BACK.x, GLOVE_BACK.y, normal.y) * smoothstep(GLOVE_CUFF.x, GLOVE_CUFF.y, absf(at.x))
	return Color(glove, boot, float(shares.get(&"head", 0.0)), back)


## How far a vertex is from where the stripe runs on its part (metres, front to back: measured so, a stripe is a straight band of one
## width whatever the mesh's triangles are), and 1 if a stripe runs there: the top of an arm and on over the back of its glove to the
## knuckles (where the surface faces up, `normal`), the outside of a leg, the body's sides (the shader ends a stripe at the last vertices
## it runs on, a clean cut along the mesh's own rings).
static func stripe_coordinate(at: Vector3, shares: Dictionary, normal := Vector3.ZERO) -> Vector2:
	var part: StringName = &"body"
	var most := 0.0
	for group: StringName in shares:
		if float(shares[group]) > most:
			most = shares[group]
			part = group
	match part:
		&"arm":
			return Vector2(at.z - ARM_LINE.y, 1.0 if at.y > ARM_LINE.x and absf(at.x) > ARM_STRIPE_FROM else 0.0)
		&"leg":
			return Vector2(at.z - LEG_LINE.y, 1.0 if absf(at.x) > LEG_LINE.x and at.y < LEG_STRIPE_TOP else 0.0)
		&"body":
			return Vector2(at.z - BODY_LINE, 1.0 if at.y > BODY_STRIPE.x and at.y < BODY_STRIPE.y else 0.0)
		&"hand":
			return Vector2(at.z - ARM_LINE.y, 1.0 if normal.y > GLOVE_BACK.y and absf(at.x) < KNUCKLES else 0.0)
	return Vector2.ZERO
