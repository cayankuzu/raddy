# Phase L: level design 2, real rally roads a navigator chooses between

The owner (2026-11-17, three messages): "Update, improve and develop the level designs, the roads and the maps. More complex, more fun.
The level designs must be flawless." "Make a more complex map, with every road on it. Forked roads. Right now it looks very simple. I want
it to be like real rally roads. The game must be hard and fun. Not one plain road: turns and curves, shortcuts and long ways."

Today a stage is one gently bending line with three to six dead-end stubs: the navigator never chooses anything and the driver is rarely
asked a question. Direction 2 (`docs/GAME_DESIGN.md`, "Direction 2", laws 2, 3, 5, 7, 8) decides what a stage becomes: a real rally road,
with bypasses that have a price, slots where a seeded gag can stand, one signature place, a rhythm. This phase builds the roads, the slots
and the rules and redesigns all six stages against them (Black Pine and Red Canyon first, the other four in a second run once those two are
right). What stands in the slots (breakable things, a flock, a tractor) is phase X; the village and the barn are phase W: this phase
leaves their places checked and empty, and every commit leaves whole stages.

Read first: CLAUDE.md "Stages", "Paper map and pace notes" and "Multiplayer"; GAME_DESIGN §4 and "Direction 2"; `scripts/procedural/route_graph.gd`,
`stage_builder.gd`, `stage_catalog.gd`, `route_validator.gd`, `stage_design_rules.gd`, `sightline.gd`, `route_tracker.gd`, `route_index.gd`,
`recovery_anchor.gd`, `route_follower.gd`, `road_builder.gd`, `rally_dressing.gd`; `scripts/gameplay/race_progress.gd`, `race_session.gd`
(`_measure_gaps`, the trackers); `scripts/map/*` (phase M's map page draws every road as a road: see `docs/phases/m_map.md`); the tests of each.

## The traps the code holds (found by reading it; every one must end as a test)
- **One coordinate.** About a hundred places walk `main_route_points()` and think in one distance along the stage. A bypass does not change
  that: `graph.along_of(road, index_or_distance)` maps any point of a bypass onto the stretch of the stage it replaces (from its mouth to its
  rejoin, linearly along its own length), and that is the only way anything learns where on the stage a car on a bypass is. Write it as a
  law in GAME_DESIGN before a stage changes.
- **Gates in order.** `RaceProgress.record` ignores a gate crossed out of order: a bypass that passed a split by would leave a team unable to
  finish. No gate lies between a bypass's mouth and its rejoin; the validator says so.
- **The tracker** searches only the stage's own polyline and finds a lost car again only up to 30 m ahead of its furthest point: it must also
  search the bypasses that are open from where the car is; progress on a bypass counts (`ON_ROAD` from the bypass's own line), runs forward
  without a freeze or a jump at the mouth and the rejoin, and never runs backward into the stretch behind the mouth.
- **Recovery** puts a car back on the road it is on, bypass or stage, facing the way it was going; the stuck and wrong-way logic knows a
  bypass is no wrong way.
- **Spurs' rule** forbids "a way through to another part of the road": a bypass is exactly that, on purpose. It gets a rule of its own
  (`_check_bypasses`): it leaves and rejoins the same stage in the stage's direction, the rejoin lies ahead of the mouth by at least a minimum,
  its mouths are junctions (the spacing and the side rule hold), it crosses nothing, keeps 30 m from other stretches except at its mouths,
  its radius and grade are drivable, the terrain, ditches and verges close at both mouths with no step.
- **Records.** Redesigned roads bump `StageCatalog.LAYOUT`: old times go. Medal speeds are judged on the stage's own road; measure road and
  bypass with the bot on each difficulty and say which is faster and by how much.
- **Peers.** The same roads, slots and draws on every peer from the stage and the room's seed; nothing placed here depends on a graphics
  level or on effects settings; what a new setting or RPC adds bumps the protocol version.

## Deliver
1. **Bypasses.** A recipe key on a segment (where it leaves, on which side, its own segments or length, where it rejoins, its surface and
   width, its kind and price) builds a `RouteGraph.Bypass` beside `spurs` (its own edge ids; `road_edges()` gives it to whatever builds the
   world; whatever follows the stage reads `along_of`). Two kinds: a **shortcut** (clearly shorter, with a price: `ford`, `gate`, `rough`,
   `narrow`, or a gag slot of its own) and a **long way** (longer and safe, round a hard piece of the stage's own road: a jump, a ford, a
   cliff). The world: its road, ditches and verges, mouths that look like the road carrying on in both directions (a fork, a T, a turn off:
   real junction shapes, at least one branch turning 60 degrees or more), the price built for real (a ford is water with its splash and
   washing; a gate is a farm gate across the road that a car rams open at a cost in damage and speed, or that the crew opens from the
   standing car with a job held for three seconds; rough is a surface with its own grip and noise; narrow is a width with banks). Pace
   notes: the junction's call names both ways and the price ("Kısayol solda: dere", "Uzun yol sağda"), in Turkish and English; the map draws
   the bypass as a road with its price's pictogram.
2. **Everything that follows the stage follows two roads**: tracker, progress and gates, recovery, the gaps between cars and the standings,
   the results, the stone chips' follower range, the bots (a bot takes a bypass or not by a seeded choice per run and drives it cleanly, its
   price included: slows for the ford, stops and opens or rams the gate), the HUD's stage bar, the map's marker, voice and whatever else
   reads a distance along the stage (find them all: grep the call sites, list them in DEVELOPMENT_PLAN).
3. **A real rally road, in numbers** (`StageDesignRules`, second edition; GAME_DESIGN §4 rewritten; each measure pure, tested and printed
   on the stage's summary notes; first print today's six stages as the baseline that shows how plain they are). Starting values, to be
   tuned by driving and never relaxed to let a recipe pass:
   - turning: the sum of the road's heading changes per kilometre at least 700 degrees on forest and mountain stages and 500 in the desert,
     and never under 300 over any single kilometre;
   - straights: nothing straighter than a "6" corner for more than 250 m, except one flat-out stretch a stage of up to 450 m that ends in a
     corner of 3 or tighter or over a crest;
   - the mix: every severity from 1 to 6, at least two hairpins or square junction turns, at least three linked sequences (two or more
     corners of opposite sense within 60 m of each other), at least two corners that tighten or open (the recipe and the notes gain
     "tightens" and "opens" if they lack them), at least two crests or jumps inside or just before a corner;
   - the land: a real climb and a real descent a stage, a crest, jump or dip at least every 400 m;
   - choices: one to three bypasses a stage, at least one shortcut and one long way among the six stages' every pair, each with its price;
   - places: four to eight gag slots at least 250 m apart, one signature place, at least two places for spectators (as today);
   - rhythm: no more than 600 m without a change of pace (fast, technical, a place), an air moment, a water or ice moment, a squeeze;
   - hard and fair: the first edition's sightline budget and danger spacing stay; the bot finishes clean on every difficulty.
4. **Gag slots.** A recipe key marks where a gag may stand (`beside` the road, `across_slow` for what moves off the road, `overhead`),
   checked by the judges like a feature (never at a gate, a junction's mouth, under a surprise, on a crest's blind side, on a cliff's lip;
   in sight from at least the braking distance of the stage's speed there; room for what stands there, kept clear by `clearings()`).
   `GagDirector` (pure, tested): from the room's seed and the stage, which three or four of the catalogue's kinds stand in which slots this
   run, the same on every peer; `--gags=` for the dev scenes. The catalogue is data here and empty of looks: phase X fills it.
5. **The signature place.** Each stage names one set piece and reserves its ground (a recipe feature with the footprint, the approach and
   the exit checked by the judges): the barn the road runs through, the village street, the bridge. This phase flattens and clears the
   ground and routes the road through it; phase W builds what stands there.
6. **The six stages redesigned** against all of it, corner by corner: what a crew sees, hears and has to decide every few hundred metres;
   corners that flow into each other the way a real stage's do; each bypass a real question for the navigator; the junctions readable from
   the seat at the stage's speed; spectators where the stage is at its best; pace notes that call it right (read every call against the
   road). Each stage keeps its name, biome, length band (2-4 km) and character, and gets harder and more fun, not longer and emptier.

## Flawless means measured
Both judges empty for every stage; a headless bot finishes every stage on its own road and through every bypass, on each difficulty and in
each of the stage's weathers (the list and the times in DEVELOPMENT_PLAN); recovery asked for at twenty seeded places a stage, bypasses and
mouths among them, always lands on a road facing forward; the tracker's distance is continuous over every mouth and rejoin (a test drives
the line); the sightline budget holds on every road; no place where a car that left the road cannot come back or be recovered; the terrain
never pokes through a road, a ditch or a mouth (the margin test); the map agrees with the roads (phase M's truth tests extended to
bypasses); nettest and a flow test on a stage with a bypass, a client crew taking it while the host's does not.

Evidence in few contact sheets: each redesigned stage's whole map sheet before and after; each mouth and rejoin from the seat by day and at
night; each price; the signature place's ground; a table per stage of the measures before and after and of the bot's times (road against
bypass) per difficulty.

Done means: GAME_DESIGN (§4 and law 2), CLAUDE.md "Stages", DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN (what two people must judge: is the
choice at the junction a real one, is the price fair, is it hard and fun), the strings; full GUT, nettest, flow tests pass; commits on main.
