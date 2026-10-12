class_name PortOpener
extends RefCounted
## Opens the host's UDP port on the home router with UPnP (free, built into Godot) and finds the
## public address for the internet room code. Discovery blocks for seconds, so it runs on a
## thread; the lobby polls `status`. Many ISPs put homes behind carrier-grade NAT, where no port
## can be opened: the status says so and the lobby offers the LAN code or a free VPN instead.

enum Status { IDLE, TRYING, OPEN, NO_ROUTER, SHARED_ADDRESS, FAILED }

var status := Status.IDLE
var external_ip := ""
var port := 0

var _thread: Thread
var _upnp: UPNP
var _mutex := Mutex.new()


func start(open_port: int) -> void:
	if status == Status.TRYING:
		return
	port = open_port
	status = Status.TRYING
	_thread = Thread.new()
	_thread.start(_work)


func _work() -> void:
	var upnp := UPNP.new()
	var result := upnp.discover(2000, 2, "InternetGatewayDevice")
	var final := Status.FAILED
	var address := ""
	if result != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		final = Status.NO_ROUTER
	else:
		var mapped := upnp.add_port_mapping(port, port, "RADDY", "UDP", 0)
		address = upnp.query_external_address()
		if not is_public(address):
			final = Status.SHARED_ADDRESS
		elif mapped == UPNP.UPNP_RESULT_SUCCESS:
			final = Status.OPEN
	_mutex.lock()
	_upnp = upnp
	external_ip = address
	status = final
	_mutex.unlock()


## Removes the mapping again (best effort; the router also forgets it on reboot).
func close() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_mutex.lock()
	if _upnp != null and status == Status.OPEN:
		_upnp.delete_port_mapping(port, "UDP")
	_upnp = null
	status = Status.IDLE
	_mutex.unlock()


## The room code friends on the internet use, or "" when there is none.
func internet_code() -> String:
	return RoomCode.encode(external_ip, port) if status == Status.OPEN else ""


## Public addresses only: private ranges and the carrier-grade NAT block 100.64.0.0/10 are not.
static func is_public(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size() != 4:
		return false
	var a := int(parts[0])
	var b := int(parts[1])
	if a == 10 or a == 127 or a == 0 or a >= 224:
		return false
	if a == 100 and b >= 64 and b <= 127:
		return false
	if a == 169 and b == 254:
		return false
	if a == 172 and b >= 16 and b <= 31:
		return false
	if a == 192 and b == 168:
		return false
	return true
