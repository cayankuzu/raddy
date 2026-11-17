# Phase X: mayhem. Things break, the living get out of the way

The owner (2026-11-17): "Add things that go viral: features, ways of playing. Fun. The cheek of the big sandbox comedies." Direction 2
(`docs/GAME_DESIGN.md`, laws 1, 4, 5, 7, 8) says what that means here: whatever is a thing beside the road breaks, flies and is counted;
nothing alive is ever hit (people dive aside, animals scatter); what a crew breaks stays broken for the crews behind; it earns awards and a
line in the feed, never a score mode; each run draws three or four gags from a catalogue into the slots phase L checked; every kit has a
measured budget; the world is the same on every peer whatever its graphics level.

Read first: GAME_DESIGN "Direction 2"; CLAUDE.md on `CrashRules`, `RoadFxPool`, the `Cabin` (dirt, wipers, windows, exposure), `WindshieldGlass`,
`Spectators`, `StageEvents`, `RallyDressing`, `RouteFollower.obstacles`, the horn, the multiplayer model, and what phase L wrote about gag
slots and `GagDirector`; `docs/phases/downloads.md` (the Poly Haven and Sketchfab models on the disk: copy what is used into `assets/` with
its manifest row and its `ASSET_LICENSES.md` row; look at each in the engine first: no maker's badge, no foreign text, no flag).

## The traps (each ends as a test)
- **First contact is the driver's peer's.** A solid prop would stop a client's car a round trip before the host knew. Breakables are
  overlap shapes, never solid: the driving peer breaks the thing at once, takes the speed the catalogue says (a drag by mass, as an
  impulse on its own car) and reports it; the host confirms by index (it exists, it stood, that car was near it by its tracker) and tells
  every peer; pieces are local and cosmetic and collide with the ground only. Solid stay: walls, houses, big trees, the tractor.
- **Indexes are the same everywhere.** The list of breakables comes from the stage, its dressing plan and the room's seed alone: a test
  builds it at two graphics levels and two effects settings and compares. A broken thing is a bit in a set the host keeps and sends to a
  peer that joins the race again.
- **Moving things need no stream.** The tractor's place is a function of the race clock, the same on every peer; a honk is a host message
  "pull over from t". The flock is the host's, sent ten times a second on the unreliable channel, with no collision: a tenth of a second
  of lag cannot matter.
- **A gag never decides a medal by luck.** Slots sit beside the stage's own line or cost every crew the same; say for each gag what it costs
  a clean run (the bot's time with and without, per stage) and keep the medal speeds honest.
- **The protocol.** Every new RPC and setting bumps `Net.PROTOCOL_VERSION`; add the fingerprint test of the A8 brief (item 1, last sentences)
  now, so that no later phase can forget.

## Deliver
1. **Breakables.** A catalogue (data: the model, a mass class, what it breaks into, its sound kind for `CrashRules`, the drag, its weight
   for the awards) of about a dozen kinds from the downloaded models: wooden crates, barrels, plastic crates, cardboard boxes, wicker
   baskets, a trash can, the picnic table, benches and chairs, cones, bales, the "wet floor" sign, the garden gnome, a football, the log
   fence, the portable toilet (it tips over; nobody is in it), and a market stall built in code from crates, a table and the fruit. Drawn as
   MultiMesh chunks by kind; a broken one leaves its chunk and becomes pieces (`RoadFxPool`'s bits and flakes: splinters, straw, fruit) or
   one flung body from a small pool (ground collision only, gone after a few seconds, at most two dozen awake). What breaks stays broken
   for the race, on every peer, for the crews behind.
2. **Gags that reach into the cabin** (each is a job for the crew; host-decided, pure rules, tested): fruit pulp on the windshield from a
   market stall (blobs the wipers clear in two sweeps), straw from bales and stacks (the wipers smear it first), a sheet from a washing
   line across a village lane over most of the glass (off after two wipes or a few seconds at speed), bees through an open window when a
   hive is hit (a buzz, specks in that seat's view, the view flinching until the windows have been shut for three seconds). They ride on
   the `Cabin`'s existing glass and exposure systems; the seat's body shows it where that is cheap (a hand batting at bees).
3. **The crowd dives.** In front of every place for spectators stands something solid a car cannot pass (the bales and a low bank), so a
   car never reaches a person. When a car comes at a place fast and close, the people of that place throw themselves back and aside (a pose
   of the crowd's shader, by a pure rule of distance, closing speed and line: each peer works it out from what it sees, like the cheer),
   then come up shaking fists and flags. The same for the marshals and photographers phase W adds.
4. **What the horn moves.** A tractor (the downloaded one, with the trailer if it holds up in the engine) that pulls out at an `across_slow`
   slot, trundles along the road and pulls off again, sooner when honked at: solid, on the clock, the bots brake for it and honk. A flock
   of sheep (the downloaded model, a simple gait in the shader) on the road at such a slot: the sheep always get out of a car's way (no
   contact, each peer keeps them off its cars' boxes), the road through them is slow until they have cleared it, and the horn clears it in
   a third of the time. Pace notes do not call either: they are the run's surprise; the map marks neither.
5. **The gag director, filled.** The catalogue of gags for phase L's slots: beside the road (a market stall, a stack of crates, a wall of
   bales, barrels, a picnic, the portable toilet, a garden of gnomes, a run of fence), across it and slow (the flock, the tractor), overhead
   (the washing line). Three or four a run from the room's seed; Surprise Rally changes the draw from day to day; `--gags=` picks them
   for shots and tests.
6. **Awards and the feed.** The host counts per crew (one pure class with tests): things broken by kind, the stall, sheets worn, bees let
   in, flocks honked through or ploughed through, tractors passed, the cleanest run. The results show three to five named awards with the
   crew's names, in Turkish and English ("Pazarı da götürdüler", "Arı kovanına çomak sokan"); a short line names a feat as it happens on the
   navigator's HUD only (the driver hears it and stays blind). This is the first piece of A6's awards: build it so A6 only adds to it.
7. **Sounds.** Wood, straw and plastic breaking from what the game has by `struck` kind; the downloaded mud splat for fruit; a bleat and
   a far flock from the approved farm sounds; bees, a flapping sheet and a tractor made the way the project makes its other synthesised
   sounds (pure Python tools) unless an approved recording fits; everything on the Game bus under -1 dBFS.

## Measured
`perf.ps1 --flip-props` and `--flip-gags` (twice, both orders): what the breakables and each gag cost a frame on Low, Medium and High with
three crews; Medium stays over 60 fps. A headless bot finishes each stage with every gag drawn in turn, on each difficulty. nettest: a
client breaks a thing, the host and the other client see it broken, a late peer gets the set; the flock and the tractor in the same place
on every peer; a flow test with gags on. Evidence: one contact sheet per gag (before, during, after, from the seat), the crowd diving
from the seat and from beside the road, the awards on the results.

Done means: GAME_DESIGN, CLAUDE.md, DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN (what only a crew on voice can judge: is it funny the tenth
time), `ASSET_LICENSES.md` and the credits' rows, the strings; full GUT, nettest and flow tests pass; commits on main.
