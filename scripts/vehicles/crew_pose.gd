class_name CrewPose
extends RefCounted
## A crew member sitting in a rally seat, as rotations of the mannequin's bones (pure: from the skeleton's rest pose and where the eyes,
## the hands and the feet must be). The pelvis and the back lean back with the seat by `recline`, the neck brings the head upright, the
## legs reach for the feet's places and the arms for the hands' (each a two-bone chain bent towards its pole), the hands turn their palms
## to what they hold and the fingers curl round it. All in the model's space (the mannequin faces +Z, its left is +X, its feet stand on
## y = 0); `to_car` puts the model in the car so that its eyes are where the seat's camera rests.

## The skeleton's bones that the pose moves (UAL1's names, as Godot imports them).
const HIPS := &"DEF-hips"
const BELLY := &"DEF-spine_001"
const CHEST := &"DEF-spine_003"
const NECK := &"DEF-neck"
const HEAD := &"DEF-head"
const ARMS := {Side.LEFT: [&"DEF-shoulder_L", &"DEF-upper_arm_L", &"DEF-forearm_L", &"DEF-hand_L"],
	Side.RIGHT: [&"DEF-shoulder_R", &"DEF-upper_arm_R", &"DEF-forearm_R", &"DEF-hand_R"]}
const LEGS := {Side.LEFT: [&"DEF-thigh_L", &"DEF-shin_L", &"DEF-foot_L", &"DEF-toe_L"],
	Side.RIGHT: [&"DEF-thigh_R", &"DEF-shin_R", &"DEF-foot_R", &"DEF-toe_R"]}
const FINGERS := ["index", "middle", "ring", "pinky"]
## Between the eyes, a little behind the face, in the mannequin's rest pose.
const EYES_AT_REST := Vector3(0.0, 1.70, 0.09)
## How far the fingers curl at each knuckle and the thumb across the palm (radians).
const CURL := 1.15
const THUMB_CURL := 0.5
## The neck takes this share of bringing the head upright, the head the rest.
const NECK_SHARE := 0.55

enum Side { LEFT, RIGHT }

## Per bone, the rotation to pose it with (local, as Skeleton3D.set_bone_pose_rotation takes it).
var rotations: Array[Quaternion] = []
## The model's place in the car (model -> car space).
var to_car := Transform3D.IDENTITY

var _rest: Array[Transform3D] = []
var _parents := PackedInt32Array()
var _names := {}  # bone name -> index
var _global: Array[Transform3D] = []


## The rest pose of `skeleton`, ready to be posed.
func _init(skeleton: Skeleton3D) -> void:
	for bone in skeleton.get_bone_count():
		_rest.append(skeleton.get_bone_rest(bone))
		_parents.append(skeleton.get_bone_parent(bone))
		_names[skeleton.get_bone_name(bone)] = bone
		rotations.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	_update_globals()


func bone(bone_name: StringName) -> int:
	return _names[bone_name]


## Where a bone is now (model space).
func global_of(bone_name: StringName) -> Transform3D:
	return _global[bone(bone_name)]


## Sits the body: `eye` is where its eyes must be in the car, `scale` the body's size, `seat` the rest (CrewSeats): "recline" (radians),
## and car-space places for the feet ("feet": balls of the feet left and right), the hands ("hands": wrists; "palms": a point each palm
## faces), the knees' and elbows' poles ("knee_pole", "elbow_pole": ways, left side; the right is the mirror).
func sit(eye: Vector3, body_scale: float, seat: Dictionary) -> void:
	var recline: float = seat.recline
	_turn_global(bone(HIPS), Basis(Vector3.RIGHT, -recline))
	_turn_global(bone(NECK), Basis(Vector3.RIGHT, recline * NECK_SHARE))
	# The head upright and facing ahead, whatever the back does.
	_set_global_basis(bone(HEAD), _rest_global(bone(HEAD)).basis)
	var turn := Basis(Vector3.UP, PI).scaled(Vector3.ONE * body_scale)
	to_car = Transform3D(turn, eye - turn * eyes())
	var to_model := to_car.affine_inverse()
	for side: int in [Side.LEFT, Side.RIGHT]:
		var mirror := 1.0 if side == Side.LEFT else -1.0
		var feet: Array = seat.feet
		var hands: Array = seat.hands
		var palms: Array = seat.palms
		_leg(LEGS[side], to_model * (feet[side] as Vector3), _pole(to_model, seat.knee_pole, mirror))
		_arm(side, to_model * (hands[side] as Vector3), to_model * (palms[side] as Vector3), _pole(to_model, seat.elbow_pole, mirror))


## Where the eyes are now (model space).
func eyes() -> Vector3:
	var head := _global[bone(HEAD)]
	return head * (_rest_global(bone(HEAD)).affine_inverse() * EYES_AT_REST)


## A pole given for the left side in car space, as a way in the model's space for `mirror` (1 left, -1 right).
static func _pole(to_model: Transform3D, pole: Vector3, mirror: float) -> Vector3:
	return (to_model.basis * Vector3(pole.x * mirror, pole.y, pole.z)).normalized()


## A leg reaching the ball of the foot to `ball`: hip to knee to ankle as a two-bone chain bent towards `pole`, the foot along to the ball.
func _leg(chain: Array, ball: Vector3, pole: Vector3) -> void:
	var thigh := bone(chain[0])
	var shin := bone(chain[1])
	var foot := bone(chain[2])
	var toe := bone(chain[3])
	var foot_length := _rest_global(foot).origin.distance_to(_rest_global(toe).origin)
	# The ankle above and behind the ball: the foot slopes up to it as on a pedal or the floor's toe board.
	var ankle := ball + Vector3(0.0, 0.55, -0.83).normalized() * foot_length
	_two_bones(thigh, shin, foot, ankle, pole)
	_aim(foot, toe, ball)


## An arm reaching `wrist`: shoulder to elbow to wrist bent towards `pole`, the hand on along the forearm with its palm turned to `palm`, the
## fingers curled round what it holds.
func _arm(side: int, wrist: Vector3, palm: Vector3, pole: Vector3) -> void:
	var upper := bone(ARMS[side][1])
	var fore := bone(ARMS[side][2])
	var hand := bone(ARMS[side][3])
	_two_bones(upper, fore, hand, wrist, pole)
	var along := (wrist - _global[fore].origin).normalized()
	_aim_way(hand, along)
	_roll_palm(hand, palm)
	curl_fingers(side, [CURL, CURL, CURL, CURL], THUMB_CURL)


## Curls a hand's fingers from straight: the index, middle, ring and pinky by `curls` at each knuckle (radians), the thumb across the palm by
## `thumb`. Returns the fingers' rotations (bone -> local Quaternion), which are the same whatever the hand does.
func curl_fingers(side: int, curls: Array, thumb: float) -> Dictionary:
	var hand := bone(ARMS[side][3])
	var letter := "L" if side == Side.LEFT else "R"
	var fingers: Array[int] = []
	for finger: String in FINGERS:
		for knuckle in 3:
			fingers.append(bone(StringName("DEF-f_%s_0%d_%s" % [finger, knuckle + 1, letter])))
	fingers.append(bone(StringName("DEF-thumb_01_%s" % letter)))
	for each in fingers:
		rotations[each] = _rest[each].basis.get_rotation_quaternion()
	_update_globals()
	for each in fingers.size():
		_curl(fingers[each], hand, thumb if each == fingers.size() - 1 else float(curls[each / 3]))
	var out := {}
	for each in fingers:
		out[each] = rotations[each]
	return out


## A hand's turn from the way its fingers point (`along`) and its palm faces (`palm`), in whatever space they are given: its +Y along, its
## palm side (+X of the left hand, -X of the right, see _palm) to the palm.
static func hand_basis(along: Vector3, palm: Vector3, side: int) -> Basis:
	var y := along.normalized()
	var x := (palm - y * palm.dot(y)).normalized()
	if side == Side.RIGHT:
		x = -x
	return Basis(x, y, x.cross(y))


## Bends `root` and `middle` so that `end`'s joint reaches `target` (or as near as the bones allow), the middle joint towards `pole`.
func _two_bones(root: int, middle: int, end: int, target: Vector3, pole: Vector3) -> void:
	var start := _global[root].origin
	var upper := _rest[middle].origin.length()
	var lower := _rest[end].origin.length()
	var to_target := target - start
	var reach := clampf(to_target.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var way := to_target.normalized()
	var bend := (pole - way * pole.dot(way)).normalized()
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var joint := start + way * along + bend * sqrt(maxf(upper * upper - along * along, 0.0))
	_aim_way(root, (joint - start).normalized())
	_aim_way(middle, (start + way * reach - joint).normalized())


## Turns `bone` (keeping its roll as near as it can) so that its child `child`'s joint lies towards `target`.
func _aim(bone_index: int, child: int, target: Vector3) -> void:
	_aim_way(bone_index, (target - _global[bone_index].origin).normalized())


## Turns `bone` the shortest way so that its +Y (where its child lies) points along `way`.
func _aim_way(bone_index: int, way: Vector3) -> void:
	var now := _global[bone_index].basis.y.normalized()
	var axis := now.cross(way)
	if axis.length() < 0.000001:
		return
	_turn_global(bone_index, Basis(axis.normalized(), now.signed_angle_to(way, axis)))


## Rolls a hand about its length so that its palm (the side the fingers curl to) faces `point`.
func _roll_palm(hand: int, point: Vector3) -> void:
	var length := _global[hand].basis.y.normalized()
	var palm := _palm(hand)
	var wanted := point - _global[hand].origin
	wanted = (wanted - length * wanted.dot(length)).normalized()
	if wanted.length() < 0.5:
		return
	_turn_global(hand, Basis(length, palm.signed_angle_to(wanted, length)))


## The way a hand's palm faces (model space): its +X on the left hand, its -X on the right (the T-pose holds them palm down).
func _palm(hand: int) -> Vector3:
	var x := _global[hand].basis.x.normalized()
	return x if String(_names.find_key(hand)).ends_with("_L") else -x


## Curls a finger bone towards the palm of `hand` by `angle`.
func _curl(finger: int, hand: int, angle: float) -> void:
	var axis := _global[finger].basis.y.normalized().cross(_palm(hand)).normalized()
	_turn_global(finger, Basis(axis, angle))


## Turns a bone by `turn` in model space (its children go with it).
func _turn_global(bone_index: int, turn: Basis) -> void:
	_set_global_basis(bone_index, turn * _global[bone_index].basis)


## Gives a bone this orientation in model space (its children go with it).
func _set_global_basis(bone_index: int, basis: Basis) -> void:
	var parent := _parents[bone_index]
	var parent_basis := _global[parent].basis if parent >= 0 else Basis.IDENTITY
	rotations[bone_index] = (parent_basis.inverse() * basis).get_rotation_quaternion()
	_update_globals()


func _rest_global(bone_index: int) -> Transform3D:
	var at := _rest[bone_index]
	var parent := _parents[bone_index]
	while parent >= 0:
		at = _rest[parent] * at
		parent = _parents[parent]
	return at


## Every bone's place in model space from the rotations (bones are listed after their parents).
func _update_globals() -> void:
	_global.resize(_rest.size())
	for bone_index in _rest.size():
		var local := Transform3D(Basis(rotations[bone_index]), _rest[bone_index].origin)
		var parent := _parents[bone_index]
		_global[bone_index] = _global[parent] * local if parent >= 0 else local
