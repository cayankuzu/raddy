# Phase L2: the other four stages, and events that change the road

The owner (2026-11-17, again): "Complex maps. Dead ends, roads that join the main road, events. It must feel like real rally chaos: hard,
fun, full, perfect." Phase L (`docs/phases/l_levels.md`) built bypasses on one road coordinate, the second edition of the stage rules, gag
slots, the signature place, and redesigned Black Pine and Red Canyon. This phase finishes the stages and gives them events that change
what a crew finds on the road from one run to the next, so the map is never the whole story.

Read first: `docs/phases/l_levels.md` and what phase L wrote into DEVELOPMENT_PLAN, CLAUDE.md "Stages" and "Multiplayer", GAME_DESIGN §4 and
"Direction 2"; `scripts/procedural/stage_event_builder.gd`, `scripts/gameplay/stage_events.gd`, `scripts/vehicles/vehicle_damage.gd`,
`car_damage_fx.gd`, `rally_car.gd` (the tyres), `route_follower.gd` (obstacles), `rally_dressing.gd`, `scripts/map/*` (the sheet draws every
road from `RouteGraph.roads()`).

## 1. The four stages, redesigned (Misty Creek, Scorpion Hills, Eagle Nest, Glacier Ridge)
To the second edition of the rules, as phase L did Black Pine and Red Canyon, with everything under its "Flawless means measured". Each
keeps its name, biome, length band and character and becomes a real rally road with a map worth reading: one to three bypasses each
(a shortcut with a price, a long way round something hard), more wrong ways than today where the land allows (dead ends that look like the
road, a closed road behind a barrier, a farm track that ends at a gate), junctions of real shapes (forks, T's, a square turn off the stage
at a village), gag slots, the signature place's ground (Misty Creek: the ford village by the mill; Scorpion Hills: the dry river bed under
a village on a hill; Eagle Nest: the cliff road and, if it can be made safe for the tracker, the stage passing under itself through the
three-arch stone bridge; Glacier Ridge: the frozen lake by a shepherds' hamlet). When all six claim the second edition, the first edition
goes, with its tests.

**One crossing, optional.** A stage may pass over its own earlier part once, on a bridge with at least 5 m of clearance, if and only if
tests show that the tracker, recovery, the gaps, the bots and the map's marker never take a car on one level for a car on the other (the
tracker's search is by distance along the stage, so it should hold; prove it by driving both levels and asking for recovery on each).
The validator's crossing rule gains that one exception, keyed by the recipe; the map draws the upper road over the lower with a bridge's
casing. If it cannot be made sure in the phase, leave it out and say so.

## 2. Events that change the road (`StageEvents`, second edition)
The host decides each from the room's seed and the stage's slots (phase L's gag slots and the existing event places), every peer plays it,
bots handle it, nothing about it is printed on the map or in the pace notes: the crew finds it. Each event is one pure rule with tests,
host-authoritative like today's falling fir; what it leaves stays for the crews behind.
- **A wreck ahead.** Past a blind crest or round a fast corner, a car of an earlier crew of the day (a Milano in a livery of its own, damaged
  through `CarDamageFx`, hazards on, steam) lies half across the road or in the ditch, its crew behind the rail waving their arms, a marshal
  running up the road blowing a whistle and holding up a board ("YAVAŞ" / "SLOW"). The road past it is narrowed by the wreck; the wreck is
  solid; a hit on it is a crash like any other.
- **The road closed.** At a junction with a bypass, for this run, the stage's own road is closed beyond the mouth: a barrier, tape, a board
  "YOL KAPALI" / "ROAD CLOSED" and a marshal pointing down the bypass (a landslide, the bridge out: the reason is seen beyond the barrier).
  Every crew must take the other way; the bots read the board. Seeded, at most one a run, never on Redline's first run of a room (it must
  be learnable), and the medal speeds judge a closed-road run against the bypass's own time.
- **A puncture.** A hard hit with a wheel on a rock, a kerb, a boulder or a wreck may burst a tyre (a pure rule from the hit's strength and
  where it landed): the air blast (the downloaded `j_soundeffects` file, credited), the car pulls to that side, the tyre flaps and then runs
  on the rim (less grip, a scrape, sparks from the rim on tarmac and rock, brightest at night), the speed it can hold falls. A recovery fixes
  it; so does the finish. Synced like damage (the host judges, every peer sees it in the wheel, the sparks and the sound).
- **More trees and rocks.** A second size of falling tree, a branch that only scrapes the roof and drops onto the bonnet (it slides off as the
  car turns), a rockfall that leaves a boulder field to weave through; each with its sound from the approved recordings.
- **A fog bank.** In a hollow of a stage (a seeded place on a valley floor), a bank of fog that hangs over the road for 80-150 m whatever the
  weather (a local fog volume, flat fog on Low as dense), so the crew drives into white and the navigator's calls are all there is.

## 3. Measured
For each of the four stages everything under phase L's "Flawless means measured"; for each event a headless bot through it on every stage
where it can happen and on each difficulty, nettest lines that every peer saw it the same way (the wreck's place, the closed road, a client's
puncture), a flow test with events on, the frame cost of each (`perf.ps1` flips) on Low, Medium and High. Evidence in few contact sheets:
each redesigned stage's map sheet before and after, its signature place's ground, each event from the seat (day and night for the puncture's
sparks and the fog).

Done means: GAME_DESIGN §4 and the events in "Direction 2", CLAUDE.md "Stages" and the events, DEVELOPMENT_PLAN (the measures and the bot
times per stage), CHANGELOG, TEST_PLAN, the strings, `ASSET_LICENSES.md` for the recordings used; full GUT, nettest, flow tests pass; commits
on main.
