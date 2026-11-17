extends GutTest
## Remote-body playback: snapshots interpolate in sender time, late packets are dropped and
## extrapolation is capped, so network jitter never becomes speed jitter. The playback clock (phase F) moves on by each tick's delta:
## two ticks in one frame show two moments, whatever the frames and the packets do.

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


## A sender at 30 Hz moving at 10 m/s (so x / 10 is the sender's second shown), its packets 20-60 ms on the way; a 60 Hz receiver whose
## frames jitter by 4 ms either way and run physics ticks the engine's way (0-3 a frame, mostly two at one wall-clock millisecond; at most
## eight, the rest of a slower frame's time lost to the physics). `frame` (s) slows the receiver down. Returns {wall: [ms], shown: [sender
## ms]} a tick.
func _play(seconds: float, by_clock: bool, frame_s := 1.0 / 60.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buffer := SnapshotBuffer.new()
	var packets: Array[Vector2i] = []  # (sent, arrives) in ms
	for i in int(seconds * 30.0) + 30:
		var sent := 1000 + int(i * 1000.0 / 30.0)
		packets.append(Vector2i(sent, sent + 4020 + rng.randi_range(0, 40)))
	var tick := 1.0 / 120.0
	var now := 5000.0 / 1000.0
	var accumulated := 0.0
	var walls: Array[float] = []
	var shown: Array[float] = []
	while now < 5.0 + seconds:
		var frame := frame_s + rng.randf_range(-0.004, 0.004)
		now += frame
		accumulated = minf(accumulated + frame, tick * 8.0)
		var wall := int(now * 1000.0)
		while not packets.is_empty() and packets[0].y <= wall:
			var packet: Vector2i = packets.pop_front()
			buffer.push(packet.x, packet.y, _snap(packet.x * 0.01, 10.0))
		while accumulated >= tick:
			accumulated -= tick
			var state := buffer.playback(tick, wall, DELAY) if by_clock else buffer.sample(wall, DELAY)
			if state.is_empty():
				continue  # nothing has arrived yet
			walls.append(float(wall))
			shown.append(state.origin.x * 100.0)
	return {"wall": walls, "shown": shown}


func test_playback_moves_on_every_tick_under_two_tick_frames_and_jitter() -> void:
	var run := _play(20.0, true)
	var shown: Array[float] = run.shown
	var tick_ms := 1000.0 / 120.0
	var repeats := 0
	var smallest := INF
	var largest := 0.0
	# From a second in: before the first snapshot's moment the oldest one is held.
	for i in range(121, shown.size()):
		var step := shown[i] - shown[i - 1]
		if step <= 0.0:
			repeats += 1
		smallest = minf(smallest, step)
		largest = maxf(largest, step)
	gut.p("playback clock: %d ticks, a tick shows %.2f-%.2f ms on (a tick is %.2f)" % [shown.size(), smallest, largest, tick_ms])
	assert_eq(repeats, 0, "no tick shows the same moment as the one before it")
	assert_gt(smallest, tick_ms * 0.9, "a tick's moment on, within a tenth")
	assert_lt(largest, tick_ms * 1.1, "never stepped")
	# The delay stays the 100 ms it was: the fastest packet took 20 ms, so what is shown is about 120 ms behind the wall clock.
	var behind := 0.0
	var walls: Array[float] = run.wall
	var half := shown.size() / 2
	for i in range(half, shown.size()):
		behind += walls[i] - 4000.0 - shown[i]
	behind /= shown.size() - half
	gut.p("playback clock: %.1f ms behind the sender (the 100 ms delay and the 20 ms the fastest packet took)" % behind)
	assert_almost_eq(behind, DELAY + 20.0, 3.0, "no tick of delay added")


func test_the_wall_clock_showed_one_moment_twice_in_a_frame() -> void:
	# Why the playback clock exists: sampled at the frame's wall-clock millisecond, the second tick of a frame repeats the first.
	var shown: Array[float] = _play(5.0, false).shown
	var repeats := 0
	for i in range(1, shown.size()):
		if shown[i] <= shown[i - 1]:
			repeats += 1
	gut.p("wall-clock sampling: %d of %d ticks repeat the tick before" % [repeats, shown.size()])
	assert_gt(repeats, shown.size() / 3)


func test_playback_starts_again_after_a_stall() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1000, 5000, _snap(0.0, 10.0))
	buffer.push(1100, 5100, _snap(1.0, 10.0))
	assert_almost_eq(buffer.playback(1.0 / 120.0, 5150, DELAY).origin.x, 0.5, 0.001, "starts where it should be")
	buffer.push(2000, 6000, _snap(10.0, 10.0))
	buffer.push(2100, 6100, _snap(11.0, 10.0))
	# A second later (a stall): too far off to catch up gently.
	assert_almost_eq(buffer.playback(1.0 / 120.0, 6150, DELAY).origin.x, 10.5, 0.001)


func test_empty_buffer_plays_nothing() -> void:
	assert_true(SnapshotBuffer.new().playback(1.0 / 120.0, 5000, DELAY).is_empty())


func test_a_corner_is_played_back_round() -> void:
	# A car on a 30 m circle at 20 m/s, a snapshot every 100 ms: halfway between two, straight pieces would cut 17 mm inside it.
	var buffer := SnapshotBuffer.new()
	var radius := 30.0
	var rate := 20.0 / radius
	for i in 3:
		var angle := rate * i * 0.1
		var at := Vector3(cos(angle), 0.0, sin(angle)) * radius
		var velocity := Vector3(-sin(angle), 0.0, cos(angle)) * 20.0
		buffer.push(1000 + i * 100, 5000 + i * 100, {"origin": at, "rotation": Quaternion.IDENTITY, "lin": velocity, "ang": Vector3.ZERO,
			"extra": PackedFloat32Array()})
	var halfway: Vector3 = buffer.sample(5150, DELAY).origin
	gut.p("halfway between two snapshots: %.2f mm off the circle" % ((halfway.length() - radius) * 1000.0))
	assert_almost_eq(halfway.length(), radius, 0.001, "on the circle within a millimetre")


func test_a_turn_that_quickens_is_played_back_smoothly() -> void:
	# Yawing ever faster (heading t^2, so 2t rad/s), a snapshot every 100 ms: halfway, a steady turn between two would be 0.14 deg off.
	var buffer := SnapshotBuffer.new()
	for i in 3:
		var t := i * 0.1
		buffer.push(1000 + i * 100, 5000 + i * 100, {"origin": Vector3.ZERO, "rotation": Quaternion(Vector3.UP, t * t), "lin": Vector3.ZERO,
			"ang": Vector3.UP * 2.0 * t, "extra": PackedFloat32Array()})
	var halfway: Quaternion = buffer.sample(5250, DELAY).rotation
	var heading := halfway.get_euler().y
	gut.p("halfway through a quickening turn: %.4f deg off" % rad_to_deg(heading - 0.0225))
	assert_almost_eq(heading, 0.0225, 0.0002, "on the turn's own path")


func test_playback_keeps_up_with_a_receiver_at_13_fps_without_a_step() -> void:
	# Frames of 71-79 ms: the engine runs eight ticks (67 ms) and the rest of each frame is lost to the physics.
	var run := _play(20.0, true, 0.075)
	var shown: Array[float] = run.shown
	var walls: Array[float] = run.wall
	var largest := 0.0
	var behind := 0.0
	for i in range(121, shown.size()):
		largest = maxf(largest, shown[i] - shown[i - 1])
		behind = maxf(behind, walls[i] - 4000.0 - shown[i])
	gut.p("at 13 fps: a tick shows up to %.2f ms on, at most %.0f ms behind the sender" % [largest, behind])
	assert_lt(largest, 1000.0 / 120.0 * (1.0 + SnapshotBuffer.CLOCK_SKEW) + 0.01, "never stepped")
	assert_lt(behind, DELAY + 20.0 + 100.0, "keeps up")
