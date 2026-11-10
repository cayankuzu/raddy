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
  window): steering then works one-handed (slower steering, less lock) until the hand is back.
- **Navigator:** the map takes both hands. One-handed jobs (can, shock gun, window, pointing) mean
  folding or dropping the map. Gestures: point left/right/straight, "slow down", thumbs up.
- Fainted (exposure, shock): 6 s, then 4 s immune to a new shock. A fainted driver's car coasts; a
  fainted navigator drops the map (out of an open window if the wind takes it).

## 4. Stages (real rally, unpredictable)
- Road width 3.6-5.0 m (Explore +0.8 m, Redline -0.2 m), a drivable gravel shoulder of 0.8 m, a ditch 0.4 m deep
  (none beside a drop or at a splash); undergrowth from 1.2 m off the edge (in the ditch), trunks and rocks from
  2.6 m; the inside of every corner is screened by trees, rocks or a bank.
- **Sightline budget:** at stage speed the driver sees at most ~80 m of road ahead (corners, crests,
  trees, fog); straights longer than 250 m are broken by a crest or a kink.
- **Junctions with wrong ways:** 3-6 per stage (farm and logging tracks, a closed road with a
  barrier, a long track that bends out of sight; loops that rejoin later come when the tracker can follow two roads). Only the
  map tells which way; a wrong way costs time, never the run (dead ends have room to turn).
- Corner rhythm: a hairpin or a "danger" every 300-500 m; each stage has 2-3 *signature moments*
  (a jump with spectators, a water splash, a cliff with a rail gap; a wooden bridge and a village street
  come later, with their assets).
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
  hard use, sun visors that come down for a low sun ahead, a glove box that opens when a can is taken, a radio that lights with the
  engine. The vents and the door pulls stay as they are: a crew does not touch them in a race.

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
- Two crew members per car in a race suit and a full-face helmet in the team colour; first-person
  body for yourself, full body for your partner and the rivals; IK hands on the wheel, the map, the
  gear lever; head turns with the mouse look; gestures; fainted slump; shock shake.
- A body sits in every seat a player holds, on every peer; an empty seat has none (its harness lies loose on it). The crew sits as
  a rally crew does: low, upright, close to the wheel; the eyes are the seats' cameras, so from the seat the road is the star (the
  windshield about half the frame height at a vertical field of view of 62 degrees). Your own arms, knees and harness are in view,
  your own head never is (it shows in the mirrors); your partner is beside you and in the interior mirror.
- The cabin is a rally car's: a roll cage that hides no more of the road than the pillars it follows, bucket seats with six-point
  harnesses in the team colour, a trip meter in front of the navigator, a fire extinguisher, no rear seat.

## 8. HUD and UI
- Driver HUD: rev counter with shift lights, gear, speed, damage silhouette, split delta (green/red),
  stage progress with every crew, recovery prompt, who is talking. Never the road ahead.
- Navigator: the paper map with the live car arrow, a trip meter (distance since reset, real rally
  practice), the current note highlighted on the sheet.
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
