class_name Spectators
extends Node3D
## A stage's spectators (SpectatorRules says who stands where and in what): the crew's mannequin standing at RallyDressing's places for the
## crowd, one MultiMesh a place, so a place is one draw call. A skeleton cannot be shared by a MultiMesh, so the body is posed once
## standing (CrewPose.stand) and baked with what its bones weigh on each vertex; shaders/spectator.gdshader moves the arms and the
## heads from that: each person rests in their own way, looks at the car coming and cheers as it passes, a flag of Turkey waving over the
## heads of those who carry one. Every peer, never sent: each place follows the cars (RallyCar.GROUP) as this peer sees them move.

const SHADER := preload("res://shaders/spectator.gdshader")
## Further than this nobody makes out a person (m); people cast shadows, but not as far as that.
const DRAW_RANGE := 160.0
## How far the arms hang out from the sides (degrees).
const STAND_OUT := 9.0
## The flag a supporter holds: on a stick going on from the fist along the forearm (m), the cloth at its far end (the flag's own
## proportions), the stick's thickness.
const FLAG_STICK := Vector2(0.08, 0.62)
const FLAG_HEIGHT := 0.22
const STICK_RADIUS := 0.008
## Where the body is thinned out for the distance, vertices whose normals differ by less than this (degrees) count as one.
const LOD_MERGE := 25.0
## The trousers come up to the belt (m, the mannequin standing: from all trousers to all shirt).
const WAIST := Vector2(1.03, 1.07)

## Dev: no crowd at all (route_test --no-crowd, perf comparisons).
static var off := false

## Each place: [MultiMeshInstance3D, its middle, how excited it is, how near a car is to look at].
var _places: Array[Array] = []
## Each car: [where it is, how fast it goes (m/s: how far it has come since the last frame)].
var _cars: Dictionary = {}

static var _body: ArrayMesh
static var _material: ShaderMaterial


## The crowd at `spots` (RallyDressing's "spot" items) for a stage of `biome` and `stage_seed`.
static func build(spots: Array, biome: int, stage_seed: int) -> Spectators:
	var node := Spectators.new()
	node.name = "Spectators"
	var people := SpectatorRules.crowd(spots, biome, stage_seed) if not off else ([] as Array[Dictionary])
	var by_place := {}
	for person in people:
		var place: Array = by_place.get(person.zone, [])
		place.append(person)
		by_place[person.zone] = place
	for zone: int in by_place:
		node._add_place(zone, by_place[zone])
	return node


func _add_place(zone: int, people: Array) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = body_mesh()
	multimesh.instance_count = people.size()
	var middle := Vector3.ZERO
	for i in people.size():
		var person: Dictionary = people[i]
		var facing: Vector2 = person.facing
		var turn := Basis(Vector3.UP, atan2(facing.x, facing.y)).scaled(Vector3.ONE * float(person.height))
		multimesh.set_instance_transform(i, Transform3D(turn, person.position))
		multimesh.set_instance_custom_data(i, Color(float(person.pose), float(person.seed), float(person.outfit), float(person.skin)))
		middle += person.position
	var instance := MultiMeshInstance3D.new()
	instance.name = "Place%d" % zone
	instance.multimesh = multimesh
	instance.material_override = material()
	instance.layers = GraphicsQuality.FINE_SCENERY_LAYER
	instance.visibility_range_end = DRAW_RANGE
	add_child(instance)
	_places.append([instance, middle / people.size(), 0.0, 0.0])


func _process(delta: float) -> void:
	var cars := {}
	for car: Node3D in get_tree().get_nodes_in_group(RallyCar.GROUP):
		var at := car.global_position
		cars[car] = [at, (_cars[car][0] as Vector3).distance_to(at) / delta if _cars.has(car) and delta > 0.0 else 0.0]
	_cars = cars
	for place in _places:
		var instance: MultiMeshInstance3D = place[0]
		var middle: Vector3 = place[1]
		var nearest: Node3D = null
		var distance := INF
		var thrill := 0.0
		for car: Node3D in cars:
			var away := middle.distance_to(cars[car][0])
			if away < SpectatorRules.CHEER_FROM:
				thrill = maxf(thrill, SpectatorRules.thrill(away, cars[car][1]))
			if away < distance:
				distance = away
				nearest = car
		var cheer := SpectatorRules.cheer(float(place[2]), thrill, delta)
		var near := 1.0 - smoothstep(SpectatorRules.CHEER_FROM, SpectatorRules.CHEER_FROM * 2.0, distance)
		if cheer != place[2]:
			place[2] = cheer
			instance.set_instance_shader_parameter(&"cheer", cheer)
		if near != place[3]:
			place[3] = near
			instance.set_instance_shader_parameter(&"car_near", near)
		if near > 0.0:
			instance.set_instance_shader_parameter(&"car_at", nearest.global_position)


## The crowd's material, the same for every place: the joints the shader turns the arms and the head about, the clothes' colours, the
## flag's cloth.
static func material() -> ShaderMaterial:
	if _material == null:
		var mesh := body_mesh()
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		for joint: StringName in [&"shoulder_l", &"elbow_l", &"shoulder_r", &"elbow_r", &"neck"]:
			_material.set_shader_parameter(joint, mesh.get_meta(joint))
		for palette: Array in [[&"shirts", SpectatorRules.SHIRTS], [&"trousers", SpectatorRules.TROUSERS], [&"hair", SpectatorRules.HAIR],
				[&"hats", SpectatorRules.HATS]]:
			var colours := PackedVector3Array()
			for colour: Color in palette[1]:
				colours.append(Vector3(colour.r, colour.g, colour.b))
			_material.set_shader_parameter(palette[0], colours)
		_material.set_shader_parameter(&"flag_cloth", TurkishFlag.texture())
	return _material


## The mannequin standing (CrewPose.stand), skinned once into a plain mesh, and a flag on a stick in its right hand. Each vertex says what
## moves it (CUSTOM0: the weight of the left upper arm, the left forearm and hand, the right's; CUSTOM1: the head's, how much of it is
## forearm (bare in short sleeves), the flag's cloth, its stick) and what it is (COLOR: skin, trousers, shoes, hair). The joints of the
## standing pose are the mesh's meta.
static func body_mesh() -> ArrayMesh:
	if _body != null:
		return _body
	var mannequin: Node3D = CrewBody.MANNEQUIN.instantiate()
	var skeleton := mannequin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var source := (skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var arrays := CrewBody.suit_mesh(source, skeleton).surface_get_arrays(0)
	var pose := CrewPose.new(skeleton)
	pose.stand(deg_to_rad(STAND_OUT))
	var skins: Array[Transform3D] = []
	var groups := PackedInt32Array()
	for bone in skeleton.get_bone_count():
		skins.append(pose.skin(bone))
		groups.append(_group(skeleton, bone))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var regions: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var per := bones.size() / vertices.size()
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var arms := PackedFloat32Array()
	var parts := PackedFloat32Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	for v in vertices.size():
		var at := Vector3.ZERO
		var normal := Vector3.ZERO
		var arm := [0.0, 0.0, 0.0, 0.0]
		var head := 0.0
		var forearm := 0.0
		for k in per:
			var bone := bones[v * per + k]
			var weight := weights[v * per + k]
			at += skins[bone] * vertices[v] * weight
			normal += skins[bone].basis * normals[v] * weight
			match groups[bone]:
				Group.UPPER_LEFT, Group.FORE_LEFT, Group.UPPER_RIGHT, Group.FORE_RIGHT:
					arm[groups[bone]] += weight
				Group.HEAD:
					head += weight
				Group.NECK:
					head += weight * 0.5
			if skeleton.get_bone_name(bone).begins_with("DEF-forearm"):
				forearm += weight
		out_vertices.append(at)
		out_normals.append(normal.normalized())
		arms.append_array(PackedFloat32Array(arm))
		parts.append_array(PackedFloat32Array([head, forearm, 0.0, 0.0]))
		# The suit's regions (CrewBody.suit_region) become clothes: gloves are bare hands, boots shoes, the balaclava a face under hair.
		var region := regions[v]
		var rest := vertices[v]
		var hair := region.b * (1.0 if rest.y > 1.71 or (rest.z < -0.01 and rest.y > 1.6) else 0.0)
		var legs := 1.0 - smoothstep(WAIST.x, WAIST.y, rest.y)
		colours.append(Color(maxf(region.r, region.b - hair), legs * (1.0 - region.g), region.g, hair))
		uvs.append(Vector2.ZERO)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_add_flag(pose, skeleton, out_vertices, out_normals, arms, parts, colours, uvs, indices)
	var baked := []
	baked.resize(Mesh.ARRAY_MAX)
	baked[Mesh.ARRAY_VERTEX] = out_vertices
	baked[Mesh.ARRAY_NORMAL] = out_normals
	baked[Mesh.ARRAY_TEX_UV] = uvs
	baked[Mesh.ARRAY_COLOR] = colours
	baked[Mesh.ARRAY_CUSTOM0] = arms
	baked[Mesh.ARRAY_CUSTOM1] = parts
	baked[Mesh.ARRAY_INDEX] = indices
	var custom := Mesh.ARRAY_CUSTOM_RGBA_FLOAT
	# Thinned out for a place seen from further off: the same vertices under fewer triangles, which the engine picks by how big the place
	# is on the screen (a body is 13.7k triangles, a place eight bodies in the view and in each of the sun's shadow maps).
	var thinned := ImporterMesh.new()
	thinned.add_surface(Mesh.PRIMITIVE_TRIANGLES, baked, [], {}, null, "",
		(custom << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (custom << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	thinned.generate_lods(LOD_MERGE, 0.0, [])
	_body = thinned.get_mesh()
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		var letter := "l" if side == CrewPose.Side.LEFT else "r"
		_body.set_meta(StringName("shoulder_" + letter), pose.global_of(CrewPose.ARMS[side][1]).origin)
		_body.set_meta(StringName("elbow_" + letter), pose.global_of(CrewPose.ARMS[side][2]).origin)
	_body.set_meta(&"neck", pose.global_of(CrewPose.HEAD).origin)
	mannequin.free()
	return _body


enum Group { UPPER_LEFT, FORE_LEFT, UPPER_RIGHT, FORE_RIGHT, HEAD, NECK, BODY }


## What a bone moves of the body: an upper arm, a forearm with its hand and fingers, the head, the neck or the rest.
static func _group(skeleton: Skeleton3D, bone: int) -> int:
	var at := bone
	while at >= 0:
		match skeleton.get_bone_name(at):
			"DEF-upper_arm_L":
				return Group.UPPER_LEFT if at == bone else Group.FORE_LEFT
			"DEF-upper_arm_R":
				return Group.UPPER_RIGHT if at == bone else Group.FORE_RIGHT
			"DEF-head":
				return Group.HEAD
			"DEF-neck":
				return Group.NECK if at == bone else Group.HEAD
		at = skeleton.get_bone_parent(at)
	return Group.BODY


## A small flag of Turkey on a stick in the right fist, going on along the forearm (pointing down by the leg as the body stands; up when the
## arm is raised), the cloth at the stick's far end flying away from the body, both faces of it. All of it rides the right forearm.
static func _add_flag(pose: CrewPose, skeleton: Skeleton3D, vertices: PackedVector3Array, normals: PackedVector3Array, arms: PackedFloat32Array,
		parts: PackedFloat32Array, colours: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var hand := pose.global_of(CrewPose.ARMS[CrewPose.Side.RIGHT][3]).origin
	var elbow := pose.global_of(CrewPose.ARMS[CrewPose.Side.RIGHT][2]).origin
	var along := (hand - elbow).normalized()
	var out := Vector3.RIGHT.cross(along).cross(along).normalized()
	out = -out if out.x > 0.0 else out
	var facing := along.cross(out).normalized()
	var grip := hand + along * 0.06
	var tip := grip + along * FLAG_STICK.y
	var add := func(at: Vector3, normal: Vector3, uv: Vector2, cloth: bool) -> void:
		vertices.append(at)
		normals.append(normal)
		arms.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 1.0]))
		parts.append_array(PackedFloat32Array([0.0, 0.0, 1.0 if cloth else 0.0, 0.0 if cloth else 1.0]))
		colours.append(Color(0, 0, 0, 0))
		uvs.append(uv)
	# The stick: a thin square rod, each face a quad turned to the outside.
	var side := facing * STICK_RADIUS
	var across := out * STICK_RADIUS
	var corners: Array[Vector3] = [side + across, side - across, -side - across, -side + across]
	for face in 4:
		var a := corners[face]
		var b := corners[(face + 1) % 4]
		var normal := (a + b).normalized()
		_quad(indices, vertices.size(), [grip - along * FLAG_STICK.x + a, grip - along * FLAG_STICK.x + b, tip + b, tip + a], normal)
		for corner: Vector3 in [grip - along * FLAG_STICK.x + a, grip - along * FLAG_STICK.x + b, tip + b, tip + a]:
			add.call(corner, normal, Vector2.ZERO, false)
	# The cloth: the hoist along the stick from its tip, the fly out from it; a face each way.
	var width := FLAG_HEIGHT * TurkishFlag.LENGTH
	for face: float in [1.0, -1.0]:
		var normal := facing * face
		var quad: Array[Vector3] = []
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			quad.append(tip - along * FLAG_HEIGHT * corner.y + out * width * corner.x + normal * 0.002)
		_quad(indices, vertices.size(), quad, normal)
		for corner in 4:
			add.call(quad[corner], normal, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)][corner], true)


## Two triangles over the four `corners` (a quad, in order round it) added from vertex `base`, wound so they face `normal` (Godot draws a
## triangle that turns clockwise as seen).
static func _quad(indices: PackedInt32Array, base: int, corners: Array, normal: Vector3) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	else:
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
