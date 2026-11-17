# Phase J: a friend can always get in

Direction 2 puts this before anything is public: a co-op game reaches only as many people as their friends can join, and most home
connections in Turkey sit behind carrier-grade NAT, where UPnP cannot open a port and today's internet room code does not work. The owner
approved netfox and its noray addon on 2026-11-17; the release zips (v1.35.3, MIT) lie unopened in `raw_assets/downloads/netfox/v1.35.3/`
with their hashes in `docs/phases/downloads.md`.

**Since Direction 3 (2026-11-17, `order.md` phase 9).** Phase P1 built the protocol fingerprint test
(`tests/unit/network/test_protocol_fingerprint.gd`): item 3 here is only the refusal message. Item 4's rejoin uses P1's held car (the host
holds an empty car where it stands and hands it back through `_rpc_car_authority`).

Read first: CLAUDE.md "Multiplayer" and the gotchas about ENet; `scripts/network/net.gd`, `room_code.gd`, `port_opener*.gd`, `roster_rules.gd`;
the room's screens in `scripts/ui/`; `docs/phases/a8_net.md` (items 2 and 3 are this phase's; item 1's fingerprint is P1's and its refusal message is item 3 here; the
rest is A8's).

## Deliver
1. **The addon, pinned.** Unpack only what is needed from the zips with a script (check every member's name first) into `addons/` (the
   noray client and whatever of netfox's core it really needs; nothing of the example game), read its code before it runs, confirm it loads
   and works on Godot 4.7.2 (its stated range, a headless check), pin it in CLAUDE.md's "Third-party" with version and hash.
2. **Through any router.** Hosting registers the room with a noray server (a public instance; verify with a web search which ones run,
   their terms and whether a game may use them, and make the address a setting with a sensible default and a fallback list); the room code
   carries what a joiner needs (keep the `XXXX-XXXX-XXXX` look if it fits; a different visible prefix if it cannot); joining tries in order:
   the LAN address, the UPnP internet address, NAT punch-through through noray, noray's relay; each step with a timeout, the screen saying
   what it is doing in plain words in both languages, and a clear end ("could not reach the room: ask the host to check the code, or use
   Radmin VPN as the guide says"). Nothing personal is sent to the server (no names, no machine data: only what the protocol needs).
3. **The version refusal.** P1 pinned `Net.PROTOCOL_VERSION` against a fingerprint of every RPC's name and arguments and the room
   settings' keys, so a change without a bump fails the suite; here a peer with another version is refused with a message in its language
   naming both versions.
4. **Back into one's seat.** A client that drops during a race can rejoin the same room by its code within 60 s and gets its seat back with
   the state it needs (the car where it is, cabin, damage, gates, events fired, broken things, map state); meanwhile the host holds its car
   where it stands (P1's held car); the host leaving ends the race for everyone with the results so far and a message.
5. **Tests.** Headless tests for the code, the order of attempts and their timeouts (a fake noray), the refusal; nettest gains a client
   that drops and rejoins; a real check through the public noray server from this PC to itself (host and client on two ports), reported
   honestly with what it can and cannot prove; TEST_PLAN gets the check only people can do (two homes, two routers, one on mobile data).

Done means: CLAUDE.md (multiplayer, third-party), DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN, `ASSET_LICENSES.md` (netfox MIT), the strings;
full GUT, nettest and a flow test pass; commits on main.
