class_name CrewRig
extends Node
## What a seated crew member does from moment to moment, on every peer, through Godot's skeleton modifiers: two-bone IK brings each wrist
## to where its hand works and the hand takes that place's turn (TwoBoneIK3D, CopyTransformModifier3D), the head looks where its player
## looks, the chest and the neck taking part of a turn (LookAtModifier3D), the legs kick the windshield out (TwoBoneIK3D). What each hand
## does comes from the seat (Cabin.hands_of, CrewRules): the driver's hands ride the turning wheel and leave it for the shock gun, the
## window's winder, the wipers' stalk, the horn and the handbrake; the navigator holds the real map by its lower corners while it is open, the hands
## on the lap otherwise; a gesture points the hand nearer the partner. Out cold the body slumps in its harness, a shock shakes it first.
## The harness holds the body to the seat, the neck gives to the car's swing (CrewSway: a corner tilts the head out of it, braking nods
## it, a hit jolts it), from how this peer sees the car's velocity change.
## The goals are set here every frame in the car's space, before the skeleton works them out; nothing here touches the simulation. Only a
## crew someone can see moves: the local player's own car's always, another's while it is on the screen within CrewBody.DRAW_RANGE or close
## enough to fill a mirror (MIRROR_RANGE); otherwise it rests as it sits, the skeleton left alone.

## Another car's crew off the screen still moves this close to the camera (it could fill a mirror), and is on the screen while this much of
## it is (a sphere round its middle, m).
const MIRROR_RANGE := 10.0
const BODY_RADIUS := 0.8
## A hand goes from one thing to the next in this long (s); the fingers change their grip in this long.
const BLEND_SECONDS := 0.24
const FINGER_SECONDS := 0.12
## How the fingers hold (curls at each knuckle of the index, middle, ring and pinky, then the thumb towards the palm, over it and out from
## the fingers; radians): round a bar, round a gun's grip with the index on the trigger, pointing, flat with the thumb along the index (the
## mannequin's thumb rests 27 degrees out of the hand's plane, towards the palm), cupped over a knob, resting, flat behind a sheet with the
## thumb round its edge onto the front, a fist with the thumb held out.
enum Grip { FIST, TRIGGER, POINT, FLAT, PINCH, REST, SHEET, THUMB }
const GRIPS := {
	Grip.FIST: [[CrewPose.CURL, CrewPose.CURL, CrewPose.CURL, CrewPose.CURL], CrewPose.THUMB_CURL, 0.0, 0.0],
	Grip.TRIGGER: [[0.12, 1.2, 1.25, 1.3], 0.55, 0.0, 0.0],
	Grip.POINT: [[0.03, 1.35, 1.4, 1.45], 0.35, 0.0, 0.0],
	Grip.FLAT: [[0.06, 0.05, 0.06, 0.08], -0.38, 0.0, -0.3],
	Grip.PINCH: [[0.75, 0.8, 0.85, 0.9], 0.3, 0.0, 0.0],
	Grip.REST: [[0.3, 0.38, 0.45, 0.5], 0.25, 0.0, 0.0],
	Grip.SHEET: [[0.03, 0.04, 0.05, 0.06], 0.75, 0.75, 0.0],
	Grip.THUMB: [[CrewPose.CURL, CrewPose.CURL, CrewPose.CURL, CrewPose.CURL], -0.45, 0.0, 1.1],
}
## The grip of each sign a gesture is made with.
const SIGN_GRIPS := {CrewRules.Sign.FINGER: Grip.POINT, CrewRules.Sign.THUMB: Grip.THUMB, CrewRules.Sign.CHOP: Grip.FLAT, CrewRules.Sign.PAT: Grip.FLAT}
const GRIP_OF := {CrewRules.Hand.WHEEL: Grip.FIST, CrewRules.Hand.LAP: Grip.REST, CrewRules.Hand.MAP: Grip.SHEET,
	CrewRules.Hand.GUN: Grip.TRIGGER, CrewRules.Hand.POINT: Grip.POINT, CrewRules.Hand.WINDOW: Grip.FIST, CrewRules.Hand.WIPERS: Grip.REST,
	CrewRules.Hand.HORN: Grip.FLAT, CrewRules.Hand.HANDBRAKE: Grip.FIST, CrewRules.Hand.THROW: Grip.FIST, CrewRules.Hand.GEAR: Grip.PINCH}
## A hand follows the turning wheel as far round as its arm reaches with this much to spare (a share of the arm's length); past that the
## rim slides through it (push-pull steering), worked out from where the body sits.
const WHEEL_REACH := 0.97
## Which way each elbow bends for what its hand does (car space, the left arm's; the right's is its mirror): down and out on the wheel and
## its stalk and hub.
const ELBOWS := {CrewRules.Hand.WHEEL: Vector3(-0.7, -1.0, 0.2), CrewRules.Hand.LAP: Vector3(-0.3, -0.4, 1.0), CrewRules.Hand.MAP: Vector3(-0.6, -1.0, 0.25),
	CrewRules.Hand.GUN: Vector3(-0.5, -1.0, 0.1), CrewRules.Hand.POINT: Vector3(-0.25, -1.0, 0.2), CrewRules.Hand.WINDOW: Vector3(-0.3, -1.0, 0.5),
	CrewRules.Hand.HANDBRAKE: Vector3(-0.3, -0.5, 1.0), CrewRules.Hand.THROW: Vector3(-0.6, -0.7, 0.6), CrewRules.Hand.GEAR: Vector3(-0.5, -0.8, 0.6)}
## A gear change takes the driver's right hand to the lever's knob for this long (s), the hand cupped over it this far behind and above.
const SHIFT_SECONDS := 0.45
const KNOB_HAND := Vector3(0.0, 0.05, 0.07)
## The winders low on the doors (car space), the circle a hand winds and how many turns it makes a second.
const WINDERS: Array[Vector3] = [Vector3(-0.68, 0.22, -0.22), Vector3(0.68, 0.22, -0.17)]
const WIND_RADIUS := 0.045
const WIND_TURNS := 1.5
## The wipers' stalk on the right of the column (car space) and how far the flick pushes it down; the horn's pad in the hub, this far
## out of the wheel's middle towards the driver.
const STALK := Vector3(-0.235, 0.275, -0.41)
const FLICK := 0.03
const HUB_OUT := 0.05
## The gun hand from the eye in the look's frame (the right hand: right, down, ahead) and how far round the arm follows the look (degrees).
## A side window that is not open stops the gun's muzzle this far from the car's middle, inside its glass.
const GUN_HAND := Vector3(0.1, -0.16, -0.36)
const GUN_YAW := 100.0
const GLASS_INSIDE := 0.55
## A gesture is made where the partner sees it at a glance: just past the middle of the car at the height of the eyes, as far ahead as
## the arm reaches with its shoulder brought forward, under the interior mirror. There the hand shows against the windshield, not against
## the dash, and at night against the road the lamps light. The wrist, from the partner's eye: this far across towards the own seat, up
## and ahead (about 40 degrees off their straight ahead). The signs (CrewRules.Sign), each jabbed along its way JAB.x times a second: the
## index finger points across to the partner's side and a little ahead (FINGER_WAY: across, up, ahead), the hand going JAB.y along it;
## for the side away from the partner the fist is held out ahead (THUMB_HAND: nearer the partner and a little lower, so that the thumb
## stays in their sight) with the thumb up and out to that side, and jerks it that way (THUMB_UP: degrees above level, at rest and at
## the jerk's end); for straight on the flat hand stands on its edge, its back to the partner, the fingers ahead and up (CHOP_WAY), and
## chops CHOP_REACH along them. Slow down: the flat hand pats the air this often and this high, a little higher up, tipping with it
## by PAT_TILT degrees.
const GESTURE_HAND := Vector3(0.25, -0.01, -0.29)
const FINGER_WAY := Vector3(0.8, 0.05, -0.6)
const THUMB_HAND := Vector3(0.17, -0.05, -0.31)
const THUMB_UP := Vector2(58.0, 32.0)
const CHOP_WAY := Vector3(0.0, 0.3, -1.0)
const CHOP_REACH := 0.07
const JAB := Vector2(1.7, 0.03)
const PAT := Vector3(2.0, 0.03, 0.06)
const PAT_TILT := 10.0
## The harness holds the back to the seat: to reach ahead a hand's shoulder comes forward instead (degrees round, for what the hand does).
const REACH := {CrewRules.Hand.POINT: 24.0, CrewRules.Hand.MAP: 14.0, CrewRules.Hand.GUN: 12.0, CrewRules.Hand.GEAR: 24.0}
## The throw: the right hand back by the shoulder, then out through the right window (car space), as the job runs.
const THROW_BACK := Vector3(0.5, 0.4, 0.12)
const THROW_OUT := Vector3(0.92, 0.52, -0.12)
## The kick: the ankles slide back along the floor out from under the dash, come up behind its lower edge, over its top and onto the
## bottom of the windshield, then back the same way (car space: height and how far ahead), the toes turning up as they go (degrees from
## how the foot rests: the soles flat on the sloping glass at the push): each leg of the way from one place to the next (0 resting, 1
## back, 2 tucked, 3 over the top, 4 pushing) over its share of the job's time. The knees bend up towards KICK_KNEE.
const KICK_PLACES: Array[Vector2] = [Vector2(-0.18, -0.45), Vector2(0.08, -0.42), Vector2(0.46, -0.48), Vector2(0.55, -0.62)]
const KICK_TOES: Array[float] = [0.0, 20.0, 105.0, 150.0, 186.0]
const KICK_PATH := [[0, 1, 0.0, 0.14], [1, 2, 0.14, 0.26], [2, 3, 0.26, 0.38], [3, 4, 0.38, 0.5], [4, 3, 0.58, 0.68], [3, 2, 0.68, 0.78],
	[2, 1, 0.78, 0.88], [1, 0, 0.88, 1.0]]
const KICK_KNEE := Vector3(0.0, 1.0, -0.2)
## How loose each seat's neck is (CrewSway): the driver holds on to the wheel, the navigator to nothing; how much of the nod the head takes
## with it (the eyes stay on the road).
const SWAY_LOOSENESS := {RosterRules.Role.DRIVER: 1.0, RosterRules.Role.NAVIGATOR: 1.3}
const SWAY_NOD := 0.6
## The chest takes this share of a turn of the head (the harness holds it), the neck these (yaw, pitch); the head turns the rest. How far a
## head turns at most (degrees: either side, as far as the seat's camera does; down, up).
const CHEST_TURN := 0.06
const NECK_TURN := Vector2(0.35, 0.4)
const HEAD_LIMITS := Vector3(CockpitCamera.LOOK_YAW, -60.0, 35.0)
## Out cold: the head drops to the chest and towards the door (degrees round, down), the back sags forward and to the door in the harness
## (degrees), over this long (s); waking takes longer.
const SLUMP_HEAD := Vector2(22.0, -58.0)
const SLUMP_BACK := Vector2(5.0, 4.0)
const SLUMP_SECONDS := 0.5
const WAKE_SECONDS := 0.9
## A shock: the body jerks and shakes this long (s), this much (degrees at the back and the neck, metres at the hands).
const SHAKE_SECONDS := 0.9
const SHAKE_TURN := 5.0
const SHAKE_HANDS := 0.035

var body: CrewBody
var model: CarModel
var cabin: Cabin
## What each hand does now (CrewRules.Hand), the left first.
var held := PackedInt32Array([-1, -1])

var _skeleton: Skeleton3D
var _goals: Node3D
var _hand_goals: Array[Node3D] = []
var _elbow_goals: Array[Node3D] = []
var _foot_goals: Array[Node3D] = []
var _knee_goals: Array[Node3D] = []
var _look_goal: Node3D
var _gun: MeshInstance3D
var _arms: TwoBoneIK3D
var _palms: CopyTransformModifier3D
var _legs: TwoBoneIK3D
var _soles: CopyTransformModifier3D
var _head: LookAtModifier3D
var _active := true
## The bones the rig turns besides the IK's, and what each was last turned by (yaw, pitch, roll).
var _turned_by: Dictionary = {}
var _eye := Vector3.ZERO
## Where the partner's eyes rest (car space): a gesture is made in their sight.
var _partner_eye := Vector3.ZERO
var _head_at := Vector3.ZERO
var _shoulders: Array[Vector3] = []
var _rest_hands: Array[Transform3D] = []
## How far round the wheel each hand follows it (radians, either way from where it rests).
var _wheel_arcs: Array[Vector2] = []
var _laps: Array[Transform3D] = []
var _feet: Array[Transform3D] = []
## Each leg's hip joint and the lengths of its thigh and shin (car space), and where its knee is in a kick.
var _hips: Array[Vector3] = []
var _leg_bones: Array[Vector2] = []
var _kick_knees: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Each hand's way from where it was (the transform it left from, how far along 0..1) and its last place; the fingers' grip on the way.
var _from: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _blend := PackedFloat32Array([1.0, 1.0])
var _last: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _grip: Array[int] = [-1, -1]
var _grip_from: Array[Dictionary] = [{}, {}]
var _grip_blend := PackedFloat32Array([1.0, 1.0])
var _since := 0.0
var _job_seen := -1
var _job_time := 0.0
## The job this body began last: it runs its time here, whatever its seat says meanwhile (another player's seat says it is over a
## moment before this peer has seen it through).
var _job := CrewRules.Job.NONE
var _look := Vector2.ZERO
var _look_from := Vector2.ZERO
var _look_to := Vector2.ZERO
var _look_blend := 1.0
var _slump := 0.0
var _shake_left := 0.0
## The car's sound, whose gearbox is the gear the driver's hand follows on this peer.
var _audio: CarAudio
var _gear := 0
var _shift_left := 0.0
var _noise := FastNoiseLite.new()
var _sway: CrewSway
## How far each shoulder has come forward (degrees, REACH).
var _reach := PackedFloat32Array([0.0, 0.0])
## Per bone the rig turns from how it sits (the chest, the neck, the shoulders): its seated rotation and the model's up, left and ahead in
## its own space.
var _turned: Dictionary = {}

## Every body's fingers (the same mannequin): Side -> Grip -> bone -> local rotation.
static var _grips: Dictionary = {}


## Hooks the body up in its car: the goals in the car's space, the modifiers on its skeleton, where its hands rest. `eye` is where the
## seat's camera rests.
func build(crew_body: CrewBody, car_model: CarModel, eye: Vector3) -> void:
	body = crew_body
	model = car_model
	cabin = model.car.get_node(^"Cabin") as Cabin
	_audio = model.car.get_node_or_null(^"Audio") as CarAudio
	cabin.shocked.connect(func(role: int) -> void:
		if role == body.role:
			_shake_left = SHAKE_SECONDS)
	_skeleton = body.skeleton
	_eye = eye
	var partner := RosterRules.Role.NAVIGATOR if body.role == RosterRules.Role.DRIVER else RosterRules.Role.DRIVER
	_partner_eye = (model.car.get_node(NodePath(CarModel.seat_camera(partner))) as CockpitCamera).seat_position()
	_noise.frequency = 9.0
	_noise.seed = body.role + 7
	_sway = CrewSway.new(SWAY_LOOSENESS[body.role])
	var pose := body.pose
	var to_car := pose.to_car
	var turn := to_car.basis.orthonormalized()
	_head_at = to_car * pose.global_of(CrewPose.HEAD).origin
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		_shoulders.append(to_car * pose.global_of(CrewPose.ARMS[side][1]).origin)
		var hand := pose.global_of(CrewPose.ARMS[side][3])
		_rest_hands.append(Transform3D(turn * hand.basis, to_car * hand.origin))
		var hip := to_car * pose.global_of(CrewPose.LEGS[side][0]).origin
		var knee := to_car * pose.global_of(CrewPose.LEGS[side][1]).origin
		_laps.append(_lap_on(hip, knee, side))
		var foot := pose.global_of(CrewPose.LEGS[side][2])
		_feet.append(Transform3D(turn * foot.basis, to_car * foot.origin))
		_hips.append(hip)
		_leg_bones.append(Vector2(hip.distance_to(knee), knee.distance_to(_feet[side].origin)))
	var arm := (pose.global_of(CrewPose.ARMS[0][1]).origin.distance_to(pose.global_of(CrewPose.ARMS[0][2]).origin)
		+ pose.global_of(CrewPose.ARMS[0][2]).origin.distance_to(pose.global_of(CrewPose.ARMS[0][3]).origin)) * CrewBody.BODY_SCALE
	for side in 2:
		_wheel_arcs.append(_reachable_arc(side, arm * WHEEL_REACH))
	for bone_name: StringName in [CrewPose.CHEST, CrewPose.NECK, CrewPose.ARMS[CrewPose.Side.LEFT][0], CrewPose.ARMS[CrewPose.Side.RIGHT][0]]:
		var bone := pose.bone(bone_name)
		var inverse := pose.global_of(bone_name).basis.inverse()
		_turned[bone] = [pose.rotations[bone], inverse * Vector3.UP, inverse * Vector3.RIGHT, inverse * Vector3.BACK]
	_goals = Node3D.new()
	_goals.name = "Goals"
	body.add_child(_goals)
	# The goals are given in car space.
	_goals.transform = to_car.affine_inverse()
	for side in 2:
		_hand_goals.append(_goal("Hand%d" % side))
		_elbow_goals.append(_goal("Elbow%d" % side))
		_foot_goals.append(_goal("Foot%d" % side))
		_knee_goals.append(_goal("Knee%d" % side))
	_look_goal = _goal("Look")
	_build_modifiers()
	var in_hand := BoneAttachment3D.new()
	in_hand.name = "GunHand"
	in_hand.bone_name = CrewPose.ARMS[CrewPose.Side.RIGHT][3]
	_skeleton.add_child(in_hand)
	_gun = MeshInstance3D.new()
	_gun.name = "ShockGun"
	_gun.mesh = ShockGun.mesh()
	_gun.layers = GraphicsQuality.CABIN_LAYER
	_gun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gun.visibility_range_end = CrewBody.DRAW_RANGE
	_gun.visible = false
	in_hand.add_child(_gun)
	if not _grips.has(CrewPose.Side.LEFT):
		_learn_grips()
	# The skeleton works the modifiers out after the car has turned its wheel and this has set the goals.
	_skeleton.process_priority = 1


func _goal(goal_name: String) -> Node3D:
	var goal := Node3D.new()
	goal.name = goal_name
	_goals.add_child(goal)
	return goal


func _build_modifiers() -> void:
	_arms = TwoBoneIK3D.new()
	_arms.name = "Arms"
	_skeleton.add_child(_arms)
	_arms.setting_count = 2
	_palms = CopyTransformModifier3D.new()
	_palms.name = "Palms"
	_skeleton.add_child(_palms)
	_palms.setting_count = 2
	_legs = TwoBoneIK3D.new()
	_legs.name = "Legs"
	_skeleton.add_child(_legs)
	_legs.setting_count = 2
	_legs.influence = 0.0
	_legs.active = false
	_soles = CopyTransformModifier3D.new()
	_soles.name = "Soles"
	_skeleton.add_child(_soles)
	_soles.setting_count = 2
	_soles.active = false
	for side in 2:
		_arms.set_root_bone_name(side, CrewPose.ARMS[side][1])
		_arms.set_middle_bone_name(side, CrewPose.ARMS[side][2])
		_arms.set_end_bone_name(side, CrewPose.ARMS[side][3])
		_arms.set_target_node(side, _arms.get_path_to(_hand_goals[side]))
		_arms.set_pole_node(side, _arms.get_path_to(_elbow_goals[side]))
		_palms.set_apply_bone_name(side, CrewPose.ARMS[side][3])
		_palms.set_reference_type(side, BoneConstraint3D.REFERENCE_TYPE_NODE)
		_palms.set_reference_node(side, _palms.get_path_to(_hand_goals[side]))
		_palms.set_copy_position(side, false)
		_palms.set_copy_scale(side, false)
		_legs.set_root_bone_name(side, CrewPose.LEGS[side][0])
		_legs.set_middle_bone_name(side, CrewPose.LEGS[side][1])
		_legs.set_end_bone_name(side, CrewPose.LEGS[side][2])
		_legs.set_target_node(side, _legs.get_path_to(_foot_goals[side]))
		_legs.set_pole_node(side, _legs.get_path_to(_knee_goals[side]))
		_soles.set_apply_bone_name(side, CrewPose.LEGS[side][2])
		_soles.set_reference_type(side, BoneConstraint3D.REFERENCE_TYPE_NODE)
		_soles.set_reference_node(side, _soles.get_path_to(_foot_goals[side]))
		_soles.set_copy_position(side, false)
		_soles.set_copy_scale(side, false)
	_head = LookAtModifier3D.new()
	_head.name = "Head"
	_skeleton.add_child(_head)
	_head.bone_name = CrewPose.HEAD
	_head.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	_head.target_node = _head.get_path_to(_look_goal)


## Every grip of each hand, worked out once on the mannequin's rest skeleton.
func _learn_grips() -> void:
	var shaper := CrewPose.new(_skeleton)
	for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
		var grips := {}
		for grip: int in GRIPS:
			grips[grip] = shaper.curl_fingers(side, GRIPS[grip][0], GRIPS[grip][1], GRIPS[grip][2], GRIPS[grip][3])
		_grips[side] = grips


## The neck feels the car on its ticks, from its velocity as this peer sees it (the own car's and a snapshot's alike).
func _physics_process(delta: float) -> void:
	if _active:
		_sway.follow(model.car.seen_velocity(), model.car.global_basis, delta)


func _process(delta: float) -> void:
	var seen := _seen(get_viewport().get_camera_3d())
	if seen != _active:
		_set_active(seen)
	if not seen:
		return
	_since += delta
	var seat: CrewRules.Seat = cabin.seats[body.role]
	var fainted := cabin.is_fainted(body.role)
	_slump = move_toward(_slump, 1.0 if fainted else 0.0, delta / (SLUMP_SECONDS if fainted else WAKE_SECONDS))
	_shake_left = maxf(_shake_left - delta, 0.0)
	if seat.jobs != _job_seen:
		_job_seen = seat.jobs
		_job_time = 0.0
		_job = seat.job
	_job_time += delta
	var shake := _shake_left / SHAKE_SECONDS
	_kick()
	var now := cabin.hands_of(body.role, _shifting(delta))
	for side in 2:
		if now[side] != held[side]:
			# On its first frame a hand is where it works at once.
			_blend[side] = 1.0 if held[side] < 0 else 0.0
			held[side] = now[side]
			_from[side] = _last[side]
		_blend[side] = minf(_blend[side] + delta / BLEND_SECONDS, 1.0)
		var place := _hand_place(side, held[side], seat)
		if _blend[side] < 1.0:
			place = _from[side].interpolate_with(place, smoothstep(0.0, 1.0, _blend[side]))
		_last[side] = place
		if shake > 0.0:
			place = place.translated(Vector3(_noise.get_noise_2d(_since * 3.0, side * 40.0), _noise.get_noise_2d(_since * 3.0, side * 40.0 + 13.0), 0.0)
				* SHAKE_HANDS * shake)
		_hand_goals[side].transform = place
		var mirror := 1.0 if side == CrewPose.Side.LEFT else -1.0
		_reach[side] = move_toward(_reach[side], float(REACH.get(held[side], 0.0)), float(REACH[CrewRules.Hand.POINT]) * delta / BLEND_SECONDS)
		_turn(CrewPose.ARMS[side][0], -mirror * _reach[side], 0.0, 0.0)
		var elbow: Vector3 = ELBOWS.get(held[side], ELBOWS[CrewRules.Hand.WHEEL])
		_elbow_goals[side].position = _shoulders[side] + Vector3(elbow.x * mirror, elbow.y, elbow.z).normalized() * 0.5
		_shape_fingers(side, delta, seat)
	_gun.visible = held[CrewPose.Side.RIGHT] == CrewRules.Hand.GUN and _blend[CrewPose.Side.RIGHT] > 0.5
	_turn_head(seat, delta, shake)


## Whether anyone can see this crew move: the local player's own car's, or near enough and on the screen or in a mirror.
func _seen(camera: Camera3D) -> bool:
	if camera == null or cabin.local_role != RosterRules.Role.NONE:
		return true
	var middle := body.global_position
	var distance := camera.global_position.distance_to(middle)
	if distance < MIRROR_RANGE:
		return true
	if distance > CrewBody.DRAW_RANGE:
		return false
	for plane in camera.get_frustum():
		if plane.distance_to(middle) > BODY_RADIUS:
			return false
	return true


## Moving, or resting as the body sits (the skeleton then left alone): a hand that starts again is where it works at once.
func _set_active(on: bool) -> void:
	_active = on
	for modifier: SkeletonModifier3D in [_arms, _palms, _head]:
		modifier.active = on
	if on:
		return
	_legs.active = false
	_soles.active = false
	_job = CrewRules.Job.NONE
	_gun.visible = false
	_sway.settle()
	held = PackedInt32Array([-1, -1])
	_grip = [-1, -1]
	_turned_by.clear()
	for bone: int in _turned:
		_skeleton.set_bone_pose_rotation(bone, body.pose.rotations[bone])
	for side in 2:
		for bone: int in _grips[side][Grip.FIST]:
			_skeleton.set_bone_pose_rotation(bone, body.pose.rotations[bone])


## Whether the driver is changing gear: the gear the car's sound is in on this peer moved, a moment ago.
func _shifting(delta: float) -> bool:
	if body.role != RosterRules.Role.DRIVER or _audio == null:
		return false
	_shift_left = maxf(_shift_left - delta, 0.0)
	if _audio.gearbox.gear != _gear:
		if _gear != 0:
			_shift_left = SHIFT_SECONDS
		_gear = _audio.gearbox.gear
	return _shift_left > 0.0


## Where the darts leave the shock gun held up (world), or null when it is not.
func muzzle() -> Variant:
	return _gun.global_transform * ShockGun.MUZZLE if _gun.visible else null


## Where a hand holds the wheel now (car space): turned with it as far as the arm reaches, then held there while the rim slides on.
func wheel_grip(side: int) -> Transform3D:
	var wheel := model.steering()
	var turn := wheel.basis.get_rotation_quaternion()
	var axis := CarModel.WHEEL_AXIS.normalized()
	var angle := clampf(wrapf(turn.get_angle() * signf(turn.get_axis().dot(axis)), -PI, PI), _wheel_arcs[side].x, _wheel_arcs[side].y)
	var gripped := Basis(axis, angle)
	return Transform3D(gripped, wheel.origin - gripped * wheel.origin) * _rest_hands[side]


## How far round the wheel a hand can follow it from where it rests before its wrist is further than `reach` from its shoulder (radians, the
## turn back and the turn forward).
func _reachable_arc(side: int, reach: float) -> Vector2:
	var hub := model.steering().origin
	var axis := CarModel.WHEEL_AXIS.normalized()
	var arc := Vector2.ZERO
	for way: int in [-1, 1]:
		var angle := 0.0
		while absf(angle) < PI:
			var next := angle + way * deg_to_rad(2.0)
			if (hub + Basis(axis, next) * (_rest_hands[side].origin - hub)).distance_to(_shoulders[side]) > reach:
				break
			angle = next
		arc[0 if way < 0 else 1] = angle
	return arc


## Where a hand is for what it does (car space: the wrist and the hand's turn).
func _hand_place(side: int, hand: int, seat: CrewRules.Seat) -> Transform3D:
	var sign_x := -1.0 if side == CrewPose.Side.LEFT else 1.0
	match hand:
		CrewRules.Hand.WHEEL:
			return wheel_grip(side)
		CrewRules.Hand.LAP:
			var lap := _laps[side]
			if _legs.active:
				# The hands ride the thighs up.
				lap = lap.interpolate_with(_lap_on(_hips[side], _kick_knees[side], side), _legs.influence)
			return lap.translated(Vector3(sign_x * 0.05, -0.05, 0.04) * _slump)
		CrewRules.Hand.MAP:
			return cabin.paper_map.hold(side)
		CrewRules.Hand.GUN:
			var aim := Basis.from_euler(Vector3(deg_to_rad(seat.look.y), deg_to_rad(clampf(seat.look.x, -GUN_YAW, GUN_YAW)), 0.0), EULER_ORDER_YXZ)
			var barrel := (aim * Vector3(0.0, 0.08, -1.0)).normalized()
			var at := _eye + aim * GUN_HAND
			# Out of an open window the gun goes; glass stops it.
			var through := absf(at.x + barrel.x * ShockGun.MUZZLE.y) - GLASS_INSIDE
			if through > 0.0 and not cabin.is_open_for_shot(ShockRules.Opening.LEFT if barrel.x < 0.0 else ShockRules.Opening.RIGHT):
				at -= barrel * through / maxf(absf(barrel.x), 0.4)
			return Transform3D(CrewPose.hand_basis(barrel, aim * Vector3.LEFT, side), at)
		CrewRules.Hand.POINT:
			return _gesture(side, seat.gesture)
		CrewRules.Hand.WINDOW:
			var winder := WINDERS[0 if seat.job == CrewRules.Job.WINDOW_LEFT else 1]
			var wound := TAU * WIND_TURNS * _job_time
			var palm := Vector3(signf(winder.x), 0.0, 0.0)
			return Transform3D(CrewPose.hand_basis(Vector3(0.0, -0.35, -1.0), palm, side),
				winder + Vector3(-palm.x * 0.07, cos(wound) * WIND_RADIUS, sin(wound) * WIND_RADIUS))
		CrewRules.Hand.WIPERS:
			var push := Vector3.DOWN * FLICK * sin(PI * clampf(_job_time / float(CrewRules.JOB_SECONDS[CrewRules.Job.WIPERS]), 0.0, 1.0))
			return Transform3D(CrewPose.hand_basis(Vector3(-0.45, 0.0, -1.0), Vector3.DOWN, side), STALK + Vector3(0.05, 0.02, 0.07) + push)
		CrewRules.Hand.HORN:
			var hub := model.steering()
			var up := CarModel.WHEEL_AXIS.cross(Vector3.RIGHT).normalized()
			return Transform3D(CrewPose.hand_basis(up, -CarModel.WHEEL_AXIS, side), hub.origin + CarModel.WHEEL_AXIS.normalized() * HUB_OUT - up * 0.07)
		CrewRules.Hand.HANDBRAKE:
			var grip := model.cockpit.handbrake_grip()
			var along := Vector3(1.0, -0.3, 0.0)
			return Transform3D(CrewPose.hand_basis(along, Vector3.DOWN, side), grip.origin - along.normalized() * 0.07 + Vector3.UP * 0.02)
		CrewRules.Hand.GEAR:
			return Transform3D(CrewPose.hand_basis(Vector3(0.0, -0.45, -1.0), Vector3.DOWN, side), model.cockpit.lever_knob() + KNOB_HAND)
		CrewRules.Hand.THROW:
			var out := smoothstep(0.3, 0.55, _job_time / float(CrewRules.JOB_SECONDS[CrewRules.Job.THROW]))
			var along := Vector3(0.0, 1.0, 0.3).lerp(Vector3(1.0, 0.1, -0.3), out)
			return Transform3D(CrewPose.hand_basis(along, Vector3(0.0, 0.0, -1.0).lerp(Vector3.DOWN, out), side), THROW_BACK.lerp(THROW_OUT, out))
	return _rest_hands[side]


## The hand nearer the partner makes the gesture over the middle of the car, in the sign that says it (CrewRules.sign_of).
func _gesture(side: int, gesture: int) -> Transform3D:
	var sign := CrewRules.sign_of(body.role, gesture)
	var hand: Vector3 = THUMB_HAND if sign == CrewRules.Sign.THUMB else GESTURE_HAND
	# Towards the partner (along x).
	var inboard := signf(_partner_eye.x - _eye.x)
	var at := _partner_eye + Vector3(-inboard * hand.x, hand.y, hand.z)
	var beat := 0.5 - 0.5 * cos(TAU * JAB.x * _since)
	match sign:
		CrewRules.Sign.PAT:
			var pat := sin(TAU * PAT.x * _since)
			var flat := CrewPose.hand_basis(Vector3.FORWARD, Vector3.DOWN, side)
			return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(PAT_TILT) * pat) * flat, at + Vector3.UP * (PAT.z + PAT.y * pat))
		CrewRules.Sign.CHOP:
			return Transform3D(CrewPose.hand_basis(CHOP_WAY, Vector3.LEFT * inboard, side), at + CHOP_WAY.normalized() * CHOP_REACH * beat)
		CrewRules.Sign.THUMB:
			var up := deg_to_rad(lerpf(THUMB_UP.x, THUMB_UP.y, beat))
			var thumb := Vector3(-inboard * cos(up), sin(up), 0.0)
			var knuckles := Vector3(0.0, 0.1, -1.0)
			# A hand's thumb is on its +Z: the palm is turned so that it points the thumb's way.
			return Transform3D(CrewPose.hand_basis(knuckles, knuckles.cross(thumb) * (1.0 if side == CrewPose.Side.LEFT else -1.0), side), at)
	var along := Vector3(inboard * FINGER_WAY.x, FINGER_WAY.y, FINGER_WAY.z).normalized()
	return Transform3D(CrewPose.hand_basis(along, Vector3.DOWN, side), at + along * JAB.y * beat)


## The fingers take the grip of what the hand does, quickly.
func _shape_fingers(side: int, delta: float, seat: CrewRules.Seat) -> void:
	var grip: int = GRIP_OF[held[side]]
	if held[side] == CrewRules.Hand.POINT:
		grip = SIGN_GRIPS[CrewRules.sign_of(body.role, seat.gesture)]
	if grip != _grip[side]:
		var first := _grip[side] < 0
		_grip[side] = grip
		_grip_from[side] = {}
		for bone: int in _grips[side][grip]:
			_grip_from[side][bone] = _skeleton.get_bone_pose_rotation(bone)
		_grip_blend[side] = 1.0 if first else 0.0
	elif _grip_blend[side] >= 1.0:
		return
	_grip_blend[side] = minf(_grip_blend[side] + delta / FINGER_SECONDS, 1.0)
	var to: Dictionary = _grips[side][grip]
	for bone: int in to:
		_skeleton.set_bone_pose_rotation(bone, (_grip_from[side][bone] as Quaternion).slerp(to[bone], _grip_blend[side]))


## The head looks where the seat's player looks (the own seat as it is, another's eased between what arrives), the chest and the neck
## taking a share; the neck gives to the car's swing; out cold it drops to the chest, a shock shakes the back and the neck.
func _turn_head(seat: CrewRules.Seat, delta: float, shake: float) -> void:
	if body.role == cabin.local_role:
		_look = seat.look
	else:
		if seat.look != _look_to:
			_look_from = _look
			_look_to = seat.look
			_look_blend = 0.0
		_look_blend = minf(_look_blend + delta * CrewRules.SEND_RATE, 1.0)
		_look = _look_from.lerp(_look_to, _look_blend)
	var outboard := -1.0 if body.role == RosterRules.Role.DRIVER else 1.0
	var look := Vector2(clampf(_look.x, -HEAD_LIMITS.x, HEAD_LIMITS.x), clampf(_look.y, HEAD_LIMITS.y, HEAD_LIMITS.z))
	look = look.lerp(Vector2(-outboard * SLUMP_HEAD.x, SLUMP_HEAD.y), smoothstep(0.0, 1.0, _slump))
	var jolt := Vector3.ZERO
	if shake > 0.0:
		jolt = Vector3(_noise.get_noise_2d(_since * 4.0, 80.0), _noise.get_noise_2d(_since * 4.0, 95.0), _noise.get_noise_2d(_since * 4.0, 110.0)) * SHAKE_TURN * shake
	_turn(CrewPose.CHEST, look.x * CHEST_TURN + jolt.x, -SLUMP_BACK.x * _slump + jolt.y,
		outboard * SLUMP_BACK.y * _slump + jolt.z)
	var sway := _sway.tilt
	_turn(CrewPose.NECK, look.x * NECK_TURN.x - jolt.z, look.y * NECK_TURN.y + jolt.x + sway.y, jolt.y + sway.x)
	var way := Basis.from_euler(Vector3(deg_to_rad(look.y + jolt.y * 2.0 + sway.y * SWAY_NOD), deg_to_rad(look.x + jolt.x * 2.0), 0.0), EULER_ORDER_YXZ) * Vector3.FORWARD
	_look_goal.position = _head_at + way * 4.0


## Turns a bone of the back, the neck or a shoulder from how it sits, about the body's own up, left and ahead (degrees: to the left, up, to
## the right).
func _turn(bone_name: StringName, yaw: float, pitch: float, roll: float) -> void:
	var bone := body.pose.bone(bone_name)
	var by := Vector3(yaw, pitch, roll)
	if _turned_by.get(bone) == by:
		return
	_turned_by[bone] = by
	var turned: Array = _turned[bone]
	var rotation := (turned[0] as Quaternion) * Quaternion(turned[1], deg_to_rad(yaw)) * Quaternion(turned[2], deg_to_rad(-pitch)) \
		* Quaternion(turned[3], deg_to_rad(roll))
	_skeleton.set_bone_pose_rotation(bone, rotation)


## The legs kick the windshield out once that job has begun: up off the floor and back, over the dash onto the glass, and back the same
## way, to the end.
func _kick() -> void:
	var kicking := _job == CrewRules.Job.KICK and _job_time < float(CrewRules.JOB_SECONDS[CrewRules.Job.KICK])
	if kicking != _legs.active:
		_legs.active = kicking
		_soles.active = kicking
	if not kicking:
		return
	var phase := _job_time / float(CrewRules.JOB_SECONDS[CrewRules.Job.KICK])
	_legs.influence = smoothstep(0.0, 0.06, phase) * (1.0 - smoothstep(0.94, 1.0, phase))
	_soles.influence = _legs.influence
	for side in 2:
		var foot := kick_foot(_feet[side], phase)
		_foot_goals[side].transform = foot
		_knee_goals[side].position = foot.origin + KICK_KNEE
		_kick_knees[side] = knee_of(_hips[side], foot.origin, foot.origin + KICK_KNEE, _leg_bones[side])


## Where a foot resting as `rest` is `phase` (0..1) into a kick (car space: the ankle and the foot's turn): along KICK_PATH from the floor
## back out from under the dash, up behind its lower edge, over its top, onto the glass, and back.
static func kick_foot(rest: Transform3D, phase: float) -> Transform3D:
	var places: Array[Vector3] = [rest.origin]
	for place in KICK_PLACES:
		places.append(Vector3(rest.origin.x, place.x, place.y))
	var at := rest.origin
	var toes := 0.0
	for leg: Array in KICK_PATH:
		if phase < float(leg[2]):
			break
		var t := smoothstep(float(leg[2]), float(leg[3]), phase)
		at = places[leg[0]].lerp(places[leg[1]], t)
		toes = lerpf(KICK_TOES[leg[0]], KICK_TOES[leg[1]], t)
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(toes)) * rest.basis, at)


## Where the middle joint of a limb from `root` to `end` lies, bent towards `pole`, its two bones `lengths` long (as two-bone IK puts it).
static func knee_of(root: Vector3, end: Vector3, pole: Vector3, lengths: Vector2) -> Vector3:
	var way := (end - root).normalized()
	var reach := clampf(root.distance_to(end), absf(lengths.x - lengths.y) + 0.001, lengths.x + lengths.y - 0.001)
	var along := (lengths.x * lengths.x - lengths.y * lengths.y + reach * reach) / (2.0 * reach)
	var bend := ((pole - root) - way * (pole - root).dot(way)).normalized()
	return root + way * along + bend * sqrt(maxf(lengths.x * lengths.x - along * along, 0.0))


## Where a hand rests on a thigh from `hip` to `knee` (car space).
static func _lap_on(hip: Vector3, knee: Vector3, side: int) -> Transform3D:
	return Transform3D(CrewPose.hand_basis(knee - hip, Vector3.DOWN, side), hip.lerp(knee, 0.5) + Vector3.UP * 0.075)
