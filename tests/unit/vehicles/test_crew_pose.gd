extends GutTest
## A crew member sitting (CrewPose: the mannequin's rest skeleton posed for a seat, pure): the eyes where the seat's camera rests, the
## head upright and facing ahead, the feet and the hands where the seat says, the knees bent up and the elbows down and out.

const MANNEQUIN := preload("res://assets/characters/crew_mannequin.glb")
const CAR_SCENE := preload("res://scenes/vehicles/rally_car.tscn")

var _skeleton: Skeleton3D
var _eyes := {}


func before_each() -> void:
	var mannequin: Node3D = MANNEQUIN.instantiate()
	add_child_autofree(mannequin)
	_skeleton = mannequin.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# Where each seat's camera rests, from the car's scene (before it is in a tree its cameras sit where the scene puts them).
	var car := CAR_SCENE.instantiate()
	for role: int in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		_eyes[role] = (car.get_node(NodePath(CarModel.seat_camera(role))) as Node3D).position
	car.free()


func _sat(role: int) -> CrewPose:
	var pose := CrewPose.new(_skeleton)
	pose.sit(_eyes[role], CrewBody.BODY_SCALE, CrewBody.SEATS[role])
	return pose


func _at(pose: CrewPose, bone_name: StringName) -> Vector3:
	return pose.to_car * pose.global_of(bone_name).origin


func test_the_eyes_are_where_the_seats_camera_rests_and_the_head_is_upright() -> void:
	for role: int in _eyes:
		var pose := _sat(role)
		var head := pose.global_of(CrewPose.HEAD)
		var eyes := pose.to_car * pose.eyes()
		assert_almost_eq(eyes.distance_to(_eyes[role]), 0.0, 0.001, "%s: the eyes are the camera's" % RosterRules.role_name(role))
		var up := (pose.to_car.basis * head.basis.y).normalized()
		var ahead := (pose.to_car.basis * head.basis.z).normalized()
		assert_gt(up.y, 0.99, "the head upright")
		assert_lt(ahead.z, -0.99, "and looking along the car")


func test_the_feet_and_the_hands_reach_their_places() -> void:
	for role: int in _eyes:
		var pose := _sat(role)
		var seat: Dictionary = CrewBody.SEATS[role]
		for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
			var ball := _at(pose, CrewPose.LEGS[side][3])
			var wrist := _at(pose, CrewPose.ARMS[side][3])
			gut.p("%s %s: the foot %.1f cm from its place, the wrist %.1f cm" % [RosterRules.role_name(role), CrewPose.Side.keys()[side],
				ball.distance_to(seat.feet[side]) * 100.0, wrist.distance_to(seat.hands[side]) * 100.0])
			assert_lt(ball.distance_to(seat.feet[side]), 0.02, "the ball of the foot on its pedal or the floor")
			assert_lt(wrist.distance_to(seat.hands[side]), 0.01, "the hand where it holds")


func test_knees_bend_up_and_elbows_down_and_out() -> void:
	for role: int in _eyes:
		var pose := _sat(role)
		for side: int in [CrewPose.Side.LEFT, CrewPose.Side.RIGHT]:
			var hip := _at(pose, CrewPose.LEGS[side][0])
			var knee := _at(pose, CrewPose.LEGS[side][1])
			var ankle := _at(pose, CrewPose.LEGS[side][2])
			var line := hip.lerp(ankle, (knee - hip).dot(ankle - hip) / (ankle - hip).length_squared())
			assert_gt(knee.y, line.y + 0.02, "the knee above the line from the hip to the ankle")
			var shoulder := _at(pose, CrewPose.ARMS[side][1])
			var elbow := _at(pose, CrewPose.ARMS[side][2])
			var wrist := _at(pose, CrewPose.ARMS[side][3])
			var arm_line := shoulder.lerp(wrist, (elbow - shoulder).dot(wrist - shoulder) / (wrist - shoulder).length_squared())
			assert_lt(elbow.y, arm_line.y, "the elbow under the line from the shoulder to the hand")
			var outward := signf(shoulder.x - _at(pose, CrewPose.NECK).x)
			assert_gt((elbow.x - arm_line.x) * outward, -0.01, "and not in across the chest")


func test_the_pose_only_turns_bones() -> void:
	var pose := _sat(RosterRules.Role.DRIVER)
	for rotation in pose.rotations:
		assert_almost_eq(rotation.length(), 1.0, 0.0001)
	var thigh := pose.global_of(CrewPose.LEGS[CrewPose.Side.LEFT][0]).origin.distance_to(pose.global_of(CrewPose.LEGS[CrewPose.Side.LEFT][1]).origin)
	var rest := _skeleton.get_bone_rest(_skeleton.find_bone(CrewPose.LEGS[CrewPose.Side.LEFT][1])).origin.length()
	assert_almost_eq(thigh, rest, 0.0001, "bones keep their lengths")
