# Phase P: on foot, and into any car

The owner (2026-11-17): "You must be able to get into cars. The character control is very mediocre: fix it. More interaction: everything
can be touched." Direction 2 (`docs/GAME_DESIGN.md`, last section, item 9 of the order) already put "on foot: get out and in while the car
stands, walk, push, open the gate" after the demo, and named what has to come first: `Cabin.occupant`, because today a role **is** a seat
**is** a simulating peer. This phase does that refactor first, then gives every player a body that walks with the feel of a good
first-person game, the rally car's doors to get in and out by, a few ordinary cars that drive, and hands on foot for doors, things and
people. The laws stay: nothing alive is ever hit (law 1: a car never touches a walking player either), the rally is the heart (getting out
costs time; it never becomes a shortcut), you never take another crew's car and never ride on a roof.

**Two phases, far apart (Direction 3, `order.md`).** Steps 1-2 are **phase P1, "the seat is not the player"**: plumbing with no visible
change, run early (after L2, before X), because X's breakables and debris need named physics layers, J's rejoin needs a car that can change
hands and wait without its driver, and every later RPC needs the protocol fingerprint test, which P1 builds (A8 item 1's last sentences; J
and every later phase keep it green). Steps 3-9 are **phase P2, "on foot"**, after D: by then X's `DiveRules`, W's villages, gates and
parked cars and H's pick rule exist, so P2 builds on them instead of stand-ins. Since the owner asked for it ("arabalara binilebilmeli"),
on foot is in the play-test build, no longer "after the demo" (Direction 2's item 9 is overruled by Direction 3).

**Honest size.** About 25 builder parts of 1-3 hours (the table at the end: P1 5, P2 20, listed in `order.md`), in nine steps, each leaving the game whole and
the suite green. What a free, AI-built version reaches: a first-person controller that feels as tight as a good independent game (the numbers below
are the targets, measured by tests, not by eye), animation from the 89 free Quaternius clips already on the disk, getting into a car by a
procedural path and the real opening door (no motion capture: it will read as deliberate, not as GTA's hand-animated entries), four
drivable cars (the rally car and three ordinary ones from one author's series), people who answer with a written line. Not in reach and not
promised: GTA's scale, traffic that drives itself, dialogue trees, entering buildings (that belongs to the world phases), weapons.

## Read first
- CLAUDE.md, all of "Vehicle code", "Crew", "What a crew member does", "Multiplayer", "Tests"; GAME_DESIGN §10 (one state owner per system)
  and "Direction 2" (laws 1, 6, 7, 8).
- `scripts/gameplay/race_session.gd`: `_rpc_spawn_car` (the car's authority is fixed at spawn to the roster's driver, `impact` is connected
  only on that peer), `_bind_local_seat` (creates `PlayerCarInput`, `RouteFollower`, `SeatEffects`, `RecoveryInput`, `CabinInput`,
  `ShockInput` and never frees them), `_on_player_left` (a team whose driver leaves is despawned: "MVP, spec 4.2"), `seat_taken`,
  `seat_head`, `voice_anchor` (the roster's role picks the seat camera), `_team_seats`, `_seat_crew`.
- `scripts/gameplay/cabin.gd` (14 places read the roster's role: `_rpc_seat_to_host`, `may_hold_map`, `_may_touch`, the navigator's faint
  and map), `cabin_input.gd`, `shock_input.gd`, `recovery_input.gd`, `crew_rules.gd` (`Seat.pack`, `CHANNEL` 3).
- `scripts/network/body_net_sync.gd` and `snapshot_buffer.gd`, `net.gd` (`roster`, `PROTOCOL_VERSION`, `is_in_team`),
  `roster_rules.gd`; `scenes/dev/net_test.tscn` and `scripts/dev/net_test.gd` (the scripted actions nettest asserts).
- `scripts/vehicles/crew_body.gd` (`build`, `bake`, `harness_mesh`, `set_own`), `crew_rig.gd`, `crew_pose.gd` (`sit`, `stand`,
  `EYES_AT_REST`), `car_model.gd` (`WHEELS`, `seat_crew`, `bind_seat`), `car_parts.gd`, `car_rally_kit.gd` (`seat_taken`),
  `rally_car.gd` (`set_simulated`, `get_net_extra`, wheel rays), `vehicle_config.gd`, `tools/make_crew_mannequin.gd`,
  `scripts/procedural/spectator_clothes.gd` and `spectators.gd` (they read the mannequin's vertices), `rally_props.gd` (the parked Milano).
- `scripts/gameplay/checkpoint.gd`, `water_splash.gd`, `stage_events.gd`, `scripts/props/energy_can.gd`: every `Area3D` in the game.
- Briefs that touch this one: `a6_chaos.md` item 2 (doors that pop open: the same door cut), `h_hands.md` (the pick rule and the hint line),
  `x_mayhem.md` (people who dive, breakables), `w_world.md` (parked cars, gates, villages), `a8_net.md` (anti-teleport, rate limits),
  `j_join.md` (the version refusal on P1's fingerprint, rejoin).

## Traps the code holds
1. **One physics layer for everything.** No layer is named in `project.godot`; every body is on layer 1 and every query and area uses
   the default mask. A walker on layer 1 would be hit by the cars' wheel rays (`RallyCar._simulate_wheel`: a car would drive up onto a
   person), would pass gates (`Checkpoint` reports any body to `_on_gate_passed`), fire stage events (`StageEvents` triggers), splash
   (`WaterSplash`) and be found by the recovery's ground ray. Step 1 names the layers and gives every query and area an explicit mask
   before a walker exists.
2. **The car's authority is set once.** `set_multiplayer_authority(driver_peer)` on the car and its `BodyNetSync` at spawn;
   `_rpc_snapshot` is `"authority"`: after a change, an old owner's snapshot still in flight is refused by SceneMultiplayer with an error in
   the log, which nettest would read as a failure. Make the snapshot RPC `any_peer` and drop, silently, what does not come from the current
   owner of the current epoch.
3. **Binding is one way.** `_bind_local_seat` adds six nodes to the session and `CarModel.bind_seat` raises the glass's priority, takes
   `OWN_HEAD_LAYER` out of the camera and wakes the mirrors; nothing undoes any of it. Getting out needs the exact inverse
   (`unbind_seat`), tested by binding and unbinding twice and comparing the node tree and the mirrors' state.
4. **The harness and HANS are static meshes made over the seated pose, in car space** (`CrewBody.harness_mesh`). A standing body
   cannot wear them. The walking body is the same suit and helmet without them (the helmet's tethers end on the hips: they hang).
5. **The mannequin is shared.** The crew's suit (`CrewSuit`), the crowd (`SpectatorClothes`, `face_relief`) and the own-head folding read
   `crew_mannequin.glb`'s vertices and bone weights. Do not re-bake its mesh: put the clips in a separate `AnimationLibrary` (step 3) and
   pin the glb's bytes with a test.
6. **Two skeletons in the free library.** UAL1's Godot file (46 clips, 53 joints `root`, `DEF-hips`, `DEF-spine.001`...) is the
   mannequin's own skeleton: its clips play as they are once the dots are renamed to underscores the way the import did. UAL2's file (43
   clips) uses an Unreal skeleton (`pelvis`, `spine_01`, 65 joints): those clips need retargeting through a `BoneMap` to
   `SkeletonProfileHumanoid`; take only the few this phase needs from it and check each by eye.
7. **Skeleton modifiers run after the animation.** The crew's `TwoBoneIK3D`, `LookAtModifier3D` and `CopyTransformModifier3D` sit on the
   same skeleton; on foot they must be off (or used only for the head's look and a hand on a door), or they fight the clips.
8. **Doors are not parts.** The Milano's front doors are welded into `Milano95_Body` (only the glass and mirrors are cut by `CarParts`);
   the three ordinary cars are the same (`Fairheaven_*`, `LCT300095_*`, `Shvan92_*`: separate wheels `WheelStock_FL/FR/RL/RR`, glass,
   steering wheel and interior, no separate front doors). Probe first whether a door panel is an island inside its box; if it is not,
   `CarParts` needs a slicing cut along the shut lines (clip the triangles by planes, close the edge with the interior's door card).
   `Shvan92` names two wheels `WheelStock_RL`: map its wheels by position, not by name. The Fairheaven's tailgate carries a badge material
   (`Carbadges_misc_U`): cover it. The tractor's wheels share meshes and the moped is one mesh: out of this phase.
9. **`RallyCar._ready` adds `CarAudio`, `CarRoadFx`, `CarTyreMarks`** and the group `rally_cars` (the crowd watches it, the stones count it).
   An ordinary car can share the physics, the sound and the marks, but not the group's meaning: give it its own group and check every
   reader of `RallyCar.GROUP` and of `RaceSession._team_cars`.
10. **ENet channels 1-3 are taken** (snapshots, voice, seats). Walkers take channel 4; check the channel count `Net.host`/`join` create the
    peer with.

## Deliver (in order; each step ends with GUT, nettest and a flow test green and a commit)
1. **The occupant refactor (no visible change).** `Cabin.occupants: Dictionary` role -> peer (0 empty), owned by the host, synced with a
   reliable RPC and printed (`NET occupant team 2 driver 1234`). The roster's `role` stays what the lobby chose (the start seat, the
   names on the livery); everything that asks "who is in this seat now" asks the cabin: `seat_taken`, `seat_head`, `voice_anchor`,
   `_team_seats`, `may_hold_map`, `_may_touch`, `_rpc_seat_to_host` (the sender's seat from the occupants), `CrewRig`'s 13 reads,
   `RaceHud`, `LiveryRules.seat_name`. A pure `SeatRules` (tested): who may enter which seat (own team only, a free seat, the car
   standing, `GateRules.STANDING_SPEED`), who simulates a car (the driver seat's occupant, else the host). Name the physics layers (world,
   cars, walkers, props, debris, triggers, interiors: leave the bits phases X and I need named and unused) and give every ray, shape and
   area an explicit mask (trap 1). Done when the 64 roster reads in 12 files are down to the lobby's and a grep test keeps them there.
   **The protocol fingerprint** (`tests/unit/network/test_protocol_fingerprint.gd`): every RPC's name and argument list and the room
   settings' keys hashed and pinned against `Net.PROTOCOL_VERSION`, so a change without a bump fails the suite; this step's own RPCs are
   its first bump. J item 3 then only adds the refusal message; X, P2, OW, I, N and Q bump it as they add.
2. **A car changes hands.** `RaceSession._rpc_car_authority(car_id, peer, epoch)`: every peer sets the car's and its sync's authority,
   clears the buffer, `set_simulated(peer == me)`, and (re)connects `impact` and the input there. Allowed only while the car stands, so the
   100 ms the copy lags is nothing. An empty car belongs to the host, handbrake on, throttle 0 (`HOLD_SPEED` holds it on a slope).
   `_on_player_left` no longer despawns a team whose driver leaves: the car stands where it is on the host, the navigator may move over
   (step 5) and drive on; the team is out only when nobody of it is left. Tests: a pure test of the epoch rule; nettest: the driver
   client leaves mid-stage, the host holds the car, the navigator takes the wheel and finishes (`NET authority car 2 -> 1 -> 3`).
3. **The clips.** `tools/make_crew_clips.gd` (headless) reads UAL1 and the few UAL2 clips, renames the tracks to the mannequin's bones,
   drops root motion from loops, measures each loop's ground speed from its planted foot and writes `assets/characters/crew_clips.res`
   (an `AnimationLibrary`) plus that speed as metadata. From UAL1: `Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`,
   `Crouch_Idle_Loop`, `Crouch_Fwd_Loop`, `Jump_Start`, `Jump_Loop`, `Jump_Land`, `Roll`, `Push_Loop`, `PickUp_Table`, `Interact`,
   `Idle_Talking_Loop`, `Sitting_Exit`; from UAL2: `Walk_Carry_Loop`, `OverhandThrow`, `ClimbUp_1m_RM`, `Idle_FoldArms_Loop`,
   `Chest_Open`. Tests: every track resolves to a bone, `crew_mannequin.glb`'s hash is unchanged, the crowd and the suit tests still pass,
   the shipped library stays under 3 MB.
4. **A body that walks** (`scripts/player/`): `Walker` (`CharacterBody3D`, capsule 0.30 x 1.74 m, crouched 1.20 m) driven by
   `WalkerRules` (pure, tested: speeds, acceleration, air control, step, slope, coyote time, jump buffer); `WalkerBody` (the suit and
   helmet of `CrewBody` standing, no harness or HANS, an `AnimationTree` blending the clips by speed with `speed_scale` = ground speed /
   the clip's measured speed, so the feet do not skate); `WalkerCamera` (first person from the capsule's eye, 1.615 m, not from the head
   bone: the eye follows the capsule smoothed plus a bob of its own, the body is placed under it; the own head folded away as in a seat;
   C toggles a third-person view on a `SpringArm3D` 3.2 m behind and 0.4 m right, the own head shown). Dev scene
   `scenes/dev/walk_test.tscn`: steps of 10-45 cm, slopes of 20-50 degrees, a ramp, a 1 m ledge, crates and barrels, a parked Milano,
   a gate; `--autowalk` runs a scripted course for tests and shots. The feel targets, all asserted:

   | | target |
   |---|---|
   | speeds | walk 1.5 m/s (Alt held), jog 3.6 m/s (default), sprint 5.8 m/s (Shift), crouch 1.1 m/s |
   | ground | to jog in 0.18 s, to sprint in 0.4 s, stop from jog in 0.12 s; turning at speed keeps 85 % of it |
   | air | control 20 %; jump 0.5 m high; coyote 0.12 s; a jump pressed 0.1 s early still jumps |
   | ground shape | climbs 0.35 m steps without a jump and without a hitch in speed (step up by `test_move`, then snap down); walks 40 degree slopes, slides on steeper; snaps to the ground up to 0.4 m on the way down |
   | camera | mouse raw, no smoothing, the cockpit's sensitivity setting; bob 2.5 cm up and 1.5 cm aside a stride at a jog, 4 cm sprinting, nothing standing, off/low/full in the settings; FOV 64 degrees vertical (+4 sprinting, eased) |
   | landing | the eye dips 4 cm per m/s of fall, at most 12 cm, back in 0.25 s; from 7 m/s a stumble (0.4 s slower), from 9 m/s a roll; nobody is hurt |
   | input lag | none over one physics tick (120 Hz), pinned like the driving benchmarks |
5. **In and out of the rally car.** Hold X 0.4 s in a seat while the car stands (or click the inner handle, law 6) to get out; LMB or E
   on the outer handle to get in, into the seat behind that door (a free seat; the navigator's door gives the driver's seat when it is
   empty: seat swaps happen this way). The doors: `CarParts` cuts both front doors (trap 8) and hinges them at the A pillar, the door's
   state in `Cabin` like the windows (host-owned, synced) so A6's doors that pop open build on it. The way in and out is a pure path
   (`SeatPath`, tested): the eye from standing beside the door to the seat's camera, ducking under the roof line, measured against the
   car's own triangles as `test_seat_view.gd` does (never within 3 cm of a triangle), 1.1 s in, 0.9 s out; the body blends from the clip
   to `CrewPose.sit` with its hips along the same path and its feet placed by IK; the door opens 0.35 s before and shuts behind (the
   Sonniss `volvo_door_interior.wav` and `fiesta_door_various.wav`, cut by `tools/cut_audio.py`). The seated `CrewBody` and the walking
   one are swapped at the path's end, where their poses meet; the harness shows buckled once seated (A6 adds the click). `unbind_seat`
   and `bind_walker` are each other's inverse (trap 3).
6. **Walkers on the network.** `WalkerNetSync` (owner-authoritative, 20 Hz on channel 4: position, yaw, pitch, velocity, a state byte:
   crouched, airborne, sprinting, carrying, in a path), played back 100 ms behind with `SnapshotBuffer`, the clips driven from the played
   velocity. Getting in and out are requests to the host (`SeatRules`, the walker's last snapshot within 2 m of the door, the car
   standing), which moves the occupant and, for the driver's seat, the car's authority (step 2). The host also refuses a walker that moves
   faster than 9 m/s outside a jump or a path (A8's anti-teleport, for walkers). Voice hangs on the walker's head while on foot. Protocol
   version up, P1's fingerprint test updated. A walker who drops rejoins (J item 4) where its last snapshot was. nettest: a scripted client gets out, walks 15 m, comes back, gets in the other seat, the car drives
   on (`NET walker`, `NET occupant` lines asserted on every peer).
7. **The rally with someone out.** Getting out is allowed only while the car stands (no jumping from a moving car). The car may drive on
   with a seat empty; a crew member on foot more than 40 m from their car for 20 s, or when the car passes a split or the finish, is
   brought back to their seat: their screen cuts to black for a second with a line in the game's dry voice ("Yirmi saniye sonra, utanç
   içinde arabaya geri döndün." / "Twenty seconds later, you got back in. Nobody mentions it."), the team takes 15 s, and the results show
   it as an award line ("Unutulan navigatör" / "Left behind"). A recovery puts everyone back in their seat. Bots never get out. Before the
   countdown and after the finish anyone may walk about the start or finish area freely. Law 1 for walkers: a car and a walker never
   collide (the cars' mask leaves walkers out; the walker's own collides with cars, so nobody walks through a parked one); a walker in a
   car's path 0.6 s ahead dives aside on its own peer (`Roll`, the input held off 0.6 s, X's `DiveRules`, the same rule as the crowd's); a car
   does not move off while a walker stands in its open door. flowtest `--flow-walk`: the navigator bot gets out at the first split's
   stop, is left behind, is brought back, the results show the line.
8. **Hands on foot.** One `use` (LMB per law 6, E as the key, the gamepad's X) on what the view ray meets, picked by the same rule as H's
   hotspots (nearest within 1.8 m reach and within a small cone, no physics query; H's code, shared), named in the hint line
   in both languages. Doors (cars now; W's gates and houses later through an `Interactable` node with a kind and a verb). Pick up, carry
   and throw: a loose body under 25 kg (cans, X's crates, fruit, cones) is carried 0.6 m before the chest on a spring, its authority handed
   to the carrier like a car's (step 2's mechanism, any speed: it is light), the clip `Walk_Carry_Loop`; LMB again throws it along the
   view (`OverhandThrow`, 9 m/s, the release on the clip's frame), RMB drops it; heavier bodies (barrels, a standing car) are pushed:
   holding `use` on them with `Push_Loop` asks their owner to apply up to 600 N each (two players push a stuck rally car out of a ditch).
   People: `use` on a person within 2.5 m calls `Talkable.talk(crew)` if the person has one; this step builds the `Talkable` node (an
   interface: a kind, a verb for the hint line, `talk(crew)`) and the hint line, and nothing else: who answers and what they say is phase
   N's (N1 replaces the crowd's shader posing, so this phase never touches `spectator.gdshader`; N11 gives `Talkable` its lines through F's
   `HudSubtitle`). G on foot opens a gate you stand at (`GateRules`).
9. **Ordinary cars that drive.** `Vehicle` setup from data: `VehicleKind` resources (model, wheel nodes by position, glass, steering
   wheel, seat eyes measured from the interior, door boxes, a `VehicleConfig`) for the Milano as an ordinary car (front-wheel drive), the
   Fairheaven SW '84 estate (front-wheel drive, softer), the Shvan '92 van (rear-wheel drive, 1900 kg, tall) and the LCT 3000 box truck
   (rear-wheel drive, 3500 kg, top speed 30 m/s, wide turns). Each `.tres` passes the handling benchmarks' shape (0-100, 100-0, a turn-in)
   with its own expected numbers. Parked cars stay what they are today (batched props, `RallyProps`, W's placements) until a player uses
   one: the host promotes it to a live vehicle at the same place (id from the plan's index, so every peer agrees) and demotes it once
   empty, still and unseen beyond 60 m; at most four live ordinary cars at once. During a timed stage an ordinary car may be moved off
   the road but never carries a crew past a gate (the tracker follows rally cars only); in the start and finish areas, free. Never another
   crew's rally car (`SeatRules`), and never a car with someone in it (law 1: nobody is pulled out of anything; N9's traffic cars cannot be
   taken). `VehicleKind` is the one description of every car that is not a crew's rally car: N9's traffic and Q's mission vehicles take
   their looks, wheels and glass from it.

## Budgets (Direction 2 law 7; inside one process with a flip, `perf.ps1 --flip-walkers --flip-vehicles`, twice in both orders)
Medium stays over 60 fps on the dev laptop with three crews (today 77-80 on Black Pine). A walker: about 0.1 ms of script and skeleton and
3 draw calls (suit, helmet, shadow on High only for the local one); six walkers under 0.8 ms. A live ordinary car: about a rally car's
physics (0.05 ms a tick) and its model's draw calls (under 20, one material per skin); four at most. The clips library under 3 MB,
`WalkerNetSync` under 1 KB/s per walker. Nothing new runs for a walker or car nobody can see (the crew's `DRAW_RANGE` rule).

## Tests and evidence
Pure: `SeatRules`, the epoch rule, `WalkerRules` (every number in the feel table), `SeatPath` against the car's triangles for both doors of
every drivable kind, the carry and throw rules, the dive rule. Physics (`PhysicsTestCase`, `wait_ticks`): the step, slope, landing and
lag benchmarks in `walk_test.tscn`; a car never touches a walker; a walker never fires a gate, a stage event or a splash; foot slide under
5 cm a stride at walk and jog. Network: nettest's new script (out, walk, carry, back in the other seat, drive on), the driver leaving
mid-stage, two players pushing a car. Flow test `--flow-walk` on two stages. Evidence: a contact sheet of the way in and out from outside
and from the seat (six frames each, day and night), a third-person sheet of walk, jog, sprint, crouch, jump and land, a Movie Maker clip
of two players pushing the rally car out of a ditch, the four ordinary cars driven by the bot on one stage's start area. TEST_PLAN gets what
only people judge: does walking feel tight, is the bob sickening, is getting out worth its 15 s, do the lines land.

## Out of scope
Entering buildings (phase I adds the walk layer to the insides it builds, after OW; this phase leaves `Interactable` doors for it), traffic that drives itself, motorbikes, the moped and the tractor, swimming,
ladders, weapons and the shock gun on foot (it stays between cabins: the body holsters it), ragdolls, harm of any kind, taking another
crew's car, riding on a roof, jumping from a moving car, the browser demo's version of any of this.

## Parts (about 25: P1 5, P2 20, listed in `order.md`)
| Step | Parts |
|---|---|
| **P1** 1 occupants, layers, the protocol fingerprint | 3 |
| **P1** 2 car authority handover, empty car, driver leaving | 2 |
| **P2** 3 clips | 1 |
| **P2** 4 walker, camera, feel, dev scene | 5 |
| **P2** 5 doors and the way in and out | 4 |
| **P2** 6 walkers on the network | 2 |
| **P2** 7 the rally with someone out, law 1 for walkers | 2 |
| **P2** 8 hands on foot | 3 |
| **P2** 9 ordinary cars | 2 |
| **P2** evidence, docs | 1 (with each step's own docs) |

Done means: CLAUDE.md (a section "On foot", the layers, the occupants, the authority handover, the vehicle kinds), GAME_DESIGN (Direction 2
item 9 marked built, the rule for a crew member out), DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN, `ASSET_LICENSES.md` (the three cars, the
sounds, UAL2), the strings in TR and EN; full GUT, nettest and flow tests pass; commits on main.
