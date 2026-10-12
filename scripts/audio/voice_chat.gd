extends Node
## Autoload "Voice": proximity voice chat. Push-to-talk by default. Packets go to the host, which
## relays each one only to peers within range of the speaker (no team or global channel: spec §5);
## receivers play them from the speaker's seat through a VoicePlayback (3D, attenuated).
## A world provider (RaceSession) tells the host where each peer is and where to attach playback.
## Voice never touches the race: it fails soft and the game keeps running without it.

signal speaking_changed(peer_id: int, speaking: bool)
signal mic_problem(message: String)

## Peers farther than this from the speaker hear nothing (the host does not relay).
const RANGE := VoicePlayback.DEFAULT_RANGE
const CHANNEL := 2

var enabled := true
var push_to_talk := true
## Voice-activity mode (push_to_talk = false): transmit while the frame RMS is above this.
var activity_threshold := 0.02
var output_volume_db := 0.0
var capture := VoiceCapture.new()

var packets_sent := 0
var relayed_near := 0
var relayed_far := 0

var _muted_peers: Dictionary = {}  # peer_id -> true
var _playbacks: Dictionary = {}  # peer_id -> VoicePlayback
var _sequence := 0
var _activity_hang := 0.0
## Object with voice_position(peer_id) -> Vector3 (or null) and voice_anchor(peer_id) -> Node3D.
var _world: Object
var _fake_transmit_left := 0.0


func _ready() -> void:
	capture.name = "Capture"
	add_child(capture)
	capture.frame_ready.connect(_on_frame_ready)
	capture.silent_device.connect(func(seconds: float) -> void:
		mic_problem.emit("Mikrofon %d saniyedir hiç ses vermiyor: Windows mikrofon izni ve cihaz seçimini kontrol et" % int(seconds)))
	Net.session_started.connect(_on_session_started)
	Net.session_ended.connect(func(_reason: String) -> void: _teardown())


## RaceSession (or the lobby) tells Voice where players are.
func set_world(world: Object) -> void:
	_world = world
	for peer_id in _playbacks.keys():
		_attach(peer_id)


func mute_peer(peer_id: int, muted: bool) -> void:
	if muted:
		_muted_peers[peer_id] = true
	else:
		_muted_peers.erase(peer_id)


func is_peer_muted(peer_id: int) -> bool:
	return _muted_peers.has(peer_id)


func is_speaking(peer_id: int) -> bool:
	var playback: VoicePlayback = _playbacks.get(peer_id)
	return is_instance_valid(playback) and playback.speaking


func packets_from(peer_id: int) -> int:
	var playback: VoicePlayback = _playbacks.get(peer_id)
	return playback.packets_received if is_instance_valid(playback) else 0


func level_from(peer_id: int) -> float:
	var playback: VoicePlayback = _playbacks.get(peer_id)
	return playback.last_level if is_instance_valid(playback) else 0.0


## Tests: send a tone for `seconds` without a microphone.
func start_fake_transmit(seconds: float, tone_hz := 440.0) -> void:
	capture.fake_tone_hz = tone_hz
	capture.start()
	_fake_transmit_left = seconds


func _on_session_started(_as_host: bool) -> void:
	if not enabled or capture.fake_tone_hz > 0.0:
		return
	if AudioServer.get_driver_name() == "Dummy":
		print("VOICE capture off: no audio driver (headless)")
		return
	var err := capture.start()
	if err != OK:
		mic_problem.emit("Mikrofon açılamadı (%s); sesli sohbet kapalı, oyun devam ediyor" % error_string(err))


func _teardown() -> void:
	capture.stop()
	for playback in _playbacks.values():
		# A playback parented to a car dies with that car (despawn, scene change, quit).
		if is_instance_valid(playback):
			playback.queue_free()
	_playbacks.clear()


func _process(delta: float) -> void:
	if _fake_transmit_left > 0.0:
		_fake_transmit_left -= delta
		capture.transmitting = _fake_transmit_left > 0.0
		return
	if not Net.is_active() or not enabled:
		capture.transmitting = false
		return
	if push_to_talk:
		capture.transmitting = Input.is_action_pressed(&"voice_talk")
	else:
		if capture.level > activity_threshold:
			_activity_hang = 0.3
		else:
			_activity_hang -= delta
		capture.transmitting = _activity_hang > 0.0 or capture.level > activity_threshold


func _on_frame_ready(samples: PackedFloat32Array) -> void:
	if not Net.is_active():
		return
	_sequence = (_sequence + 1) & 0xFFFF
	packets_sent += 1
	var packet := VoiceCodec.encode_mulaw(samples)
	if Net.is_host():
		_relay(1, _sequence, packet)
	else:
		_rpc_voice_to_host.rpc_id(1, _sequence, packet)


@rpc("any_peer", "call_remote", "unreliable_ordered", CHANNEL)
func _rpc_voice_to_host(seq: int, packet: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var speaker := multiplayer.get_remote_sender_id()
	if not Net.roster.has(speaker) or packet.size() > VoiceCodec.FRAME_SAMPLES * 2:
		return
	_relay(speaker, seq, packet)


## Host: forward to every seated peer within RANGE of the speaker (and play it here if the host
## is a player in range). Without a world (lobby), everyone is "near".
func _relay(speaker: int, seq: int, packet: PackedByteArray) -> void:
	var speaker_position: Variant = _world.voice_position(speaker) if _world != null else null
	for peer_id in Net.roster:
		if peer_id == speaker:
			continue
		var near := true
		if speaker_position != null:
			var listener_position: Variant = _world.voice_position(peer_id)
			near = listener_position != null and (listener_position as Vector3).distance_to(speaker_position) <= RANGE
		if not near:
			relayed_far += 1
			continue
		relayed_near += 1
		if peer_id == multiplayer.get_unique_id():
			_rpc_voice_from(speaker, seq, packet)
		else:
			_rpc_voice_from.rpc_id(peer_id, speaker, seq, packet)


@rpc("authority", "call_remote", "unreliable_ordered", CHANNEL)
func _rpc_voice_from(speaker: int, seq: int, packet: PackedByteArray) -> void:
	if _muted_peers.has(speaker) or packet.size() > VoiceCodec.FRAME_SAMPLES * 2:
		return
	var playback := _playback_for(speaker)
	playback.push_packet(seq, VoiceCodec.decode_mulaw(packet))


func _playback_for(peer_id: int) -> VoicePlayback:
	if _playbacks.has(peer_id) and is_instance_valid(_playbacks[peer_id]):
		return _playbacks[peer_id]
	var playback := VoicePlayback.new()
	playback.name = "Voice%d" % peer_id
	playback.volume_db = output_volume_db
	playback.speaking_changed.connect(func(speaking: bool) -> void: speaking_changed.emit(peer_id, speaking))
	_playbacks[peer_id] = playback
	_attach(peer_id)
	return playback


## Puts the playback at the speaker's seat; with no world it hangs off this autoload (non-spatial).
func _attach(peer_id: int) -> void:
	var playback: VoicePlayback = _playbacks[peer_id]
	if not is_instance_valid(playback):
		_playbacks.erase(peer_id)  # went down with its car; recreated on the next packet
		return
	var anchor: Node3D = _world.voice_anchor(peer_id) if _world != null else null
	var parent: Node = anchor if anchor != null else self
	if playback.get_parent() == parent:
		return
	if playback.get_parent() != null:
		playback.get_parent().remove_child(playback)
	parent.add_child(playback)
	playback.position = Vector3.ZERO
