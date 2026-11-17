# Phase Q: why the player stays. Errands, a career, a car worth upgrading, a voice of its own, and an opening

The owner (2026-11-17, translated): "Add things that make whoever plays it addicted, Postal-style missions if needed, so the player does not get
to the bottom of it at once ... continuity ... its humour should be dark humour, and viral ... add an opening animation, a short one with
subtitles." The lead keeps GAME_DESIGN's Direction 2: nothing alive is ever hurt by the player (law 1), the humour lives in writing,
situations and absurdity, never in cruelty, never at religion, a people or a real person, and the rally (a blind driver, a navigator with the
map, co-op) stays the heart: the errands happen on the rally's roads, around the rally's weekend, and almost all of them need both seats.

Today RADDY has no reason to come back but the clock: `StageRecords` keeps a best time and a medal per stage on this PC
(`scripts/core/stage_records.gd`), `ResultsPanel` shows them, the room picks a stage. There is no profile, no money, no unlock, no mission,
no career, no save beyond `user://settings.cfg` and `user://records.cfg`, and no intro (the game opens on `scenes/ui/main_menu.tscn`). No
opening animation was ever agreed in RADDY's records: the lead approved the script below (Q13) as written on 2026-11-17, since the owner
asked the lead to decide everything; it is built in this phase, and the owner may change it later (the timeline is data).

## Honest size

About **26 builder parts of 1-3 hours** (listed in `order.md`) (Q2 and Q4-Q14 below, each with its count; Q1 is built by phase OW and Q3 is folded into it), so
50-75 hours of agent work.
What a free, zero-budget, AI-built version can really reach, and should promise no more:
- **30 errands** on the rally's roads (the six stages' roads, their wrong ways and bypasses, the villages and farms phase W builds, and the
  region's roads of phase OW, built before this one), each a few minutes, each with three stars to earn. Not a
  story campaign with cutscenes; a weekend of absurd chores told in short subtitled lines.
- **A career of three seasons** (three rally weekends each, plus an endless "season N" after), about 12-20 hours for a player who chases
  every star, gnome and upgrade; the six stages are reused at every time of day and weather, because six stages is what exists.
- Ten bot rival crews with names, faces only on the results card, and lines; their times simulated from the bot's measured times except the
  two that drive physically in a solo weekend.
- No voice acting (subtitles over a babble or a loudspeaker's crackle), no lip sync, no online leaderboard (no server: zero cost), no
  microtransactions, ever.
Never promise "GTA's size" or "Postal's story". Say "a rally weekend's worth of trouble, and a reason to run it again".

## Order and prerequisites

**Decided by the lead (Direction 3, `order.md`):** this phase comes after F, H, X, W, J, D, P2, OW, I and N, so it builds on what they
left and never on stand-ins: H's hands hold the cargo (law 6), D's solo session and bot co-driver carry solo errands and the solo career,
P2's walker gets out to fetch things, OW's region holds the places (`MissionPlace` resolves on its places and roads, the stages' spurs
and bypasses inside it, its villages and farms), OW's `Profile` is the save (Q1's design below is what OW builds; this phase adds its
sections), OW's roam is the free roam (Q3's design is folded into OW item 8), I's houses are where a giver lives, N gives the givers
bodies, `Talkable`, `Conversation`, `BarkLines`, the traffic a mission vehicle drives on, and the speed control's `fined`. Where a model
of the approved farm animals turns out unusable (the goat, the chickens, the dog), the errand uses the fallback written beside it, or waits
and says so in `MissionCatalog`. The opening (Q13) is built once, at the end of this phase, when everything its montage shows exists.

## Read first

- `docs/GAME_DESIGN.md` §2 (pillars), §3 (the hands), §6, §8 (HUD: never the road ahead on the driver's screen), "Direction 2" (all eight
  laws), and the open-world and N briefs (`docs/phases/ow_open_world.md`, `n_npc_life.md`: N's §N11 `Conversation`, §N12 the writing
  guide, §N10 `fined(team, amount, village)`).
- CLAUDE.md: "Screens and flow" (`Flow`, `Settings`, `RaceSettings`, `StageRecords`, `RaceResults`, `UiTheme`, the canvas layers),
  "Multiplayer" (`Net`, the roster, `RaceSession`, `Cabin`, recovery, the snapshot extras, damage), "Stages" (`RouteGraph`, spurs,
  bypasses, `RouteTracker`, `RouteFollower`, `GagDirector`), "Paper map" (`MapCanvas`, `PaperMap`), "Tests".
- Code: `scripts/core/flow.gd`, `settings.gd` (how a file is saved and how tests point it elsewhere), `stage_records.gd`,
  `race_settings.gd`; `scripts/network/net.gd` (`PROTOCOL_VERSION`, `JOIN_VERSION`, `start_race`, `_rpc_lobby_settings`);
  `scripts/gameplay/race_session.gd` (`_rpc_spawn_car` lines ~798-835, `_on_gate_passed`, `_publish_results`, recovery), `race_results.gd`,
  `route_tracker.gd`, `recovery_anchor.gd`; `scripts/vehicles/rally_car.gd` (reads `config` in `_ready`, lines ~93-98), `vehicle_config.gd`,
  `vehicle_damage.gd` (five zones of 0-100 points, `to_array`/`from_array`), `route_follower.gd`, `crew_rules.gd`; `scripts/ui/*`;
  `scripts/procedural/gag_director.gd`; `data/locale/strings.csv` (keys,tr,en); `tests/unit/vehicles/test_handling_benchmarks.gd`.
- `docs/phases/x_mayhem.md` (awards and the feed: the counters this phase pays for), `w_world.md`, `d_demo.md` (solo, the bot co-driver,
  the share card), `a7_ui.md` (every screen here gets A7's design system: build plain with `UiTheme` first, never a second look).

## The rules this phase never bends

1. **Law 1 in every mission.** Living cargo and living targets (the goat, the chickens, the dog, the cow, the sheep, the bees, any person)
   have *patience*, never *health*: a rough drive makes the goat jump out at the next stop and walk home, the chickens shout, the dog keep the
   map; nothing alive is injured, ever, and no objective is "hit X" where X lives. A test walks `MissionCatalog` and fails on any living
   target with an integrity, a break or a hit objective.
2. **The driver stays blind.** A mission's destination is drawn on the navigator's paper map (a pencil mark) and said by the navigator; the
   driver's HUD shows the mission's timer and the cargo's state, never an arrow, a distance to a place or anything about the road ahead.
3. **The rally stays the heart.** Errands live around the stages (the Friday's roam, the road between service and the next start, a
   photographer's request inside a stage) and almost all need both seats: the cargo takes the navigator's hands (pillar 2), the map is still
   the only way to the place (pillar 1).
4. **One place for money.** Every lira that enters or leaves a profile goes through `Economy` (pure), with a reason; the HUD and the results
   show the line. No other script adds money.
5. **Stock stays stock.** `data/vehicles/rally_hatch.tres` and the handling benchmarks do not change: an upgrade is a copy of the config with
   deltas, and a stock car is bit for bit today's car.
6. **No dark patterns.** No paid anything, no loot boxes, no random rewards for money, no streak that punishes a missed day without a
   forgiveness (one free missed day a week), no notification outside the game. The hook is wanting one more star, one more gnome, one more
   upgrade, and the next line of the radio.

## The traps (each ends as a test)

- **`user://` is shared by every instance** (CLAUDE.md "Gotchas"). Profiles live in `user://profiles/` and, when `--instance=N` is on the
  command line, in `user://profiles/i<N>/`; tests point `Profile.save_path` elsewhere, as `Settings.save_path` does. A test runs two
  "instances" and checks neither touches the other's file.
- **Bots must not earn.** `ResultsPanel` writes records unless `Flow.args` has `autodrive` or it is a flow test; payouts, unlocks,
  achievements and the daily rally go through the same gate (`Profile.counts_progress()`), except in a flow test that asks for it with
  `--profile-test` and its own scratch path.
- **`StageCatalog.LAYOUT` bumps wipe times, never careers.** Records are kept per layout (`best_v<LAYOUT>`); career progress, money, stars,
  collectibles and unlocks are keyed by stage *id* (`&"black_pine"`), never by index or layout. A collectible's id is (stage id, its number
  in `CollectiblePlan`); when a layout moves them, the count a player earned is kept (a test bumps a fake layout and checks the totals).
- **The shared `VehicleConfig`.** `rally_car.tscn` points at `rally_hatch.tres`; mutating it changes every car and every test. Builds go
  through `CarBuildRules.config_for(build) -> VehicleConfig` that returns `base.duplicate()` with the deltas; a stock build returns the base
  resource itself. The config must be set before the car enters the tree (`RallyCar._ready` copies mass and centre of mass): in
  `RaceSession._rpc_spawn_car` before `_cars.add_child(car)`.
- **Physics has no gears.** `Gearbox` is the sound's (`CarAudio.gearbox`); engine force is one number up to `top_speed`. A gearbox upgrade
  must change something `RallyCar` reads: add `VehicleConfig.low_speed_force_scale` (default 1.0, a force multiplier below 12 m/s fading to
  1 at 25 m/s) and shorter shift times in `Gearbox` for the sound and the dash. Every new config field defaults to today's behaviour.
- **Grip is one weather number today** (`RallyCar.grip_scale`). Tyre compounds need a per-surface factor: `TyreCompound.factor(surface)`
  multiplied where each wheel reads its `Surface` (stock: 1.0 everywhere, so the benchmarks hold).
- **The driver's peer simulates.** A team's build must be known on the driver's peer before the first tick and on every other peer for what
  shows (the light pod's strength, the livery, the horn). It rides in the roster entry (`build`, `cosmetics`), validated by the host
  (`CarBuildRules.valid`: known parts, levels in range), so `_rpc_spawn_car` on every peer reads the same thing. Bump
  `Net.PROTOCOL_VERSION` for every new RPC, roster field and setting; add X's protocol fingerprint test if it is not there yet.
- **Records per class.** An upgraded car's time is not a stock record: `StageRecords` sections become `best_v<LAYOUT>` (stock, as today, so
  no player loses a time) and `best_v<LAYOUT>_open` (any build). The medal speeds judge stock and open alike, so upgrades make gold
  reachable, which is the point; the daily rally is always stock.
- **Free roam is not a race** (OW's trap 8, decided and built there). In roam no stage tracker follows a car (the region's map marker is
  the car's world position): a mission's place is reached by a distance check in world space, and a step that needs "along a road" (Follow,
  Lead, Race) measures along `RegionRoads`' polyline the vehicle drives, never along `RouteTracker`.
- **Places on wrong ways.** Spurs are outside `edges` (ids from `SPUR_EDGE_BASE`); the tracker and `along_of` know the stage and bypasses
  only. A mission place on a spur is a point in world space plus the spur's id, found with `graph.road_edges()`; reaching it is a distance
  check, not a tracker distance.
- **`RouteFollower` and other roads.** It follows a path it is given (it "stops at the end of an open path"); a mission vehicle on a spur, a
  bypass or a road back needs its path built from that road's points (`graph.spurs`, `followed_roads()`), reversed where it drives against
  the stage. A test drives a follower car down every spur of Black Pine and back.
- **The paper map renders once.** `MapCanvas` is a 1792x1152 SubViewport drawn once a race (M's cost rule); a mission's pencil marks are
  drawn into it when the mission changes, never each frame (a test counts the renders while a mission runs).
- **The hands are one rule.** Holding cargo is a job in `CrewRules.hands` (A6 item 3's audit): both of the navigator's hands, so the map
  folds; one hand for a small thing (the phone in "mother calls"). Nothing else decides what a hand holds.
- **The flow test must keep passing.** The intro never plays when `Flow.is_flow_test()`, headless, `--skip-intro` or any `--autodrive`;
  new menu entries leave `main_menu.gd`'s `_automate` path as it is (a test opens the menu with the flow-test args and checks the room is
  reached in the same frames as before).
- **Translation.** Every line is a key in `data/locale/strings.csv`, Turkish and English both; static helpers use
  `TranslationServer.translate`, not `tr`; Turkish capitals through the locale (`i` → `İ`).

## Deliver (each step leaves the game whole and every test green)

**Q1. The profile and the save (built by phase OW, item 10, to this design; this phase adds the sections `wallet`, `garage`,
`cosmetics`, `career`, `missions`, `collectibles`, `achievements`, `daily`, each with its migration step).** An autoload `Profile` (`scripts/core/profile.gd`, after `Settings`) holding a `ProfileData`
(RefCounted, pure: a dictionary with typed accessors, `to_dict`/`from_dict`) and a `ProfileStore` (the file). Three slots,
`user://profiles/slot_<n>.cfg` (ConfigFile, as `settings.cfg` and `records.cfg` are; small, readable, under 64 KB). Sections: `meta`
(`version`, created, played seconds, the slot's name), `wallet` (lira, the last 50 lines of the ledger), `garage` (owned parts, the build per
car), `cosmetics` (owned, worn), `career` (season, weekend, run, standings, the damage carried, the rivals' state), `missions` (per id: state,
stars, best time, the secret star found), `collectibles` (per stage id: the ids found), `achievements`, `daily` (date → best, the streak and
its forgiveness), `flags` (`intro_seen`, the first-run cards, the radio lines heard). `PROFILE_VERSION` 1 with a `migrate(from, data)` chain
(each step a function with a test, from the first one on). Writes are atomic: write `slot_<n>.cfg.tmp`, keep the previous as `.bak`, rename
over (`DirAccess.rename_absolute`); a file that fails to load or fails its checksum (a CRC of the content: it finds corruption, it is no
lock) loads the `.bak` and the menu says one line. Saved after the results, after a mission's end, after a purchase, on leaving the service
park and on `NOTIFICATION_WM_CLOSE_REQUEST`; never during a stage. The main menu gets a slot picker (name, money, season, played hours).
Tests: round trip, migration, the `.bak` path, a truncated file, two instances, a write under 5 ms (`gut.p` it).

**Q2. Money and the insurer (1-2 parts).** `Economy` (pure, tested) turns what happened into ledger lines: a stage's place and medal, the
weekend's standings, a mission's reward by stars, X's awards (each named award pays a little: mayhem is something that happens to someone,
law 4, and the insurer bills it), N's `fined`, the tow after a recovery (250), repairs at the service park. `InsuranceRules` (pure): the bill
from `VehicleDamage`'s zones and X's broken things (a price per kind in X's catalogue), what the policy covers (none, "kasko" with a
deductible, "full" at 80 %; a policy bought per season), and the letter that comes with it (Q12's insurer). The host computes each team's
lines from its results and sends them (`RaceSession._rpc_payout(team, lines)`); every peer adds to its own profile the lines of the team it
sat in, guests included (a modified client can cheat its own single-player wallet; say so in the code and do not build anti-cheat for it).
Numbers to start from and tune by play (TEST_PLAN):

| Source | Lira |
|---|---|
| Stage: 1st / 2nd / 3rd / finished | 1500 / 1000 / 700 / 300; a medal adds 200 / 400 / 800 |
| Weekend standings: 1st / 2nd / 3rd | 5000 / 3000 / 2000 |
| Errand | 300-2500 by its length, x1 / x1.5 / x2 by stars |
| Tow, recovery | -250 |
| Repairs, per damage point | -12 (a crash of 40 points: about 500) |
| Windshield / side window / door mirror | -900 / -250 / -150 |
| Policy for a season: kasko / full | -2500 / -6000 |

A weekend done well pays 8-15 thousand; Q9's full car and Q10's best cosmetics take about 110 thousand, so three seasons. The results show
the ledger lines in a column (A7 styles it).

**Q3. Free roam: folded into phase OW (item 8).** OW owns the roam mode, its session without a stage graph, recovery in roam and the
service park's place. This phase adds what roam is for: the errands' boards at the service park and the tea garden, the radio (Q12), the
givers on the map once met, and nothing that turns the calm drive into a timer it did not ask for.

**Q4. Errands: the core, solo (3 parts).** Data first:
- `MissionCatalog` (`scripts/missions/mission_catalog.gd`, data like `GagDirector.CATALOGUE`, one entry per errand): id, title key, giver
  (kind, place), scope (`crew` or `room`), seats needed (both, or either with D's bot in the other), the steps, the fail conditions, the
  timer, rewards per star, the secret star's condition, what it waits for (`&"w_village"`, `&"x_flock"`), the stages it can run on.
- `MissionPlace`: a kind (`giver`, `deliver`, `fetch`, `zone`, `stunt`, `meet`), resolved by `MissionPlaces.resolve(graph, plan, kind,
  seed)` to a world position, a road (`RouteGraph.STAGE`, a bypass's id or a spur's id), a metre along it and a side, from what the stage has:
  W's villages and farms (`RallyDressing.plan`'s items), a spur's landing (`LANDING_RADIUS` 9 m, the dead end of a wrong way is where lost
  things are), a gag slot, the signature place, a crowd's spot, the start and finish areas. Law 8: the same on every peer, from the stage's
  seed and the mission's id.
- `MissionRules` (pure, tested, one state machine): steps of a few kinds, each a small class: `Reach` (be within R of a place below S km/h),
  `Carry` (a `Cargo` on board from A to B), `Collect` (N things along the road), `Follow` (stay 15-60 m behind a vehicle), `Lead` (a vehicle
  follows you; it must not lose you by more than 80 m), `Chase` (be within 12 m of a vehicle for 3 s, or box it at a dead end), `Herd` (a
  flock off the road with the horn), `Stunt` (air over a height at a place, a slide past a camera under a distance, a jump's length), `Break`
  (exactly these breakables and none of those), `Avoid` (a zone where a speed, a brake or a horn costs), `Hold` (a seat's job held for a
  time: the phone, the cake), `Race` (to a place before a rival). Fails: the timer, the cargo, patience out, the vehicle lost, a wrong break,
  three fines in a zone. Everything is fed per physics tick from what the host sees (`RallyCar.seen_velocity`, `impact`, the tracker, X's
  break reports, the cabin's state).
- `Cargo` (`CargoRules`, pure): `integrity` for things (a cake's tiers, jars, melons, tea), `patience` for the living (law 1), `heat` for tea,
  `dust` for a suit; per tick from the car's g (a corner over 0.6 g, braking, a landing's vertical speed), impacts by strength, airtime, the
  windows open, the surface; held in the navigator's hands it takes half (both hands: the map is folded, pillar 2); set on the floor it takes
  all of it and the map stays open. Its look: a cake built in code (stacked cylinders, a frosting shader, a tier that slides off and smears
  the dash when it falls under its threshold), a jar crate, a cage under a cloth (heard: Batch H's clucking; never
  draw one that is hurt), the goat's horns showing over the rear seats' place (phase N's goat if it found one, else horns in code, see
  "Downloads" below).
- `MissionRunner` (host, a child of `RaceSession`): holds each team's active mission, ticks `MissionRules`, sends state changes
  (`_rpc_mission(team, id, step, timer, cargo, result)`, reliable, only on change; the cargo's value 5 times a second, unreliable), resets on
  retry. Offline it runs locally, as `Cabin._broadcast` does.
- Givers: a person at the giver's place (N's body and `Conversation` when built, the crowd's standing bake with a waving pose and a small
  board with the errand's pictogram until then); the navigator clicks the giver through the window while the car stands within 8 m (law 6),
  the giver's two or three subtitled lines play, the crew accepts or not. In the career and the service park the errands of the weekend are
  also pinned on a board (a menu list, A7 styles it).
- The navigator's map gets the pencil marks (`MapCanvas.set_marks(marks)`: a circled cross for the place, a dashed circle for a search area,
  a note in the margin in the map's hand-written style); the driver's HUD a mission line: the title, the timer, the cargo's state as a bar
  with an icon (the zone phase F reserved in `HudLayout`). Never a distance or an arrow (rule 2).
- First three errands, solo, on Black Pine and Red Canyon: the wedding cake (Carry), the photographer's jump (Stunt), the mayor's goat
  (Reach a dead end, Carry a living cargo home).
- Fail and retry: the fail line (Q12's writing) on both seats, then "Tekrar dene / Retry" (the car put back at the mission's start with
  `RallyCar.reset_to` through the recovery RPC, the cargo and the vehicles reset; no scene reload, under a second) or "Bırak / Abandon".
Tests: every step kind, every fail, the catalogue lint (law 1 above; every key in strings.csv; every place resolvable on every stage it
names), cargo numbers (`gut.p` the cake's integrity after a clean bot run and after a crash: the bot's clean run must keep three tiers of
five).

**Q5. Errands for the crew and the room (2 parts).** Co-op over the network: a crew's errand is the crew's (both seats see the same mission
line, the cargo in the cabin on every peer, the navigator's hands holding it on every peer through `CrewRules`), a room errand (`scope`
`room`: the lost trophy, the old champion) is every crew's at once with one result row each. The mission log (pause menu tab "Görevler /
Errands", and the career hub): every errand known on this profile, by stage and giver, locked / available / active / done with stars, the
best time, the secret star shown as "?" until found; pin one to draw its giver on the map. Solo with D's bot: as the driver, the bot
navigator holds the cargo and calls the way to the place; as the navigator, the bot drives where the player's gestures point. nettest:
`NET mission team N id step` lines agree on every peer; a client's cargo integrity matches the host's within 0.02.

**Q6. Vehicles with a job (2 parts).** The vans, pickups and tractors errands need are N's `TrafficCar` (host-simulated,
AnimatableBody3D, 10 Hz, its look from P2's `VehicleKind`): one owner of a car that drives itself; no second kind of driven car. `MissionVehicle` gives a path (any road, either way), a speed profile (the funeral's walking pace, the vet's
"brakes mostly there", the van that flees and takes wrong ways on purpose), and what it does when a car is near (the van speeds up, the vet
waits). At most one mission vehicle a crew, at most two in a room with three crews (budget below). Chase and escort: the stolen service
van, the vet's pickup, the tractor's funeral, the old champion.

**Q7. The other errands (3 parts).** The rest of the thirty below, in the order of what they need (what exists first). Each gets its giver's
lines, its fail lines, its three stars and its secret star, its bot run (a headless bot finishes each errand that a bot can drive with
`--mission=<id> --autodrive` on the stages it names, `gut.p` the time) and a shot from the seat.

**Q8. The career (3 parts).** `CareerRules` (pure): seasons of three weekends, one a biome:
- **Season 1, "Köy Kupası / Village Cup"** (Explore, day and golden hour, clear weather), **Season 2, "Bölge Şampiyonası / Regional
  Championship"** (Rally, every time of day, the stage's weathers), **Season 3, "Altın Direksiyon / Golden Wheel"** (Redline, nights,
  fog and snow, the old champion), then **"Sezon N"** endless: the rivals a little faster each season, the weekends drawn from all six stages.
- **Where a weekend happens**: the forest weekends in OW's region (Çamlık Vadisi, its two stages run from their start controls, the
  service park on the village square); the desert and mountain weekends in OW's single-stage roam of each stage until OW2 gives them their
  regions (the Friday then roams one stage's world at a time, the liaison is the road from its finish area back to its start area). The
  service park is OW's place; this phase replaces OW's free repair with the paid, timed service below and takes X's dents away with the
  zones it repairs.
- **A weekend**: Friday, roam on the weekend's two stages with the errands of the weekend (four to six offered, two of them new); Saturday,
  the two stages (day, then golden hour), service between; Sunday, the first stage again at dusk and the second at night as the "power stage"
  (bonus points 5-4-3-2-1). Between stages the **service park**: a screen over the car in its state (dirt, damage, the cracked glass), the
  damage carried from the stage (`VehicleDamage.to_array`), repairs bought by the zone with money and with *service minutes* (30 a service:
  a bonnet takes 12, a windshield 8, a bumper 6: a real rally's choice, what to fix in the time), the tyre compound and the suspension's soft
  or hard for the next stage, the radio (Q12), the weekend's table. The road from service to the next start is a short **liaison** in roam
  with a target time: late at the time control costs 10 s a minute, which is how a real rally punishes it; an errand on the liaison is the
  gamble.
- **Rivals**: ten crews (Q12's cast), each with a pace factor against the bot's measured time (0.90-1.10), a consistency, and a quirk ("goes
  off at jumps one run in eight", "never crashes, never hurries"). `RivalModel.time(stage, weather, time_of_day, difficulty, rng)` from
  `data/career/bot_times.json`, the headless bot's own time per stage, weather and time of day, measured by a tool
  (`tools/bot_times.ps1`, the way DEVELOPMENT_PLAN's L table was measured; rerun when a stage changes, a test fails when a stage has no
  entry). In a solo weekend two of them drive physically beside the player (D's bots, head to head); the rest are simulated. In a room the
  other crews are players.
- **The table**: 25-18-15-12-10-8-6-4-2-1 for the weekend's overall time, plus the power stage's bonus; the standings after each weekend
  with the radio's comment; a season won unlocks the next and a trophy for the shelf (the career hub shows trophies, the car, the rivals).
- **Retiring**: a car that cannot go on (critical damage the crew will not wait out, a quit) retires from the day and restarts the next
  with a 5-minute penalty, as real rallies do; no weekend is lost to one crash.
- **Co-op career**: the host's profile holds the career (its weekend, its table, its rivals); every player who sits in it earns into their
  own wallet (Q2), stars of errands they finished and the trophies as guests ("misafir"). A room setting says whether the weekend is the
  host's career or a plain race.
A flow test `--flow-career` (`tools\flowtest.ps1 -Career`): a host and one client start a weekend, two bots drive Saturday's two stages, the
service park opens and closes, the table is shown, the profiles have the payout (scratch paths), everyone quits.

**Q9. Car builds (2 parts).** `CarBuild` (engine, gearbox, suspension, tyres, lights, each 0-3; tyres a set of compounds owned) and
`CarBuildRules.config_for(build)` (pure, tested):

| Part | Level 1 / 2 / 3 | Price (lira) |
|---|---|---|
| Engine | `engine_force` x1.06 / 1.12 / 1.18, `top_speed` +2 / +4 / +6 m/s | 4000 / 9000 / 18000 |
| Gearbox (close ratios) | `low_speed_force_scale` 1.10 / 1.18 / 1.25, shifts 30 / 50 / 70 % shorter (sound and dash) | 3000 / 7000 / 14000 |
| Suspension | damping +8 / 16 / 24 %, `anti_roll_stiffness` +10 / 20 / 30 %, bump stop later; unlocks the soft/hard choice (springs -/+15 %) | 3500 / 8000 / 15000 |
| Tyres | compounds: gravel (stock), soft gravel (+6 % gravel and dirt, -8 % tarmac), studs (+25 % snow, -10 % gravel), wet (+10 % mud and wet) | 1500 a compound |
| Lights | the pod's beams x1.2 / x1.4 brighter and longer (`CarLightPod.beam_pattern`'s range), level 3 a roof bar in code | 2500 / 6000 / 11000 |

`test_handling_benchmarks.gd` gains a column per level (0-100, 100-0, turn-in, the handbrake hairpin, landing: `gut.p` each), stock's rows
unchanged; the headless bot's time on Black Pine with a full build (`gut.p` it: an upgraded car must be faster but not leave the medal
table meaningless: full build at most 8 % quicker than stock). The room rule `cars`: `equal` (everyone stock: the default for a plain race
and always for the daily) or `own` (each driver's build, from the roster). Records split by class (trap above). The garage screen: the car
on a stand (A7's 3D menu backdrop when built), each part with what it changes in words ("0-100: 7.9 s → 7.4 s", from the benchmark rule).

**Q10. Cosmetics (2 parts).** What the crew wears and the car says, bought or earned, shown on every peer (the roster's `cosmetics`,
validated like the build), never hiding the team colour that tells crews apart on the map and the HUD:
- **Liveries**: patterns over the paint in `car_body.gdshader` (stripes, a fade, chequers, a "rust-coloured" patina, mud-coloured
  "camouflage" that is no army's), the team colour always the base; fictional local sponsors' panels drawn by `CarLivery` like the crew's
  names ("Hüsnü Usta Oto Döşeme", "Kaya Lokum", "Toz FM": no real brand, no maker's logo).
- **Helmets**: a pattern in `crew_helmet.gdshader` (the stripe's shape, a second colour, chequers on the crown); the flag of Turkey on the
  flanks stays as it is, in its border, nothing over it.
- **Suits**: the stripe's colour and the panels' shade (`crew_suit.gdshader`); the team colour stays the suit's main colour.
- **Horns**: the stock horn, a two-tone, a gas horn (the approved `gas_horn_*`), a bicycle bell, a rubber duck's squeak, the goat's bleat
  (after its errand), a truck's air horn; no melody that has an owner, no tune tied to a faith, a team or a party.
- **Dash toys**: a nazar bead hanging from the interior mirror (a pendulum on the car's sway, `CrewSway`'s numbers; a test with
  `test_seat_view.gd`'s rays keeps it out of the mirror's glass and the road), the garden gnome (Poly Haven, CC0), the rubber duck (CC0), the
  concrete cat (CC0) as a dashboard cat, a nodding dog made in code, the wedding cake's top tier under a dome (after its errand), tin cans on
  a string that rattle behind the car (after the wedding errand: they bounce on the road, sound and all, on every peer).
Shop and wardrobe in the career hub; unlocks by errands, stars, collectibles and achievements as well as by money (each cosmetic says how).
Budget: a dash toy is one draw call; tin cans one MultiMesh.

**Q11. Collectibles, achievements, the daily rally (2 parts).**
- **Collectibles** (`CollectiblePlan`, pure, from the stage's seed alone, law 8; the same at every graphics level, tested): per stage ten
  garden gnomes, three nazar beads (made in code: concentric dark blue, white, light blue, black glass, `shaders/nazar_bead.gdshader`, one
  draw call per stage) and two old rally plates from 1987 (boards with a line of the region's rally history, Q12 writes them: twelve plates
  tell the old champion's story before Season 3 meets him). Hidden where a crew must choose to go: at the dead end of a wrong way, on a
  bypass, behind a market stall, on a bale stack, in the barn, at the signature place, beyond a ford. Collected by driving through the spot
  below 40 km/h in roam and in a race alike (in a race it costs time: the crew's choice); the item pops into the air and onto the dash
  shelf; a counter on the navigator's HUD. On the map only after it is found (a small pictogram), never before.
- **Achievements** (`Achievements`, about 40, data with ids ready for a store's API later, no API now): e.g. "Keçi Fısıldayan / Goat
  Whisperer" (the goat home with full patience), "Beş Kat / Five Tiers" (the cake whole), "Ters Yolun Ustası / Master of the Wrong Way" (every
  dead end of a stage in one roam), "Sigortanın Kâbusu / The Insurer's Nightmare" (a 20 000 lira bill), "Sessiz Navigatör / Silent
  Navigator" (a stage won with gestures alone), "Kör Uçuş / Blind Flight" (the painted-glass errand with three stars), "Bahçe Cücesi
  Koleksiyoncusu / Gnome Collector" (all sixty), "Hiç Kimseye Dokunmadan / Without Touching Anyone" (a crowd dived for you ten times on a
  weekend and nobody was ever near: law 1 made a joke of itself). A toast (A7) and a page in the hub.
- **The daily Surprise Rally**: the date (UTC) seeds `RaceSettings.surprise()`'s roll, X's gag draw and one modifier from a list (the
  painted glass, mother calls, no brakes, chickens on board); stock cars; the best time of the day kept locally with a streak (a forgiven
  missed day a week, rule 6). No server, so no world leaderboard: a share line instead, "RADDY · 17.11.2026 · Kara Çam · 2:41.3 · #7KQ2"
  (the last part a checksum of the date, the stage and the time so friends spot a typo; it is not secure and says nothing about it), copied
  with one key, and D's share card with the date on it.

**Q12. The voice of the game (1-2 parts).** The writing guide (below) goes into the one guide N12 creates (`data/life/WRITING.md`); this
phase adds the voices of the rally: the **loudspeaker** at the start, the finish and the crowd's places (subtitles to the seats within its
reach over a crackle, never invented words), the **radio** (Radyo Toz FM, in the service park and on the car's radio when the engine runs,
its readout showing the station: news written from what this profile's crews did, `RadioDesk` picks lines by the feats X counts and the
errands done, never the same line twice in a weekend), the **insurer's letters** (one with each bill: a modal paper in the service park),
the **results** (one line under the table chosen by what happened: a clean run, a car in pieces, a goat still on board), the **givers'** and
**fail** lines, the rivals' one-liners on the table. About 400 lines in both languages to start; the owner reads the first fifty; a review
agent reads every line against the guide before it is merged. `test_writing_rules.gd`: both languages present, lengths (a subtitle at most
two lines of 42 characters, a bark 60, at most 17 characters a second to read), and a banned-words list (anything holy, any people or
region by name in a joke, the army and the police in a joke, real brands, real people, swearing beyond "Hay aksi" / "Oh, come on").

**Q13. The opening (2 parts).** An in-engine intro (`scenes/intro/intro.tscn`, `IntroDirector`, the timeline as data in
`data/intro/intro.json`: shots, cameras, car placements, events, subtitle keys, music cues), about 60 s, played once at first launch
(`Profile.flags.intro_seen`, per PC: the first profile's flag) and from the menu ("Giriş Filmi / Intro"). Skippable: Esc at once, any other
key or button held 0.8 s (a ring fills; "Geçmek için basılı tut / Hold to skip"). Never in a flow test, headless, `--skip-intro` or with
`--autodrive`. Built so it cannot go wrong: **every shot places the car itself** (`RallyCar.reset_to` at a metre and a speed, the bot or a
recorded steer driving it for that shot only) behind a cut, so no shot depends on the physics of the last; the stage is built while shot 1
plays on black (the audio thread keeps the rooster and the loudspeaker going while the main thread builds; measure the build and keep shot
1 longer than it, at most 8 s). One version, built last in this phase, when X, W and N have made everything the montage shows (the
market stall, the flock, the washing line, the barn, the village, the crowd's dive). **The script below is approved as written** (the lead,
2026-11-17: no record of an agreed opening was found, and the owner asked the lead to decide everything; the owner may change it later,
which the timeline's data allows without code). Movie Maker renders it for the evidence and for the itch.io page's trailer
(A10's capture tool).

The script (approved; times are the cut's, golden hour on Black Pine, clear):

| Time | What the camera sees | Subtitle (TR / EN) | Sound and music |
|---|---|---|---|
| 0:00-0:06 | Black. | (Loudspeaker) "Köylülerin dikkatine. Yarın köyümüzden ralli geçecektir." / "Attention, villagers. Tomorrow, a rally will pass through our village." | A rooster far off; the loudspeaker's crackle and hum. |
| 0:06-0:14 | Dawn over the forest; a slow crane down past the start arch's flag of Turkey moving in the wind to a goat tied to a fence post by the road, chewing. | "Keçilerinizi bağlayınız. Çamaşırlarınızı toplayınız." / "Tie up your goats. Take in your washing." Then: "Pastaları... pastaları ortada bırakmayınız." / "And cakes... do not leave cakes lying around." | Birds; the loudspeaker. |
| 0:14-0:24 | Through the windshield from the bonnet: the crew in the cabin, helmets on; the navigator opens the map, turns it round, turns it back. The windshield is filthy. | Navigator: "Sana bir şey söylemem lazım." / "There's something I need to tell you." Driver: "Şimdi mi?" / "Now?" Navigator: "Ben harita okumayı bilmiyorum." / "I can't read a map." Driver: "Ben de camdan bir şey görmüyorum. Hadi bakalım." / "And I can't see through this glass. Off we go, then." | Engine idling; the map's rustle; a seat belt's click. |
| 0:24-0:30 | The start: the marshal, the lights, the rally plate close up, the launch; the dust cloud swallows the camera. | (Loudspeaker) "Ve start! Bir numaralı araç... bir numaralı araç ters yöne gidiyor." / "And they're away! Car number one is... car number one is going the wrong way." | Music in on the launch (cue A). |
| 0:30-0:44 | Montage, a cut on each beat, about 2 s each: the jump and a crowd diving onto the bales, fists and flags up after; a market stall bursting into fruit over the windshield, the wipers smearing it; a flock parting round the car at the horn; a sheet off a washing line over the glass; the map leaving through the window; a tractor pulling out. | (A phone, in italics) "Sigorta şirketi, iyi günler... Pazar tezgâhı mı?... Poliçenizde 'meyve' yok." / "Insurance, good morning... A market stall?... Your policy doesn't cover 'fruit'." | Music; each hit's own sound over it. |
| 0:44-0:52 | Over a crest, the car in the air toward the camera, slowing to a stop in mid-air; the RADDY wordmark lands. | "Biri kör sürer, biri haritayı tutar. Gerisi sigortanın sorunu." / "One drives blind, one holds the map. The rest is the insurer's problem." | Music cuts to silence and wind on the freeze (cue B). |
| 0:52-0:60 | Time runs again: the landing, the car into the end bales, the bonnet up, steam; the goat from 0:06 trots past the car with a page of the map in its mouth. | (Loudspeaker) "...keçileri bağlayın demiştik." / "...we did say: tie up your goats." Then the card: "Başlamak için bir tuşa bas / Press any key". | A comic sting (cue C), the goat's bleat. |

Music: the approved `raw_assets/audio/spring/TITLE_BOUT.ogg` (CC BY, "Spring / Spring Enterprises", the credits and `ASSET_LICENSES.md`
row) if it fits the cut, else a cue made the way the project makes its other sounds; nothing else downloaded. The goat: phase N's goat (a
static model with a gait in the shader, if N found one that holds up); if there is none, the shot keeps the goat out of the frame and only
its bleat (Batch H) and the moving fence rope are seen (the joke survives).

**Q14. Tuning, the evidence, the documents (1 part).** The economy's pace by a played Season 1 (the owner's and a friend's), the errands'
timers by the bot and by hand, the rivals' pace factors so a careful crew wins Season 1 and Season 3 needs gold times; DEVELOPMENT_PLAN's
table of every errand's bot time and stars, the payout of a weekend, the frame cost.

## The thirty errands (one line each, in the game's tone; id, title, what it asks, its kind)

1. `wedding_cake`, **Düğün Pastası / The Wedding Cake**: five tiers to the next village before the stage closes the road; the navigator holds
   it, so the map is folded, and every landing costs a tier. Carry.
2. `mayors_goat`, **Muhtarın Keçisi / The Headman's Goat**: it climbed to the quarry at the end of a dead-end track and will only come down in
   your car; it eats a pace note off the map every minute it is bored. Reach a wrong way's end, Carry (patience).
3. `chicken_cage`, **Kümes Kaçakçılığı / Poultry Smuggling**: twelve chickens under a cloth through the village where the organisers check speeds (N10); every hard brake
   sets them shouting, and three shouts within the official's hearing is a penalty (N's `fined`). Carry, Avoid.
4. `map_dog`, **Köpek Haritayı Aldı / The Dog Has Your Map**: the map flew out of the window and the farmer's dog thinks it is his now; honk
   from the yard's gate until he drops it, without one wheel on the rose bed. Reach, Hold (horn); the dog is never touched.
5. `vet_calving`, **Doğum Var / A Calf Is Coming**: lead the vet's pickup to a cow in labour on the far farm; she cannot read your map and her
   brakes are, in her words, mostly there. Lead.
6. `stolen_van`, **Servis Aracı Kaçırıldı / Your Service Van Is Gone**: the rival crew's mechanic took your van "by mistake" with your spare
   tyres; catch it before it reaches the main road, it knows the wrong ways better than you. Chase.
7. `tractor_funeral`, **Traktörün Cenazesi / The Tractor's Funeral**: the village is saying goodbye to its oldest tractor after forty-seven
   years of service, and the procession is on the only road; 400 m at walking pace, no horn, no revs, until the farmer waves you by. Follow,
   Avoid.
8. `cover_jump`, **Kapak Fotoğrafı / The Front Page**: the local paper's photographer has one frame left and wants a car higher than last
   year's (1.2 m) over his crest. Stunt.
9. `insurance_fence`, **Hüsnü'nün Çiti / Hüsnü's Fence**: the fence is rotten and the policy pays for "damage by rally cars"; break all twelve
   panels and not one of his apple crates. Break.
10. `pickle_jars`, **Turşu Seferi / The Pickle Run**: forty jars of a grandmother's pickles to the finish's tea garden; every broken jar fills
   the cabin, and the smell makes a faint come sooner (the Cabin's exposure). Carry.
11. `tv_slide`, **Canlı Yayın / Live on Air**: the regional TV crew goes live in three minutes with nothing to show; slide past their camera
   sideways within five metres. Stunt, timer.
12. `lost_marshal`, **Kayıp Hakem / The Lost Marshal**: a marshal took the wrong track with the stage's only stopwatch; he is at one of three
   dead ends, and only the map says which tracks are dead ends. Reach (search).
13. `beehive_home`, **Arıları Eve Götür / Take the Bees Home**: the beekeeper's hive goes back to his garden with the windows shut all the way;
   open one and they leave, and so does your navigator's composure. Carry (patience), the windows.
14. `grooms_suit`, **Damadın Takımı / The Groom's Suit**: the groom's suit is on a washing line two villages over; get it to the wedding before
   the photographs without a grain of dust on it, on a gravel road, with the windows shut. Carry (dust).
15. `melons`, **Karpuz Seferi / The Melon Run**: ten watermelons in the boot, three jumps on the way; the seller is paid per melon that arrives
   round. Carry (count).
16. `wrong_way_bet`, **Ters Yol İddiası / The Wrong-Way Bet**: the tea garden bets you will take a wrong way; take every wrong way on the stage
   on purpose and be back inside the time. Reach (all spurs), timer.
17. `generator_fuel`, **Jeneratör Bitti / The Generator Ran Dry**: the service park is dark and the night stage starts in six minutes; a
   jerrycan from the farm, back with the dome lamp off so the driver sees. Carry, timer, night.
18. `loudspeaker_ford`, **Hoparlör Suya Düştü / The Loudspeaker Fell In**: the commentator's loudspeaker blew off its pole into the ford;
   fish it out before he starts announcing through a funnel. Reach (water), Carry.
19. `sheep_pen`, **Koyun Sayımı / Counting Sheep**: the shepherd fell asleep counting; move his flock off the road and into the pen with the
   horn alone, not one sheep left on the road. Herd.
20. `tea_round`, **Çay Servisi / The Tea Round**: twelve glasses of tea on a tray to the marshals at the split; cold tea is sent back and
   spilled tea is never forgotten. Carry (heat and integrity).
21. `gnome_heist`, **Cüce Operasyonu / The Gnome Job**: a collector pays for the mountain village's twelve garden gnomes; the next day the
   village pays more to have them back. Collect, then Carry back (a chain: both pay).
22. `painted_glass`, **Gözü Kapalı / Blindfolded**: the scrutineer bets your driver cannot do the stage's first kilometre with the windshield
   painted over; the navigator's voice is all there is. A modifier: the glass at full dirt, the wipers smear only.
23. `baker_wakeup`, **Fırıncı Uyuyakaldı / The Baker Overslept**: honk under the baker's window on the village street before dawn, not a
   minute late, or the crowd at the start has no bread. Reach, Hold (horn), timer, dusk.
24. `exam_papers`, **Sınav Kâğıtları / The Exam Papers**: a teacher's exam papers blew all over the stage when her car met a bale; collect
   twenty sheets along the road before the first car starts, and the wind of your own car blows them on. Collect.
25. `bale_tower`, **Saman Kulesi / The Bale Tower**: the farmer wants his bale tower knocked down "by accident" so the insurance pays; more than
   60 km/h, from the road side, and nothing else touched. Break, Stunt.
26. `old_champion`, **Eski Şampiyon / The Old Champion**: the 1987 champion runs the stage once at dawn in his old livery; beat him to the
   finish on the stage's own road without the pace notes. Race (Season 3, after the twelve plates).
27. `seed_crisis`, **Çekirdek Krizi / The Sunflower Seed Crisis**: the crowd at the jump ran out of sunflower seeds and is booing every car;
   three sacks from the village shop before the first car, and they cheer you louder all weekend. Carry, timer.
28. `mother_calls`, **Annem Arıyor / Mum's Calling**: the navigator's mother calls every ninety seconds; answer with one hand and keep her
   talking, or she phones the organisers; the map in the other hand. Hold (one hand) through a stage.
29. `no_brakes`, **Fren Biraz Yorgun / The Brakes Are a Bit Tired**: the mechanic says the brakes are fine, mostly; finish a stage with the
   handbrake, the gears and the hedges. A modifier: the pedal does a fifth of its work.
30. `lost_trophy`, **Kupa Nerede? / Where's the Trophy?**: the championship trophy fell off the organisers' pickup somewhere on the last stage;
   every crew in the room searches, and the crew that brings it to the podium lifts it first. Collect (room).

Continuity: the cast recurs (the headman, his goat, the vet, the rival crew's mechanic, the photographer, the old champion); errands unlock
errands (the cake leads to the groom's suit, the goat to the dog, the twelve plates to the old champion); the radio talks about what the
crew did yesterday; the goat of the intro is the goat of errand 2, and it is there at the end of Season 3.

## Writing guide (for N12's `data/life/WRITING.md`: one guide for the whole game)

**The tone.** Dry and deadpan. The countryside takes the rally completely seriously while everything around it goes wrong; the joke is on
the crews, the organisers, the insurer, the paperwork, the machines and the situation, never on the villagers for being villagers. Dark
means death only of objects (the tractor's funeral, the bonnet's last flight, the cake's lost tiers), bills, bad luck and the indifference of
goats. The straight man is always the rally's official (the speed control, the scrutineer, the marshal): dignified, unbothered, and right.

**Never**: religion or anything holy (no place of worship and no religious sound in the world at all, Direction 3: the headman's own
loudspeaker on the coffee house roof; no oath that names God; no prayer, no religious holiday); a people, a region, an accent or a dialect as the joke (no "Karadeniz" jokes); a real person, a real
brand, a real team, a party or politics, the economy or inflation; the army, the police or the gendarmerie at all (no state institution is a
character in the game: the officials are the rally's own, Direction 3); bodies, blood, illness, disability (the driver's blindness is the windshield's, never a person's;
never "kör" as an insult); alcohol, drugs, sex; children doing anything but being delighted; animals in pain (they win every time).
Every flag is the flag of Turkey and nothing in the writing treats it lightly.

**The craft.** Turkish is written first and natively; English is rewritten as its own joke, not translated. Specific beats general ("forty
jars", "forty-seven years"); the rule of three with the turn on the third; the payoff later (a line set up in the intro, paid off in Season
3); the joke ends the line, no explanation after it. A subtitle is at most two lines of 42 characters and stays 17 characters a second or
slower; a bark 60 characters; the driver's lines fit a glance. Every line has a speaker and a situation in the strings' key
(`LINE_RADIO_FEAT_MARKET_1`), so a reviewer reads it where it plays.

**The cast** (fictional, every name checked against real public figures before it ships): **Spiker Rıza / Rıza the announcer** (the
loudspeaker: over-dramatic, gets names wrong, reads local sponsors); **Muhtar Fikret / Fikret, the headman** (announcements, his goat);
**Selda, Radyo Toz FM / Selda on Dust FM** (the radio between stages); **Nevzat Bey, sigortacı / Mr Nevzat, the insurer** (letters, the
phone); **Veteriner Gül Hanım / Gül the vet**; **Teknik Kontrolör Bülent / Bülent the scrutineer**; the navigator's mother (a voice on the
phone, gender-neutral "yavrum"); the rivals: **Kuzenler** (two cousins both called Ercan), **Emekli Öğretmenler** (Nevin Hanım and Sabri Bey,
never late, never fast), **Gümüş Tilki** (the sponsored hotshot of "Kaya Lokum Racing"), **Muhtarın Oğlu** (in his father's car),
**Fırıncılar** (the baker brothers, always late to the time control), **Rakip Servis** (whose mechanic took your van), **Veterinerler** (Gül
Hanım and her assistant, who may leave a stage for a calving), **Kayınpeder ve Damat** (a groom and his father-in-law), **Hız Tutkunları Derneği** (a club with a banner),
**Hayalet** (the old champion, Season 3).

**Lines to set the voice** (Turkish / English):
- Loudspeaker: "Sayın seyirciler, bir numaralı araç geliyor... Hayır, traktörmüş." / "Ladies and gentlemen, here comes car number one... No,
  that's a tractor."
- Loudspeaker: "Bu etap Hüsnü Usta Oto Döşeme'nin katkılarıyla... Koltuk kılıfında indirim var." / "This stage is brought to you by Master
  Hüsnü's Upholstery... Seat covers on special."
- Loudspeaker: "Lütfen yoldan çekiliniz. Bu bir rica değil, fizik kuralı." / "Please stay off the road. It's not a request, it's physics."
- Loudspeaker: "Kazasız bir etap için alkış!... Kimse mi? Peki." / "A round of applause for a clean stage!... Nobody? Fine."
- Radio: "Günaydın Toz FM! Hava açık, yollar kuru, sigortacılar tedirgin." / "Morning, Dust FM! Clear skies, dry roads, nervous insurers."
- Radio (a feat): "Dün bir ralli aracı pazarı tek seferde dolaştı. Karpuzlar hâlâ aranıyor." / "Yesterday a rally car did the whole market
  in one visit. The melons are still being looked for."
- Radio: "Kayıp ilanı: Muhtarımızın keçisi. Özellikleri: inatçı, harita yer." / "Lost: the headman's goat. Distinguishing features:
  stubborn, eats maps."
- Insurer: "Hasar dosyanız 'pazar tezgâhı, karpuz, 40 adet' olarak açılmıştır. Karpuzlar poliçe kapsamında değildir." / "Your claim reads
  'market stall, watermelons, 40'. Watermelons are not covered."
- Insurer: "Kaputun 'uçarak ayrıldığını' beyan etmişsiniz. Kaputlar uçmaz. Lütfen açıklayınız." / "You state the bonnet 'left by air'.
  Bonnets do not fly. Please explain."
- Insurer: "Prim artışınız ektedir. Ek, kaportanızdan daha sağlamdır." / "Your premium increase is attached. The attachment is in better
  shape than your bodywork."
- Giver, the cake: "Beş kat. Beşi de varacak. Dördü değil, beşi." / "Five tiers. All five arrive. Not four. Five."
- Giver, the goat: "Kendi çıktı, kendi inmez. Keçidir." / "Went up on its own. Won't come down on its own. It's a goat."
- Giver, the fence: "Çit çürük. Sigorta 'ralli aracı çarparsa öderiz' diyor. Ben bir şey demiyorum." / "The fence is rotten. The
  insurance pays if a rally car hits it. I'm not saying anything."
- Giver, the vet: "Kamyonetin freni... çoğunlukla var." / "The pickup's brakes are... mostly there."
- Giver, the funeral: "Kırk yedi yıl çalıştı. Korna çalarsan sana küserim." / "Forty-seven years of service. Honk and we're done, you and I."
- The mother: "Yavrum, yemek yedin mi? Neden rüzgâr sesi geliyor? Camı mı açtın?" / "Did you eat? Why can I hear wind? Is the window open?"
- Fail, the cake: "Pasta üç kat kaldı. Düğün iptal değil, ertelendi." / "Three tiers left. The wedding isn't off. It's postponed."
- Fail, the chickens: "Tavuklar hız kontrolcüsüne her şeyi anlattı." / "The chickens told speed control everything."
- Fail, the goat: "Keçi eve yürüyerek döndü. Sizden önce." / "The goat walked home. It got there first."
- Results: "Etabı bitirdiniz. Aracın yarısı da bitirdi." / "You finished the stage. So did half the car."
- Results: "Kazasız, belasız, keçisiz." / "No crashes. No trouble. No goat."
- Results: "Ortalama hız: iyi. Ortalama hasar: sigortacıya sorun." / "Average speed: good. Average damage: ask the insurer."
- Rival, the teachers: "Hızlı değiliz ama hiç geç kalmadık." / "We're not fast. We've just never been late."

## Budgets (dev laptop, RTX 5070 Laptop, 1080p, Medium stays over 60 fps with three crews)

| Thing | Budget |
|---|---|
| A mission vehicle | at most one a crew, two in a room of three crews; measured with `perf.ps1 --flip-mission-cars`, at most 1.0 ms Medium for two |
| Cargo in a cabin | at most 3 draw calls, no light, no shadow outside the local cabin (as the crew's rule) |
| Collectibles of a stage | gnomes one MultiMesh, beads one draw call, plates in the board's batch: 3 draw calls, nothing in the mirrors |
| Dash toys, tin cans | one draw call each; the cans one MultiMesh |
| Map marks | one re-render of the sheet per mission change (counted in a test) |
| `MissionRunner` | under 0.05 ms a tick on the host with three crews' missions (`--work-top`) |
| Save | under 5 ms a write, never in a stage |
| Intro | Medium over 60 fps at 1080p in every shot; the stage built behind shot 1 (at most 8 s) |
| Network | a mission's state under 1 kB/s a crew |

## Tests (pure first, GUT)

`test_profile` (OW's, extended: each new section's round trip and migration step), `test_economy` (every source, the
ledger, guests' payouts, bots earn nothing), `test_insurance_rules`, `test_mission_rules` (each step kind and fail), `test_cargo_rules`
(thresholds, held against on the floor, `gut.p` a clean bot run), `test_mission_catalog` (law 1's lint, keys, places on every stage named,
waits-for flags), `test_mission_places` (the same on two graphics levels and on every peer's seed), 
`test_mission_vehicle_paths` (a follower down every spur and back), `test_career_rules` (a season's weekends, points, the power stage,
retiring), `test_rival_model` (every stage has bot times; times by pace factor; seeded), `test_car_build_rules` (stock is the base resource;
each part's delta; validation), `test_handling_benchmarks` (a column per level; stock unchanged), `test_stage_records` (the two classes, no
time lost), `test_cosmetics` (team colour kept, validation, the nazar bead out of the mirror and the road by the seat-view rays),
`test_collectible_plan` (seeded, same at every level, never on a crest's blind side or in the road), `test_achievements`, `test_daily_rally`
(the date gives the same settings everywhere; the checksum), `test_writing_rules`, `test_intro_timeline` (45-75 s, every subtitle key in both
languages, reading speed, every shot places its car, skip and the flow-test guard), `test_scripts_compile` covers the new scripts.
Network: nettest lines for a crew errand, a room errand, a payout and a build in the roster; a flow test with `--flow-career`; a flow test
with a solo errand (`--mission=wedding_cake`).

## Evidence

Few contact sheets: the mission line on the driver's HUD and the pencil marks on the navigator's map by day and night; the cake on the
navigator's lap losing its tiers; the service park with a damaged car and the insurer's letter; the championship table after a weekend; the
garage with a part's numbers; three cosmetics on a car from outside and from the seat; a gnome and a bead where they hide; the daily's share
line and card; every screen in Turkish and English at 1280x720 and 1920x1080 (A7's audit). The intro rendered with Movie Maker (frames every
2 s on a sheet, and the clip for the owner). DEVELOPMENT_PLAN: every errand's bot time and stars, a weekend's payout, the frame costs.

## Downloads (approved on 2026-11-17)

The owner left the approvals to the lead. Quaternius's animated animals (`docs/phases/downloads.md` Batch I) and the farm sounds of Batch H
(a dog's bark, a goat's bleat, chickens, a rooster) are on the disk; phase N brings them into the game (N8). No free animated goat or
chicken was found: N gives a static model a gait in the shader where one holds up, or keeps the kind as sound only. This phase uses whatever
N brought (the intro, errand 2, a horn, the chickens); where there is no goat or chicken model, the fallback stands: the goat is heard and
its horns are code, the chickens stay under their cloth. Nothing else is downloaded.

## Out of scope

Walking (the on-foot brief: a giver talked to face to face waits for N's `Talkable`); entering buildings; a story campaign with cutscenes
beyond the intro; voice acting; an online leaderboard or cloud saves (a server is a running cost); any payment or loot box; a store's
achievements API (ids are ready); new stages (six exist; the career reuses them); hurting anything alive in any form.

## Done means

GAME_DESIGN (a "Progression" section: the career, the errands, the economy, the rules above), CLAUDE.md (Profile, Economy, the missions'
classes, the career, builds, cosmetics, collectibles, the daily, the intro and its flags), DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN (what only
people can judge: is the cake funny the third time, does Season 1 pay too much, does the intro make a friend want to play), the strings,
`ASSET_LICENSES.md` and the credits for every asset used; full GUT, nettest and the flow tests (plain, career, a solo errand) pass; commits
on main.
