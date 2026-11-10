class_name CrewRules
extends RefCounted
## What a crew member does with the head and the hands (pure, tested): the hands system of GAME_DESIGN §3 as the bodies every peer sees
## show it (CrewRig), and a seat's state as it travels the network. Every hand holds one thing: the wheel, the map, the shock gun, a
## window's winder, the wipers' stalk, the horn, the handbrake, a can, a pointing finger. A gesture is a way to talk without a voice:
## pointing left, straight on or right, or patting the air for "slow down", with the hand nearer the partner (the driver's right, the
## navigator's left), where the partner sees it at a glance.

enum Gesture { NONE, LEFT, STRAIGHT, RIGHT, SLOW }
## What a player sent a hand (or the legs) to do for a moment: wind a window (each side), switch the wipers, throw a can out of the right
## window, kick the windshield out.
enum Job { NONE, WINDOW_LEFT, WINDOW_RIGHT, WIPERS, THROW, KICK }
## What a hand does: holds the wheel, rests on the lap (or hangs there, out cold), holds the map, the shock gun, points (a gesture), winds a
## window, flicks the wipers' stalk, presses the horn, pulls the handbrake, throws a can, changes gear.
enum Hand { WHEEL, LAP, MAP, GUN, POINT, WINDOW, WIPERS, HORN, HANDBRAKE, THROW, GEAR }

const LEFT := 0
const RIGHT := 1
## How long each job takes (s): a window as long as its pane moves.
const JOB_SECONDS := {Job.WINDOW_LEFT: Cabin.PANE_SECONDS, Job.WINDOW_RIGHT: Cabin.PANE_SECONDS, Job.WIPERS: 0.5, Job.THROW: 0.6,
	Job.KICK: 0.9}
## A gesture shows at least this long however short the press (s), so the partner can catch it.
const GESTURE_SECONDS := 1.2
## A seat's state goes out this often (per second) through the host: a head turns and a hand moves slowly enough for that.
const SEND_RATE := 10.0
## The network channel it travels on (the snapshots use 1, the voice 2).
const CHANNEL := 3
## The input actions that make each gesture.
const GESTURE_ACTIONS := {&"gesture_left": Gesture.LEFT, &"gesture_straight": Gesture.STRAIGHT, &"gesture_right": Gesture.RIGHT,
	&"gesture_slow": Gesture.SLOW}


## One seat's state: its own peer keeps it, every other peer mirrors it.
class Seat:
	## Where the head looks (degrees: x to the left, y up), as the seat's camera turns.
	var look := Vector2.ZERO
	var gesture := Gesture.NONE
	var job := Job.NONE
	## Jobs started so far (one byte): a mirror sees a new one even when it is the same again (a second can).
	var jobs := 0
	## The shock gun is up (ShockInput).
	var aiming := false
	var _held := Gesture.NONE
	var _gesture_left := 0.0
	var _job_left := 0.0

	## A gesture's key went down: the hand points, at least GESTURE_SECONDS and as long as the key is held.
	func point(which: int) -> void:
		gesture = which
		_held = which
		_gesture_left = GESTURE_SECONDS

	## A gesture's key came up.
	func release(which: int) -> void:
		if _held == which:
			_held = Gesture.NONE

	func start_job(which: int) -> void:
		job = which
		jobs = (jobs + 1) % 256
		_job_left = JOB_SECONDS[which]

	## The seat's own peer: a gesture let go and shown long enough ends, a job done ends.
	func step(delta: float) -> void:
		_gesture_left = maxf(_gesture_left - delta, 0.0)
		if _held == Gesture.NONE and _gesture_left <= 0.0:
			gesture = Gesture.NONE
		if job != Job.NONE:
			_job_left -= delta
			if _job_left <= 0.0:
				job = Job.NONE

	## Four bytes for the wire: the look in whole degrees (signed), the gesture, the job and the gun in one byte, the job count.
	func pack() -> PackedByteArray:
		var bytes := PackedByteArray()
		bytes.resize(4)
		bytes.encode_s8(0, clampi(roundi(look.x), -127, 127))
		bytes.encode_s8(1, clampi(roundi(look.y), -127, 127))
		bytes[2] = gesture | job << 3 | (128 if aiming else 0)
		bytes[3] = jobs
		return bytes

	## Takes what another peer's seat sent; false, and nothing changes, when it is not a seat's state.
	func unpack(bytes: PackedByteArray) -> bool:
		if bytes.size() != 4:
			return false
		var which_gesture := bytes[2] & 7
		var which_job := (bytes[2] >> 3) & 15
		if which_gesture >= Gesture.size() or which_job >= Job.size():
			return false
		look = Vector2(bytes.decode_s8(0), bytes.decode_s8(1))
		gesture = which_gesture
		job = which_job
		aiming = bytes[2] & 128 != 0
		jobs = bytes[3]
		return true


## The hand a gesture is made with: the one nearer the partner.
static func gesture_hand(role: int) -> int:
	return RIGHT if role == RosterRules.Role.DRIVER else LEFT


## A player can gesture unless out cold or aiming the shock gun (the right hand holds it, and the gesture would need the other).
static func can_gesture(seat: Seat, fainted: bool) -> bool:
	return not fainted and not seat.aiming


## The hand a job is done with (LEFT or RIGHT; -1: none, the legs kick): the left winds the left window (the navigator reaches across for
## it), the right winds the right one, flicks the wipers' stalk (the driver) and throws (the navigator).
static func job_hand(job: int) -> int:
	match job:
		Job.WINDOW_LEFT:
			return LEFT
		Job.WINDOW_RIGHT, Job.WIPERS, Job.THROW:
			return RIGHT
	return -1


## What the hand of a job done with a hand does meanwhile.
static func job_does(job: int) -> int:
	match job:
		Job.WIPERS:
			return Hand.WIPERS
		Job.THROW:
			return Hand.THROW
	return Hand.WINDOW


## What each hand of a seat does, [left, right] (Hand). Out cold both rest on the lap. The shock gun is in the right hand, a job in its hand,
## a gesture in the hand nearer the partner, in that order; the driver's right hand pulls the handbrake, changes gear (`shifting`) or
## presses the horn while the car says so; the rest holds the wheel (the driver), the map while it is open (the navigator: both hands, so
## one busy hand leaves the other on the lap, the map folding) or rests on the lap.
static func hands(role: int, seat: Seat, fainted: bool, map_open: bool, horn: bool, handbrake: bool, shifting := false) -> PackedInt32Array:
	if fainted:
		return PackedInt32Array([Hand.LAP, Hand.LAP])
	var driver := role == RosterRules.Role.DRIVER
	var idle := Hand.WHEEL if driver else (Hand.MAP if map_open else Hand.LAP)
	var out := PackedInt32Array([idle, idle])
	if seat.aiming:
		out[RIGHT] = Hand.GUN
	var side := job_hand(seat.job)
	if side >= 0 and out[side] == idle:
		out[side] = job_does(seat.job)
	side = gesture_hand(role)
	if seat.gesture != Gesture.NONE and out[side] == idle:
		out[side] = Hand.POINT
	if driver and out[RIGHT] == Hand.WHEEL:
		if handbrake:
			out[RIGHT] = Hand.HANDBRAKE
		elif shifting:
			out[RIGHT] = Hand.GEAR
		elif horn:
			out[RIGHT] = Hand.HORN
	if idle == Hand.MAP and (out[LEFT] != Hand.MAP or out[RIGHT] != Hand.MAP):
		for each in 2:
			if out[each] == Hand.MAP:
				out[each] = Hand.LAP
	return out


## The driver steers with one hand while the other is off the wheel on a job (GAME_DESIGN §3), but not for a pull of the handbrake or a
## gear change: a rally driver's hand is back on the rim before the car has turned.
static func one_handed(role: int, held: PackedInt32Array) -> bool:
	return role == RosterRules.Role.DRIVER and held.count(Hand.WHEEL) == 1 and not held.has(Hand.HANDBRAKE) and not held.has(Hand.GEAR)
