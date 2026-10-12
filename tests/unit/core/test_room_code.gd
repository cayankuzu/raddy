extends GutTest
## Room codes (spec §6.1): address + port round-trip, misreads are caught, garbage is rejected.


func test_round_trip_for_lan_and_internet_addresses() -> void:
	for ip in ["192.168.1.37", "10.0.0.2", "85.102.244.9", "255.255.255.255", "0.0.0.1"]:
		for port in [7777, 1, 65535, 27015]:
			var code := RoomCode.encode(ip, port)
			assert_eq(code.length(), 14, "XXXX-XXXX-XXXX: %s" % code)
			assert_eq(code.count("-"), 2)
			var decoded := RoomCode.decode(code)
			assert_eq(decoded.get("ip"), ip, code)
			assert_eq(decoded.get("port"), port, code)


func test_accepts_lowercase_spaces_and_missing_dashes() -> void:
	var code := RoomCode.encode("192.168.1.37", 7777)
	var sloppy := code.to_lower().replace("-", " ")
	assert_eq(RoomCode.decode(sloppy).get("ip"), "192.168.1.37")
	assert_eq(RoomCode.decode(code.replace("-", "")).get("port"), 7777)


func test_a_single_wrong_letter_is_rejected_not_misrouted() -> void:
	var code := RoomCode.encode("85.102.244.9", 7777)
	var wrong := 0
	for i in code.length():
		if code[i] == "-":
			continue
		for replacement in ["2", "9", "K", "Z"]:
			if replacement == code[i]:
				continue
			var typo: String = code.substr(0, i) + replacement + code.substr(i + 1)
			if RoomCode.decode(typo).is_empty():
				wrong += 1
			else:
				fail_test("typo %s decoded to %s" % [typo, RoomCode.decode(typo)])
	assert_gt(wrong, 30)


func test_rejects_garbage() -> void:
	assert_eq(RoomCode.decode(""), {})
	assert_eq(RoomCode.decode("HELLO-WORLD"), {})
	assert_eq(RoomCode.decode("2222-2222-2222-2"), {})
	assert_eq(RoomCode.encode("not.an.ip", 7777), "")
	assert_eq(RoomCode.encode("1.2.3.4", 0), "")
	assert_eq(RoomCode.encode("1.2.3.256", 7777), "")


func test_private_address_detection() -> void:
	assert_true(RoomCode.is_private("192.168.0.5"))
	assert_true(RoomCode.is_private("10.1.2.3"))
	assert_true(RoomCode.is_private("172.20.0.1"))
	assert_false(RoomCode.is_private("172.32.0.1"))
	assert_false(RoomCode.is_private("85.102.244.9"))
