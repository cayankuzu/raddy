# Phase F: the feel of play and the race HUD

The owner (2026-11-17, translated): "The character control is very mediocre: fix it. There are some gameplay and feel bugs: fix them."
"Make the HUD more professional; now it is very plain and simple and has nothing to do with the game." "It must look made by a AAA senior
game developer and designer." The owner named no particular bug, so this phase first **measures** the feel. It finds what is wrong with
numbers and pictures and fixes it in small steps you can undo, the old feel kept one setting away (the owner drives the two blind at the
play-test, item 8). Then it builds the race HUD that A7's item 4 described. That item moves into this phase and runs now. A7 keeps the
menus, the room, the results and the settings screens. This phase also changes those screens' look where the HUD's style reaches them, and
nothing more. And it makes the game Turkish and English everywhere (Part 3, built right after the HUD's design system: the owner asked for
complete support of both on 2026-11-17).

**The lead's reading (Direction 3).** Today nobody walks: the only "character" a player controls is the car and the head in its seat, so
"character control" is read as the car's handling, the steering chain and the seat's camera. The walking body's feel is phase P2's (its own
table of numbers, built on what this phase's kit measures). This phase is the first of Direction 3 and owns, for every later phase: the
car's feel, the seat camera's motion and options, **the feel of a hit** (`ImpactFeel`, item 6: moved here from the interiors draft so one
phase owns the camera's and the sound's answer to a crash), and the HUD's components (timing, feed, prompts, the subtitle line). Later
phases use them and never draw a second kind of toast, prompt or subtitle.

The laws stay as they are (GAME_DESIGN "Direction 2" and "Direction 3"). The rally is the heart of the game. The driver gets no picture of the road ahead
and no mayhem score on screen (law 4: a feat is a line on the navigator's HUD only). The navigator's main instrument is the paper map.
Nothing alive is ever hit. Budgets are measured (law 7): Medium must stay over 60 fps on the dev laptop with three crews.

## How big this is, honestly
This phase has two halves of about the same size and a short third part. In total it is about **24 builder parts of 1-3 hours** (listed
one by one in `order.md`).
- **Feel: about 13 parts.**
  - The measuring kit: 2 parts.
  - The baseline report: 1 part.
  - The fixes, one suspect at a time: 7 parts.
  - `ImpactFeel`, the hit you feel: 1 part.
  - The audit of the whole game by a player's eye: 2 parts.
- **HUD: 10 parts**, in the order given below (the trip meter is phase M2's, the menus' look A7's).
- **Turkish and English everywhere: 1 part** (Part 3), built right after the HUD's design system.

What a free, AI-built version can really reach:
- **Feel:** a car whose numbers are measured and held by tests, with no stutter and no clipped input, and steering that answers within a
  tick. Whether it *feels* good is decided by the owner and friends at the wheel, never by an agent. Every fix ships behind a switch, so the
  owner can compare the two.
- **HUD:** a broadcast-style rally HUD of the class of a good indie rally game, drawn in code in the game's own fonts and animated. It is
  not a studio's motion-graphics package: no video assets and no hand-drawn art beyond what code and the approved icons give.
- **Not here:** "GTA size" is not this phase's to promise, and no phase of this project promises it.

## Read first
- `CLAUDE.md`: the vehicle code, steering, the cockpit camera, mirrors, the crew, the multiplayer model, `tools\perf.ps1`, `tools\screenshot.ps1`.
- `docs/GAME_DESIGN.md`: §5 (driving feel targets), §8 (HUD and UI), §9 (quality bar: "no input lag > 1 tick", Driving feel and HUD rows),
  and "Direction 2" (laws 1, 4, 6, 7).
- `docs/phases/a7_ui.md` (item 4 and item 10's seat, FOV, HUD modes and night palette become this phase's; item 10's trip meter is M2's) and `docs/DEVELOPMENT_PLAN.md` (A2 "driving feel 2.0": its benchmark figures
  are the baseline).
- The vehicle and camera code:
  - `scripts/vehicles/rally_car.gd`, `vehicle_config.gd`, `data/vehicles/rally_hatch.tres`
  - `steering_input.gd`, `player_car_input.gd`, `cockpit_camera.gd`, `speed_blur.gd` (+ `shaders/speed_blur.gdshader`), `gearbox.gd`, `chase_camera.gd`
  - `scripts/network/body_net_sync.gd` with `snapshot_buffer.gd`
- The tests: `tests/unit/vehicles/test_handling_benchmarks.gd`, `test_steering_input.gd`, `tests/unit/network/test_snapshot_buffer.gd`.
- The HUD code: `scripts/ui/race_hud.gd`, `hud_cluster.gd`, `hud_stage_bar.gd`, `ui_theme.gd`, `scripts/gameplay/seat_effects.gd`, the
  signals at the top of `race_session.gd`, `tests/unit/ui/test_race_hud.gd`, and the `HUD_*` rows of `data/locale/strings.csv`.
- The cabin's own displays: `CarCockpit` and `CockpitRules` (the dash), and `CarRallyKit.trip_display()` (the navigator's trip meter box,
  which shows no numbers yet).
- The approved assets on the disk:
  - `assets/fonts/saira/Saira-Variable.ttf` (HUD figures) and `assets/fonts/inter/Inter-Variable.ttf` (words), each with its `OFL.txt`
  - `assets/icons/tabler/*.svg` (MIT)
  - Kenney's input prompts, `raw_assets/downloads/kenney/kenney_input-prompts_1.5.zip` (CC0): extract only the glyphs used into
    `assets/icons/prompts/` and add the `ASSET_LICENSES.md` rows.
- For Part 3: `scripts/core/settings.gd` (the saved language), `scripts/ui/main_menu.gd`, `settings_menu.gd` (the picker and the in-place
  rebuild), `data/locale/strings.csv` and its imported `.translation` files.

---

# Part 1: Feel

## The traps (each ends as a test)
- **The navigator's view on a client is a played-back car.**
  - The car is simulated only on the driver's peer. Every other peer moves a frozen kinematic copy in `BodyNetSync._physics_process`, and
    it samples the buffer at `Time.get_ticks_msec()`.
  - At 120 ticks and 60 fps, two ticks run back to back in one frame at nearly the same wall-clock millisecond, so both read the same
    sample. The copy moves two ticks' worth at once and then stands still, and physics interpolation then blends between two equal
    places. Clock times also have only millisecond steps.
  - On every client, the navigator's camera rides that copy (`CockpitCamera._process` → `car.get_global_transform_interpolated()`). This is
    the most likely "feel bug" a player meets, and half the players are navigators.
  - The fix is a playback clock that moves forward by each tick's `delta`. It is pulled gently toward wall-clock time minus the delay, but
    never stepped. `SnapshotBuffer` stays pure and gets a test for this.
  - This phase owns the playback clock (it is a feel bug); A8 later tunes the buffer for bad networks on top of it and keeps this test
    green. It changes no RPC: nettest must pass unchanged, with the 100 ms delay kept.
- **The camera's G lean reads the wrong velocity on a copy.**
  - `CockpitCamera._physics_process` takes `car.linear_velocity`, which is zero on a frozen copy. So a client's navigator gets no lean and
    no pitch from the car.
  - The crew already does this right (`RallyCar.seen_velocity()`), and the camera must use the same function.
  - On a copy, wheel compression arrives at 30 Hz (`apply_net_extra`), and the camera's roughness divides each 30 Hz step by a 1/120 s
    tick. That is a spike every fourth tick. Measure roughness in compression change per second over the time between snapshots.
- **Mouse look clips fast flicks.**
  - `CockpitCamera._unhandled_input` caps *every* motion event at 120 px (`limit_length(120.0)`), to absorb the jump when the mouse is
    captured.
  - Godot gathers the motion of a frame into one event (`Input.use_accumulated_input`, on by default). A quick flick on a 1600 DPI mouse
    is easily 300-600 px in one 60 fps frame, so the head turns less the faster the hand moves.
  - Ignore only the first event after the mouse is captured, and test it: inject 10 events of 400 px with `Input.parse_input_event` and
    check that the turn is in proportion to them.
- **Counter-steer is capped at speed.**
  - `RallyCar.max_steer_angle_at` brings the lock down from 32° to 7° by 32 m/s. At 100 km/h about 10° is left.
  - A slide of 20° at that speed cannot be caught by hand, so only the stability assist catches it. With the assist off (level 0), a fast
    slide is lost whatever the player does. A wheel user gets the same cap on a 900° wheel.
  - Fix: limit the lock around the direction of travel, not around the nose. Allow up to the slip angle plus the speed's lock, toward the
    slide only. A wheel passes straight through (`Device.WHEEL` keeps the full lock and the wheel's own range).
- **There are two steering filters in a row.**
  - `SteeringInput` shapes the input. Then `RallyCar._update_steering` rate-limits the road wheels again (`steer_rate` 2.2 rad/s,
    `steer_return_rate` 3.5).
  - On a gamepad or a wheel, full lock at walking pace therefore takes at least 0.25 s whatever the stick does. That is lag in GAME_DESIGN
    §9's terms.
  - The keyboard's ramp belongs in `SteeringInput` alone. The car's own rate limit should stand only for the real steering rack (fast,
    about 6-8 rad/s at the road wheels), or be removed for pad and wheel.
  - The A2 benchmark "keyboard to full lock 0.21 s / 0.33 s" must still hold after the change.
- **The stability assist is an invisible hand.**
  - `_apply_stability_assist` applies a yaw torque straight to the body: `excess * assist²`, and at level 2, `assist_scale` is 1.8, so the
    torque is 3.24 times level 1's.
  - It switches off while the handbrake is held, yields 0.8 for 1.5 s after it, and then comes back at full strength in one tick. A player
    feels this as "the car straightens itself" or "it fights me".
  - Log the assist's torque every tick: how often it acts on a clean bot run per stage, and its largest share of the tyres' yaw moment.
  - Fixes to try:
    - fade it back in over 0.3-0.5 s;
    - cap it at a share of what the tyres give;
    - make level 1 work through the steering (the counter-steer that already exists) more than through torque.
- **The tyres are forgiving to the point of being numb.**
  - In `_apply_tire_force`, lateral force grows linearly to `peak_slip_angle` (8°) and then stays flat: there is no fall-off past the peak.
  - Grip is exactly proportional to load, so weight transfer moves balance but never total grip.
  - There is no wheel speed: no wheelspin and no lock-up. The drive force is a force, not a torque through a spinning wheel.
  - The friction circle gives cornering priority, so throttle cannot break the rear loose (`slide_drive_floor` 0.35 keeps some drive).
  - `tire_force_lift` 0.3 m shrinks the roll and pitch moments that weight transfer comes from.
  - What results, by a rally player's eye:
    - lifting off in a corner barely rotates the car;
    - trail braking does not tighten the line;
    - power does not steer the rear;
    - a slide, once started, holds at whatever angle it has.
  - Each item is a guess until it is measured (below).
  - The fixes are small and one at a time:
    - a gentle fall-off past the peak (about 10-15 % by 3x peak slip);
    - load sensitivity (grip ∝ load^0.9);
    - `tire_force_lift` toward 0.15;
    - a smaller cornering priority on the rear axle under power.
  - Every fix must keep the A2 benchmarks inside their bands and keep keyboard play forgiving.
- **The gearbox is only heard.**
  - `Gearbox` is pure audio and dashboard: "the car's physics does not drive through it". The drive force is `engine_force * (1 - t²)`,
    the same pull from 0 to top speed.
  - So shifts are heard and seen on the needles, but nothing in the car's motion follows them.
  - Try a short cut of the drive force during `Gearbox.shifting` (0.16 s, down to about 40 %) and a mild torque curve by revs. The 0-100
    time must stay in its band (4.0-7.5 s). The car's physics must stay the same on every peer: the gearbox already runs on the driving
    peer (`CarAudio`), so the cut belongs there, as a controls-side scale on the simulating peer only.
- **The driver's head looks where the wheels point, not where the car goes.**
  - `_corner_yaw` follows `-steer_angle * 0.55`. With opposite lock in a slide, the head turns *away* from where the car is travelling.
  - Look toward the direction of travel (the velocity in car space, or yaw rate times a look-ahead time), capped at the same 55 %.
- **The camera's motion inside a car.**
  - The view rolls and pitches fully with the body. Real heads level the horizon somewhat, and the big rally sims offer a horizon lock.
    Add a setting (0-100 %, default to be judged, start at 30 %) and keep the head lean as it is.
  - The speed FOV adds up to 11° to `BASE_FOV`. In a cockpit view this makes the whole cabin "breathe". It also changes how much of the
    mirrors `test_seat_view.gd` sees.
    - Try 3-4° or less.
    - Give it a setting. The FOV slider A7 already promised goes here.
  - The road buzz's noise runs at a fixed `_time * 22`, not tied to speed or surface. Tie its frequency to speed.
- **Keys are all or nothing.**
  - Throttle and brake from keys are 0 or 1. Holding the brake below 1 m/s turns it into reverse (`_update_drivetrain`), so a player who
    brakes to a stop and keeps holding starts backing up.
  - Measure, decide and write down. A 60-100 ms ramp on key pedals is the usual soft touch. A 0.25 s pause at a standstill before reverse
    stops the "it went backwards" surprise.
- **Hits.**
  - `continuous_cd` is on and Jolt does the response, but nobody has looked at what a hit does to the car. Check whether it bounces back
    off a wall, sticks to it, or spins.
  - The impact signal fires at 3 m/s of change in one tick, with a 0.25 s cooldown.
  - Measure scripted hits (see below). The car's physics material (friction, bounce) is the first lever, set on the body in `rally_car.tscn`.
- **Physics tests use `PhysicsTestCase.wait_ticks`** and run at `--fixed-fps 120`, so results are deterministic. A feel change that
  moves a benchmark must update that benchmark's band *with the reason*, never quietly.

## Deliver (in order; each step leaves the game whole)
1. **The measuring kit.**
   - **Feel probe:**
     - `tools/feel_probe.gd`, a node `route_test` adds with `--feel=<script>[+<script>]`.
     - It plays scripted inputs into `car.controls`, or through `SteeringInput` for a device (`--feel-device=key|pad|wheel`).
     - It writes one CSV a run to `reports/feel/<tag>/<script>.csv`. Each row is one physics tick: time, raw input, steer command,
       `steer_angle`, speed, yaw rate, body slip, lateral and longitudinal g, the assist's torque, wheels in contact, impact strength.
     - It also writes one row a frame of the camera: position, the angle between frames, FOV, `look`, and the frame time.
   - **Scripts:**
     - `step` (half lock at 40, 70 and 100 km/h)
     - `slalom` (a 0.5 Hz sine)
     - `liftoff` (lift in a steady corner)
     - `trail` (brake into a corner)
     - `power` (full throttle mid-corner)
     - `hairpin` (handbrake)
     - `catch` (a slide started at 100 km/h, then full counter-steer)
     - `crash15`, `crash45`, `crash90` (into a wall at 60 km/h)
     - `land` (the 0.8 m drop)
     - `flick` (mouse events of 50-600 px)
   - The same scripts run headless in a GUT file where they can.
   - **Plot:**
     - `tools/plot_feel.gd` draws a CSV's columns into a PNG with labelled axes, two runs overlaid (before and after). It uses only Image
       drawing, because numpy is blocked on this PC.
     - `tools/feel.ps1 [-Scripts ...] [-Tag now] [-Compare <tag>] [-ExtraArgs ...]` runs and plots in one go.
   - **Camera smoothness in numbers:** the frame-to-frame change in the camera's angular speed (its second difference). Report the median
     and the 99th percentile in degrees per frame², for the driver's peer and for a client navigator (a `nettest` run with `--feel-log`).
2. **The baseline report.**
   - Run everything on the current build.
   - Write one table in DEVELOPMENT_PLAN under "F baseline": every suspect above with its number and a plot.
   - Add the existing A2 benchmark figures.
   - Then a ranked list: what the numbers say is worst for a player.
3. **Fix the invisible bugs first.** Their numbers prove them, and they change no tuning:
   - the playback clock (`SnapshotBuffer`/`BodyNetSync`, tested with simulated two-tick frames and jittered arrival);
   - `seen_velocity()` in `CockpitCamera`;
   - the roughness on a copy;
   - the mouse clip.
   - Gate: a client navigator's p99 camera jerk within 1.5x the driver's own. That is a measured target, chosen so the two views feel the
     same.
4. **The steering chain.**
   - Lock around the travel direction.
   - One filter per device.
   - The wheel's full range.
   - New benchmarks:
     - pad input to road-wheel answer at most one tick;
     - the `catch` script recovers a 20° slide at 100 km/h with the assist **off**;
     - the keyboard ramp figures held.
5. **The assist and the tyres**, one change per commit. Each is behind `VehicleConfig` values, so the old feel stays one `.tres` away.
   `--feel-preset=a2` loads the old values for the owner's side-by-side drive.
   - Benchmarks to add:
     - lift-off rotation (yaw-rate gain in the first 0.5 s after the lift, at least 15 % over steady state);
     - trail-braking rotation;
     - a power-on yaw response;
     - the assist's average torque on a clean bot run (a cap).
   - Keep the bot's medal speeds: rerun `flowtest -AllStages` and compare each bot's average with the L table.
6. **Feel you can see and hear.**
   - The gear-change cut.
   - The pedal ramp and the reverse pause.
   - Corner look toward the travel.
   - The horizon lock and FOV kick settings.
   - Road buzz by speed.
   - The hit response.
   - A crash must give:
     - its sound, the camera trauma and the rumble on the same tick as the impact signal;
     - a yaw kick the CSV shows;
     - no bounce-back of more than 20 % of the speed into a flat wall (a starting number, to be judged by the owner).
   - **`ImpactFeel` (pure, tested) and its players** (the one owner of how a hit is felt; phase X's breakables, I's glass and collapses
     and N's traffic wrecks call it, never a second rule). From a hit's strength (m/s lost), what was struck and its mass class (light,
     medium, heavy, immovable), one record: `hold_ms` (0-60), `trauma`, `fov_punch` (0-3 degrees, back in 0.25 s), `duck_db` and
     `duck_ms` (the engine, road and wind dip -6 to -14 dB for 40-120 ms, so the crunch lands in a hole), `thump_db` (a 45-70 Hz body
     under the crunch, by mass), `rumble` (strong motor, 80-250 ms), `crunch` (the sound's kind and size). The hold: for `hold_ms` the seat
     camera's shake, sway and look offsets freeze at the hit's first frame, then release into the trauma; the head (`CrewSway`) takes its
     jolt after the hold, so the body and the view agree. `CockpitCamera.add_impact` takes the record (today it takes a strength),
     `CarAudio.play_crash` takes it too and plays the thump from a synthesised one-shot (`tools/make_thump_sounds.py`, pure Python like the
     other sound tools, three masses, four variations, under -1 dBFS). Scaled by the existing "camera_shake" setting (0 turns the hold and the
     punch off: accessibility). The navigator in a car simulated elsewhere gets it from `_rpc_crash_fx`, as today. **Never touch
     `Engine.time_scale`**: physics is 120 ticks and every peer's clock is the host's; the hold is presentation only. Tests: monotonic in
     strength and mass, capped, a light thing never holds, a tree at 20 m/s holds 40-60 ms, setting 0 holds nothing; the feel audit's crash
     row (sound, camera, rumble, hold on the impact's tick).
7. **The feel audit of the whole game** (below), with each finding fixed or written down as another phase's.
8. **The owner's drive, at the play-test** (decided by the lead on 2026-11-17: the owner is not asked for a drive when this phase ends).
   - The defaults are the measured ones (the new benchmarks met). The old feel stays one setting away: `--feel-preset=a2` and the settings
     row "Sürüş hissi: yeni / eski" / "Driving feel: new / old".
   - The blind A/B goes into the play-test build's checklist in `TEST_PLAN.md` (Direction 3: the owner's first build comes after A9b):
     drive Black Pine on keyboard, then on a pad, `--feel-preset=a2` against the new feel, in a random order the owner does not know,
     10-15 minutes, with the exact command and keys.
   - Questions: which car turns in better, catches a slide better, feels heavier; which head view is calmer.
   - The answers may change the defaults after the play-test (phase T). Say this in DEVELOPMENT_PLAN.

## The feel audit (by a player's eye)
Walk through every moment of one evening's play. For each moment, record:
- the time it takes;
- how many inputs it needs;
- whether every action gets feedback (a sound and a visual, and a rumble on a pad) within 100 ms;
- what a new player would not understand.

Use the flow test's own path (`tools\flowtest.ps1`), `screenshot.ps1` frame sequences (60 frames = 1 s), and the probe's frame log. Write
one row per moment in DEVELOPMENT_PLAN. If a finding belongs to another phase, name that phase.

| Moment | What to measure | What to look for |
|---|---|---|
| Launch to the menu | seconds (the `NET boot wall=` line's way) | a black window or a frozen frame with no sign of life |
| Join by code, room, ready, start | clicks and seconds from the menu to the countdown | a dead wait with nothing moving, an error with no words |
| Loading, spawn, countdown | the gap between "loaded" and the first lamp, the clients' lag (A5b measured 24-82 ms) | the countdown has no rhythm, the car twitches on the grid |
| The start | throttle on GO to the car moving (ticks), the launch revs, the sound | a dead first half second |
| First corner, a slide, a hairpin | the probe's CSVs on the real stage | the car steering itself, the head turning the wrong way |
| A crash | impact → sound, camera, rumble, damage line (ticks apart) | silence, the camera jolting a frame late, a car stuck to a tree |
| Stuck → recovery | seconds from stuck to the offer (spec 3 s), the hold, the reset, the first second after it | 3 s of nothing on screen (show the wait filling from the first second), a spawn facing the wrong way |
| The map (navigator) | key to fully open (ms), whether the next notes are readable at 1080p, mouse look pausing while it is held | the map arriving late, a jump in the view when it closes |
| The cabin jobs | window, kick, wipers, can, gestures, gun: key to the hand's move to the result (ms) | a job that answers before the body moves, or long after |
| Finish → results → room | seconds and clicks, the moment of the finish | the finish passing with no ceremony |
| Two peers, one car | the navigator's view on a client against the driver's (camera jerk), voice while driving | the client's view stuttering |

---

# Part 2: The race HUD

## The rules
- **By role.**
  - **The driver** gets timing, the car's state, prompts and who is talking. Never anything that shows the road ahead: no corner, crest or
    profile of the stage's shape, and no mayhem score.
  - **The navigator** gets the same frame. The map stays the main thing on that screen, and the feed's mayhem lines are the navigator's only.
  - **A spectator or finished crew** gets the standings.
  - `RaceHud.shows_cluster` is already a rule of this kind. Make every element's visibility a pure function of the role, the HUD mode and
    the race state (`HudRules`, tested).
- **What the cabin can show, the cabin shows.**
  - The dash's needles and lamps are real (`CarCockpit`), so the HUD's own rev counter becomes optional (mode Minimal hides it).
  - The navigator's trip meter box shows real numbers, built by phase M2 (`docs/phases/m_map.md` point 8), not here.
  - Screen space is for what the cabin cannot show: the clock, splits, standings, prompts, the feed.
- **Motorsport broadcast, restrained.**
  - Dark translucent panels with a clipped corner.
  - One accent colour, and team colours as thin bars.
  - Tabular figures.
  - Animations of 150-250 ms that ease out.
  - Nothing that glows into the night.
  - No neon sci-fi and no default Godot look.
- **The world comes later, but its places are kept.**
  - Free roam (phase OW) and the errands and career (phase Q) will add a mission line (title, timer, the cargo's state as a bar with an
    icon), a money line (a payout or a bill, shown only outside a timed stage: the results, the service park, roam), a discovery toast and
    the subtitle line (item 6). This phase reserves their layout zones in `HudLayout` and builds the subtitle line; it builds none of the
    rest.
  - **There is never a minimap, anywhere** (Direction 3: pillar 1 everywhere; the region's map is paper, in the navigator's hands, in a
    walker's hands with M, and full-screen only in the pause menu). A rule test holds that no minimap, no arrow or distance to a place,
    nothing of the road's shape and no mayhem score is ever created on any role's HUD, and that no money line is created while a timed
    stage runs. A mission line during a stage is allowed (an errand that runs through a stage) and carries only its title, timer and
    cargo bar.

## The traps
- **The font must ship with the game.**
  - `UiTheme.hud_font()` is Windows' Bahnschrift through `SystemFont`. A PC without it falls back to Segoe UI or Arial, and a web or other
    build has neither.
  - Move the HUD to `Saira-Variable.ttf` for figures and `Inter-Variable.ttf` for words, with `tnum` and the weights through
    `FontVariation`.
  - Keep `hud_font()`'s signature so callers keep working: `HudCluster`, `HudStageBar`, the livery's name picture, `CrewBody.name_picture`.
  - Check that the livery's letters still fit their boxes (`test_car_livery`, the name-picture tests) after the change, or keep Bahnschrift
    for the livery only and say so.
- **Order.**
  - `RaceHud` has `process_priority` 10, so it runs after the cameras. The cluster's fade over the right door mirror depends on that
    (DEVELOPMENT_PLAN, A3 final check).
  - Any new element placed near a mirror must use `CarMirrors.glass_center` the same way, and the fade test must keep passing.
- **Canvas layers.** SeatEffects 5, RaceHud 8, ResultsPanel 12, PauseMenu 15, SettingsMenu 20. The HUD must never draw over a menu.
  The faint and the shock flicker (SeatEffects) sit *under* the HUD, so prompts stay readable.
- **Words.**
  - Static helpers use `TranslationServer.translate`, not `tr`.
  - Turkish upper case goes through `TextServer.string_to_upper(..., locale)` (the stage bar already does: "İ").
  - A `UiTheme.label` wraps and needs a width (CLAUDE.md, Tests).
  - Every new string goes into `strings.csv` in TR and EN.
- **Headless and the flow test.** The HUD is built on headless peers too. Nothing in it may need a rendering device, and nothing may
  stop the flow test (`--flow-test` drives the real race).
- **Draw cost.**
  - `_draw()` every frame with `queue_redraw()` is fine for a few controls. A stage bar with a profile or a damage drawing must cache what
    does not change: bake it once to a texture or a `Line2D`.
  - `perf.ps1 --flip-hud` today measures about 0 ms (A9a table). Budget: work at most 0.25 ms and GPU at most 0.2 ms on Medium, with three
    crews, by day and at night.
- **The countdown is the host's.** `RaceSession.countdown_started(seconds)` and `race_go` arrive on each peer 24-82 ms apart (A5b).
  Lights must follow `countdown_left`, not a separate timer, so GO lights with the car's unlock.

## Deliver (in order; each step leaves the game whole)
1. **The HUD's design system.**
   - `HudStyle`: tokens for colours (panel, ink, accent, the team colours from `TeamColors`, the delta green and red, a night palette at
     about 70 % brightness), the type scale (figures in Saira 600-700 condensed, labels in Inter 500), spacing, the clipped-corner panel,
     and drop shadows that read on snow and against a low sun.
   - `HudAnim`: slide-in, fade, pop, rolling numbers, and a pulse that respects a "reduce motion" flag.
   - `HudLayout`: anchored zones with safe margins, scaled by a HUD scale of 0.75-1.5. It includes the free-roam zones, left empty.
   - `HudRules` (pure, tested): which element shows for which role, mode (Full, Minimal, Off) and race state.
   - Swap the fonts. Remove the dev text from the player's screens: the summary line and the key line stay only as onboarding, fade after
     the first stage, and turn off in settings.
2. **The timing tower** (top left).
   - The stage time in large tabular figures.
   - Under it, the crews in order: team colour bar, number, the driver's and navigator's names, the gap.
   - The splits: when a crew passes a split, its row pops and shows its delta to the fastest at that gate, green (fastest) or red (+s).
     This replaces `_split`, keeps `_on_progress`'s maths, and is tested on the order and the delta's sign.
   - Your own row is outlined.
3. **The countdown, on screen and in the world.**
   - **On screen:** a rally start light tree. Three red lamps light one per second from `countdown_left`, then all turn green at `race_go`
     with a short flash, a beep per lamp and a higher one at GO. The beeps come from the game's sounds or a pure-Python synthesised one,
     like `tools/make_shock_sounds.py`, under -1 dBFS. A jump start is out of scope: the cars are locked.
   - **In the world, if it fits the budget:** the same lamps on the start arch's tower (`RallyArch`, one emissive mesh, the board's
     shader), seen through the windshield. It is the moment people clip.
4. **The cluster redesigned** (driver only, Full mode).
   - An arc rev counter with a row of shift lights (green, amber, red, blinking at the limiter) from `Gearbox.rpm`, and the gear large.
   - Speed in km/h.
   - Keep the fade over the right door mirror (`HudCluster.alpha_over`, its test).
   - In Minimal it is hidden: the dash is real.
5. **The car's state** (bottom left).
   - A damage outline: the Milano from above, drawn once from simple shapes, with each `VehicleDamage.Zone` tinted by its points. The
     bonnet, bumpers and windshield are shown by state (loose, gone, cracked, out), and engine smoke when `CarDamageFx` smokes.
   - The shock gun's darts as two icons (Tabler).
   - Wipers on and dirty glass as small icons, never sentences.
   - It changes with `damage_changed` and the cabin's state, and pops on a change.
6. **The feed** (top right, under the standings).
   - `HudFeed`: toasts with an icon, a team colour bar and short text. At most 4 show, each for 4 s, and the newest slides in.
   - A priority decides what pushes out what: a hit by the shock gun before a join or leave, before a feat.
   - Role filtering through `HudRules`: X's feats only on the navigator's screen.
   - It covers today's shock feed, a rival's split ("Takım 2 — S1 +1.4"), a crew finishing, a player leaving, and the system messages
     (GAME_DESIGN §8's "subtitles for system messages").
   - **`HudSubtitle`**, the one subtitle line of the game (people's barks and conversations in phase N, the loudspeaker, the radio and the
     givers in phase Q, the co-driver's calls in phase D): the speaker's name in their colour, at most two lines of 42 characters, shown at
     a reading speed of at most 17 characters a second, queued by priority, for the seats that hear it; the driver's is smaller and lower
     (it must fit a glance). A test with the longest Turkish line at 1280x720.
7. **Prompts and people.**
   - The recovery prompt becomes a ring that fills while R is held, with the key's glyph (keyboard or pad by the last device, Kenney's
     prompts) and the confirmations as dots per seat.
   - The stuck wait shows from its first second (feel audit).
   - The same component serves the gate's hold, the map gone, the map warning and the fainted countdown (today's `_prompt_text`, unchanged
     in what it decides).
   - Voice: chips with the speaker's name, team colour and a level bar from `Voice`.
8. **The finish moment.**
   - At your crew's finish: a chequered wipe and the time large, the delta to the leader, your place, and the medal if the time earns one
     (`StageRecords`).
   - Rivals' finishes go to the feed. This hands over to the results panel (A7) without a black gap.
9. **The seat's options and the settings.**
   - The camera's options, owned here because this phase changes the camera (A7 item 10's seat and FOV options move here): the field of
     view (a slider round `CockpitCamera.BASE_FOV` 62, within what `test_seat_view.gd` allows), the seat's eye forward/back and up/down
     within what the mirrors and dials allow, a default that shows at least 85 % of the driver's interior mirror at rest with the road still
     the star (a test holds it, A5's review measured 60 % today), the horizon lock and the FOV kick (from Part 1).
   - The settings rows: HUD mode, HUD scale, reduce motion, the feel preset (item 8), and the camera's options above. The settings menu's
     look stays A7's.
   - Night: the night palette from dusk on (`RaceLook`). Glare: the shadows and panel strength checked against snow and a low sun ahead.

---

# Part 3: Turkish and English everywhere

The owner (2026-11-17): the game must support Turkish and English completely. Most of it is there: every UI string is a key of
`data/locale/strings.csv` (keys,tr,en), and the settings menu has a language picker (`scripts/ui/settings_menu.gd`). What is missing is a
first launch in the player's own language, a switch a new player finds before any menu, the few texts that bypass the table, and the tests
that keep every later phase honest (Direction 3, law 15: every phase's content is in both languages). Built right after Part 2's item 1
(`order.md` part 15), so every HUD element after it is written against these tests. One part.

1. **The first launch speaks the player's language.** `Settings` starts with `"language": "tr"` (`scripts/core/settings.gd`). When no
   `user://settings.cfg` exists yet, take the OS's language instead: Turkish if `OS.get_locale_language()` is `tr`, English for every other
   language. Once the player picks one, the choice is saved and the OS is never asked again. A pure rule, tested with `tr`, `tr_TR`,
   `en_US`, `de_DE` and an empty locale.
2. **A TR/EN switch on the main menu.** A small two-state switch in a corner of the main menu (`scripts/ui/main_menu.gd`) that reads
   without knowing either language ("TR | EN", the current one marked) and changes `Settings`' language at once, rebuilding the menu in
   place as the settings menu already does; the settings menu's picker shows the same choice. A7 restyles it with the menus and never
   removes it.
3. **No text bypasses the table.** Move into `strings.csv`: the join code's placeholder in `main_menu.gd` (`"XXXX-XXXX-XXXX"`), the place
   on the HUD in `race_hud.gd` (`"P%d/%d"`: a key with its format in each language), and every other literal the scan below finds. Figures
   written differently by language (a split's delta "+1,4" in Turkish and "+1.4" in English; later a sum of money) go through one helper,
   not through each caller.
4. **Tests that keep it so.** Every key of `strings.csv` has a non-empty Turkish and English value, no key twice, the same placeholders
   (`%d`, `%s`, `%.1f`, `{name}`) on both sides. A scan of every script under `scripts/` fails on a literal a player can see that is not a
   key: a string given to a Control's `text`, `placeholder_text` or `tooltip_text`, to `UiTheme`'s helpers or to `tts_speak`, unless it is
   a key, a figure's format (digits, a time, `%d`) or a symbol on a short allow-list with a comment for each entry. A new screen with a raw
   literal then fails the suite in every later phase.
5. **The voice speaks the game's language.** Whatever the game says aloud (phase D's solo co-driver first) speaks the game's language,
   never the OS's: one function picks a voice from `DisplayServer.tts_get_voices_for_language` for `Settings`' language and returns none
   when this PC has no such voice, so the caller shows the large text instead (D's fallback). Tested with a faked list of voices; D builds
   the co-driver on it.

Evidence: the main menu, the room and the race HUD in both languages at 1920x1080 and 1280x720 (on Part 2's sheet), and the first launch
on a Turkish and an English locale (a dev argument that fakes the OS's language for the shot).

---

# The whole phase

## Budgets
- **HUD (`perf.ps1 --flip-hud`, twice, both orders, three crews, Medium, day and night):** work at most 0.25 ms and GPU at most 0.2 ms.
  The world-space start lamps add at most 1 draw call.
- **Part 1's changes:**
  - `--work-top` must show no new script over 0.05 ms.
  - The playback clock must not add a tick of delay (the gap stays 100 ms).
  - Medium stays over 60 fps on Black Pine with three crews (A9a's measure).

## Tests
- **Unit tests:**
  - `SnapshotBuffer` playback under two-tick frames and jitter (no repeated sample, monotonic time).
  - Mouse look in proportion to 400 px events.
  - `CockpitCamera` lean on a non-simulated car.
  - `SteeringInput` per device (one filter, pad latency at most a tick, the wheel's range).
  - The new handling benchmarks (catch with the assist off, lift-off rotation, trail braking, power-on yaw, assist torque cap, hit
    bounce-back). The old ones keep their bands or change them with the reason.
  - `HudRules` (role × mode × state: never a map, minimap, profile or score on the driver's screen; never a minimap on any screen; no
    money line in a timed stage).
  - `ImpactFeel` (item 6) and `HudSubtitle` (item 6 of Part 2).
  - The seat's options: the interior mirror at least 85 % in frame at the default, every option inside `test_seat_view.gd`'s limits.
  - The timing tower's order and deltas.
  - The countdown lamps against `countdown_left`.
  - Feed priority and expiry.
  - Fonts load from `res://` (no SystemFont in the HUD).
  - Every HUD string is in TR and EN.
  - Part 3: every key in both languages with the same placeholders, the scan for literals outside the table, the first launch's
    language, the voice by language.
  - Label overflow at 1280x720 for the longest Turkish strings.
- **The existing tests:** `test_race_hud.gd` is extended; full GUT, `nettest` (and a client navigator's camera-jerk line), and the flow
  test on two stages pass.

## Evidence
- **Feel:**
  - `reports/feel/baseline/` and `reports/feel/final/`, plots of before and after on one sheet per script.
  - The camera-jerk table: driver, client navigator, before and after.
  - The blind A/B in `TEST_PLAN.md`'s play-test checklist (item 8).
- **HUD:**
  - Screenshots at 1920x1080 and 1280x720, in Turkish and English, by role.
  - Moments: the grid with the lights (each lamp), mid-stage by day, at dusk, at night, in snow, into a low sun, a split pop, the feed
    full, damage at each level, the recovery ring, the finish.
  - Use `screenshot.ps1 -Scene res://scenes/ui/main_menu.tscn -ExtraArgs "--flow-test,--role=server,--players=1,--autodrive"` and the
    route_test args.
  - A contact sheet of all of them, and the countdown and finish as frame sequences.
  - Reviewed by eye against the A7 brief's words. Keep iterating until each shot looks like a shipped game.

## Out of scope
- **A7's screens:** menus, room, results, settings layout, onboarding, credits, gamepad navigation of menus.
- **D's photo mode and share card.**
- **The trip meter** (phase M2) and the road book.
- **The car's dents, dragging bumper and rattles** (phase X: what a crash does to the car's body; this phase owns how a hit is felt).
- **A new car or physics engine.** RallyCar's ray model stays: this phase tunes and fixes it, it does not replace it.
- **On foot, getting into other cars, the open world's money and missions.** Their zones are kept, nothing is built; a minimap is never built (Direction 3).
- **A jump-start rule.**
- **Force feedback on wheels:** Godot has no FFB API. Rumble stays as it is.

## Done means
- The baseline and final feel tables, and the bugs proven by numbers fixed with tests.
- Each tuning change behind a preset (`--feel-preset=a2`, the settings row), the measured defaults set, the owner's blind A/B on the
  play-test checklist.
- The HUD built in the order above, measured and photographed.
- Turkish and English everywhere (Part 3), its tests in the suite.
- The documents and assets brought up to date:
  - GAME_DESIGN §5 and §8 updated (the new numbers, the HUD's rules by role);
  - CLAUDE.md: the vehicle and HUD sections and the new tools `feel.ps1`, `feel_probe.gd` and `plot_feel.gd`;
  - DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN;
  - `ASSET_LICENSES.md` for the fonts and glyphs.
- Full GUT, nettest and flow tests pass. Commits on main.
