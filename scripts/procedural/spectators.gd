class_name Spectators
extends Node3D
## A stage's spectators (SpectatorRules says who stands where and in what): the crew's mannequin standing at RallyDressing's places for the
## crowd, dressed (SpectatorClothes: a shirt or a jacket, sleeves and trousers with shapes and hems of their own), ordinary arms and a face
## on its head, one MultiMesh a place, so a place is one draw call. A skeleton cannot be shared by a MultiMesh, so the body is posed once
## standing (CrewPose.stand) and baked with what its bones weigh on each vertex; shaders/spectator.gdshader moves the arms and the
## heads from that: each person rests in their own way, looks at the car coming and cheers as it passes, a flag of Turkey waving over the
## heads of those who carry one. Every peer, never sent: each place follows the cars (RallyCar.GROUP) as this peer sees them move.

const SHADER := preload("res://shaders/spectator.gdshader")
## Further than this nobody makes out a person (m); people cast shadows, but not as far as that.
const DRAW_RANGE := 160.0
## How far the arms hang out from the sides (degrees).
const STAND_OUT := 3.0
## The flag a supporter holds: on a stick going on from the fist along the forearm (m), the cloth at its far end (the flag's own
## proportions), the stick's thickness.
const FLAG_STICK := Vector2(0.08, 0.62)
const FLAG_HEIGHT := 0.22
const STICK_RADIUS := 0.008
## Where the body is thinned out for the distance, vertices whose normals differ by less than this (degrees) count as one.
const LOD_MERGE := 25.0
## The clothes (SpectatorClothes; the mannequin at rest): a shirt's hem (m up), the chest it hangs from (m up: under the arms), how far
## a short sleeve reaches from the shoulder towards the elbow (a long one: to the wrist); how far in from an open edge the cloth rolls
## down to the body (m).
const HEM := 0.99
const CHEST := 1.4
const SHORT_SLEEVE := 0.45
const EDGE_ROLL := 0.015
## Trousers hang from the knee (m down the leg from the hip), a sleeve from under the shoulder's ball (m down the arm). The neck (from its
## joint at rest): skin within this far of its middle, up to this high (the head's above); round it the shirt's collar.
const KNEE := 0.38
const SHOULDER_BALL := 0.09
const NECK := Vector2(0.068, 0.07)
## How much slimmer than the mannequin's an upper arm and a forearm are round their bones.
const SLIM := Vector2(0.82, 0.92)
## Where the hair begins (m up at the middle of the forehead; this much lower at the temples); behind the ears it comes down to the nape.
const HAIRLINE := Vector2(1.725, 0.03)
## The face: the front of the head (the mannequin standing: further forward than this, between these heights). Its vertices tell the
## shader where they are on it: UV = metres to the person's left and up from the middle of the face, plus FACE_UV (no other vertex of
## the body has a UV that big).
const FACE_FRONT := 0.03
const FACE_HEIGHTS := Vector2(1.555, 1.78)
const FACE_MIDDLE := 1.7
const FACE_UV := 8.0

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


## The mannequin standing (CrewPose.stand), skinned once into a plain mesh and dressed (SpectatorClothes, a face shaped on its head), and a
## flag on a stick in its right hand. Each vertex says what moves it (CUSTOM0: the weight of the left upper arm, the left forearm and hand,
## the right's; CUSTOM1: the head's, how far past a short sleeve's end it is (m along the arm at rest; -1 off the arms), the flag's cloth,
## its stick), what it is (COLOR: skin, trousers, shoes, hair), how much further a long sleeve stands off it (UV2.x, m along its normal: some
## wear one), how far inside the open edges of a shirt's body it is at rest (UV2.y: its hem and its collar, _shirt_edge) and, on the face,
## where (UV, face_uv). The shader cuts a shirt's edges and a short sleeve's end where those are nought, straight across the triangles. The
## arms are an ordinary man's, not the mannequin's (SLIM). The joints of the standing pose are the mesh's meta.
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
	var neck := skeleton.get_bone_global_rest(skeleton.find_bone(CrewPose.NECK)).origin
	var arm: Array = CrewPose.ARMS[CrewPose.Side.LEFT]
	var sleeve_end := lerpf(_rest_x(skeleton, arm[1]), _rest_x(skeleton, arm[2]), SHORT_SLEEVE)
	var wrist := _rest_x(skeleton, arm[3])
	var axes := {}
	for group: int in [Group.UPPER_LEFT, Group.FORE_LEFT, Group.UPPER_RIGHT, Group.FORE_RIGHT]:
		axes[group] = _axis(pose, group)
	var standing := PackedVector3Array()
	var standing_normals := PackedVector3Array()
	var arms := PackedFloat32Array()
	var parts := PackedFloat32Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var cuts := PackedVector2Array()
	# How far in from its open edges each vertex's clothes are (m): as baked (in a short sleeve), and in a long sleeve.
	var inside := PackedVector2Array()
	# Each piece of clothing (the part it hangs round, the garment it hangs as) and the vertices it is made of.
	var pieces := {}
	for v in vertices.size():
		var at := Vector3.ZERO
		var normal := Vector3.ZERO
		var shares := PackedFloat32Array()
		shares.resize(Group.size())
		for k in per:
			var bone := bones[v * per + k]
			var weight := weights[v * per + k]
			at += skins[bone] * vertices[v] * weight
			normal += skins[bone].basis * normals[v] * weight
			shares[groups[bone]] += weight
		var rest := vertices[v]
		var head := shares[Group.HEAD] + shares[Group.NECK] * 0.5
		var face := face_uv(rest) if head > 0.5 else Vector2.ZERO
		var group := _most(shares)
		# Round the neck's base the shirt's collar: the shoulders under the neck's weight are its.
		if group == Group.HEAD and rest.y < neck.y + NECK.y and _off_neck(rest, neck) > 0.0:
			group = Group.BODY
		if face != Vector2.ZERO:
			at += Vector3.BACK * face_relief(face - Vector2.ONE * FACE_UV)
		elif group <= Group.FORE_RIGHT and regions[v].r < 0.5:
			# Slimmer down to the wrist.
			var axis: Array[Vector3] = axes[group]
			var slim := SLIM.x if group == Group.UPPER_LEFT or group == Group.UPPER_RIGHT else lerpf(SLIM.y, 1.0, smoothstep(wrist - 0.06, wrist, absf(rest.x)))
			var on := Geometry3D.get_closest_point_to_segment_uncapped(at, axis[0], axis[1])
			at = on + (at - on) * slim
		standing.append(at)
		standing_normals.append(normal.normalized())
		arms.append_array(shares.slice(Group.UPPER_LEFT, Group.FORE_RIGHT + 1))
		var garment := _garment(group, regions[v], rest, sleeve_end)
		parts.append_array(PackedFloat32Array([head, absf(rest.x) - sleeve_end if group <= Group.FORE_RIGHT else -1.0, 0.0, 0.0]))
		colours.append(Color(1.0 if garment in [SpectatorClothes.Garment.SKIN, SpectatorClothes.Garment.HAIR] else 0.0,
			1.0 if garment == SpectatorClothes.Garment.TROUSERS else 0.0, 1.0 if garment == SpectatorClothes.Garment.SHOES else 0.0,
			1.0 if garment == SpectatorClothes.Garment.HAIR else 0.0))
		uvs.append(face)
		cuts.append(Vector2(0.0, _shirt_edge(rest, neck)))
		inside.append(_inside(group, garment, rest, neck, sleeve_end, wrist))
		var piece := _piece(group, garment)
		if piece.y >= 0:
			if not pieces.has(piece):
				pieces[piece] = PackedInt32Array()
			pieces[piece].append(v)
	var dressed := standing.duplicate()
	# The vertices dressed cloth is made of, one standing for each place at rest (the mannequin's vertices split at its seams move as one).
	var first := {}
	for piece: Vector2i in pieces:
		var members: PackedInt32Array = pieces[piece]
		if piece.y == SpectatorClothes.Garment.HAIR:
			for v in members:
				dressed[v] = standing[v] + standing_normals[v] * float(SpectatorClothes.OFFSETS[SpectatorClothes.Garment.HAIR])
			continue
		var axis := _axis(pose, piece.x)
		var placed := SpectatorClothes.hang(standing, standing_normals, members, axis[0], axis[1], piece.y, _hangs_from(piece, axis[0]))
		for m in members.size():
			var v := members[m]
			# The cloth rolls down to the body at an open edge; a long sleeve is each person's to wear or not, the shader puts it on.
			var lift := placed[m] - standing[v]
			var worn := smoothstep(0.0, EDGE_ROLL, inside[v].x)
			dressed[v] = standing[v] + lift * worn
			cuts[v].x = lift.length() * (smoothstep(0.0, EDGE_ROLL, inside[v].y) - worn)
			if worn > 0.0 and not first.has(vertices[v]):
				first[vertices[v]] = v
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Where the cloth was pushed out over a groove between the mannequin's blocks it folds in a pleat: smoothed out.
	SpectatorClothes.relax(dressed, _rings(indices, vertices, first), standing, standing_normals)
	for v in vertices.size():
		var at: int = first.get(vertices[v], v)
		dressed[v] = dressed[at]
	var dressed_normals := _normals(dressed, indices, vertices, standing_normals)
	_add_flag(pose, skeleton, dressed, dressed_normals, arms, parts, colours, uvs, indices)
	# The flag is no trousers.
	while cuts.size() < dressed.size():
		cuts.append(Vector2(0.0, 1.0))
	var baked := []
	baked.resize(Mesh.ARRAY_MAX)
	baked[Mesh.ARRAY_VERTEX] = dressed
	baked[Mesh.ARRAY_NORMAL] = dressed_normals
	baked[Mesh.ARRAY_TEX_UV] = uvs
	baked[Mesh.ARRAY_TEX_UV2] = cuts
	baked[Mesh.ARRAY_COLOR] = colours
	baked[Mesh.ARRAY_CUSTOM0] = arms
	baked[Mesh.ARRAY_CUSTOM1] = parts
	baked[Mesh.ARRAY_INDEX] = indices
	var custom := Mesh.ARRAY_CUSTOM_RGBA_FLOAT
	# Thinned out for a place seen from further off: the same vertices under fewer triangles, which the engine picks by how big the place
	# is on the screen (a place is eight bodies in the view and in each of the sun's shadow maps).
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


## Where on the face a vertex of the head is (the mannequin standing at `rest`), as the shader takes it: zero off the face.
static func face_uv(rest: Vector3) -> Vector2:
	if rest.z < FACE_FRONT or rest.y < FACE_HEIGHTS.x or rest.y > FACE_HEIGHTS.y:
		return Vector2.ZERO
	return Vector2(rest.x + FACE_UV, rest.y - FACE_MIDDLE + FACE_UV)


## How far forward the face stands at `at` (m to the person's left and up from the middle of the face) over the mannequin's smooth egg of
## a head: a nose from between the brows to its tip, brows over sunken eyes, cheekbones, lips and a chin, enough to catch the light and
## throw a shadow under the nose and the brows from the road.
static func face_relief(at: Vector2) -> float:
	var across := absf(at.x)
	var nose := 0.015 * _bump(Vector2(across / 0.012, (at.y + 0.03) / 0.017)) + 0.006 * _bump(Vector2(across / 0.009, (at.y + 0.008) / 0.026))
	var brows := 0.004 * _bump(Vector2((across - 0.03) / 0.021, (at.y - 0.008) / 0.009))
	var eyes := -0.005 * _bump(Vector2((across - 0.031) / 0.017, (at.y + 0.012) / 0.012))
	var cheeks := 0.003 * _bump(Vector2((across - 0.045) / 0.018, (at.y + 0.04) / 0.016))
	var lips := 0.0025 * _bump(Vector2(across / 0.023, (at.y + 0.076) / 0.009))
	var chin := 0.004 * _bump(Vector2(across / 0.022, (at.y + 0.112) / 0.014))
	return nose + brows + eyes + cheeks + lips + chin


## A smooth bump of height one at the middle, nought from a distance of one (`at` scaled by the bump's half sizes).
static func _bump(at: Vector2) -> float:
	return pow(maxf(1.0 - at.length_squared(), 0.0), 2.0)


## What moves a part of the body (the shader's arms and head) and which clothes hang round it: an upper arm, a forearm with its hand and
## fingers, the head, the neck, the body, a leg with its foot.
enum Group { UPPER_LEFT, FORE_LEFT, UPPER_RIGHT, FORE_RIGHT, HEAD, NECK, BODY, LEG_LEFT, LEG_RIGHT }


## The part of the body a bone moves.
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
			"DEF-thigh_L":
				return Group.LEG_LEFT
			"DEF-thigh_R":
				return Group.LEG_RIGHT
		at = skeleton.get_bone_parent(at)
	return Group.BODY


## The part that carries most of a vertex (by Group), the neck's counted as the head's.
static func _most(shares: PackedFloat32Array) -> int:
	var most := Group.BODY
	for group in shares.size():
		if shares[group] > shares[most]:
			most = group
	return Group.HEAD if most == Group.NECK else most


## What a vertex of `group` wears (SpectatorClothes.Garment), by where it is on the mannequin at rest (`rest`, its T-pose) and the suit's
## regions there (CrewBody.suit_region: r the hands, g the boots): the head is skin, under hair from the crown down the back to the nape;
## the body a shirt down to its hem and trousers below; a leg trousers down to the shoes; an arm a short sleeve out to `sleeve_end` (along
## x), then a long sleeve or skin; a hand skin.
static func _garment(group: int, region: Color, rest: Vector3, sleeve_end: float) -> int:
	match group:
		Group.HEAD:
			var hair := rest.y > HAIRLINE.x - HAIRLINE.y * smoothstep(0.035, 0.06, absf(rest.x)) or (rest.z < -0.01 and rest.y > 1.6)
			return SpectatorClothes.Garment.HAIR if hair else SpectatorClothes.Garment.SKIN
		Group.BODY:
			return SpectatorClothes.Garment.SHIRT if rest.y > HEM else SpectatorClothes.Garment.TROUSERS
		Group.LEG_LEFT, Group.LEG_RIGHT:
			return SpectatorClothes.Garment.SHOES if region.g > 0.5 else SpectatorClothes.Garment.TROUSERS
	if region.r > 0.5:
		return SpectatorClothes.Garment.SKIN
	var upper := group == Group.UPPER_LEFT or group == Group.UPPER_RIGHT
	return SpectatorClothes.Garment.SHIRT if upper and absf(rest.x) < sleeve_end else SpectatorClothes.Garment.SLEEVE


## How far in from its open edges a vertex's clothes are at rest, where the cloth ends on the skin (m; less than nought: not worn): as baked
## (a short sleeve) and with a long sleeve on. A shirt's body ends at its collar, a short sleeve at `sleeve_end`, a long one at the `wrist`
## (both along x); its hem over the trousers and the trousers' over the shoes stand proud, and hair has no open edge that shows.
static func _inside(group: int, garment: int, rest: Vector3, neck: Vector3, sleeve_end: float, wrist: float) -> Vector2:
	match garment:
		SpectatorClothes.Garment.SHIRT:
			if group == Group.BODY:
				var edge := minf(_off_neck(rest, neck), neck.y + NECK.y - rest.y)
				return Vector2(edge, edge)
			return Vector2(sleeve_end - absf(rest.x), wrist - absf(rest.x))
		SpectatorClothes.Garment.SLEEVE:
			return Vector2(-1.0, wrist - absf(rest.x))
	return Vector2(INF, INF)


## How far a point of the mannequin at rest is out from the neck (m, less than nought: on it), round the line up through its joint at
## `neck` (up to NECK.y above it; above that the head begins).
static func _off_neck(rest: Vector3, neck: Vector3) -> float:
	return Vector2(rest.x - neck.x, rest.z - neck.z).length() - NECK.x


## How far inside the open edges of a shirt's body a point of the mannequin at rest is (m; less than nought: outside): above its hem, out
## from the neck past its collar, below the head.
static func _shirt_edge(rest: Vector3, neck: Vector3) -> float:
	return minf(minf(rest.y - HEM, _off_neck(rest, neck)), neck.y + NECK.y - rest.y)


## Which piece of clothing a vertex of `group` wearing `garment` belongs to: (the part it hangs round, the garment it hangs as), y below
## zero for skin and shoes. A short sleeve and the long one going on from it hang as one.
static func _piece(group: int, garment: int) -> Vector2i:
	if garment == SpectatorClothes.Garment.SKIN or garment == SpectatorClothes.Garment.SHOES:
		return Vector2i(group, -1)
	if garment == SpectatorClothes.Garment.SHIRT and group != Group.BODY:
		return Vector2i(group, SpectatorClothes.Garment.SLEEVE)
	return Vector2i(group, garment)


## The axis clothes hang round on a part of the standing body, from its top down: the body's from the neck's height straight down through
## the hips, a leg's from the hip to the ankle, an upper arm's from the shoulder to the elbow, a forearm's on to the wrist.
static func _axis(pose: CrewPose, group: int) -> Array[Vector3]:
	match group:
		Group.LEG_LEFT, Group.LEG_RIGHT:
			var leg: Array = CrewPose.LEGS[CrewPose.Side.LEFT if group == Group.LEG_LEFT else CrewPose.Side.RIGHT]
			return [pose.global_of(leg[0]).origin, pose.global_of(leg[2]).origin]
		Group.UPPER_LEFT, Group.FORE_LEFT, Group.UPPER_RIGHT, Group.FORE_RIGHT:
			var arm: Array = CrewPose.ARMS[CrewPose.Side.LEFT if group <= Group.FORE_LEFT else CrewPose.Side.RIGHT]
			var upper := group == Group.UPPER_LEFT or group == Group.UPPER_RIGHT
			return [pose.global_of(arm[1 if upper else 2]).origin, pose.global_of(arm[2 if upper else 3]).origin]
	var hips := pose.global_of(CrewPose.HIPS).origin
	return [Vector3(hips.x, pose.global_of(CrewPose.NECK).origin.y, hips.z), Vector3(hips.x, 0.0, hips.z)]


## How far down its axis a piece starts to hang (SpectatorClothes.hang), `top` the axis's top: a shirt from the chest, trousers from the
## hips over the groin and from the knee down the legs, a sleeve from just under the shoulder's ball.
static func _hangs_from(piece: Vector2i, top: Vector3) -> float:
	match piece.x:
		Group.BODY:
			return top.y - (CHEST if piece.y == SpectatorClothes.Garment.SHIRT else HEM)
		Group.LEG_LEFT, Group.LEG_RIGHT:
			return KNEE
		Group.UPPER_LEFT, Group.UPPER_RIGHT:
			return SHOULDER_BALL
	return 0.0


## How far out along x a joint is on the mannequin at rest (its T-pose: the arms along x).
static func _rest_x(skeleton: Skeleton3D, bone_name: StringName) -> float:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone_name)).origin.x


## The points of dressed cloth (`first`: a place on the mannequin at `rest` -> the vertex standing for it) and the points each shares an edge
## with (by the vertex standing for their place; a vertex that is no cloth stands for itself).
static func _rings(indices: PackedInt32Array, rest: PackedVector3Array, first: Dictionary) -> Dictionary:
	var rings := {}
	for v: int in first.values():
		rings[v] = PackedInt32Array()
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a: int = first.get(rest[indices[t + e]], indices[t + e])
			var b: int = first.get(rest[indices[t + (e + 1) % 3]], indices[t + (e + 1) % 3])
			if rings.has(a) and not rings[a].has(b):
				rings[a].append(b)
			if rings.has(b) and not rings[b].has(a):
				rings[b].append(a)
	return rings


## The dressed body's normals: each vertex's the mean of its faces' and of those of the vertices at its place at `rest` whose normal it
## shared `before` (the rims of the soles and the fingertips stay sharp, the mannequin's two materials meet without a seam).
static func _normals(points: PackedVector3Array, indices: PackedInt32Array, rest: PackedVector3Array, before: PackedVector3Array) -> PackedVector3Array:
	var sums := PackedVector3Array()
	sums.resize(points.size())
	for t in range(0, indices.size(), 3):
		# Godot's front faces turn clockwise as seen.
		var face := (points[indices[t + 2]] - points[indices[t]]).cross(points[indices[t + 1]] - points[indices[t]])
		for corner in 3:
			sums[indices[t + corner]] += face
	var at := {}
	for v in rest.size():
		if not at.has(rest[v]):
			at[rest[v]] = PackedInt32Array()
		at[rest[v]].append(v)
	var out := PackedVector3Array()
	for v in points.size():
		var sum := sums[v]
		for w: int in at[rest[v]]:
			if w != v and before[w].dot(before[v]) > 0.7:
				sum += sums[w]
		out.append(sum.normalized())
	return out


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
