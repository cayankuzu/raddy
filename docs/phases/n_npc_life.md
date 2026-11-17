# Phase N: people and life. A countryside that lives, reacts and talks back, and that nobody in it is ever hurt by

The owner (2026-11-17, translated): "More things, more NPCs, people, interaction. You must be able to get into cars. The blended feel of games
like GTA and Postal ... a chaos game where you can interact with everything ... dark humour, viral ... it must be addictive." The lead keeps
GAME_DESIGN's Direction 2: nothing alive is ever hurt (law 1), the humour is in writing, situations and absurdity, never in cruelty, never at
religion, a people or a real person, and the rally stays the heart of the game. This phase gives the world its people and animals: they live
on a schedule, walk on real paths, notice the crews, get out of the way with style, say something short and dry about it, and some of them
hand out the errands other phases turn into missions.

Today the only people are the crowd: `Spectators`, one MultiMesh per place, the UAL1 mannequin baked standing and posed in
`shaders/spectator.gdshader` (four ways of standing, a cheer, the head to the nearest car), no skeleton, no collision, nothing sent. The only
living bodies with skeletons are the crews (`CrewBody`, `CrewRig`: skeleton modifiers, 0.07 ms a moving body, about thirty draw calls for
three crews). There is no traffic, no animal, no navigation mesh, no dialogue, no subtitle system.

## Honest size

About **26 builder parts of 1-3 hours** (N1-N12 below as `order.md` lists them: N1, N4 and N9 three parts each, N10 and N12 one, the rest two, the evidence one), after phases W
(villages and farms: where people live) and X (breakables, the crowd's dive, the flock and the tractor) and after the open-world brief that
gives the countryside its roads beyond the stages (phase OW, with `Profile`), and after phases P2 (walking, `use`, the `Talkable` hook,
`VehicleKind`) and I (insides, each room's `spot`s): so N11 talks face to face from the start, and N3 puts people in their houses.

What a free, zero-budget, AI-built version can really reach, and should promise no more:
- A village of 20-40 people of about ten kinds, a start area of 60, each on a day's routine; 6-12 traffic vehicles of four or five kinds near
  the players; flocks of 10-30 sheep, a few cows, goats, chickens and dogs, if the models hold up (see N8).
- Bodies from the one mannequin (UAL1's, and UAL2's female mannequin if its rig matches) in clothes made in code, animated with the
  Universal Animation Library's clips: no faces that move, no lip sync, no recorded voices (a synthesised babble under the subtitle), no
  hand-made animation. Up close this is a good indie game's people, not a big studio's.
- 300-400 short lines in Turkish and English, written to a style guide, picked so a player does not hear the same one twice in an evening.
Never promise "GTA's population". Say "a living countryside along the rally".

## Read first
- GAME_DESIGN §4, §6, §7 and all of "Direction 2" (laws 1, 4, 7, 8); CLAUDE.md on `Spectators`, `SpectatorRules`, `SpectatorClothes`,
  `CrewBody`/`CrewPose`/`CrewRig` (the mannequin, its `DEF-*` bones with the dots imported as `_`, `subdivide`, `generate_lods`), the
  multiplayer model (`BodyNetSync`, `SnapshotBuffer`, host-simulated cans, `Cabin`'s seat state on `CrewRules.CHANNEL` 3), `RouteFollower`,
  `RouteGraph`/`RouteIndex`/`RouteTracker`, `TerrainField`, `GraphicsQuality` (`FINE_SCENERY_LAYER`, the mirrors' layers), the `--flip`
  method of `tools/perf.ps1`.
- `docs/phases/w_world.md` (item 3, more kinds of people, which this phase animates; item 6, the plan the map reads), `x_mayhem.md` (item 7,
  the crowd dives, `DiveRules`; item 8, the tractor and the flock: X builds the first version, N turns them into the general systems below without
  changing what X's tests pin), phase F's `HudSubtitle` and `HudFeed` (the one subtitle line and the one feed: N gives them lines, never draws its own panel),
  `ow_open_world.md` (its road graph is the traffic's lanes), `i_interiors_destruction.md` (the walk layer, each room's `spot`s),
  `downloads.md` (what is on the disk).
- The A9a section of DEVELOPMENT_PLAN: Medium on Black Pine with three crews runs 77-80 fps, about 12.6 ms; 60 fps is 16.7 ms. W, X, the
  open world and N share the 4 ms between, and N's share is written below.
- `raw_assets/downloads/ual/` (UAL1 with its Godot animation library, UAL2 with a female mannequin): untrusted until a headless script has
  listed every member; nothing there has been opened by a phase except the mannequin `tools/make_crew_mannequin.gd` cut.

## The rules this phase never bends
1. **No contact, ever, on any peer.** No collider between a car and a person or an animal: people and animals are on a physics layer no car's
   mask has, and they are not bodies at all (they are placed, not simulated). Their safety is a geometric promise checked every frame on every
   peer: the person's capsule (0.3 m radius) stays outside every car's box grown by 0.3 m, as that peer sees the car (`SafetyShell`, N5).
2. **Safety is local, the routine is shared.** Where someone walks is the same everywhere (from the seed and the clock, or from the host);
   whether they are diving out of a car's way right now is each peer's own decision from what that peer sees, like the cheer today. A
   client's car is ahead of the host's copy by the round trip; a dive decided by the host would arrive after the car.
3. **A live stage is a closed road.** As in a real rally, while a stage runs nobody walks on its road and no traffic drives it: people stand
   behind the tape, at their doors, in the tea garden; marshals (whistle and a board, never a flag but Turkey's) keep it so. Traffic and
   crossings live on the open world's other roads, and on a stage's road only outside a race.
4. **The joke is on the crew, never on the people.** Lines are dry and dark about the situation (the car, the speed, the broken fence, the
   crew's judgement), never about a person's body, faith, ethnicity, class or a real person. **No place of worship, no religious sound or
   symbol anywhere in the game** (Direction 3, decided by the lead: in a game where things break, nothing holy stands in reach of the
   chaos; the draft's quiet call to prayer from a minaret is out, and with it the risk of a recording's licence and placement). **No state
   institution as a character**: no gendarme, police or soldier; the officials in the world are the rally's own (marshals, the scrutineer,
   the organisers' speed control), who are the dignified straight men of the writing.
5. **Law 8 holds.** Who exists, where they live and what they do on schedule comes from the stage's (or region's) seed alone, the same at every
   graphics level; the graphics level only decides how a person is drawn.

## The traps (each ends as a test)
- **The crowd's MultiMesh picks one level of detail for the whole place** (CLAUDE.md, `Spectators`). A village's people spread over 150 m:
  draw the far tier by 25 m cells, never one MultiMesh for a village.
- **The mannequin is 32.8k triangles after `subdivide`.** A skinned copy per near person is fine for 16-32 bodies, not for a crowd: the far tier
  uses `generate_lods`' 4.1k and 1.0k levels, and the near tier its own LODs (`ImporterMesh.generate_lods` on the skinned mesh; check the
  engine keeps the skin with them).
- **UAL1's clips match the mannequin's bones, but the import renames them**: track paths say `DEF-spine.001`, the imported skeleton
  `DEF-spine_001` (CLAUDE.md, crew). Retarget by renaming tracks once when the library is baked (`tools/make_life_anims.gd`), and test that
  every track of every used clip finds its bone. UAL2's female mannequin may use another rig: check bone names and rest poses headless before a
  single clip is planned for it; if it does not match, women are the same mannequin with SpectatorClothes' skirt and headscarf (W item 3).
- **Skeleton modifiers run headless** (CLAUDE.md, Tests). A headless host must create no bodies at all: `LifeDirector` keeps people as data
  and only a peer with a window draws them.
- **GDScript per person per frame does not scale.** Today `Spectators._process` loops places in script every frame. N keeps people in packed
  arrays in one `LifeDirector` and updates them by tier: near 30 Hz, middle 5 Hz, far only from the clock when drawn; a person is never a Node
  unless promoted to the near tier, and promoted bodies come from a pool (no `instantiate` in a race).
- **`RouteFollower` drives a `RallyCar`**: 120 Hz ray wheels each. A dozen traffic cars as RallyCars would cost more than the three crews.
  Traffic is kinematic along its lane (an `AnimatableBody3D` moved on the physics tick, `sync_to_physics` on) and becomes a free `RigidBody3D`
  wreck only when a player car hits it (the cans' model: host authority, a `BodyNetSync`).
- **An `AnimatableBody3D` pushes a car as if it weighed infinitely much.** A traffic car must never drive into a player car: it brakes on
  what the host sees (IDM, N9) and stops dead when a player car is within 2 m of its box; the player's car drives into it, never the reverse.
- **`FINE_SCENERY_LAYER` is not in the mirrors.** The far crowd may stay off them; a near body (and the speed control's official waving behind you) must be on a
  layer the mirror camera draws, inside the mirror's budget (one mirror a frame).
- **Strings**: every line needs both languages in `data/locale/strings.csv`; `UiTheme` statics use `TranslationServer.translate`. A test
  reads the CSV and fails on a line key with an empty column.
- **The protocol.** Every new RPC, channel and room setting bumps `Net.PROTOCOL_VERSION` and passes X's fingerprint test.

## Deliver (each step leaves the game whole and the tests green)

**N1. Bone animation for the crowd (no behaviour change).** `LifeAnims` bakes the UAL clips the game uses into one texture of bone matrices
(rows: clip frames at 30 fps, columns: three texels per bone), once a session beside `CrewBody.bake` (budget 0.3 s). The crowd's vertices
already carry their bones' weights (CUSTOM0/1); `shaders/life_crowd.gdshader` skins them from the texture with a per-instance clip, start time
and speed (`INSTANCE_CUSTOM`, a time offset so nobody moves in step). The spectators' four stands and the cheer move onto clips (idle,
arms crossed, hands on hips, a flag held up: a clip with the flag stick's bone the shader already has) and the old shader stays until the
new one's shots match today's within the existing pixel tests (`test_spectators.gd`). Start with `tools/list_ual_clips.gd`: every clip's
name, length and bones, printed; pick from that list, never from memory. Clips wanted (names to be checked): idle (3 kinds), walk, jog, run,
sit on a chair and on the ground, cheer, clap, point, wave, a fall or dive and a roll, getting up, a shrug, a phone held up (a hand pose plus
a phone prop on the hand's bone), sweeping, carrying.

**N2. Tiers and the pool.** `LifeLod` (pure, tested): from the distance to the local camera, the screen, and a budget per graphics level,
which people are near (a pooled `LifeBody`: `Skeleton3D` + one skinned surface + an `AnimationPlayer` on the shared library + a
`LookAtModifier3D` for the head), which are middle (the bone-texture MultiMesh in 25 m cells) and which are not drawn; hysteresis of 5 m
so nobody flickers between tiers; a swap is invisible (the same clip and time handed over). Budget: Low 8, Medium 16, High 28 near bodies;
middle to 120 m (Low 80 m), off past 160 m. Only the 4 nearest cast shadows on High, none on Low and Medium.

**N3. Who lives here: `LifeSchedule` (pure, tested).** From the region's plan (W's `VillagePlan`, the farms, the rally's own place, the
open world's buildings) and the seed: the people of each place (kind, home, work, the bench they sit on), and for any clock time where each
one is and what they do: at home after dark with a lit window, at the tea garden mid-morning and in the evening, in the field by day, children
on the square after school, the shopkeeper at the kiosk, the marshals at their posts from an hour before the first car, photographers at
corners, campers at their fire, the rally's officials at the time control and the service area, rival crews by their vans. A person's place
is a function of the seed and the race clock: nothing is sent for anyone who is only living their day. Kinds (W adds the looks): villager,
farmer, shopkeeper, tea drinker, granny with a broom, child, old man with a cap, marshal, photographer, TV crew, camper, official, rival crew
member, the organisers' speed control official, traffic driver.

**N4. Paths.** Routines walk on `LifePaths`, a graph of footpaths built from the plan (door to street, street to square, square to tea
garden, field gate to field), pure and the same on every peer; heights from `TerrainField.height`. A navigation mesh is only for what leaves
the paths (a reaction, a chase, a detour round a wreck): `NavigationServer3D` regions of 200 m round each village and the start area, baked
on the host at load on `WorkerThreadPool` from the terrain's grid and the buildings' footprints (agent radius 0.3 m, cell 0.3 m; budget 150 ms
a region, reported). Clients never need the mesh: an off-path person's place comes from the host (N6). Inside buildings: on phase I's walk layer
(`i_interiors_destruction.md` item 9), a region of its own floor; nobody walks through a wall (a test walks every path edge with a ray).

**N5. The dive, and the shell under it.** `ReactionRules` (pure, tested, every peer): from a car as this peer sees it (place, velocity,
box) and a person (place, facing, kind, what they are doing), the time to contact and the closest approach; the answer: nothing, look, step
back, dive aside (the side away from the car's line), throw themselves over a wall or into a ditch. The dive starts at the latest when the
car is `0.6 s + stance` away, faster for younger kinds; a dive's arc is long enough at any speed the car can reach (to 60 m/s, at every
angle: the test sweeps 10 000 cases and checks the shell is never touched). Under it, `SafetyShell`: every frame each drawn person and animal
is pushed out of every car's box grown by 0.3 m, whatever the animation says. The shell should never have work to do; the soak (Evidence)
counts how often it did (target 0 a run; above 1 in 1000 passes the dive rule is wrong). After a dive: lie there 1-2 s, get up (a clip), then
one of shake a fist, shout, brush off, film the car on a phone, or walk on as if nothing happened (the drier the better). Rejected: an
invisible bumper that nudges the car's steering or speed. It changes the driving under a blind driver and lies about the physics; the
car's control is never touched for a person.

**N6. The host's people, sent cheaply.** A person who leaves the routine (reacting, chasing, called over by the speed control, a mission's giver
walking to a crew) becomes the host's: `LifeDirector` on the host moves them (navigation mesh, 10 Hz) and `LifeSync` sends, ten times a
second on a channel of its own (4, unreliable_ordered), only the people who are off their routine and within 300 m of some player: 8 bytes
each (id 2, x and z as 16-bit offsets in their region 4, clip and phase 1, flags 1); a full state reliable to a peer that joins or rejoins.
Fifty people off routine cost 4 kB/s to each peer. `LifeSyncCodec` is pure and round-trip tested. Clients ease towards the host's place over
0.2 s; their dive (N5) stays local on top of it. The routine resumes from the clock when the reaction ends.

**N7. Reactions with a tongue.** `ReactionRules` grows the rest: a car sliding past within 8 m: step back, a shout; a car breaking a thing
the person owns (X's breakables carry an owner from the plan): the owner comes out and shakes a fist, or chases the car with a broom for
20-40 m (the granny; she never reaches a road while a car is near it); the horn: people turn, children wave, an old man waves back a stick;
a car going fast through a village outside a stage: the speed control (N10); a crash nearby: two or three come over to look and film it, keeping
3 m from the wreck; a car standing still: someone walks up to the window and offers advice. Every reaction has a cooldown per person and per
crew, so a village never shouts in chorus. Animals react through the same rules with their own table (N8).

**N8. Animals.** `AnimalRules` (pure, tested): sheep and goats in flocks (a simple boids rule: keep together, follow the leader, flee a car or
a horn, never into a car's grown box), cows that look up and walk off slowly, chickens that scatter and flap, dogs that chase a passing car
along its side (1.5-3 m out from its box, barking, giving up after 60-150 m or at the edge of their village, never in front of a wheel).
Drawn like people: bone-texture MultiMesh for the herd, a few pooled skeletons near. Models: the sheep and the cow on the disk
(`downloads.md`; bake their clips the same way); dogs, goats and chickens from what the lead approved on 2026-11-17
(`downloads.md` Batch I: Quaternius's animated animals, two unopened zips in `raw_assets/downloads/quaternius_animals/`, unpacked by a
script that checks every member's name first; Batch H: a dog's bark, a goat's bleat, chickens clucking, a rooster): look at each model in
the engine beside Poly Haven's scans and bake its clips the same way. No free animated goat or chicken was found: give a static model on the
disk a gait in the shader if one holds up, or keep that kind as sound only, and say which; a kind with no usable model is never built in
code. X's flock becomes `AnimalRules`' first user without changing X's tests.

**N9. Traffic.** `TrafficLanes` from the open world's road graph (right-hand traffic, a lane 1.6 m right of the middle, junctions with
right of way by the road's class); `SpeedProfile` (pure) is the corner speed planner taken out of `RouteFollower` (its curvature, `CORNER_ACCEL`,
`BRAKE_ACCEL`; RouteFollower then uses it, and the bot's times on Black Pine and Red Canyon stay within 0.2 s, the test); `IdmRules` (the
intelligent driver model, pure) keeps a gap to whatever is ahead, a player car included as the host sees it; junctions are first come, first
through. `TrafficCar` (`AnimatableBody3D`, host-simulated, sent at 10 Hz with `LifeSyncCodec`'s 8 bytes plus speed; wheels turn, body leans
on its springs in the shader-free way `CarModel` turns the Milano's wheels; its look, wheels and glass from P2's `VehicleKind`, never a
second car description): the parked cars on the disk (estate, box truck, the van as a
dolmuş in yellow with its sign in Turkish), the Milano '95, the tractor and trailer at 25 km/h; a bus only if an approved model is found.
Spawned out of sight ahead of players, 400 m round them, Low 4, Medium 8, High 12. Hit by a player car: it becomes a wreck (`RigidBody3D`,
host authority, `CrashRules` metal), the driver gets out (a near body), walks round it, delivers a line, and the wreck stays as long as X's
breakables stay. Never on a live stage's road (rule 3). A player never takes a traffic car (nobody is pulled out of a car); its wreck stays a wreck.

**N10. The organisers' speed control.** As on a real rally's road sections, the organisers check the crews' speed through villages
outside a stage: a speed limit (50 km/h) on a village street, and an official of the rally in its orange vest (W's marshal kind, with a
clipboard and a radar gun built in code) beside the organisers' car (a `VehicleKind` in the event's livery from `LIVERY_EVENT`, no
emblem, no state colours). `SpeedingRules` (pure, tested): a crew through at more than limit + 20 km/h within 60 m of the official is
waved down (a whistle, an arm out, a near body); stop within 150 m and the official walks to the driver's window, writes a penalty (a
paper on the windshield, the `Cabin`'s glass system, cleared by a wipe), and says a line; don't stop and it is a line in the feed and a mark
on the results ("Hız kontrol sizi tanıdı" / "Speed control knows your face"). One penalty per village per crew per run. The fine's amount is a
number the progression brief may spend; N only emits `fined(team, amount, village)`. Nobody chases, arrests or blocks the road.

**N11. Talking.** `Conversation` (data in `data/life/conversations.json`, keys into strings.csv): a giver's opening, two or three of the
crew's answers, the giver's replies, and what it starts (a key the mission brief listens for). Played as subtitles (F's `HudSubtitle`) to the seats
of the crew that is talking, with a babble voice under each line (`tools/make_babble.py`, pure Python like the other sound tools: syllable
blips pitched per kind; or nothing) and the speaker's head and hands moving (an idle talk clip, a point). Started today from the car standing
by a giver (the navigator clicks the person through the window, law 6), or on foot through `Talkable.talk(crew)`, the hook P2 built (the
person turns to the walker, a per-person look target in N1's crowd shader or the near body's `LookAtModifier3D`). Barks (one-liners from N5, N7, N10) are `BarkLines` (pure, tested): by kind and situation, never the same line twice within the
last 12 for that crew, heard within 30 m, subtitled for the seats that hear them, the driver's subtitle small and at the bottom (F's `HudSubtitle`).

**N12. The writing.** The style guide's text is the one in phase Q's brief ("Writing guide", one guide for the whole game), written
into `data/life/WRITING.md` here, with Direction 3's never-list; a style guide in `data/life/WRITING.md` (short, dry, the joke on the crew and the situation; the absurd straight face;
never a body, a faith, a people, a class, a real person; no swearing beyond the mildest grumble, and no oath that names God or anything holy; children never swear)
and the first 300 lines, Turkish written first, English after as its own joke rather than a translation. Examples of the tone:
- Speed control: "Sınır elli. Siz yüz kırk. Aradaki farkı tahsil ediyoruz." / "The limit's fifty. You did a hundred and forty. We'll bill you for
  the difference."
- Tea drinker, the third car through: "Çay daha soğumadı, üçüncüsü geçti." / "Third one. The tea isn't even cold."
- The granny, broom up: "Bu çit benden yaşlıydı!" / "That fence was older than me!"
- A farmer, at the flock: "Koyunlar sigortalı. Siz değilsiniz." / "The sheep are insured. You aren't."
- A photographer, after a dive: "Bir daha geçer misiniz? Odak kaçtı." / "Could you go by again? I missed focus."
- A child: "Abi bir daha! Bu sefer ahırın içinden!" / "Again! Through the barn this time!"
A review agent reads every line against the guide before it is merged; the owner reads the first fifty.

## Budgets (dev laptop, RTX 5070 Laptop, 1080p, three crews, the busiest village or the start area)
| Thing | Low | Medium | High |
|---|---|---|---|
| Near bodies (skeletons) | 8 | 16 | 28 |
| Their CPU (animation, look-at, script) | 0.4 ms | 0.8 ms | 1.4 ms |
| Middle tier draw calls (25 m cells) | 6 | 10 | 14 |
| Animals near / middle cells | 4 / 4 | 8 / 6 | 12 / 8 |
| Traffic vehicles | 4 | 8 | 12 |
| Whole phase, `work_ms` + `gpu_ms` added | 1.0 ms | 1.5 ms | 2.5 ms |
| Network, each peer | 6 kB/s at most | | |
Medium stays over 60 fps everywhere W, X and the open world are also present; if it does not, take A9a's banked cuts (trees first) before
cutting N's counts, and write which was taken. Headless host: `LifeDirector` with 200 people, 30 off routine, 12 traffic cars costs under 0.5 ms
a frame (measured with `--work-top`).

## Tests (pure first, GUT)
`test_life_anims` (every used clip's tracks find their bones; the bone texture's size), `test_life_lod` (counts never above the budget,
hysteresis, the hand-over keeps clip and time), `test_life_schedule` (same seed same day on two runs and two graphics levels; nobody on a live
stage's road; everyone home at 03:00), `test_life_paths` (no edge through a wall; every routine's places reachable), `test_reaction_rules` and
`test_safety_shell` (the 10 000-case sweep: no contact at speeds to 60 m/s, any angle, any kind; the shell's correction 0 in the sweep),
`test_life_sync_codec` (round trip, 8 bytes, region bounds), `test_animal_rules` (flock never in a car's box; a dog's chase never ahead of the
front axle), `test_speed_profile` (RouteFollower's bot times unchanged), `test_idm_rules`, `test_traffic` (never on a live stage; brakes for a
standing player car; a wreck on a hit), `test_speeding_rules`, `test_bark_lines` (no repeat within 12; every key in both languages; no line
over 70 characters), `test_conversations` (every node reachable, every key exists). `test_scripts_compile` covers the new scripts.

## Evidence
- `perf.ps1 --flip-life --flip-life-near --flip-animals --flip-traffic` (twice, the second time in the reverse order) on Low, Medium and High
  in the busiest place, the numbers with what ran beside them.
- The law-1 soak: `route_test --life-soak` drives a bot 100 times through the village and the start area aiming at people (a dev-only
  target mode), on the host and on two clients through `tools\nettest.ps1`; the `LIFE closest_m` line (the smallest distance between a car's
  box and a person seen on that peer) stays above 0.3 m and `LIFE shell_pushes` is 0 on every peer.
- nettest: a client's car scares a villager: every peer sees the dive; a host-moved person is within 0.5 m on all peers after 10 s; a traffic
  wreck is the same everywhere; a late joiner gets the people off routine.
- A contact sheet: a village by day, evening and night (lit windows, the tea garden full, then empty); a dive from the seat and from the
  roadside; the granny's broom chase; a dog's chase; a flock parting; traffic at a junction; the speed control's official at the window; a conversation's
  subtitles in both languages at 1280x720 and 4K.
- A flow test on Black Pine and Red Canyon with N on.

## Out of scope
Hurting anyone or anything alive, in any form, or a mode that rewards trying; taking another crew's car or a traffic car (Direction 3:
nobody is pulled out of a car; parked cars are P2's); missions themselves (phase Q uses `Conversation`'s keys and N10's `fined`); faces that
move, lip sync, recorded voices; a crowd simulation of hundreds on screen; chases, weapons, arrests, any state institution as a character;
any place of worship or religious sound.

## Done means
Every item above built in order, its tests passing; the budgets measured and met on Medium; the soak at 0; GAME_DESIGN (§7 the people,
§6 the reactions, law 1's how), CLAUDE.md (a section "People and life"), DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN (is a line funny the
tenth time, does the dive read as a joke and never as harm, does the speed control read as the rally's own and never as police), `ASSET_LICENSES.md` and the
credits, the strings; `Net.PROTOCOL_VERSION` bumped; full GUT, nettest and a flow test pass; commits on main.
