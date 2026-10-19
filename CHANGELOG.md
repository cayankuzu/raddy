# Changelog

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
- **Performance:** scenery batched by mesh (forest draw calls 1429 → 608); graphics quality
  setting (Auto/Low/Medium/High; Auto picks Low on integrated graphics).
- **Fixes:** the grid sat behind the stage's start wall; jump landings counted as crashes (drivers
  now report body impacts to the host); the model's dark glass darkened the cockpit view.

## 0.1.0 — first playable (2026-10-12)
Driving prototype with ray-cast suspension and surfaces; host-authoritative rooms for six players
in three crews with room codes and UPnP; proximity voice chat; navigator's paper map with pace
notes; windows, windscreen, dirt, wipers, exposure and faints; cans thrown from the cabin; three
damage levels; joint R recovery; main menu, room, race, results, pause and settings (TR/EN);
automated unit, network and end-to-end flow tests.
