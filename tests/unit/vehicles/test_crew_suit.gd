extends GutTest
## How the race suit is cut over the mannequin (CrewSuit): where a limb's piece meets the body a seam is sewn along the crease, and a
## finger's back is the upper half of each of its pieces, as a glove is cut.


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


func test_a_fingers_back_is_the_upper_half_of_each_piece() -> void:
	var points := PackedVector3Array([Vector3(0.8, 1.40, 0.0), Vector3(0.8, 1.44, 0.0), Vector3(0.81, 1.42, 0.0),
		Vector3(0.9, 1.43, 0.0), Vector3(0.9, 1.45, 0.0), Vector3(0.91, 1.44, 0.0), Vector3(0.7, 1.4, 0.0)])
	var indices := PackedInt32Array([0, 1, 2, 3, 4, 5])
	var parts := PackedInt32Array([3, 3, 3, 3, 3, 3, CrewSuit.Part.ARM])
	var island := CrewSuit.islands(points, indices)
	assert_eq(island[0], island[2], "a piece is one island")
	assert_ne(island[0], island[3], "two pieces are two")
	var backs := CrewSuit.finger_backs(points, parts, island, PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7]))
	assert_eq(backs[0], 0.0, "the bottom of a piece is palm")
	assert_eq(backs[1], 1.0, "its top is the back")
	assert_almost_eq(backs[2], 0.5, 0.01, "its sides between")
	assert_eq([backs[3], backs[4]], [0.0, 1.0], "each piece by its own height")
	assert_almost_eq(backs[6], 0.7, 0.0001, "the hand's back keeps its own")
