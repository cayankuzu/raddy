# Changelog

## Unreleased (Phase A3: stages 2.0)
- **Flags:** every flag is the flag of Turkey, in its exact geometry and 3:2 proportions, waving on the
  crowd's poles, flying from the arches, printed on their banners and on the start's board.
- **Start and finish:** real rally gantries with steel truss towers, a printed banner and concrete blocks;
  the grid stands far enough back to see them. Splits have their own yellow boards.
- **Guard rails:** a corrugated, worn W-beam with real posts and bolts, ends turned into the ground, torn
  and bent where something went through.
- **Roads:** fine loose gravel with stones scattered on it and two packed wheel tracks, on every surface;
  lumpy mud with water standing in the tracks; packed snow without odd marks.
- **Ground and plants:** no more lawn in the forest: leaf litter in patches, hummocks, tufts of grass, ferns
  and new bushes, grass along the road's edge. The desert's bushes were black shapes and are real shrubs now.
- **Sky and light:** clouds in every weather, a warmer shade, soft leaves that let the light through.
- **Car glass:** really clear from the seats, no haze over a dark forest; it mirrors the sky from outside.
- **Paper map:** wrong ways are red dashes crossed out by their junction, the road stands out, the numbers no
  longer lie on top of each other, the sheet no longer runs into the pillar.

## 0.2.0 — test build (2026-10-19)
Direction change after the first look: a mix of "Left! Left! LEFT!" (asymmetric co-op, cabin
chaos) and "Half Grip" (driving feel) with a realistic-leaning look, fixed named stages instead of
generated road networks.

- **Stages:** six named point-to-point stages (two per biome) with crests, jumps, dips, water
  splashes, cliffs with steel rails, canyon walls and switchbacks; the land follows the road; you
  can leave the road but invisible walls 36 m out keep you on the stage. Start line, two splits,
  finish; places by distance. The branching networks, shortcuts and laps are gone.
- **Pace notes and map:** real rally calls ("Sol 3", "Saç tokası sağ", "Kör tepe!", "Atlama!",
  "Su geçişi!", "Uçurum solda!"); the paper map turns long stages sideways and marks the hazards.
- **Car:** a real rally hatchback model (CC BY) with cockpit, turning steering wheel, clear glass,
  team paint, brake/reverse lamps and weather headlights.
- **Forest:** firs, pines and birches (CC BY) beside the road, a thick edge band and a backdrop.
- **Sound:** engine from a real Toyota Corolla rally car recording on a five-speed sound gearbox,
  gravel crunch, squeal, water, wind, crashes, horn (H), rain and thunder, paper map, menu clicks.
- **HUD:** stage bar with every crew's car, split times with the gap to the fastest, rev counter,
  gear and speed. Mouse free look in the cockpit.
- **Glass:** mud, cracks and two wiper blades on the real windscreen.
- **Water splashes** slow the car, soak the glass and splash open-window seats.
- **Stage surprises:** a fir falls across the road in front of the first crew (squeeze past the
  trunk or push through the crown and lose the view to pine needles), boulders roll down canyon and
  mountain banks.
- **Damage you can see:** the bonnet pops, flaps up at speed until the driver is blind and then
  tears off; bumpers hang and fall off; the engine steams, then smokes. Crashes jolt the camera.
- **Records and medals:** best time per stage on this PC with the crew's names; bronze, silver and
  gold times shown in the room and on the results.
- **Performance:** scenery batched by mesh (forest draw calls 1429 → 608); graphics quality
  setting (Auto/Low/Medium/High; Auto picks Low on integrated graphics).
- **Fixes:** the grid sat behind the stage's start wall; jump landings counted as crashes (drivers
  now report body impacts to the host); the model's dark glass darkened the cockpit view; critical
  damage kept closing the recovery offer while the car crawled; terrain and walls near hairpins;
  gearbox limiter and clutch take-up; HUD/map texts in both languages.

## 0.1.0 — first playable (2026-10-12)
Driving prototype with ray-cast suspension and surfaces; host-authoritative rooms for six players
in three crews with room codes and UPnP; proximity voice chat; navigator's paper map with pace
notes; windows, windscreen, dirt, wipers, exposure and faints; cans thrown from the cabin; three
damage levels; joint R recovery; main menu, room, race, results, pause and settings (TR/EN);
automated unit, network and end-to-end flow tests.
