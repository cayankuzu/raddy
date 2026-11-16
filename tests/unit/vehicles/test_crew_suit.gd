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
