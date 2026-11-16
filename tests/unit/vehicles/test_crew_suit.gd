extends GutTest
## How the race suit is cut over the mannequin (CrewSuit): where a limb's piece meets the body a seam is sewn along the crease, and a
## finger's back is one panel along it and its cloth spans the pinches at its joints, as a glove is cut.


func test_a_seam_runs_where_a_limb_comes_out_of_the_body() -> void:
	var body := [Vector3(0.0, 0.0, 0.0), Vector3(0.006, 0.0, 0.0), Vector3(0.3, 0.0, 0.0)]
	var arm := [Vector3(0.0, 0.004, 0.0), Vector3(0.0, -0.003, 0.001), Vector3(0.0, 0.1, 0.0)]
	var points := PackedVector3Array(body + arm + [Vector3(0.001, 0.001, 0.0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.UP])
	var parts := PackedInt32Array([CrewSuit.Part.BODY, CrewSuit.Part.BODY, CrewSuit.Part.BODY, CrewSuit.Part.ARM, CrewSuit.Part.ARM,
		CrewSuit.Part.ARM, CrewSuit.Part.FINGER])
	var meeting := CrewSuit.meeting(points, normals, parts)
	assert_almost_eq(meeting[3], 0.004, 0.0001, "an arm's vertex just outside the body")
	assert_almost_eq(meeting[4], -0.003, 0.0001, "one inside it")
	assert_almost_eq(meeting[5], CrewSuit.MEET_REACH, 0.0001, "one far from it meets nothing")
	assert_almost_eq(meeting[1], 0.006, 0.0001, "the body's, measured to the arm's surface")
	assert_almost_eq(meeting[2], CrewSuit.MEET_REACH, 0.0001, "the body far from any limb")
	assert_almost_eq(meeting[6], CrewSuit.MEET_REACH, 0.0001, "a finger meets nothing")


func test_a_fingers_back_is_one_panel_round_its_bones_line() -> void:
	# A finger along +x, its back up, two bones: the first carries the vertex near its joint, both the one at the joint's ball.
	var first := [1.0, Vector3.ZERO, Vector3(0.04, 0.0, 0.0), Vector3.UP]
	var second := [1.0, Vector3(0.04, 0.0, 0.0), Vector3(0.075, 0.0, 0.0), Vector3.UP]
	var faces := CrewBody.GLOVE_BACK
	assert_eq(CrewSuit.finger_back(Vector3(0.02, 0.008, 0.0), Vector3.FORWARD, [first], faces), 1.0, "the top of a piece")
	assert_eq(CrewSuit.finger_back(Vector3(0.02, -0.008, 0.0), Vector3.DOWN, [first], faces), 0.0, "its underside, the palm's")
	assert_eq(CrewSuit.finger_back(Vector3(0.039, 0.007, 0.0), Vector3.RIGHT, [first], faces), 1.0, "its round end at the joint, facing along the finger")
	assert_eq(CrewSuit.finger_back(Vector3(0.04, 0.009, 0.001), Vector3.FORWARD, [first, second], faces), 1.0, "the top of the joint's ball")
	assert_eq(CrewSuit.finger_back(Vector3(0.082, 0.004, 0.0), Vector3.RIGHT, [second], faces), 1.0, "past the last joint, over the tip")
	assert_eq(CrewSuit.finger_back(Vector3(0.07, -0.001, 0.0), Vector3(0.3, 0.95, 0.0).normalized(), [second], faces), 1.0,
		"the tip's top, fallen under the bone's line")
	assert_between(CrewSuit.finger_back(Vector3(0.02, 0.0005, 0.008), Vector3.BACK, [first], faces), 0.2, 0.8, "its side, where the seam runs")
	assert_eq(CrewSuit.finger_back(Vector3(0.02, 0.008, 0.0), Vector3.FORWARD, [], faces), 0.0, "no finger's bone, no finger's back")


func test_a_glove_spans_the_pinch_at_a_fingers_joint() -> void:
	# A finger along +x, two beads with their tops up and the pinch between them over the joint, a piece's end inside the joint, the palm's
	# side under the pinch.
	var points := PackedVector3Array([Vector3(0.01, 0.008, 0.0), Vector3(0.04, 0.005, 0.0), Vector3(0.07, 0.008, 0.0),
		Vector3(0.039, 0.002, 0.0), Vector3(0.04, -0.005, 0.0)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.RIGHT, Vector3.DOWN])
	var placed := CrewSuit.fill_fingers(points, normals, [[[0, 1, 2, 3, 4], Vector3.ZERO, Vector3(0.08, 0.0, 0.0)]])
	assert_eq(placed[0], points[0], "a bead's top stays")
	assert_eq(placed[2], points[2], "the next one's too")
	assert_almost_eq(placed[1].y, 0.008 - CrewSuit.FINGER_CREASE, 0.00001, "the pinch filled, a crease left")
	assert_eq(placed[3], points[3], "a piece's end inside the joint stays")
	assert_eq(placed[4], points[4], "nothing over the palm's side spans it")
