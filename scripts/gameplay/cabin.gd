class_name Cabin
extends Node3D
## Shared cabin state of one car: side windows, the glovebox can stock and the paper map. The
## host owns it (multiplayer authority 1): seat holders ask, the host validates against the
## roster and broadcasts. Offline the request applies directly. Cracks, the kick-out and wind
## effects come with P2; the windshield mesh is only visual for now.
## Each seat's player owns what they do with the head and the hands (`seats`): their peer sends it through the host to everyone else.

signal window_changed(side: int, open: bool)
signal cans_changed(cans_left: int)
## Host only: a throw was validated and the hand lets go; RaceSession spawns the can.
signal throw_approved(side: int)
signal map_changed(state: int)
## The wind is about to take the map (true) or the danger passed (false).
signal map_warning(active: bool)
## The map flew out of the window on `side`; a new one comes after MAP_COOLDOWN.
signal map_lost(side: int)
signal window_state_changed(side: int, state: int, cracked: bool)
signal windshield_changed(state: int)
## A stone off the road marked the windshield: `hits` so far (every peer).
signal stone_chipped(hits: int)
signal dirt_changed(level: float)
signal wipers_changed(on: bool)
signal dome_changed(on: bool)
## Gravel hit a seat's face (short flash on that player's screen).
signal face_hit(role: int)
signal faint_changed(role: int, fainted: bool)
## A shock gun dart hit this seat (every peer; the faint follows through faint_changed).
signal shocked(role: int)

enum Side { LEFT, RIGHT }
enum MapState { CLOSED, OPEN, GONE }
enum WindowState { CLOSED, OPEN, BROKEN }
enum Windshield { INTACT, CRACKED, REMOVED }
## Spec §9.4: a faint lasts this long.
const FAINT_SECONDS := 6.0
const FAINT_THRESHOLD := 1.0
## Exposure left after waking up: not straight back into the next faint.
const FAINT_RESIDUE := 0.35
## Exposure per second with the cabin fully open, on dry gravel, at 25 m/s.
const EXPOSURE_RATE := 0.09
const EXPOSURE_DECAY := 0.08
const EXPOSURE_SPEED_FLOOR := 8.0
const EXPOSURE_SPEED_FULL := 25.0
## Chance per second of a stone in the face at full exposure rate.
const FACE_HIT_CHANCE := 0.3
const FACE_HIT_EXPOSURE := 0.12
const WIPER_CLEAR_RATE := 0.22
## A side window slides this way into its door (car space, the glass's own slant) and this far, in this long. What
## has gone below its lower edge when closed, the door's sill, is cut away: the door is more upright than the glass.
const PANE_SLIDE: Array[Vector3] = [Vector3(-0.42, -0.907, 0.0), Vector3(0.42, -0.907, 0.0)]
const PANE_TRAVEL := 0.5
const SILL_MARGIN := 0.002
const PANE_SECONDS := 0.9
const RUSTLE: Array[AudioStream] = [preload("res://assets/audio/car/map_rustle_0.ogg"), preload("res://assets/audio/car/map_rustle_1.ogg")]
## Glass dirt per second while driving through a water splash (at 15 m/s), and how often an open
## window lets a wave hit the seat beside it (per second).
const WATER_DIRT_RATE := 1.4
const WATER_SOAK_CHANCE := 2.5
## Can speeds (relative, m/s) that crack and break a side window (spec §9.2, §10.3).
const WINDOW_CRACK_SPEED := 8.0
const WINDOW_BREAK_SPEED := 13.0
const CAN_STOCK := 3
## Spec §11.3: a lost map is replaced after this many seconds.
const MAP_COOLDOWN := 6.0
## Below this speed (m/s) an open window never takes the map; above it the risk grows with speed.
const MAP_WIND_SPEED := 14.0
## Risk per second per m/s over MAP_WIND_SPEED: at 25 m/s (90 km/h) the map lasts ~1 s of warning.
const MAP_RISK_RATE := 1.0 / 11.0
const MAP_RISK_DECAY := 0.6
const MAP_WARNING_RISK := 0.4
## An impact at least this hard (RallyCar.impact strength, m/s of velocity lost) drops the map.
const MAP_IMPACT_LOSS := 8.0

## Set by RaceSession at spawn; used to check who may touch this cabin.
var team := 0
## The local player's seat in this cabin (NONE when watching another team's car).
var local_role := RosterRules.Role.NONE
## Derived from window_state for the older callers: open or broken lets the wind in.
var window_open: Array[bool] = [false, false]
var window_state: Array[int] = [WindowState.CLOSED, WindowState.CLOSED]
var window_cracked: Array[bool] = [false, false]
var windshield := Windshield.INTACT
## How many stones have marked this windshield (StoneChipRules).
var stone_hits := 0
## Host: metres along the road to the next car in front, set by the race (StoneChipRules).
var gap_ahead := StoneChipRules.NOBODY_AHEAD
var dirt := 0.0
var wipers_on := false
## The cabin's dome lamp (the map holder's switch, CarLamps shows it).
var dome_on := false
## Per seat (RosterRules.Role): how much wind, dust and grit it has taken; 1 = faint.
var exposure: Dictionary = {RosterRules.Role.DRIVER: 0.0, RosterRules.Role.NAVIGATOR: 0.0}
var fainted: Dictionary = {RosterRules.Role.DRIVER: false, RosterRules.Role.NAVIGATOR: false}
var faint_left: Dictionary = {RosterRules.Role.DRIVER: 0.0, RosterRules.Role.NAVIGATOR: 0.0}
## Host: seconds a seat cannot be shocked again (the faint plus ShockRules.IMMUNE_SECONDS).
var shock_immune_left: Dictionary = {RosterRules.Role.DRIVER: 0.0, RosterRules.Role.NAVIGATOR: 0.0}
## Per seat (RosterRules.Role), what its player does with the head and the hands (CrewRules.Seat: where they look, a gesture, a job a hand
## is on, the shock gun up). The seat's own peer keeps it (the seat's camera, CabinInput, ShockInput) and sends it CrewRules.SEND_RATE
## times a second through the host, unreliably: the next one makes up for a lost one. Every other peer mirrors it; the bodies show it
## (CrewRig). Nothing in it touches the simulation but the driver's own steering (one hand off the wheel, CrewRules.one_handed).
var seats: Dictionary = {RosterRules.Role.DRIVER: CrewRules.Seat.new(), RosterRules.Role.NAVIGATOR: CrewRules.Seat.new()}
var cans_left := CAN_STOCK
## Dirt per second from the sky (rain drops, snow), set by the race layer from the weather.
var weather_dirt_rate := 0.0
var _rng := RandomNumberGenerator.new()
var _dirt_sent := 0.0
var _exposure_sent: Dictionary = {RosterRules.Role.DRIVER: 0.0, RosterRules.Role.NAVIGATOR: 0.0}
var map_state := MapState.CLOSED
var map_risk := 0.0
var map_warning_active := false
## Seconds until a lost map is replaced (counts down on every peer for the HUD).
var map_cooldown_left := 0.0
var paper_map: PaperMap

## How far down each side pane is, 0 closed .. 1 inside the door.
var _pane_down: Array[float] = [0.0, 0.0]
var _seat_send := 0.0
## Host: when each seat was last heard from (ms), so a peer cannot flood the relay.
var _seat_heard: Dictionary = {RosterRules.Role.DRIVER: 0, RosterRules.Role.NAVIGATOR: 0}
var _pane_closed: Array[Vector3] = []
var _pane_sills: Array[Plane] = []
## Host: seconds until the soles of a kick on its way meet the windshield (0: none), and the cans on their way out of a window, each
## [side, seconds until the hand lets it go].
var _kick_lands_in := 0.0
var _throws: Array[Array] = []

@onready var _window_meshes: Array[MeshInstance3D] = [$WindowLeft, $WindowRight]
@onready var _windshield_mesh: MeshInstance3D = $Windshield


func _ready() -> void:
	paper_map = PaperMap.new()
	paper_map.name = "PaperMap"
	paper_map.cabin = self
	add_child(paper_map)
	var car := get_parent() as RallyCar
	if car != null:
		car.impact.connect(_on_impact)
	for mesh in _window_meshes:
		_pane_closed.append(mesh.position)
		_pane_sills.append(_sill_of(mesh))


## Slides the side panes towards where their state says, as far as they can go: a broken one is gone. Keeps the local seat's state.
func _process(delta: float) -> void:
	for side in 2:
		var wanted := 1.0 if window_state[side] == WindowState.OPEN else 0.0
		if _pane_down[side] == wanted or window_state[side] == WindowState.BROKEN:
			continue
		_pane_down[side] = move_toward(_pane_down[side], wanted, delta / PANE_SECONDS)
		_show_pane(side)
	_keep_local_seat(delta)


## The local player's seat looks where its camera does, its gesture and its job run their time; during a race it goes out to the others.
func _keep_local_seat(delta: float) -> void:
	if local_role == RosterRules.Role.NONE:
		return
	var seat: CrewRules.Seat = seats[local_role]
	var camera := get_parent().get_node_or_null(NodePath(CarModel.seat_camera(local_role))) as CockpitCamera
	if camera != null:
		seat.look = camera.head_angles()
	seat.step(delta)
	if not Net.is_active() or not Net.race_running:
		return
	_seat_send += delta
	if _seat_send < 1.0 / CrewRules.SEND_RATE:
		return
	_seat_send = 0.0
	if multiplayer.is_server():
		_relay_seat(multiplayer.get_unique_id(), local_role, seat.pack())
	else:
		_rpc_seat_to_host.rpc_id(1, seat.pack())


## What each hand of a seat does now ([left, right], CrewRules.Hand), on every peer; `shifting`: the driver is changing gear.
func hands_of(role: int, shifting := false) -> PackedInt32Array:
	var car := get_parent() as RallyCar
	var horn := car != null and car.controls.horn
	var handbrake := car != null and car.controls.handbrake
	return CrewRules.hands(role, seats[role], is_fainted(role), role == RosterRules.Role.NAVIGATOR and map_state == MapState.OPEN, horn, handbrake,
		shifting)


## A seat's player tells the host what they do (CrewRules.Seat.pack); the host knows their seat from the roster.
@rpc("any_peer", "call_remote", "unreliable_ordered", CrewRules.CHANNEL)
func _rpc_seat_to_host(packed: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not Net.is_in_team(sender, team):
		return
	var role: int = Net.roster[sender].role
	if not seats.has(role) or Time.get_ticks_msec() - int(_seat_heard[role]) < 500.0 / CrewRules.SEND_RATE:
		return
	_seat_heard[role] = Time.get_ticks_msec()
	_relay_seat(sender, role, packed)


## Host: a seat's state, taken here (unless it is the host's own) and passed to every other player.
func _relay_seat(sender: int, role: int, packed: PackedByteArray) -> void:
	if sender != multiplayer.get_unique_id() and not _take_seat(role, packed):
		return
	for peer_id: int in Net.roster:
		if peer_id != sender and peer_id != multiplayer.get_unique_id():
			_rpc_seat.rpc_id(peer_id, role, packed)


@rpc("authority", "call_remote", "unreliable_ordered", CrewRules.CHANNEL)
func _rpc_seat(role: int, packed: PackedByteArray) -> void:
	if seats.has(role) and role != local_role:
		_take_seat(role, packed)


## Another player's seat as it was sent; false when the packet is not a seat's state. A change of the hands is printed (not every look).
func _take_seat(role: int, packed: PackedByteArray) -> bool:
	var seat: CrewRules.Seat = seats[role]
	var before := [seat.gesture, seat.job, seat.aiming]
	if not seat.unpack(packed):
		return false
	if before != [seat.gesture, seat.job, seat.aiming]:
		print("NET seat team %d %s gesture %s job %s gun %s look %d %d" % [team, RosterRules.role_name(role),
			CrewRules.Gesture.keys()[seat.gesture].to_lower(), CrewRules.Job.keys()[seat.job].to_lower(), "up" if seat.aiming else "down",
			seat.look.x, seat.look.y])
	return true


func _show_pane(side: int) -> void:
	var mesh := _window_meshes[side]
	var moved := PANE_SLIDE[side] * PANE_TRAVEL * _pane_down[side]
	mesh.position = _pane_closed[side] + moved
	mesh.visible = window_state[side] == WindowState.CLOSED or (window_state[side] == WindowState.OPEN and _pane_down[side] < 1.0)
	# The sill stays where it is while the glass moves past it.
	var sill := _pane_sills[side]
	mesh.set_instance_shader_parameter(&"sill", Vector4(sill.normal.x, sill.normal.y, sill.normal.z, sill.d - sill.normal.dot(mesh.basis.inverse() * moved)))


## The plane of a closed pane's lower edge in its mesh's space, its normal pointing up the glass.
static func _sill_of(pane: MeshInstance3D) -> Plane:
	var up := pane.basis.inverse() * Vector3.UP
	var along := pane.basis.inverse() * Vector3.BACK
	var faces := pane.mesh.get_faces()
	var least := INF
	var most := -INF
	for v in faces:
		least = minf(least, v.dot(along))
		most = maxf(most, v.dot(along))
	var front := Vector3.INF
	var rear := Vector3.INF
	for v in faces:
		var t := (v.dot(along) - least) / maxf(most - least, 0.001)
		if t < 0.25 and (front == Vector3.INF or v.dot(up) < front.dot(up)):
			front = v
		elif t > 0.75 and (rear == Vector3.INF or v.dot(up) < rear.dot(up)):
			rear = v
	var edge := rear - front
	var normal := edge.cross(up).cross(edge).normalized()
	return Plane(normal, front.dot(normal) - SILL_MARGIN)


## Gives the map its drawing; RaceSession (or a dev scene) calls it once the route exists.
func setup_map(graph: RouteGraph, notes: Array[Dictionary], contour: Image) -> void:
	paper_map.setup(graph, notes, contour)


## The map belongs to the navigator; a team without one lets its driver read it.
func may_hold_map(peer_id: int) -> bool:
	if not Net.is_active():
		return true
	var navigator := RosterRules.navigator_of(Net.roster, team)
	if navigator != 0:
		return peer_id == navigator
	return peer_id == RosterRules.driver_of(Net.roster, team)


func local_may_hold_map() -> bool:
	if not Net.is_active():
		return local_role != RosterRules.Role.NONE
	return local_role != RosterRules.Role.NONE and may_hold_map(Net.local_id())


func is_fainted(role: int) -> bool:
	return fainted.get(role, false)


func request_kick_windshield() -> void:
	if not Net.is_active():
		_handle_kick_request(0)
	elif multiplayer.is_server():
		_handle_kick_request(multiplayer.get_unique_id())
	else:
		_rpc_request_kick.rpc_id(1)


func request_wipers(on: bool) -> void:
	if not Net.is_active():
		_handle_wipers_request(0, on)
	elif multiplayer.is_server():
		_handle_wipers_request(multiplayer.get_unique_id(), on)
	else:
		_rpc_request_wipers.rpc_id(1, on)


func request_dome(on: bool) -> void:
	if not Net.is_active():
		_handle_dome_request(0, on)
	elif multiplayer.is_server():
		_handle_dome_request(multiplayer.get_unique_id(), on)
	else:
		_rpc_request_dome.rpc_id(1, on)


## Host: a can (or stone) hit a side window at `relative_speed`.
func window_hit(side: int, relative_speed: float) -> void:
	if not _is_authority_here() or window_state[side] == WindowState.BROKEN:
		return
	if relative_speed >= WINDOW_BREAK_SPEED or (window_cracked[side] and relative_speed >= WINDOW_CRACK_SPEED):
		_broadcast(_rpc_set_window_state, [side, WindowState.BROKEN, true])
	elif relative_speed >= WINDOW_CRACK_SPEED and not window_cracked[side]:
		_broadcast(_rpc_set_window_state, [side, window_state[side], true])


func request_map(open: bool) -> void:
	if not Net.is_active():
		_handle_map_request(0, open)
	elif multiplayer.is_server():
		_handle_map_request(multiplayer.get_unique_id(), open)
	else:
		_rpc_request_map.rpc_id(1, open)


func request_window(side: int, open: bool) -> void:
	if not Net.is_active():
		_handle_window_request(0, side, open)
	elif multiplayer.is_server():
		_handle_window_request(multiplayer.get_unique_id(), side, open)
	else:
		_rpc_request_window.rpc_id(1, side, open)


func request_throw(side: int) -> void:
	if not Net.is_active():
		return  # throwing needs the race session's spawner, which is network-only for now
	if multiplayer.is_server():
		_handle_throw_request(multiplayer.get_unique_id(), side)
	else:
		_rpc_request_throw.rpc_id(1, side)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_window(side: int, open: bool) -> void:
	if multiplayer.is_server():
		_handle_window_request(multiplayer.get_remote_sender_id(), side, open)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_throw(side: int) -> void:
	if multiplayer.is_server():
		_handle_throw_request(multiplayer.get_remote_sender_id(), side)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_map(open: bool) -> void:
	if multiplayer.is_server():
		_handle_map_request(multiplayer.get_remote_sender_id(), open)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_kick() -> void:
	if multiplayer.is_server():
		_handle_kick_request(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_wipers(on: bool) -> void:
	if multiplayer.is_server():
		_handle_wipers_request(multiplayer.get_remote_sender_id(), on)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_dome(on: bool) -> void:
	if multiplayer.is_server():
		_handle_dome_request(multiplayer.get_remote_sender_id(), on)


## Only the navigator kicks the windshield out (spec §9.1); a solo driver may too. The glass goes when the soles meet it (the bodies
## show the kick, CrewRig), not as the legs come up.
func _handle_kick_request(peer_id: int) -> void:
	if Net.is_active() and not may_hold_map(peer_id):
		return
	if windshield == Windshield.REMOVED or _kick_lands_in > 0.0:
		return
	_kick_lands_in = CrewRules.KICK_LANDS


func _handle_wipers_request(peer_id: int, on: bool) -> void:
	if Net.is_active() and not _may_touch(peer_id):
		return
	if wipers_on == on:
		return
	_broadcast(_rpc_set_wipers, [on])


## The dome lamp is whoever reads the map's: the navigator, or a solo driver.
func _handle_dome_request(peer_id: int, on: bool) -> void:
	if Net.is_active() and not may_hold_map(peer_id):
		return
	if dome_on == on:
		return
	_broadcast(_rpc_set_dome, [on])


## Host (or offline): dirt, stone chips, exposure and faints follow the car's speed and surface.
func _update_cabin_weather(delta: float) -> void:
	var car := get_parent() as RallyCar
	if car == null:
		return
	var speed := absf(car.forward_speed)
	var surface := car.wheel_surface(0)
	# Dirt builds up on the glass by surface and speed; wipers clear it (spec §9.1).
	if windshield != Windshield.REMOVED:
		dirt += (Surface.dirt_rate(surface) * (speed / 20.0) + weather_dirt_rate) * delta
		# A water splash throws a sheet of muddy water over the glass.
		if car.water_contacts > 0:
			dirt += WATER_DIRT_RATE * clampf(speed / 15.0, 0.2, 1.5) * delta
	if wipers_on:
		dirt -= WIPER_CLEAR_RATE * delta
	dirt = clampf(dirt, 0.0, 1.0)
	if absf(dirt - _dirt_sent) >= 0.04 or (dirt == 0.0 and _dirt_sent > 0.0):
		_dirt_sent = dirt
		_broadcast(_rpc_set_dirt, [dirt])
	# Stones off the road: rare alone, the price of following someone close.
	if windshield != Windshield.REMOVED and stone_hits < StoneChipRules.MOST_HITS \
			and _rng.randf() < StoneChipRules.chance_per_second(speed, surface, gap_ahead) * delta:
		_broadcast(_rpc_stone_chip, [stone_hits + 1])
		if stone_hits >= StoneChipRules.CRACKS_AT and windshield == Windshield.INTACT:
			_broadcast(_rpc_set_windshield, [Windshield.CRACKED])
	# Exposure per seat (spec §9.3-9.4).
	var wind := clampf((speed - EXPOSURE_SPEED_FLOOR) / (EXPOSURE_SPEED_FULL - EXPOSURE_SPEED_FLOOR), 0.0, 1.3)
	for role in [RosterRules.Role.DRIVER, RosterRules.Role.NAVIGATOR]:
		var rate := _opening_for(role) * Surface.grit(surface) * wind * EXPOSURE_RATE
		if fainted[role]:
			faint_left[role] -= delta
			if faint_left[role] <= 0.0:
				_broadcast(_rpc_set_faint, [role, false, FAINT_RESIDUE])
			continue
		# Through a splash with your own window open (or no windshield): a face full of muddy water.
		var own := Side.LEFT if role == RosterRules.Role.DRIVER else Side.RIGHT
		var soak_open := windshield == Windshield.REMOVED or window_state[own] != WindowState.CLOSED
		if car.water_contacts > 0 and speed > 6.0 and soak_open and _rng.randf() < WATER_SOAK_CHANCE * delta:
			exposure[role] += FACE_HIT_EXPOSURE
			_broadcast(_rpc_face_hit, [role])
		if rate > 0.0:
			exposure[role] += rate * delta
			if _rng.randf() < FACE_HIT_CHANCE * (rate / EXPOSURE_RATE) * delta:
				exposure[role] += FACE_HIT_EXPOSURE
				_broadcast(_rpc_face_hit, [role])
		else:
			exposure[role] = maxf(exposure[role] - EXPOSURE_DECAY * delta, 0.0)
		if exposure[role] >= FAINT_THRESHOLD:
			_broadcast(_rpc_set_faint, [role, true, FAINT_THRESHOLD])
		elif absf(exposure[role] - _exposure_sent[role]) >= 0.05:
			_exposure_sent[role] = exposure[role]
			if Net.is_active():
				_rpc_set_exposure.rpc(role, exposure[role])


## How open the cabin is for a seat: 1 = no windshield, part for an open or broken window.
func _opening_for(role: int) -> float:
	var own := Side.LEFT if role == RosterRules.Role.DRIVER else Side.RIGHT
	var other := Side.RIGHT if own == Side.LEFT else Side.LEFT
	var opening := 0.0
	match windshield:
		Windshield.REMOVED:
			opening = 1.0
		Windshield.CRACKED:
			opening = 0.1
	match window_state[own]:
		WindowState.OPEN:
			opening += 0.45
		WindowState.BROKEN:
			opening += 0.6
	if window_state[other] != WindowState.CLOSED:
		opening += 0.15
	return minf(opening, 1.3)


## Runs an authority RPC on every peer, or just here when offline.
func _broadcast(method: Callable, args: Array) -> void:
	if Net.is_active():
		_rpc_dispatch(method, args)
	else:
		method.callv(args)


func _rpc_dispatch(method: Callable, args: Array) -> void:
	# Callable.rpc() takes the arguments directly; spread them by arity.
	match args.size():
		0:
			method.rpc()
		1:
			method.rpc(args[0])
		2:
			method.rpc(args[0], args[1])
		3:
			method.rpc(args[0], args[1], args[2])
		_:
			push_error("Cabin._broadcast: too many arguments")


func _handle_map_request(peer_id: int, open: bool) -> void:
	if not may_hold_map(peer_id):
		return
	if open and map_state != MapState.CLOSED:
		return  # already open, or gone and still being replaced
	if not open and map_state != MapState.OPEN:
		return
	_broadcast_map(MapState.OPEN if open else MapState.CLOSED)


## Host (or offline): the wind risk while the map is held up with a window open, plus dirt,
## stone chips, exposure and faints.
func _physics_process(delta: float) -> void:
	if map_cooldown_left > 0.0:
		map_cooldown_left = maxf(map_cooldown_left - delta, 0.0)
	for role in faint_left:
		if faint_left[role] > 0.0 and not _is_authority_here():
			faint_left[role] = maxf(faint_left[role] - delta, 0.0)
	if not _is_authority_here():
		return
	for role in shock_immune_left:
		shock_immune_left[role] = maxf(float(shock_immune_left[role]) - delta, 0.0)
	_finish_deeds(delta)
	_update_cabin_weather(delta)
	if fainted[RosterRules.Role.NAVIGATOR] and map_state == MapState.OPEN and RosterRules.navigator_of(Net.roster, team) != 0:
		_broadcast_map(MapState.CLOSED)  # the map slips out of unconscious hands
	if map_state == MapState.GONE:
		if map_cooldown_left <= 0.0:
			_broadcast_map(MapState.CLOSED)
		return
	if map_state != MapState.OPEN:
		map_risk = 0.0
		return
	var car := get_parent() as RallyCar
	var speed := absf(car.forward_speed) if car != null else 0.0
	var exposed := window_open[Side.LEFT] or window_open[Side.RIGHT]
	if exposed and speed > MAP_WIND_SPEED:
		map_risk += (speed - MAP_WIND_SPEED) * MAP_RISK_RATE * delta
	else:
		map_risk = maxf(map_risk - MAP_RISK_DECAY * delta, 0.0)
	var warning := map_risk >= MAP_WARNING_RISK
	if warning != map_warning_active:
		_apply_map_warning(warning)
		if Net.is_active():
			_rpc_map_warning.rpc(warning)
	if map_risk >= 1.0:
		_lose_map(Side.RIGHT if window_open[Side.RIGHT] else Side.LEFT)


## Host (or offline): what a seat set going comes about when the body's move gets there: the kicked windshield goes, a thrown can flies.
func _finish_deeds(delta: float) -> void:
	if _kick_lands_in > 0.0:
		_kick_lands_in -= delta
		if _kick_lands_in <= 0.0 and windshield != Windshield.REMOVED:
			_broadcast(_rpc_set_windshield, [Windshield.REMOVED])
	for i in range(_throws.size() - 1, -1, -1):
		_throws[i][1] -= delta
		if _throws[i][1] <= 0.0:
			throw_approved.emit(_throws[i][0])
			_throws.remove_at(i)


## The car's own impact signal: only where this peer both simulates the car and owns the cabin
## (the host's own car, or offline). Client-driven cars reach host_impact through the host.
func _on_impact(strength: float, _local_direction: Vector3) -> void:
	if _is_authority_here():
		host_impact(strength)


## Whether a dart can pass this car's `opening` (ShockRules.Opening): an open or broken side
## window, or no windshield; never the rear glass.
func is_open_for_shot(opening: int) -> bool:
	match opening:
		ShockRules.Opening.LEFT:
			return window_state[Side.LEFT] != WindowState.CLOSED
		ShockRules.Opening.RIGHT:
			return window_state[Side.RIGHT] != WindowState.CLOSED
		ShockRules.Opening.FRONT:
			return windshield == Windshield.REMOVED
	return false


func is_shock_immune(role: int) -> bool:
	return float(shock_immune_left.get(role, 0.0)) > 0.0


## Host (or offline): a dart hit `role`: they faint now (Cabin.FAINT_SECONDS) and are immune until
## ShockRules.IMMUNE_SECONDS after waking. False when they were already out or still immune.
func host_shock(role: int) -> bool:
	if not _is_authority_here() or fainted.get(role, false) or is_shock_immune(role):
		return false
	shock_immune_left[role] = FAINT_SECONDS + ShockRules.IMMUNE_SECONDS
	_broadcast(_rpc_shocked, [role])
	_broadcast(_rpc_set_faint, [role, true, exposure[role]])
	return true


@rpc("authority", "call_local", "reliable")
func _rpc_shocked(role: int) -> void:
	shocked.emit(role)


## Host (or offline): something smeared the windshield (a tree's crown); the regular tick sends it.
func host_add_dirt(amount: float) -> void:
	if not _is_authority_here() or windshield == Windshield.REMOVED:
		return
	dirt = clampf(dirt + amount, 0.0, 1.0)


## Host: a crash this hard knocks the open map out of the navigator's hands.
func host_impact(strength: float) -> void:
	if map_state == MapState.OPEN and strength >= MAP_IMPACT_LOSS:
		_lose_map(Side.RIGHT if window_open[Side.RIGHT] else Side.LEFT)


func _lose_map(side: int) -> void:
	map_risk = 0.0
	if Net.is_active():
		_rpc_map_lost.rpc(side)
	else:
		_rpc_map_lost(side)


func _broadcast_map(state: int) -> void:
	if Net.is_active():
		_rpc_set_map.rpc(state)
	else:
		_rpc_set_map(state)


func _is_authority_here() -> bool:
	return not Net.is_active() or multiplayer.is_server()


func _handle_window_request(peer_id: int, side: int, open: bool) -> void:
	if not _may_touch(peer_id) or side < 0 or side > 1 or window_open[side] == open:
		return
	if window_state[side] == WindowState.BROKEN:
		return  # nothing left to close
	_broadcast(_rpc_set_window_state, [side, WindowState.OPEN if open else WindowState.CLOSED, window_cracked[side]])


func _handle_throw_request(peer_id: int, side: int) -> void:
	if not _may_touch(peer_id) or side < 0 or side > 1:
		return
	if not window_open[side] or cans_left <= 0:
		return  # closed window or empty glovebox: nothing happens (P2 adds the bounce)
	_rpc_set_cans.rpc(cans_left - 1)
	_throws.append([side, CrewRules.THROW_LEAVES])


func _may_touch(peer_id: int) -> bool:
	if not Net.is_active():
		return true
	return Net.is_in_team(peer_id, team)


@rpc("authority", "call_local", "reliable")
func _rpc_set_window(side: int, open: bool) -> void:
	_rpc_set_window_state(side, WindowState.OPEN if open else WindowState.CLOSED, window_cracked[side])


@rpc("authority", "call_local", "reliable")
func _rpc_set_window_state(side: int, state: int, cracked: bool) -> void:
	var was_open := window_open[side]
	window_state[side] = state
	window_cracked[side] = cracked
	window_open[side] = state != WindowState.CLOSED
	_show_pane(side)
	window_state_changed.emit(side, state, cracked)
	if window_open[side] != was_open:
		window_changed.emit(side, window_open[side])
	print("NET window %d %s%s team %d" % [side, WindowState.keys()[state].to_lower(), " cracked" if cracked else "", team])


@rpc("authority", "call_local", "reliable")
func _rpc_set_windshield(state: int) -> void:
	windshield = state
	_windshield_mesh.visible = state != Windshield.REMOVED
	if state == Windshield.REMOVED:
		dirt = 0.0
		dirt_changed.emit(dirt)
	windshield_changed.emit(state)
	print("NET windshield %s team %d" % [Windshield.keys()[state].to_lower(), team])


@rpc("authority", "call_local", "reliable")
func _rpc_stone_chip(hits: int) -> void:
	stone_hits = hits
	stone_chipped.emit(hits)
	print("NET stone chip %d team %d" % [hits, team])


@rpc("authority", "call_local", "reliable")
func _rpc_set_wipers(on: bool) -> void:
	wipers_on = on
	wipers_changed.emit(on)


@rpc("authority", "call_local", "reliable")
func _rpc_set_dome(on: bool) -> void:
	dome_on = on
	dome_changed.emit(on)


@rpc("authority", "call_local", "reliable")
func _rpc_set_dirt(level: float) -> void:
	dirt = level
	dirt_changed.emit(level)


@rpc("authority", "call_remote", "reliable")
func _rpc_set_exposure(role: int, value: float) -> void:
	exposure[role] = value


@rpc("authority", "call_local", "reliable")
func _rpc_face_hit(role: int) -> void:
	face_hit.emit(role)


@rpc("authority", "call_local", "reliable")
func _rpc_set_faint(role: int, is_fainted: bool, exposure_after: float) -> void:
	fainted[role] = is_fainted
	faint_left[role] = FAINT_SECONDS if is_fainted else 0.0
	exposure[role] = exposure_after
	_exposure_sent[role] = exposure_after
	faint_changed.emit(role, is_fainted)
	print("NET %s %s team %d" % ["driver" if role == RosterRules.Role.DRIVER else "navigator", "fainted" if is_fainted else "woke up", team])


@rpc("authority", "call_local", "reliable")
func _rpc_set_cans(count: int) -> void:
	cans_left = count
	cans_changed.emit(count)


@rpc("authority", "call_local", "reliable")
func _rpc_set_map(state: int) -> void:
	if state != map_state:
		_rustle()
	map_state = state
	map_risk = 0.0
	if map_warning_active:
		_apply_map_warning(false)
	map_changed.emit(state)
	print("NET map %s team %d" % [MapState.keys()[state].to_lower(), team])


## Paper noise from the navigator's seat.
func _rustle() -> void:
	var audio := get_parent().get_node_or_null(^"Audio") as CarAudio
	if audio != null:
		audio.play_one_shot(RUSTLE[randi() % RUSTLE.size()], 0.8, Vector3(0.35, 0.55, 0.0), randf_range(0.95, 1.08))


@rpc("authority", "call_local", "reliable")
func _rpc_map_lost(side: int) -> void:
	map_state = MapState.GONE
	map_cooldown_left = MAP_COOLDOWN
	if map_warning_active:
		_apply_map_warning(false)
	map_lost.emit(side)
	map_changed.emit(MapState.GONE)
	print("NET map lost through window %d team %d" % [side, team])


@rpc("authority", "call_remote", "reliable")
func _rpc_map_warning(active: bool) -> void:
	_apply_map_warning(active)


func _apply_map_warning(active: bool) -> void:
	map_warning_active = active
	map_warning.emit(active)
