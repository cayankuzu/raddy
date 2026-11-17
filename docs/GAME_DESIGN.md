# RADDY game design bible (v1, 2026-10-19)

The one place for what the game is and the rules every phase builds against. The spec
(`RADDY_MEGA_MASTER_PROMPT_FINAL.md` + supplements) stays the source of the original requirements;
this file records the decisions taken since and the quality bar. `DEVELOPMENT_PLAN.md` tracks status.

## 1. Product
- **Downloadable Windows x64 game on itch.io** (about 5.99 USD), player-hosted online co-op for up
  to three crews of two. Zero running cost: no servers, no paid assets, no paid signing.
- **No browser version at launch.** Godot's web export only runs the Compatibility renderer (no
  Forward+/D3D12: the lighting, fog and shadows that carry the look are gone), has no ENet (online
  play would need WebRTC plus a signalling server, i.e. a running cost), restricts the microphone,
  and would stream a 150+ MB game into a tab. A weak-looking web build would sell the game short.
- **Demo:** a free *downloadable* demo build from the same code (export feature tag `demo`: one stage,
  all mechanics, online co-op). A web teaser is reconsidered only after launch, only if a
  Compatibility-renderer build of one stage with the solo mode passes the look gate in section 9.
- Steam is the biggest reach lever but costs a one-time 100 USD (outside the zero-cost rule): the
  owner decides; the build stays Steam-ready (no itch-only APIs in gameplay code).

## 2. Pillars
1. **The driver is blind, the navigator is the eyes.** The road is never readable far ahead; the
   paper map and the voice are the way through. Nothing on the driver's screen shows the road ahead.
2. **One hand, many jobs** (the Half Grip idea). Every hand holds one thing: wheel, map, can,
   shock gun, window crank. Doing one thing means not doing another.
3. **Chaos, but fair.** Every surprise can be survived by a crew that talks; nothing kills a run
   without a way back (recovery, the open half of the road, the replacement map).
4. **Real rally first.** Narrow stages, real pace-note language, gravel that moves, a car that
   slides; comedy comes from people, not from cartoon physics.
5. **Moments worth sharing.** Every mechanic should produce a story a player retells or clips.

## 3. Roles and the hands system
- **Driver:** both hands on the wheel by default. Can take one hand off (shock gun, horn, wipers,
  window, a gesture): steering then works one-handed (slower steering, less lock) until the hand is back,
  and no better with both off. A pull of the handbrake or a gear change takes the right hand for a moment
  without that.
- **Navigator:** the map takes both hands. One-handed jobs (can, shock gun, window, pointing) mean
  folding or dropping the map. Gestures (1-4 or the d-pad, rebindable): left, straight on, right or
  "slow down", with the hand nearer the partner, against the windshield where they see it at a glance
  without leaving the road, each a sign of its own: the finger across to the partner's side, the thumb
  for the side away (a hand held out that way leaves their sight), a chop for straight on, a pat for slow
  down. The gloves' backs are in the suit's colour with its stripe and after dark the lit dials light the
  hands, so the signs read on a dark dash and at night. A thumbs-up later. Every peer sees them: a crew
  can talk without a word.
- Fainted (exposure, shock): 6 s, then 4 s immune to a new shock. A fainted driver's car coasts; a
  fainted navigator drops the map (out of an open window if the wind takes it).

## 4. Stages (real rally, unpredictable)
- Road width 3.6-5.0 m (Explore +0.8 m, Redline -0.2 m), a drivable gravel shoulder of 0.8 m, a ditch 0.4 m deep
  (none beside a drop or at a splash); undergrowth from 1.2 m off the edge (in the ditch), trunks and rocks from
  2.6 m; the inside of every corner is screened by trees, rocks or a bank.
- **Sightline budget:** at stage speed the driver sees at most ~80 m of road ahead (corners, crests,
  trees, fog); straights longer than 250 m are broken by a crest or a kink.
- **Junctions with wrong ways:** 3-6 per stage (farm and logging tracks, a closed road with a
  barrier, a long track that bends out of sight). Only the map tells which way; a wrong way costs time, never the run (dead ends
  have room to turn).
- **Bypasses** (law 2 and 3): a road that leaves the stage and joins it again ahead, the navigator's choice. A *shortcut* is at most 70 %
  of the stretch it replaces and has a price (a ford, a farm gate to ram or open, a rutted track, a narrow lane between banks); a *long
  way* is at least 115 % of it and goes round a hard piece of the stage (a jump, a ford, a cliff). Each end is a real junction (a fork, a
  T, a turn off: one branch turns 60 degrees or more), it never meets the road on a cliff's side (the rail would stand across it), no
  gate lies on the stretch a bypass replaces, the notes call the mouth with the
  other way and its price and the rejoin as a junction, the map prints it as a road with its price's pictogram.
- Corner rhythm: a hairpin or a "danger" every 300-500 m (`worst_danger_gap`, on the Redline notes), places for spectators at the
  stage's best moments (a jump, a water splash, a cliff with a rail gap).
- **A real rally road, in numbers** (`StageDesignRules`, second edition, 2026-11-17). Today's six stages were one gently bending line:
  measured, they turn 368-623 degrees a km, climb 8-36 m, link 0-6 sequences of corners and have at most one corner each that tightens or opens
  (the baseline table is in DEVELOPMENT_PLAN). A stage names the edition it is built to (its recipe's `rules`); the second edition judges
  only the stages that claim it, and the first goes when all six do. Measured over the timed stage (start line to finish line) on the
  stage's own road; each number is a starting value, tuned by driving and never relaxed to let a recipe pass:
  - *Turning*: the heading changes summed, at least 700 degrees a km in forest and mountain (500 in the desert, whose roads may run
    longer and faster), and never under 300 over any single km: a real stage is never a motorway, and no km of it is the boring one.
  - *Straights*: nothing straighter than a "6" for more than 250 m (a straight shows too much, the sightline budget agrees), except one
    flat-out stretch a stage of up to 450 m that ends in a corner of 3 or tighter or over a crest: the one place the car is let go, and it
    ends with a question.
  - *The mix*: every severity from 1 to 6 (a stage that never asks for a 1 or never lets the car run a 6 has one speed); two hairpins or
    square turns at a junction (where the navigator's call matters most); three linked sequences (corners of opposite sense within 60 m:
    the rhythm a driver learns to trust the notes for); two corners that tighten or open (the recipe's `tightens`/`opens`, the notes'
    "kapanıyor"/"açılıyor": the exit is not the entry); two crests or jumps in a corner or within 30 m before one (the car is light when
    it should turn).
  - *The land*: a climb and a descent of 15 m within 500 m each (the engine labours, the brakes fade, the view opens and closes); a crest,
    jump, dip or water at least every 400 m.
  - *Choices*: one to three bypasses a stage, and in each biome's pair of stages at least one shortcut and one long way.
  - *Places*: four to eight gag slots at least 250 m apart, one signature place, at least two places for spectators.
  - *Rhythm*: never more than 600 m without something new: a change of pace (technical corners of 3 and tighter to fast road, a 5, a 6
    or 150 m of straight, and back), an air moment (a jump or a crest of 1.4 m), water, a place (spectators, a gag slot, the set piece)
    or a squeeze (a wall or drop on both sides at once).
  - *Hard and fair*: the first edition's sightline budget and danger spacing stay; the bot finishes clean on every difficulty.
- **Gag slots** (law 5): a segment's `gag` {`slot`: `beside` (one side), `across_slow` (something that moves off the road, both sides) or
  `overhead`}. Every slot, whatever the edition, keeps 40 m from a gate, a junction and a surprise, stands neither on a crest's or jump's
  blind side (its top to 20 m past its end) nor where a cliff or bank takes its room, has no other stretch of road beside it, and is in
  sight from the braking distance of the speed a crew carries there (a corner's limit at 0.7 g, then 2.5 m/s² gained to at most 130
  km/h; 0.5 s to react, 0.7 g to stop): a gag is a surprise, never an ambush. Its room is flat and nothing tall grows there. `GagDirector`
  draws three or four of the catalogue's gags into the slots from the room's `gag_seed` (new every race) and the stage, the same on every
  peer; phase X gives the catalogue its looks.
- **The signature place** (law 5): a segment's `signature` {`kind`: barn, village, bridge; `reach`, 18 m of ground past each road edge}:
  40-200 m long, the road bending at most 45 degrees through it, 60 m of clear approach in sight and 40 m of exit, nothing else in any of
  them (no gate, junction, jump, crest, dip, water, cliff, bank, surprise, crowd or gag), between the lines, no other road beside it. Its
  ground lies flat, without ditches, and is cleared; phase W builds what stands there.
- Dressing that says "rally": km boards, stage start/finish boards, chevrons, marshal tape, hay bales,
  spectators at the signature moments, parked cars, flags. Every flag is the flag of Turkey, in its exact
  geometry and proportions, treated with respect (never on the ground, nothing printed over it).
- 2-4 km per stage (2-3 minutes), 3 biomes x 2-3 stages, every stage at every time of day (the room's choice, or Random):
  day, golden hour (a low sun to drive into), dusk (the sun gone, the sky burning over a land falling dark) and night. Night is
  genuinely hard but drivable: from dusk on every car wears a light pod on its bonnet, as real crews do on night stages; the road
  is seen only where the headlights and the pod reach (100 m and more on a straight where it is in sight, about 40 m into a
  corner's side through the wide lamps; a corner still shows late behind its screen of trees and the chevrons matter), dust and
  fog glow in the beams, and a crew behind another car in its dust sees nothing at all.

## 5. Driving feel targets
- Between arcade and sim (Half Grip's own description): readable slides, weight you can feel,
  gravel that pushes the car wide, a handbrake that pivots the car, landings that do not bounce.
- Steering: speed-sensitive ratio, self-centring, input smoothing tuned per device (keyboard,
  gamepad, wheel), selectable assists (off / low / high).
- Feedback layers: g-force head motion, surface rumble in the camera and gamepad vibration, tyre and
  gravel sound tied to slip, dashboard needles that match the HUD.
- **Everything on the car works.** Nothing that looks functional is decoration: three mirrors that truly reflect from
  either seat (a door mirror breaks in a hard side hit, a recovery restores it), needles and warning lamps that read the
  real speed, revs and engine damage and sweep at the key, pedals, gear lever and handbrake that move, tail, brake and
  reversing lights, hazards on a stuck car, a light pod on the bonnet at night (a loose bonnet aims it at the sky, a torn-off one
  takes it), a dome lamp to read the map by at night that half blinds the driver, windows
  that slide into the doors, wipers that clean only where they pass (the dirt in the colour of the road, a haze that glows against
  a low sun), pops and a flame on the overrun, discs that glow after
  hard use, a glove box that opens when a can is taken, a radio that lights with the engine. The vents and the door pulls stay as they
  are: a crew does not touch them in a race. No sun visors: in a caged rally car the roof bars run where they would hang, and from where
  the crew sits a lowered one hid 43 % of the windshield.

## 6. Chaos mechanics (the fun list)
- **Shock gun** (never called "Taser", a trademark): one per player, 2 darts per stage, refilled at
  each split; range 8 m; through an open/broken window or a missing windshield for rivals, always
  inside your own cabin; 6 s faint, then 4 s immunity; the host validates line of sight, range,
  ammo and cooldown. Room setting: off / rivals only / everyone (friendly fire).
- Existing: windows, windshield kick-out, mud on the glass and wipers, map blown away, cans thrown,
  falling trees, rockfalls, visible damage, joint recovery.
- **Other people's dust and stones.** On dry ground a car drags a cloud that hangs for 4-7 s: a crew 2 s behind loses the road, and only the
  navigator's voice is left (pillar 1). Within 30 m behind a car on loose ground its stones reach your windshield: a stone leaves a bullseye,
  the next one cracks it (the host's `StoneChipRules`, so a crack can always be explained: you drove in someone's stones). On your own, about one run in ten.
- Next: doors that pop open on impacts (close them or lose things), helmet intercom that breaks and
  wind noise that drowns the voice with the windows open, spectators that jump aside, animals on the
  road, an energy drink that wakes a fainted crew member sooner.
- Modes: **Head to head** (default: simultaneous start, contact, shock guns) and **Classic** (30 s
  apart, pure time). Room modifiers: blind driver, silent navigator (gestures only), chaos level.

## 7. Characters
- Two crew members per car in a race suit and an open-face rally helmet in the team colour; first-person
  body for yourself, full body for your partner and the rivals. The hands work, on every peer: on the
  turning wheel (past what the arms reach the rim slides through them, push-pull), the gear lever, the
  handbrake, the horn, the wipers' stalk, the window's winder, the shock gun (in the hand), the map held
  by its edges, a can out of the window; the legs kick the windshield out (it goes when the soles land); the head
  turns with the mouse look, as far round as the bucket seat's wings let it (100 degrees); gestures; fainted slump;
  shock shake. The harness holds the body to the seat and the neck gives to the car: heads lean out of a corner, nod
  under braking, jolt on a hit, on every peer from the car's velocity as that peer sees it. A crew moves only where
  someone can see it.
- The helmet is an open-face rally helmet with a boom microphone, no visor and no chin bar (decided in A5b by the project's lead, against
  the brief's visor and chin bar): it is what most rally crews wear, since the intercom's microphone sits before the lips and the cage is
  overhead; the face in its balaclava and the microphone are part of what a partner reads; and a visor would be a second, transparent
  draw call over every face, sorted against the glass and the dust.
- A body sits in every seat a player holds, on every peer; an empty seat has none (its harness lies loose on it). The crew sits as
  a rally crew does: low, upright, close to the wheel; the eyes are the seats' cameras, so from the seat the road is the star (the
  windshield about half the frame height at a vertical field of view of 62 degrees). Your own arms, knees and harness are in view,
  your own head never is (it shows in the mirrors); your partner is beside you and in the interior mirror.
- The cabin is a rally car's: a roll cage that hides no more of the road than the pillars it follows, bucket seats with six-point
  harnesses in the team colour, a trip meter in front of the navigator, a fire extinguisher, no rear seat.
- The car is lettered for its crew, as a rally car is: the team's number (the one the results give the team) on a panel on each front
  door, on a rally plate on the bonnet and on the rear window; the crew's names, the driver's first, after a small flag of Turkey on the
  rear side windows; mud flaps. Drawn in code from the roster, no maker's logo; the road covers it as it covers the paint.
- The crowd (§4) is a few people at each place, the same on every peer, in plain clothes for the biome, some with a small flag of
  Turkey. They cheer a car that goes by, never one that stands (the grid, a stuck car, the cars parked past the finish): those get
  their eyes. They are scenery: no collision, nothing sent, nothing a crew can do to them (people jumping aside is §6's, later).
- What nobody sees is not paid for: only the cabin the local player sits in casts shadows of its crew and its cage, a rival's crew
  moves only on the screen, the crowd is thinned with the distance.

## 8. HUD and UI
- Driver HUD: rev counter with shift lights, gear, speed, damage silhouette, split delta (green/red),
  stage progress with every crew, recovery prompt, who is talking. Never the road ahead.
- Navigator: the paper map with the live car arrow, a trip meter (distance since reset, real rally
  practice), the current note highlighted on the sheet. The map is a map of the place (phase M): every road a road
  (wrong ways too, closed as they are), everything a crew can see and tell apart on it to scale (crowds, arches, boards,
  parked cars, log piles, rails, cliffs, forest, water, contours), nothing that gives a junction's answer away; the difficulty
  only takes the route's highlighter away (Redline) and thins the calls, never the map's truth.
- Menus: 3D car in the background, room with the crews and their cosmetics, results with a podium,
  awards and a shareable result card. Everything navigable with a gamepad.
- Accessibility: colour-blind safe team colours, HUD scale, camera shake and motion options, FOV,
  subtitles for system messages, rebinding for every action.

## 9. Quality bar (every area must reach 9.8 / 10 before a phase is called done)
| Area | Objective gate (automated or measured) | Review |
|---|---|---|
| Driving feel | tuning tests (grip, slides, landings), bot lap times stable, no input lag > 1 tick | owner's drive + adversarial review |
| Co-op / gameplay | every mechanic has unit + network tests; flow test on every stage | playtest notes |
| Stage design | validator: sightline, width, junction count, rhythm; every stage drivable by the bot | screenshots per stage |
| Visuals | per-stage screenshots by day/weather/night, no popping inside 150 m | art review against `ART_DIRECTION.md` |
| Sound | every surface and event has a sound; no clipping (peak < -1 dBFS) | listening pass |
| HUD / UI / UX | every screen reachable by gamepad and mouse; texts in TR and EN; no overflow at 1280x720-4K | heuristic audit + new-player test |
| Network | nettest/flowtest pass with 3 crews; packet loss 5 % / 150 ms ping simulation; reconnect | soak test |
| Security / privacy | every RPC validated + rate-limited; no secrets in builds; streamer mode hides the room code | security review |
| Performance | 60 fps at 1080p Medium on a mid-range GPU, 30+ fps Low on integrated; load < 15 s; no shader stutter | profiler captures |
| Code quality / KISS | one state owner per system, no dead code, tests per module | code review |
| Accessibility | section 8 options work and are tested | checklist |
| Release | clean-PC install, SmartScreen guide, itch page, licences, changelog | launch checklist |

Scores come from the objective gates plus independent adversarial review agents; the human scores
(friends' playtests) are collected in `TEST_PLAN.md` and decide what goes into the next update.

## 10. KISS rules
- One state owner per system (Cabin for the cabin, RaceSession for the race, Net for the room).
- Pure rules in RefCounted classes with unit tests; scenes only wire them.
- A new mechanic must reuse an existing state when it can (the shock gun uses the Cabin faint).
- No feature without a test and a line in this file or the plan.

## Direction 2 (decided 2026-11-17): a rally through a countryside that is a playground

The owner asked for a bigger, funnier game people clip and share: every road on the map, a much richer world (houses, people, every model we
may use), level design that is more complex and flawless, features made to spread, keyboard and mouse used together, the freedom and cheek of
the big sandbox comedies. The lead wrote a direction, three critics (the player and the clip, the code, shipping) took it apart, and this is
what stands. It adds to GAME_DESIGN's pillars; where it contradicts an older line, this is the newer decision.

### The game in one sentence
Two friends in a rally car, one driving blind and one with the map, race through a living countryside where whatever stands by the road can be
hit, sent flying and honked at; the clock decides the rally, the mayhem makes the stories.

### Laws (every phase builds against these)
1. **Mischief, not cruelty.** Things break, fly and are counted. Nothing alive is ever hit: people dive aside at the last moment, shout and
   shake a flag; animals scatter from the car and the horn. No blood, no bodies, no contact between a car and a living thing, on any peer.
   (It is the most recognisable rally clip there is, it keeps the rating low, and a crowd under the flag of Turkey is never a target.) Public
   text never names another game as what this is; the credits thank "Left! Left! LEFT!" for the inspiration and say RADDY is independent.
2. **One road coordinate.** However many roads a stage has, every follower of the stage (tracker, gates, recovery, gaps, standings, results,
   notes, bots, the map's marker) reads one distance along the stage. A road that leaves the stage and rejoins it (a bypass) maps onto the
   stretch it replaces through `graph.along_of`, linearly along its own length; no gate lies inside a bypassed stretch. Where a car changes
   road the tracker fades the difference over 40 m, so its distance never jumps or runs back; what needs two cars on one road (the stones
   one throws at the next) counts only cars on the same road, along it.
3. **The navigator chooses.** A bypass has a price that is named in the notes and printed on the map (a ford, a gate, rough ground, a flock):
   shorter and riskier, or longer and safe. The map shows every road as a road.
4. **Mayhem is something that happens to someone.** What a crew breaks stays broken for the crews behind it; it earns named awards on the
   results and a short line in the feed, never a score that flies across the blind driver's screen and never a separate mode (a mode can come
   later if players ask).
5. **The same setup, a different end.** Each stage has slots where a gag can stand, checked by the stage's judges like any feature; the
   room's seed draws three or four of the catalogue's gags into them, the same on every peer. Each stage also keeps one signature set piece
   that is always there.
6. **Keyboard is the body, mouse is the eyes and hands.** The driver's jobs at speed stay on keys (horn, wipers, handbrake, gears); the
   navigator is mouse-first: what the view ray meets is used with a click and worked with a hold or a drag (the map by its edges, the window's
   winder, a can, the gun), and mouse look pauses while a hand holds something. Every job keeps a bindable key, and a gamepad keeps working.
7. **Budgets are measured.** Every kit, set piece and gag has a written budget (draw calls, triangles, awake bodies) checked inside one
   process with a flip of its own; Medium stays over 60 fps on the dev laptop with three crews.
8. **Whatever a peer's graphics level, the world is the same**: what can be hit, broken or driven round is placed from the stage's seed alone.

### The order of work
1. **M, the map** (the sheet shows every road and landmark, a road book with tulips, the trip meter, an audit of every screen).
2. **H, mouse hands** (law 6 on the existing cabin jobs).
3. **L, level design 2**, first on two stages (one forest, one other biome): bypasses with a price, the gag slots, the stage rules' second
   edition, then the other four stages.
4. **X, mayhem**: about ten breakable things, the gags that reach into the cabin (fruit and straw on the glass, a sheet over it, bees through
   an open window), the crowd that dives, a tractor and a flock the horn moves, the gag director, awards and the feed.
5. **W, the living world**: a village kit (houses built in code from scanned plaster, stone, brick and tiles, with the few good downloaded
   models), a farm kit, fields with walls, fences, sheep and cows, more kinds of people, landmarks; one signature set piece a stage (the barn
   you drive through, the village street); everything the navigator would call is on the map.
6. **J, joining**: getting through home routers behind the room code (hole punching with a relay fallback; the free paths first), a
   protocol fingerprint test, rejoining one's seat. It comes before anything is public: a friend who cannot join ends the evening.
7. **The demo**: solo with a bot co-driver who calls the notes, the share card, photo mode, credits generated from `ASSET_LICENSES.md`, a
   script that captures trailer shots; a free demo build for itch.io (the owner publishes).
8. **A7** the interface and HUD, **A8** the rest of network and security, **A9b** the test matrix (a bot per stage, route and difficulty),
   **A10** the launch.
9. **After the demo, by what players clip**: on foot (get out and in while the car stands, walk, push, open the gate; needs `Cabin.occupant`
   first, since today a role is a seat is a simulating peer), a championship evening with bot rivals, the replay as data, seat swaps.
   Never: taking another crew's car, riding on the roof.

The frame rate phase (A9a) measured and stopped: the targets hold (Low 132-140, Medium 77-80, High 60 fps on Black Pine with three crews; the
old 30-37 were the old probe's fault). Its ranked cuts (trees 6-9 ms, shadows, backdrop, mirror) are banked in DEVELOPMENT_PLAN and are taken
up when a phase pushes Medium under 60.
