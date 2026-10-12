extends GutTest
## Remote-body playback: snapshots interpolate in sender time, late packets are dropped and
## extrapolation is capped, so network jitter never becomes speed jitter.

const DELAY := 100.0


func _snap(x: float, vx := 0.0, steer := 0.0) -> Dictionary:
	return {"origin": Vector3(x, 0.0, 0.0), "rotation": Quaternion.IDENTITY, "lin": Vector3(vx, 0.0, 0.0),
		"ang": Vector3.ZERO, "extra": PackedFloat32Array([steer])}


func test_interpolates_between_two_snapshots() -> void:
	var buffer := SnapshotBuffer.new()
	# Sender clock 1000 arrives at local 5000: offset 4000.
	buffer.push(1000, 5000, _snap(0.0, 10.0, 0.0))
	buffer.push(1100, 5100, _snap(1.0, 10.0, 0.5))
	# Render time 1050 in sender clock = local 5050 + delay 100.
	var state := buffer.sample(5150, DELAY)
	assert_almost_eq(state.origin.x, 0.5, 0.001, "half way")
	assert_almost_eq(state.extra[0], 0.25, 0.001, "extras interpolate too")


func test_holds_the_oldest_snapshot_before_the_first_one() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1000, 5000, _snap(3.0))
	var state := buffer.sample(5000, DELAY)  # render time 900: before any snapshot
	assert_almost_eq(state.origin.x, 3.0, 0.001)


func test_extrapolates_past_the_newest_snapshot_but_not_forever() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1000, 5000, _snap(0.0, 10.0))
	buffer.push(1100, 5100, _snap(1.0, 10.0))
	var a := buffer.sample(5300, DELAY)  # render 1200: 100 ms past the newest
	assert_almost_eq(a.origin.x, 2.0, 0.001, "100 ms along the velocity")
	var b := buffer.sample(9000, DELAY)  # seconds past: capped
	assert_almost_eq(b.origin.x, 1.0 + 10.0 * SnapshotBuffer.MAX_EXTRAPOLATION_MS * 0.001, 0.001, "capped")


func test_late_and_duplicate_packets_are_dropped() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1000, 5000, _snap(0.0))
	buffer.push(1100, 5100, _snap(1.0))
	buffer.push(1050, 5120, _snap(99.0))  # arrived late
	buffer.push(1100, 5130, _snap(99.0))  # duplicate
	assert_eq(buffer.size(), 2)
	# Late packets still nudge the clock offset by DRIFT_RATE, hence the loose tolerance.
	assert_almost_eq(buffer.sample(5150, DELAY).origin.x, 0.5, 0.02)


func test_jittered_arrivals_do_not_change_the_timeline() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1000, 5000, _snap(0.0, 10.0))
	buffer.push(1100, 5160, _snap(1.0, 10.0))  # arrived 60 ms late
	buffer.push(1200, 5200, _snap(2.0, 10.0))
	# The offset follows the least delayed packet (4000), so sender time 1150 is local 5250.
	assert_almost_eq(buffer.sample(5250, DELAY).origin.x, 1.5, 0.05)


func test_keeps_a_bounded_history() -> void:
	var buffer := SnapshotBuffer.new()
	for i in 200:
		buffer.push(1000 + i * 33, 5000 + i * 33, _snap(float(i)))
	assert_eq(buffer.size(), SnapshotBuffer.MAX_SNAPSHOTS)


func test_empty_buffer_samples_nothing() -> void:
	assert_true(SnapshotBuffer.new().sample(5000, DELAY).is_empty())
