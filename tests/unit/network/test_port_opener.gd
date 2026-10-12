extends GutTest
## Which addresses a friend on the internet can reach (UPnP result check): private ranges and
## carrier-grade NAT (100.64.0.0/10) mean "no internet code", public ones do.


func test_public_addresses() -> void:
	for ip in ["85.102.244.9", "8.8.8.8", "100.63.255.1", "100.128.0.1", "172.32.0.1", "193.140.1.1"]:
		assert_true(PortOpener.is_public(ip), ip)


func test_private_shared_and_bad_addresses() -> void:
	for ip in ["10.0.0.1", "192.168.1.1", "172.16.5.4", "172.31.255.255", "100.64.0.1", "100.127.3.4",
			"127.0.0.1", "169.254.1.1", "0.0.0.0", "224.0.0.1", "", "not-an-ip", "1.2.3"]:
		assert_false(PortOpener.is_public(ip), ip)


func test_internet_code_only_when_open() -> void:
	var opener := PortOpener.new()
	opener.port = 7777
	opener.external_ip = "85.102.244.9"
	assert_eq(opener.internet_code(), "", "nothing before UPnP succeeded")
	opener.status = PortOpener.Status.OPEN
	var decoded := RoomCode.decode(opener.internet_code())
	assert_eq(decoded.get("ip"), "85.102.244.9")
	assert_eq(decoded.get("port"), 7777)
