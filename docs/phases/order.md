# The order of work from now on (Direction 3, decided 2026-11-17)

The lead's merge of the seven drafts of 2026-11-17 with the briefs already in `docs/phases/`. Each phase below has its brief, its parts
(one builder part is 1-3 hours and ends with GUT green and a commit; a part that grows past that is split, never stretched), two review
lenses for independent reviewers when the phase ends, the stage its flow test uses (`tools\flowtest.ps1 -Stage N`: 0 Black Pine, 1 Misty
Creek, 2 Red Canyon, 3 Scorpion Hills, 4 Eagle Nest, 5 Glacier Ridge; every phase also runs the full GUT suite and nettest, and the last part
of L2, OW, A9b and the play-test build run `tools\ci.ps1 -AllStages`), and what it depends on. Direction 3 (GAME_DESIGN's last
section) is the why; this is the when.

## Where the repo stands (2026-11-17)
- Done: A0-A5b, A9a (measured, cuts banked), M points 1-5, 9, 10 (the map page), L parts 1-3 (bypasses, the second edition of the stage
  rules, gag slots, the signature place; Black Pine and Red Canyon redesigned).
- Not done: M points 6-8 (road book, following view, trip meter) and its audit (moved to A7); L's other four stages (L2).
- The working tree has phase L's uncommitted work in progress: `scripts/procedural/stage_catalog.gd` (Black Pine's and Red Canyon's
  recipes retuned: bypass mouths, a caution corner, the ford shortcut's shape) with `route_validator.gd`, `test_bypasses.gd`, the strings
  and their lines in the docs. The first builder of phase F checks with `git status` whether it is still there: if it is, it is not F's to
  commit or revert; F leaves it alone, stages only its own changes and reports it to the lead.

## What was to be asked of the owner, decided (2026-11-17)
The owner told the lead to decide everything and never to wait for them. The lead decided:
1. **The opening.** No agreed script ("kararlaştırdığımız gibi kısa bir animasyon") is in the project's records. Phase Q's proposal (its
   Q13) is approved as written and is built in Q; the owner may change it later (its timeline is data).
2. **The downloads.** The three optional batches are approved and on the disk (`downloads.md` batches G, H and I): 66 Poly Haven furniture
   models (CC0, from `i_interiors_destruction.md` item 4's list) for phase I; CC0 Freesound recordings for breaking things (a plank's snap,
   a crate smashed, plastic crates, a clay pot, a flag's flap for the tarp, a glass pane shattering, a cardboard box, a trash can) for
   phases X and I, and farm sounds (a dog, a goat, chickens, a rooster) for N and Q; Quaternius's animated animals for N and Q (no free
   animated goat or chicken was found: N gives a static model a gait in the shader, or keeps it as sound only). Every brief that uses them
   keeps its fallback for a file that turns out unusable, and says when it took it.
3. **Phase F's drive.** Not asked: the measured defaults stand, the old feel stays one setting away, and the blind A/B of the old and new
   feel is on the play-test build's checklist.
4. **Turkish and English everywhere** (the owner, 2026-11-17: complete support of both). The table, the settings' picker and the strings
   exist; phase F adds the rest (its part 15, the brief's Part 3), and Direction 3's law 15 holds every phase to it.

## One owner per system (Direction 3, law 12)
| System | Owner phase | Extended by |
|---|---|---|
| The car's handling, steering chain, assist, tyres, gearbox's effect on the drive | F | Q (builds and compounds, as config deltas) |
| The seat camera's motion and options (FOV, seat eye, horizon lock, FOV kick) | F | |
| How a hit is felt (`ImpactFeel`: hold, FOV punch, duck, thump, rumble) | F | X, I, N call it |
| HUD components (`HudStyle`, `HudRules`, timing tower, feed, prompts, `HudSubtitle`, finish) | F | H (the dot), X/N/Q (lines) |
| The two languages: the table's tests, the first launch's language, the TR/EN switch, the voice by language | F | every phase (its strings in both), A7 (the switch's look) |
| Menus and every other screen, the UI design system for them, the screen audit | A7 | Q's screens built plain, styled by A7 |
| Map sheet (done), road book, following view, trip meter | M / M2 | OW (region sheet), Q (pencil marks) |
| The pick rule (`CabinHotspots`), mouse hands in the cabin | H | P2 (on foot uses the same rule) |
| Stage recipes, road events (wreck, closed road, puncture, fog bank) | L2 | |
| Seats and occupants (`Cabin.occupants`, `SeatRules`), named physics layers, a car's authority, the protocol fingerprint | P1 | everyone bumps the version |
| Breakables, fracture, debris, rubble, material breaks and sounds, the car's dents and drag, cabin gags, `DiveRules`, first tractor and flock, `MayhemTally` | X | I (panes, structures), N (reactions), A6 (awards), Q (payouts) |
| Villages (`VillagePlan`, `HouseRules` shells with openings as data), farms, people's looks and kinds, the rally's own place, night lights | W | OW (places them in the region), I (insides), N (lives) |
| Joining through routers, rejoin, the version refusal | J | P2 (walkers rejoin), A8 (limits) |
| Solo session, the bot co-driver, share card, photo mode, credits | D | OW (solo roam), Q (solo career) |
| The walker, its clips, the doors in and out, carry/throw/push, `Interactable`, `Talkable` hook, `VehicleKind`, ordinary cars | P2 | I (house doors), N (talking, traffic looks), A6 (doors that pop open) |
| The region, streaming, region roads, roam (also of a single stage), start control, world map, discovery, fast travel, `Profile` | OW | Q (sections, service rules), OW2 |
| Window panes, collapsing structures, insides, the walk layer inside | I | N (people inside) |
| People's schedules, paths, tiers, reactions, `SafetyShell`, animals, traffic, the speed control, conversations, barks, `WRITING.md` | N | Q (givers, lines) |
| Money, insurance, errands, career, builds, cosmetics, collectibles, achievements, the daily, the radio and loudspeaker, the opening | Q | |
| Doors that pop open, intercom, energy drink, room modes, the hands-rule audit | A6 | |
| Security, rate limits, bad networks, soak, logs | A8 | |
| Performance and the QA matrix | A9b | |
| Browser teaser | WD | |
| Release packaging: demo export, store pictures, trailer, itch page, release script | A10 | |

## The order
| # | Phase | Brief | Parts | Flow stage | Needs |
|---|---|---|---|---|---|
| 1 | F, feel, race HUD, Turkish and English | `f_feel_hud.md` | 24 | 0 | |
| 2 | OW0, the streaming spike | `ow_open_world.md` item 0 | 2 | 0 | F |
| 3 | M2, road book, trip meter, the seat's map | `m_map.md` points 6-8 | 4 | 2 | |
| 4 | H, mouse hands | `h_hands.md` | 6 | 0 | M2 |
| 5 | L2, four stages and road events | `l2_stages_events.md` | 14 | 1 | |
| 6 | P1, the seat is not the player | `p_on_foot_cars.md` steps 1-2 | 5 | 2 | |
| 7 | X, mayhem (destruction revision) | `x_mayhem.md` (the revision of 2026-11-17) | 18 | 2 | F, P1 |
| 8 | W, the living world | `w_world.md` | 14 | 0 | X |
| 9 | J, joining | `j_join.md` | 6 | 3 | P1, X |
| 10 | D, solo, share card, photo mode, credits | `d_demo.md` items 1-4 | 6 | 0 | F |
| 11 | P2, on foot | `p_on_foot_cars.md` steps 3-9 | 20 | 4 | P1, H, X, W, J |
| 12 | OW, the region (Çamlık Vadisi) and `Profile` | `ow_open_world.md` | 24 | 0 | OW0, L2, W, D, P2 |
| 13 | I, glass, collapses, insides, walking in | `i_interiors_destruction.md` | 16 | 1 | X, W, P2, OW |
| 14 | N, people and life | `n_npc_life.md` | 26 | 2 | W, X, P2, OW, I |
| 15 | Q, errands, career, voice, opening | `q_missions_career.md` | 26 | 0 | D, OW, N |
| 16 | A6, the rest of the chaos | `a6_chaos.md` items 1-4, 6-8 | 8 | 5 | P2, X |
| 17 | A7, menus, screens, the audit | `a7_ui.md` (without item 4) | 12 | 3 | Q |
| 18 | A8, network and security | `a8_net.md` items 1, 4-7 | 8 | 4 | everything networked |
| 19 | A9b, performance and QA | `a9_a10.md` part A9 | 8 | 5 | all of the above |
| ★ | **The owner's play-test build** | this file, below | | all | A9b |
| 20 | T, what the owner found | written after the play-test | 6-12 | all | ★ |
| 21 | OW2, two more regions, time and weather that move | `ow_open_world.md` "the full version", item 11 | 40-50 | 4 | T |
| 22 | WD, the browser teaser | `web_demo.md` | 12 | 2 | T |
| 23 | A10, launch | `a9_a10.md` part A10 + `d_demo.md` items 5-6 | 8 | 0 | OW2, WD |

To the play-test: about 247 parts, between 250 and 740 hours of agent work. After it: about 70 more to the launch.

Why this order: F first (the owner's first complaint, and every later phase is judged through its camera and HUD). OW0 next, because the
whole open world rests on numbers nobody has measured. M2 before H (H works the sheet M2 makes follow the car). L2 before the region (Misty
Creek's second edition is half of Çamlık Vadisi). P1 before X and J (named layers for debris, a car that can wait without its driver, the
protocol fingerprint every later RPC needs). X before W (W's villages hold X's breakables and the crowd's dive). J before anything walks or
roams online and before the owner's friends join. D before P2 and OW (solo roam and the solo career run in D's local session). P2 before OW
(the streamer takes a walker as a focus from the start) and before I (insides are walked into). OW before I, N and Q (they live in its
places and save in its `Profile`). N before Q (givers, lines, traffic for mission vehicles). A6, A7, A8 and A9b last, over the whole game.

## The phases

### 1. F, feel, race HUD, Turkish and English (24 parts, flow stage 0)
Brief: `f_feel_hud.md`. The car's feel measured and fixed, `ImpactFeel`, the race HUD built on one design system, the game in Turkish and
English everywhere.
1. Feel probe: `tools/feel_probe.gd` in route_test, the scripted inputs, CSV per tick and per camera frame.
2. Plot and runner: `tools/plot_feel.gd` (Image only), `tools/feel.ps1`, camera jerk in numbers, the client navigator's `--feel-log` in nettest.
3. Baseline report: every suspect measured, the "F baseline" table and ranked list in DEVELOPMENT_PLAN with the A2 figures.
4. Playback clock: `SnapshotBuffer`/`BodyNetSync` advance by tick delta, tests with two-tick frames and jitter, the 1.5x jerk gate.
5. Copies and the mouse: `seen_velocity()` in `CockpitCamera`, roughness per snapshot interval, the 120 px clip only after capture, tests.
6. Steering chain: lock round the travel direction, one filter per device, the wheel's range, the `catch` benchmark with the assist off.
7. Stability assist: fade-in after the handbrake, a cap against the tyres' moment, more through steering, `--feel-preset=a2`.
8. Tyres I: fall-off past the peak, load sensitivity; lift-off and trail-braking rotation benchmarks; A2 bands kept or changed with the reason.
9. Tyres II and the drive: `tire_force_lift`, rear priority under power, the shift cut, a torque curve; flowtest -AllStages bot averages.
10. Seen and heard: pedal ramp, reverse pause, corner look toward travel, horizon lock, FOV kick, road buzz by speed, the hit's bounce.
11. `ImpactFeel`: the rule, the hold, FOV punch, duck, `tools/make_thump_sounds.py`, rumble, the camera_shake setting, tests.
12. Feel audit I: the evening's moments measured (launch to finish, two peers), the table in DEVELOPMENT_PLAN.
13. Feel audit II: the findings fixed or assigned to their phase; the owner's blind A/B in TEST_PLAN's play-test checklist.
14. HUD system: `HudStyle`, `HudAnim`, `HudLayout` with the reserved zones, `HudRules`, Saira and Inter, dev text out of player screens.
15. Turkish and English (Part 3): the OS's language at first launch, the menu's TR/EN switch, the literals in the table, the tests, the voice.
16. Timing tower: stage time, crews in order with team bars, split pops with green/red deltas, own row outlined.
17. Countdown: the light tree from `countdown_left`, beeps under -1 dBFS, the arch's lamps if they fit the budget.
18. Cluster: arc rev counter with shift lights, big gear, speed, the mirror fade kept, hidden in Minimal.
19. Car state: the damage outline by zone and part, darts, glass and wiper icons, pops on change.
20. Feed and subtitle: `HudFeed` with priorities and the role filter, `HudSubtitle` with reading speed and the driver's small line.
21. Prompts and people: the recovery ring with Kenney glyphs, the stuck wait from its first second, voice chips with levels.
22. Finish moment: chequered wipe, time, delta, place, medal, the hand-over to the results without a black gap.
23. Seat options and settings rows: FOV, seat eye, the 85 % interior-mirror default and its test, HUD mode and scale, the feel preset.
24. Night, glare, budgets and evidence: night palette, snow and low sun, `--flip-hud`, shots by role, language and moment, the contact sheet.
- Lens `player_rally_feel`: "You have played every rally game since Colin McRae 2.0 and Richard Burns Rally, on a pad, a keyboard and a wheel.
  Drive the before and after presets on Black Pine and Red Canyon from the seat, as driver and as a client's navigator, and say where the car
  still lies to you: turn-in, lift-off, a caught slide at 100 km/h without the assist, a hairpin, a landing, a hit. Then judge the HUD as a
  broadcast viewer and as a driver at 120 km/h: is every number where the eye expects it, does anything distract, does anything show the road
  ahead, does it read at night, in snow and into a low sun. Name each finding with a screenshot or a CSV row."
- Lens `bug_hunter_feel`: "Assume every claim in DEVELOPMENT_PLAN's F entries is false until a test or a log line shows it. Check the
  playback clock never repeats a sample or steps back, that the A2 benchmarks still hold or changed with a written reason, that
  `ImpactFeel` never touches `Engine.time_scale`, that `HudRules` cannot put a minimap, a road profile, a money line in a stage or a mayhem
  score on any screen, that no `SystemFont` is left in the HUD, that headless peers build the HUD without a rendering device, that the
  countdown follows the host. Run GUT, nettest and the flow test yourself; report what does not reproduce."

### 2. OW0, the streaming spike (2 parts, flow stage 0)
Brief: `ow_open_world.md` item 0. A throwaway scene that proves the region's numbers before anything is built for them.
1. `scenes/dev/stream_test.tscn`: noise tiles with the forest scattered, a bot at 50 m/s on 4 km, worker preparation, a commit budget, `STREAM` and `HITCH` lines.
2. Measure on Low, Medium, High; decide tile size, rings and density; write them into `ow_open_world.md`'s numbers and DEVELOPMENT_PLAN; if 2 ms commits fail, find why.
- Lens `player_open_world`: "You drive open-world racing games at full speed and notice every pop-in, hitch and blurry tree. Watch the spike's
  recordings and logs at 180 km/h on each level: does the world appear before you reach it, does anything stutter, is the far forest
  believable? Say whether these numbers support a region worth roaming."
- Lens `bug_hunter_numbers`: "Recompute every number the spike reports from its raw `STREAM`/`HITCH` lines and the perf probe's output; check
  what else ran on the PC during each measure, whether the worst frames were counted or averaged away, and whether the conclusion written into
  the brief follows from the data. Flag any number measured once."

### 3. M2, the road book, the trip meter, the seat's map (4 parts, flow stage 2)
Brief: `m_map.md` points 6-8 (the audit is A7's). 
1. The road book page: ruled rows, distances, tulips for junctions from the graph, arcs and pictograms, danger marks.
2. The following view: the page follows the car at a readable zoom (16 px at 1080p, 11 at 720p), the next rows, Redline's exception, the raise-to-face key if needed.
3. The trip meter: real numbers on its box in the cabin, reset key, lit at night, the hand reaching if cheap, every peer from what it sees.
4. Calls' language with a native ear, the strings, tests (tulip angles, distances against the tracker, the trip against a physics run), evidence.
- Lens `player_navigator`: "You have navigated real club rallies with a road book and a trip meter. Sit in the navigator's seat on Red Canyon
  and Black Pine by day and at night: can you read the next call and the tulip at a glance at 1080p and 720p, does the page follow without
  making you sick, does the trip meter behave like the real one? Say what you would get wrong at speed."
- Lens `bug_hunter_map`: "Prove the road book against the world: pick ten junctions and check each tulip's branches and angles against the
  graph and a screenshot from the seat; check the trip meter after a recovery, a reverse and a bypass; check nothing is drawn twice or over
  something; check every new string in both languages and every claim in the DEVELOPMENT_PLAN entry."

### 4. H, mouse hands (6 parts, flow stage 0)
Brief: `h_hands.md`.
1. `CabinHotspots`: per seat places measured from the car's parts, the pick rule (nearest, reach, cone), tests that each lies on its part.
2. Using them: click as the key's request, hold, drag-to-wind by mouse travel, look frozen while held, `CrewRules.hands` answers.
3. Seeing them: the centre dot by seat and speed, a soft rim on the part, the hint line in both languages, the body's hand goes there.
4. Per seat: the navigator's map, winder, glove box, can, dome lamp, trip meter; the driver's rare clicks at standstill.
5. Settings and devices: on/off, hold or toggle, rebinding, the gamepad's use button, no stuck hand after a lost release.
6. Network field if needed (protocol bump), nettest with a scripted mouse job, evidence sheets by seat, day and night.
- Lens `player_cabin`: "You love Half Grip and Left! Left! LEFT!'s cabin chaos. Play both seats with keyboard and mouse together at speed:
  does winding a window by dragging feel physical and funny, is the dot ever in the way, does a busy hand answer clearly, would you ever
  rather press the key? Name each irritation."
- Lens `bug_hunter_hands`: "Try to break the hands: click two jobs at once, release outside the window, alt-tab mid-drag, use a gamepad
  and a mouse alternately, faint mid-job, drop the network; check every hotspot's request equals its key's and that the host trusts nothing
  new. Run the tests and nettest yourself."

### 5. L2, four stages and road events (14 parts, flow stage 1, `-AllStages` at the end)
Brief: `l2_stages_events.md`.
1-2. Misty Creek to the second edition (the ford village by the mill), measured and driven by the bot.
3-4. Scorpion Hills (the dry river bed under the hilltop village), measured and driven.
5-6. Eagle Nest (the cliff road; the bridge crossing only if the tracker test proves it), measured and driven.
7-8. Glacier Ridge (the frozen lake by the shepherds' hamlet), measured and driven, in snow too.
9. The first edition removed with its tests once all six claim the second.
10. A wreck ahead: an earlier crew's damaged Milano, hazards, a marshal with a whistle and a "YAVAŞ" board, solid, synced.
11. The road closed: barrier, tape, board, marshal pointing down the bypass; bots read it; medal judged on the bypass's time.
12. A puncture: the rule from the hit, the blast, the pull, the rim's sparks and scrape, synced like damage.
13. More trees and rocks (a second tree size, a branch on the bonnet, a boulder field) and the fog bank.
14. Measured and evidence: bot per event, stage and difficulty; nettest; flips; the sheets; the bot times table.
- Lens `player_stage_designer`: "You design WRC stages. Drive each redesigned stage with a partner reading the notes: does it have a rhythm,
  a signature place you remember, junctions where the call matters, a moment you would clip; does each event change your run without ever
  feeling unfair? Compare with the stage sheets before and after."
- Lens `bug_hunter_stages`: "Rebuild every stage's judges and summaries yourself; check each event is identical on every peer (wreck place,
  closed road, a client's puncture), that a closed road never lands on Redline's first run, that the medal speeds still mean what they did,
  that the bot finishes every event, weather and difficulty with zero recoveries. Report every number that does not reproduce."

### 6. P1, the seat is not the player (5 parts, flow stage 2)
Brief: `p_on_foot_cars.md` steps 1-2. No visible change.
1. `Cabin.occupants` and `SeatRules`: every "who sits here now" read through the cabin; a grep test keeps the roster reads to the lobby's.
2. Named physics layers (world, cars, walkers, props, debris, triggers, interiors) and an explicit mask on every ray, shape and area.
3. The protocol fingerprint test pinned against `Net.PROTOCOL_VERSION`, and its first bump.
4. A car changes hands while it stands: `_rpc_car_authority` with an epoch, snapshots from a stale owner dropped silently.
5. The empty car held by the host, a team that keeps its car when the driver leaves, nettest: the navigator takes the wheel and finishes.
- Lens `player_coop`: "You play co-op games with friends whose connections drop. Play a stage where the driver leaves mid-stage and the
  navigator moves over, and a full normal race: does anything feel different from before, does the moment of taking over make sense?"
- Lens `bug_hunter_refactor`: "This phase must change nothing visible. Diff behaviour, not code: compare nettest and flow test logs before
  and after, grep for any remaining roster-role read outside the lobby, fire a gate, a stage event and a splash with something on every new
  layer, and look for any RPC that changed without the fingerprint failing."

### 7. X, mayhem with real destruction (18 parts, flow stage 2)
Brief: `x_mayhem.md` (the destruction revision of 2026-11-17, which replaced the first X brief).
1. Breakables catalogue (about 15 kinds, material, fracture, price, owner kind), MultiMesh chunks, the host's index and broken set.
2. Breaking on the driver's peer: overlap, drag as impulse, `impact` emitted, host confirms, late joiners get the set.
3. `tools/make_fractures.gd`: islands and slab cuts with jagged, capped ends.
4. Convex Voronoi for pots, gnome, cat, trough; fallback rule; fracture tests.
5. `DebrisLaunch` and `DebrisPool` (24 awake, debris layer, no car contact).
6. Rubble chunks, waking by a car's sweep, late-join layout, the physics test (30 crates at 25 m/s).
7. Material breaks through `BreakFx` and the extended `Struck`, budgeted shares of `RoadFxPool`, `ImpactFeel` called.
8. Break sounds: Batch H's recordings cut in, `tools/make_break_sounds.py` for the rest, three sizes, four variations, patter.
9. Cabin gags I: fruit pulp and straw on the glass, the wipers' sweeps.
10. Cabin gags II: the sheet over the glass, bees through an open window.
11. `DiveRules`: the crowd dives behind its bales and comes up shaking fists and flags.
12. The tractor on the clock, honked off sooner, bots brake and honk.
13. The flock: off the cars' boxes on every peer, slow road, the horn clears it.
14. `DentRules` and the dents in `car_body.gdshader`, `test_seat_view` with the worst dents.
15. The dragging bumper, rattles, the crash-cracked windshield.
16. The gag director filled, `--gags=`, the bot's time with and without each gag.
17. `MayhemTally`: awards on the results and the navigator's feed lines, through the writing guide.
18. Measured and evidence: the flips, the bot runs, nettest, the frame sequences and WAVs.
- Lens `player_destruction`: "You have spent hours in BeamNG, Wreckfest and Teardown. Drive through every breakable kind at 30, 60 and 100
  km/h and through each gag: does wood feel like wood and glass like glass, do the pieces fly with the car's momentum, does the car feel the hit
  in the view, the sound and the pad, is it still funny the tenth time, does the crowd's dive read as a joke and never as harm?"
- Lens `bug_hunter_mayhem`: "Hunt desyncs and lies: break things on a client and compare every peer's broken set and rubble; drive a car
  through 30 crates and count debris contacts with the car; check drags stay under `SCRAPE_SPEED`; check no `Struck` value was inserted;
  check the flock never overlaps a car's box on any peer; check every award line against the writing guide's never-list; reproduce every
  budget number."

### 8. W, the living world (14 parts, flow stage 0)
Brief: `w_world.md` (with the changes listed at the end of this file).
1. `VillagePlan`, region-ready (a footprint and a road polyline in, not a stage), tested against the judges.
2. `HouseRules` geometry: footprint, storeys, roofs, windows with shutters, doors with steps, balconies, chimneys, yard walls.
3. House materials and kinds per biome, the openings and door anchors as data for phase I, batched by chunk.
4. The downloaded buildings in (barns, kiosk, bus stop, well, trough, windmill, water towers), each checked for marks.
5. Village things: fountain or well, tea garden, benches, parked cars as `VehicleKind`-ready placements, bicycles, poles with sagging wires, lamps.
6. Fields: the ground's row pattern by season and weather, bounded by stone walls, wire and log fences with gates.
7. Farm life: bales, haystack, the tractor yard, sheep and cows grazing behind walls, scarecrows, hives, landmarks on rises.
8. People kinds I: the second bake (women in long skirts and headscarves, children, old men with caps), poses and outfits.
9. People kinds II: marshals with whistles and boards, photographers, a TV crew, campers by tents and a fire, tea drinkers, a granny with a broom.
10. The rally's own place: service van, gazebo, tents, generator, loudspeaker, toilets, organisers' car, time control table, the finish's crowd.
11. Night: seeded lit windows, cheap lamps near the road, campfires, the start's flood lights.
12. The map knows: plan items with kind, place, turn, size; a `MapPrint` symbol each.
13. Collision and peers: solid what a car reaches, X's breakables elsewhere, the two-level test, no sightline changed.
14. Budgets and evidence: the flips, A9a's cuts if needed, the sheets by day, golden hour and night, `-Compare`.
- Lens `player_world`: "You know the Turkish countryside and you have played Forza Horizon's villages. Drive and look at every village,
  farm and the rally's place by day, golden hour and night: does it read as a place in this land, is anything foreign (text, badges, flags),
  is it alive or a set, would you stop to look?"
- Lens `bug_hunter_world`: "Check law 8 at two graphics levels (same collision list), that no house or wall sits in a measured sightline
  unless it closes one, that every model has its licence row and was checked for marks, that `HouseRules`' openings agree with the drawn
  façade, and every budget number."

### 9. J, joining (6 parts, flow stage 3)
Brief: `j_join.md` (item 3 is now only the refusal message: P1 built the fingerprint).
1. The addon pinned: unpack only what is needed by script, read its code, headless load check on 4.7.2, CLAUDE.md's third-party row.
2. Hosting through noray: a verified public server, address as a setting with fallbacks, nothing personal sent.
3. Joining in order (LAN, UPnP, punch-through, relay) with timeouts and plain words on screen, the room code's carriage.
4. The version refusal in the player's language naming both versions.
5. Rejoin within 60 s into the seat (P1's held car, the broken set, cabin, damage, gates, events, map state); the host leaving ends cleanly.
6. Tests: a fake noray, the order and timeouts, nettest's drop and rejoin, a real self-check through the public server, TEST_PLAN's two-home check.
- Lens `player_friends`: "You are the friend who always cannot join. Follow the screens from a host's code on a CGNAT line, on mobile data,
  behind a strict router: does every step say what it is doing, does the end tell you what to do, can you get back into your seat after a
  drop without the evening ending?"
- Lens `bug_hunter_net`: "Read the addon's code for what it sends where; check nothing personal reaches the server; time every fallback; kill
  a client mid-race and rejoin under each state (map gone, fainted, car stuck, things broken); check the fingerprint fails on a changed RPC;
  state honestly what the self-check through one PC cannot prove."

### 10. D, solo, share card, photo mode, credits (6 parts, flow stage 0)
Brief: `d_demo.md` items 1-4 (items 5-6 move to A10).
1. The solo session through `RaceSession` with no port opened, records apart.
2. The bot co-driver: TTS by language, calls timed 80 m ahead by speed, junctions named, the large-text fallback, gestures.
3. Solo as navigator: the bot drives and obeys the gesture calls; a wrong call costs time.
4. The share card at the finish arch with the car as it is, saved to `user://screenshots/`.
5. Photo mode from pause: the free camera within 15 m, grades, depth of field, a PNG key.
6. The credits generated from `ASSET_LICENSES.md` with the thanks; the test that every CC BY row reaches the screen.
- Lens `player_solo`: "You have no friends online tonight. Play a stage as driver and as navigator alone: does the co-driver sound and time
  like a real one, does the bot obey your calls and punish your mistakes fairly, is the share card worth posting?"
- Lens `bug_hunter_solo`: "Check no port opens in solo, that solo records never mix with crew records, that TTS never blocks the main thread
  and falls back when no voice fits, that the share card shows the real car state, that the credits miss no CC BY row."

### 11. P2, on foot (20 parts, flow stage 4)
Brief: `p_on_foot_cars.md` steps 3-9.
1. `tools/make_crew_clips.gd`: the UAL1 clips and the few retargeted UAL2 ones, ground speeds, the mannequin's hash pinned.
2. `WalkerRules` (pure): every number of the feel table.
3. `Walker`: capsule, step up and snap down, slopes, coyote time, jump buffer, landing.
4. `WalkerBody`: the suit and helmet standing, the `AnimationTree` by speed with no foot skate.
5. `WalkerCamera`: first person from the capsule's eye with bob settings, the third person on C, the own head folded.
6. `walk_test.tscn` and the physics benchmarks (steps, slopes, ledge, landing, lag under a tick).
7. Probe and cut the front doors (`CarParts` slicing if they are not islands), hinged, their state in `Cabin`.
8. Door handles: getting in by the outer handle, out by holding X or the inner handle; seat swaps through the doors.
9. `SeatPath` against the car's triangles, the body's blend from clip to `CrewPose.sit`, the door's timing and sounds.
10. `unbind_seat` / `bind_walker` as exact inverses, tested twice over.
11. `WalkerNetSync` on channel 4, played back 100 ms behind, the clips from the played velocity.
12. Host-validated in and out, anti-teleport for walkers, voice on the walker's head, walkers' rejoin, nettest.
13. The rally with someone out: only at a standstill, brought back after 20 s or at a gate, 15 s, the award line.
14. Law 1 for walkers: no car-walker contact, `DiveRules` dive, no drive-off with a walker in the door; `--flow-walk`.
15. `use`: the shared pick rule on foot, `Interactable`, the `Talkable` hook, the hint line, gates with G.
16. Carry and throw: under 25 kg, the authority handed to the carrier, the release on the clip's frame.
17. Push: `Push_Loop`, force asked of the owner, two players pushing the rally car out of a ditch.
18. `VehicleKind` data for the Milano as a road car, the estate, the van and the box truck; wheels by position, badges covered.
19. Promote and demote parked cars, at most four live, never during a timed stage past a gate, never a car with someone in it.
20. Budgets and evidence: the flips, the sheets in and out, the third-person sheet, the pushing clip.
- Lens `player_on_foot`: "You judge first-person controllers for a living (Mirror's Edge, Half-Life, Firewatch) and you love GTA's car
  entries. Walk, sprint, jump and land on the walk test and around the start area; get in and out of every seat and car: is it tight, does
  the camera make you sick, does getting in read as deliberate rather than stiff, is pushing the car with a friend fun?"
- Lens `bug_hunter_on_foot`: "Try to break law 1 and the network: stand in a car's path on host and clients, stand in an open door and
  drive off, get out at 1 km/h, rejoin while on foot, push a car on a client, throw a can across a tile edge; check a walker never fires a
  gate, an event or a splash, that the mannequin's bytes are unchanged and the crowd's and suit's tests still pass, and that every feel
  number in the table is asserted, not printed."

### 12. OW, the region and `Profile` (24 parts, flow stage 0, `-AllStages` at the end)
Brief: `ow_open_world.md`.
1. `RegionCatalog`: Çamlık Vadisi as data (stages, village, hamlet, lake, farm, liaison roads).
2. `RegionPlan` and `RegionValidator` with their known-answer tests.
3. `RegionTerrain` I: relief, the lake's basin, the stage pockets blended over 80 m.
4. `RegionTerrain` II: roads pressed in with the stage's cross-section, the margin and continuity tests.
5. `tools/make_region.gd` I: manifest, tiles, far ground, canopy picture.
6. The bake II: the stage pockets by their own builders, byte-equal tile rebuild, hashes, the stage-copy test.
7. `StreamRules` (pure): rings, look-ahead, hysteresis, pinned bodies, walkers as foci.
8. `RegionStreamer`: threaded loads, worker preparation, the 2 ms commit queue, pools.
9. The tile-edge physics test and `tools/regiontest.ps1` (a 10 km loop three times, `STREAM`/`HITCH` asserted).
10. `RoadBuilder` with a build context (no statics), roads cut to tiles, the four road classes, junction fillers.
11. `RegionRoads`: the junction graph, `nearest_pose`, `route` for bots and traffic.
12. `RegionScatter`: the roadside band, forest masks, hedgerows, law 8's two-level collision test.
13. Impostors: `tools/make_impostors.gd`, the mid-ring cards.
14. Scenery budgets: the near and mid flips, the cuts if needed.
15. The lake and its shore, the puddle shader's reflection by level.
16. Fords and a bridge, splash areas, stalled-not-sunk, the validator's crossing rule.
17. Roam I: the mode, the session without a graph (trap 8 decided), recovery to the nearest road, single-stage roam.
18. Roam II: the service park (free repair until Q), the relay thinning, remote cars without crew far away, the protocol bump, roam nettest.
19. The start control: the board, the box, both seats confirm, the race scene and back to the region; roam → stage → roam flow test.
20. The region's sheet in the map's style, `Discovery`, the pause menu's full map.
21. Fast travel (both seats, stopped, held until the ring loads) and the dash's ball compass.
22. `Profile`: Q1's design (slots, versions, atomic writes, `.bak`, checksum, instances), the slot picker, the `region` section.
23. Broken things repaired after 10 minutes unseen, with the bill line; the save's round trip and a corrupt file.
24. Budgets and evidence: perf on a roam route, shots from every place by day, golden hour and night, a hill's view, a hitch-free lap.
- Lens `player_open_world`: "You have roamed Forza Horizon, The Crew and DiRT's free roam. Spend an hour in Çamlık Vadisi alone and with a
  friend: is it worth driving between stages, do you get lost in a good way with the paper map, does the start control feel like a real
  rally's, is the calm drive calming, does anything pop, stutter or look empty?"
- Lens `bug_hunter_region`: "Prove the region is one world: tile edges equal on both sides, a baked tile rebuilt byte for byte, a stage
  in the region identical to the stage alone, no ground unloaded under any body on any peer, every trigger the host decides a data check,
  `Profile` surviving a killed process mid-write, two instances not touching each other's saves; reproduce every budget number."

### 13. I, glass, collapses, insides, walking in (16 parts, flow stage 1)
Brief: `i_interiors_destruction.md`.
1. `GlassShatter` and the panes' MultiMesh per village, cracked or gone by the hit.
2. Panes broken by a car, a thrown can and a falling structure; host-confirmed, in X's set.
3. `StructureRules`: posts, supports, the host's collapse message with a start time.
4. The four structures (porch, market roof, fence run, plank shed), the analytic fall, the roof on the windshield.
5. `RoomRules` over every footprint W makes, the openings respected.
6. Rooms by building kind, stairs, reachability graph.
7. `FurnishRules` and the code-built furniture (sedir, kilims, lace, stove, shelves, lamp).
8. The furniture catalogue from batches E and G (the approved Poly Haven furniture).
9. `InteriorBuilder` on workers, 8-12 draw calls a house.
10. `InteriorStreamer`: ranges by level, caps, per-frame slices, never under a walker.
11. Light inside I: the interior layer out of the sun and beams, `InteriorLight` per vertex, the sun's patch.
12. Light inside II: lamps at night, the far windows' interior mapping, `tools/make_room_atlas.gd`.
13. Doors as `Interactable`, the village's answer to a crash (a light, a door, a fist), the lines through the guide.
14. The places a car goes in: the barn, the market hall, the ruin, a half-built house.
15. The walk layer: floors, walls, stairs, doors, things to carry, the walker bot through every house kind and seed.
16. Budgets and evidence: the flips, the street by day, golden hour and night, walking in, the sun's patch moving.
- Lens `player_explorer`: "You open every door in every game. Walk into every kind of building in the region and the stages' villages,
  by day and night: does each room read as a home in this country, is anything floating, clipping or repeated, is the far window the same
  room as the near one, is a porch coming down satisfying, is anything you would expect to open locked without a reason?"
- Lens `bug_hunter_interiors`: "Check the light masks (no beam through a wall), that panes and structure parts append after X's indexes
  identically at two levels, that every room is reachable on foot and no walker falls through or gets stuck (run the walker bot yourself),
  that an inside never streams out under a walker on any peer, that collapses are identical everywhere, and every budget."

### 14. N, people and life (26 parts, flow stage 2)
Brief: `n_npc_life.md`.
1. `tools/list_ual_clips.gd` and `LifeAnims`: the bone texture.
2. `life_crowd.gdshader` skinning from it; today's crowd moved onto clips.
3. The pixel match against today's spectators, the old shader retired.
4. `LifeLod`: tiers and hysteresis by level.
5. The pooled near bodies and the invisible hand-over.
6. `LifeSchedule` I: the people of each place from the seed.
7. `LifeSchedule` II: the day's routine by clock, nobody on a live stage, people at I's room spots.
8. `LifePaths` from the plan, heights from the terrain, no edge through a wall.
9. The host's navigation regions baked on workers, budget reported.
10. Paths and off-path moves wired, the routine resuming from the clock.
11. `ReactionRules` and the dive (built on X's `DiveRules`), the 10 000-case sweep.
12. `SafetyShell` on every peer and the law-1 soak with `LIFE closest_m` and `shell_pushes`.
13. `LifeSyncCodec` and `LifeSync` on channel 4, late joiners.
14. The host's off-routine people, clients easing, nettest.
15. Reactions I: step back, the owner's fist, the granny's broom chase.
16. Reactions II: the horn, the crash onlookers, advice at a standing car; cooldowns.
17. `AnimalRules`: flocks (X's flock as first user), cows.
18. Dogs, goats and chickens (batches I and H): the packs' clips, a shader gait for a static model, or sound only; said which.
19. `SpeedProfile` out of `RouteFollower` (bot times within 0.2 s), `IdmRules`.
20. `TrafficLanes` and `TrafficCar` (kinematic, `VehicleKind` looks), spawning by level.
21. Traffic wrecks on a hit, the driver's line, never on a live stage, never taken.
22. The organisers' speed control: `SpeedingRules`, the wave-down, the paper on the windshield, `fined`.
23. `Conversation` data, the subtitled talk through `HudSubtitle`, `Talkable` from the car window and on foot.
24. `BarkLines` and `tools/make_babble.py`.
25. `data/life/WRITING.md` from Q's guide and the first 300 lines in both languages, the lint test.
26. Budgets and evidence: the flips, the soak on every peer, nettest, the contact sheet.
- Lens `player_npc`: "You love how GTA's pedestrians and Postal's townsfolk react to you, and you know Turkish villages. Spend an evening
  roaming and racing: do people live a day, do they react with timing and wit, does a dive ever look like harm, does any line repeat or
  offend, does the speed control read as the rally's own and never as police, is traffic believable and never in a live stage?"
- Lens `bug_hunter_life`: "Run the law-1 soak yourself on host and two clients and read `LIFE closest_m` and `shell_pushes`; check a
  headless host creates no bodies; check `SpeedProfile` kept the bot's times; check every line has both languages and passes the never-list
  (no religion, no state institution, no people as the joke); check the network budget and every frame budget."

### 15. Q, errands, career, the game's voice, the opening (26 parts, flow stage 0)
Brief: `q_missions_career.md`.
1. `Economy` and the ledger; bots earn nothing (`counts_progress`).
2. `InsuranceRules` and the bill from damage and X's broken things; `_rpc_payout`.
3. `MissionCatalog` and `MissionPlace` resolved on the region and the stages, law 1's lint.
4. `MissionRules` and `CargoRules`, every step kind and fail.
5. `MissionRunner`, givers through `Talkable`, pencil marks on the map, retry without reload; the first three errands solo.
6. Crew and room errands over the network, `NET mission` lines.
7. The errand log and the solo errands with D's bot.
8. `MissionVehicle` on N's `TrafficCar`: paths either way, speed profiles, reactions.
9. Chase and escort errands (the stolen van, the vet, the funeral, the old champion).
10. The other errands I (the carries: jars, melons, tea, the suit, the bees).
11. The other errands II (stunts, breaks, herding, the search, the bets).
12. The other errands III (modifiers: painted glass, mother calls, tired brakes; the room's trophy hunt).
13. `CareerRules`: seasons, weekends, points, the power stage, retiring; where each weekend happens.
14. The service park: paid, timed repairs by zone, dents removed, compounds and springs; the liaison and its time control.
15. `RivalModel` and `tools/bot_times.ps1`; the co-op career; `--flow-career`.
16. `CarBuildRules` and the new config fields with stock defaults; the benchmark columns per level.
17. The garage, records by class, the room's `cars` rule.
18. Cosmetics I: liveries with fictional sponsors, helmets, suits (team colour and flag kept).
19. Cosmetics II: horns, dash toys (the nazar bead out of the mirror's view), tin cans.
20. `CollectiblePlan`: gnomes, beads, plates, hidden where a crew must choose.
21. Achievements and the daily Surprise Rally with its share line.
22. The loudspeaker, Radyo Toz FM and `RadioDesk`.
23. The insurer's letters, the results' line, the rivals' lines; `test_writing_rules`.
24. The opening I: `IntroDirector`, the timeline as data, cars placed per shot, skip and the flow-test guard (the approved script).
25. The opening II: the shots, subtitles, music cues, the Movie Maker render.
26. Tuning and evidence: Season 1 played, timers, pace factors, the DEVELOPMENT_PLAN tables.
- Lens `player_progression`: "You are the player who plays one more weekend at 2 a.m. Play Season 1 and the start of Season 2 with a friend
  and alone: does every evening leave you wanting the next star, part or plate; are the errands funny the third time; is the economy fair;
  does the radio make you feel known; does the opening make you want to play? Name where you would stop playing and why."
- Lens `bug_hunter_progression`: "Check that no living thing has health or a break objective, that the driver's HUD never shows a place, a
  distance or money in a stage, that stock is bit for bit stock, that a profile survives a layout bump, a crash mid-write and two instances,
  that bots and flow tests earn nothing, that every line passes the writing lint and the never-list, that the opening never plays in a flow
  test or headless."

### 16. A6, the rest of the chaos (8 parts, flow stage 5)
Brief: `a6_chaos.md` items 1-4 and 6-8 (5, 9 and 10 went to L2, X, W, D).
1. Real sounds for the existing events from the approved recordings, under -1 dBFS.
2. Doors that pop open on P2's door cut and state: the rule, the flap, the exposure.
3. Closing them at speed, a door torn off, the shot through an open door; synced and tested.
4. The hands rule finished: every pair that must exclude each other, a clear answer.
5. The intercom: wind masking, a crash breaking it, the gestures' hint.
6. The energy drink.
7. Room modes: Classic start and the modifiers, a flow test each.
8. Awards extended on X's `MayhemTally`.
- Lens `player_party`: "You run game nights. Play a room with modifiers on: does a flapping door, a broken intercom or an energy drink
  create a moment people shout about, is any of it just annoying?"
- Lens `bug_hunter_chaos`: "Check every new state is host-owned and synced on every peer, the door shot through an opening, the hands rule
  for every pair, each mode's flow test, and the sounds' peaks."

### 17. A7, menus, screens and the audit (12 parts, flow stage 3)
Brief: `a7_ui.md` (item 4 and item 10's seat, FOV and HUD modes are F's; item 10's trip meter is M2's).
1-2. The design system for menus on F's tokens: components, focus, sounds, UI scale.
3. Main menu with the car in 3D, the profile slots, join flow.
4. The room: crew cards, stage card, settings panel, room code with streamer hide.
5. Results: podium, medals, awards, the ledger column, the share card's look.
6-7. Settings tabs, rebinding with glyphs, wheel calibration.
8. Onboarding, loading screen, pause menu, tips.
9. Gamepad everywhere and automatic glyphs.
10-11. Q's screens styled: career hub, garage, wardrobe and shop, errand log, service park, the insurer's letter.
12. The audit of every screen in both languages at 1080p and 720p, plain errors fixed.
- Lens `player_ux`: "You review UI for a living. Go through every screen as a new player with a mouse and then only a gamepad, in Turkish
  and English: is anything plain, inconsistent, clipped, unreadable or a dead end; does it look like a shipped game from a good studio?"
- Lens `bug_hunter_ui`: "Run the overflow, focus-walk and translation tests yourself; open every screen headless; check Turkish capitals;
  check the flow test's hooks still reach the room in the same frames; check no dev text remains."

### 18. A8, network and security (8 parts, flow stage 4)
Brief: `a8_net.md` items 1 and 4-7 (2 and 3 are J's; the fingerprint is P1's).
1-2. The RPC table with validation and rate limits, walkers, life sync, missions and payouts included.
3. Snapshot sanity and anti-teleport for cars and walkers, plausible gate times.
4. Kick and mute, streamer mode, names sanitised, save files read defensively.
5-6. Bad network simulation in nettest: 5 % loss, 150 ms, jitter; fixes.
7. Six players soak, roam included, bandwidth measured.
8. Logs, the bug report button, the voice's numbers.
- Lens `player_online`: "You play online co-op on bad Wi-Fi. Play a race and an hour of roam with 150 ms and loss: do cars, walkers and
  people stay smooth, does voice stay clear, does anything desync that you can see?"
- Lens `bug_hunter_security`: "Act as a cheater with a modified client: send malformed, oversized and flooding RPCs for every entry in the
  table, teleport a car and a walker, fake a payout and a gate; read `docs/SECURITY.md` against the code."

### 19. A9b, performance and QA (8 parts, flow stage 5, `-AllStages`)
Brief: `a9_a10.md` part A9.
1. Profile the whole game: a stage, roam, a village with insides, people and traffic, three crews; take the banked cuts if needed.
2. Shader precompilation and warm-up; no stutter after the first 2 s.
3. Load times: a stage and the region under 15 s.
4. Memory under 4 GB and no leak over ten races and an hour of roam.
5. `tools\qa_matrix.ps1`: every stage, weather, time and difficulty; the region route; every errand a bot can drive.
6. The bot in every weather (Glacier Ridge in snow) and the flow tests across weathers and times.
7. The clean-PC instructions and an exported build run from a clean folder.
8. TEST_PLAN with the real numbers and the owner's play-test checklist.
- Lens `player_performance`: "You notice every dropped frame. Play the play-test candidate on Low, Medium and High: any hitch, pop or long
  load you would notice?"
- Lens `bug_hunter_qa`: "Reproduce every number in DEVELOPMENT_PLAN's A9b entry with what ran beside it, and run the QA matrix yourself."

## ★ The owner's play-test build (after A9b)
The owner gets a build to play when, and not before, all of this is true:
- Every phase from F to A9b is done and reviewed through both lenses, its findings fixed.
- `tools\ci.ps1 -AllStages` passes: GUT, nettest (race and roam, three and six clients, the bad network mode), the flow tests on all six
  stages, the career flow test, a solo errand, roam → stage → roam, `--flow-walk`, and the export.
- On the dev laptop with three crews: Medium over 60 fps with p99 under 20 ms on every stage and roaming the region, no frame over 33 ms
  after the first 2 s, loads under 15 s.
- The exported `builds\windows\RADDY.exe` runs from a clean folder; TEST_PLAN has a play-test checklist in Turkish (host and join through J,
  solo, a weekend of the career, an hour of roam, walking into houses, the opening, F's blind old-against-new feel A/B), and a
  one-page "how to start" in Turkish with the SmartScreen steps.
The owner plays it alone and with friends. Their notes become phase T.

## After the play-test
- **T, what the owner found** (6-12 parts): written from the owner's notes; flow stage: all six.
- **OW2** (40-50 parts, flow stage 4): the forest grown to 4 x 3 km with the town hub, the desert and mountain regions with their stages,
  the river, travel between regions, stages run in place, the moving clock and weather. Lenses as OW's.
- **WD, the browser teaser** (12 parts, flow stage 2): `web_demo.md`; item 1's go/no-go may end it. Lenses: `player_web` ("You click itch.io
  links on a work laptop: does it load fast enough, play well enough and make you want the download?") and `bug_hunter_web` ("Check the
  desktop build is unchanged in look and frame rate, every path the demo's stages load survives the export filter, no microphone prompt, no
  thread use, and every measurement in the table").
- **A10, launch** (8 parts, flow stage 0): version 1.0.0-rc, changelog, README; the capture tool and the store's pictures and GIFs (from D
  item 5); the trailer plan from the opening's shots; the demo export (Çamlık Vadisi with Black Pine and its errands, Red Canyon standalone);
  the itch page in both languages with the browser teaser's part, a draft upload if the owner is signed in (the owner publishes);
  `tools\release.ps1`; the press kit and the owner's checklist. Lenses: `player_store_page` ("Would you click, download past SmartScreen and
  invite a friend from this page?") and `bug_hunter_release` ("A clean PC, the demo and full builds from the zips, every licence row, no
  secret in the build, every claim on the page true of the build").

## Changes to the briefs already in the repo (applied on 2026-11-17, when the drafts were merged)
- `docs/phases/x_mayhem.md`: replaced by the destruction revision.
- `docs/phases/a7_ui.md`: item 4 (the race HUD) is phase F's; item 10's seat position, FOV, HUD modes and night palette are F's, its trip
  meter M2's; add item 12: style phase Q's screens (career hub, garage, wardrobe and shop, errand log, service park, the insurer's letter,
  the profile slots); the HUD's tokens (`HudStyle`) are the base of the menus' design system, not a second one.
- `docs/phases/m_map.md`: points 6-8 are phase M2 (now, before H); the audit stays with A7 as already noted there.
- `docs/phases/d_demo.md`: items 1-4 only; items 5 (pictures for the page) and 6 (the demo build and the itch page) move to A10; the demo's
  content is Çamlık Vadisi with Black Pine and its errands plus Red Canyon standalone.
- `docs/phases/a6_chaos.md`: item 2's doors build on P2's door cut and `Cabin` door state; item 10 (the country beside the road) is W's.
- `docs/phases/a8_net.md`: item 1's fingerprint is P1's; items 2 and 3 are J's; the RPC table covers walkers (P2), life (N) and missions (Q).
- `docs/phases/a9_a10.md`: A10 item 4's demo is the one above (not "one stage"); A10 takes D's items 5-6; A9's matrix covers the region,
  roam, insides, people and the errands.
- `docs/phases/w_world.md`: `VillagePlan` takes a footprint and a road polyline (the region places villages too, not only stages);
  `HouseRules` outputs its openings and door anchors as data for phase I; parked cars are placements P2's `VehicleKind` can promote; the
  marshals are the rally's (law 10), and no place of worship is built.
- `docs/phases/j_join.md`: item 3 is only the refusal message (P1 built the fingerprint); item 4's rejoin uses P1's held car.
- `docs/phases/h_hands.md`: `CabinHotspots`' pick rule is shared with P2's `use` on foot: keep it free of seat-only assumptions.
- `docs/phases/l2_stages_events.md`: no change; its marshals and boards obey law 10 already.
- GAME_DESIGN: Direction 3 appended after "Direction 2"; §1 and §8 have one line each pointing to it. CLAUDE.md's line on
  `docs/phases` points to this file.
