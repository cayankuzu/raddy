class_name RoomCode
## Room codes for player-hosted rooms (spec §6.1): the host's address and port packed into
## 12 letters/digits with a checksum, grouped XXXX-XXXX-XXXX. Short enough to read out loud,
## not guessable in the sense that matters (there is no server to brute-force; a wrong code
## simply points nowhere). An alphabet without 0/O/1/I/L avoids misreads.

const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"  # 31 symbols
const LENGTH := 12


## Packs an IPv4 address and a port. Returns "" for anything that is not a dotted IPv4.
static func encode(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4 or port < 1 or port > 65535:
		return ""
	var value := 0
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		value = value * 256 + int(part)
	value = value * 65536 + port
	value = value * 256 + _checksum(value)
	var out := ""
	for i in LENGTH:
		out = ALPHABET[value % ALPHABET.length()] + out
		value /= ALPHABET.length()
	return out.substr(0, 4) + "-" + out.substr(4, 4) + "-" + out.substr(8, 4)


## Returns {"ip": String, "port": int} or {} when the code is malformed or mistyped.
static func decode(code: String) -> Dictionary:
	var clean := normalize(code)
	if clean.length() != LENGTH:
		return {}
	var value := 0
	for ch in clean:
		var digit := ALPHABET.find(ch)
		if digit < 0:
			return {}
		value = value * ALPHABET.length() + digit
	var check := value % 256
	value /= 256
	if check != _checksum(value):
		return {}
	var port := value % 65536
	var ip_value := value / 65536
	if port == 0 or ip_value > 0xFFFFFFFF:
		return {}
	var octets := PackedStringArray()
	for i in 4:
		octets.insert(0, str(ip_value % 256))
		ip_value /= 256
	return {"ip": ".".join(octets), "port": port}


## Upper-cases, drops separators and maps the easily confused characters onto the alphabet.
static func normalize(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		match ch:
			"-", " ", "_", ".":
				continue
			"O":
				out += "0"  # not in the alphabet either: stays invalid, but spelled out below
			"I", "L":
				out += "1"
			_:
				out += ch
	# 0 and 1 never appear in codes; a reader who saw them meant nothing we can recover.
	return out


## Is this the private LAN address of this PC, usable for friends on the same network?
static func is_private(ip: String) -> bool:
	return ip.begins_with("10.") or ip.begins_with("192.168.") \
		or (ip.begins_with("172.") and ip.split(".").size() == 4 and int(ip.split(".")[1]) >= 16 and int(ip.split(".")[1]) <= 31)


## First private IPv4 of this machine (for LAN play), or "" when there is none.
static func local_ipv4() -> String:
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and is_private(address) and not address.begins_with("169.254."):
			return address
	return ""


static func _checksum(value: int) -> int:
	var sum := 0
	var v := value
	while v > 0:
		sum = (sum * 31 + v % 256) % 256
		v /= 256
	return sum
