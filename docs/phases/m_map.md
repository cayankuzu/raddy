# Phase M: the map a navigator can read, and wants to

The owner (2026-11-17): "Do you think the map suits the game? Think about it and improve it. Every road must be on the map; today only the main
road shows. Find and fix errors of this kind in the UI, the UX, the logic and the look." The bar is the game's: a premium game people clip and
share. Today's sheet (`scripts/map/map_canvas.gd`, `pace_notes.gd`, `paper_map.gd`; `reports/screenshots/a3_final/map_canvas.png`,
`reports/screenshots/a5_check/nav_day/map_open.png`) fails it in four ways:

- **It is not a map of the place.** The wrong ways are short red dashes under a crossed-out disc, not roads; nothing else of the world is on
  it (no spectator places, arches, boards, parked cars, log piles, rails, cliffs, forest edge, surfaces). A map is read by matching what you
  see outside to what is printed: there is nothing to match.
- **It does the navigator's job.** The crossed discs and "Kavşak: Sol 3, düz değil!" give every answer away, so the sheet is a list to read
  aloud. The fun of the seat (GAME_DESIGN pillar 1: the driver is blind, the navigator is the eyes) is finding the place on the sheet, seeing
  what comes and which branch, under pressure.
- **It cannot be read from the seat.** The whole stage on 1792 px shows at about half a screen pixel per canvas pixel: the calls are 8 px
  tall at 1080p. Nobody reads that at speed; zooming and dragging by hand while calling is no answer.
- **It looks like a debug drawing.** Flat pastel blobs, one fat line, plain type; no title, legend, scale or north (and a stage that runs
  north-south is turned sideways without saying so).

Read first: CLAUDE.md "Paper map and pace notes", "Stages" (wrong ways, `RallyDressing.plan`, `Sightline`), GAME_DESIGN §1-§4 and §8, the three
files above, `scripts/gameplay/cabin.gd` (the map's states), `scripts/vehicles/car_rally_kit.gd` (`trip_display()`), `scripts/core/race_settings.gd`
(difficulty), `data/locale/strings.csv`.

## The design (decided: build this, improve on it where the real thing shows a better way, and say what you changed)

1. **One truth.** Everything on the sheet is where it is in the world, to scale, and everything a crew can see from the road and tell apart is on
   the sheet. Nothing on it lies and nothing is hidden that a real map would print. What difficulty changes is how much is pre-digested, never
   the map's truth.
2. **Every road is a road.** The stage and every wrong way (`graph.spurs`) are drawn with the same road symbol (a cased line, its width from the
   road's real width, its fill by surface: gravel, tarmac, dirt, snow, in the legend). A dead end ends in the turning place it has
   (`LANDING_RADIUS`), a closed road in a barrier symbol; junction furniture (the log pile, barriers and tape) is drawn as what it is. No red
   dashes, no crossed discs.
3. **The route is marked the way a crew marks it**: a translucent highlighter stroke over the stage's road with small arrowheads in the
   direction of travel, gates across it (start, splits, finish, with their names), a tick with the kilometre at every km board the world has
   (`RallyDressing`'s km boards: what you pass outside is what you find on paper). On the hardest difficulty the highlighter is absent: the crew
   reads the route off the roads themselves (a branch that ends is no stage). Decide the three levels' contents in one pure, tested rule
   (`MapRules` or in `PaceNotes`): Explore = highlighter, every call, distances; the middle level = highlighter and calls; Redline = no
   highlighter, only the dangers. The live car marker (the owner's wish: the map is live) stays on every level.
4. **The land.** Thin brown contour lines with heavier index lines and a few height numbers (from `TerrainField`), forest as a green tint with
   a fine tree pattern where `Sightline.screens`/the dresser plants forest and plain paper where the land is open, water in blue (pools and
   crossings), cliff sides as hachures on the side of the drop, banks as ticks, guard rails as a thin line with posts. A grid with numbers on the
   margin, fold creases that catch the light.
5. **Landmarks, as symbols a legend explains**: spectator places (they are the best landmarks there are), the arches, the time control and the
   boards (`RallyDressing.plan` is the data: draw from it, so that whatever a later phase adds to the plan, houses, walls, sheds, a bridge,
   appears on the sheet without touching the map again: give `MapCanvas` a list of landmarks with a kind, a place and a turn, not calls to the
   dresser), parked cars, log piles, chevrons' corners. Hazards as pictograms on the road where they are: jump, crest, dip, water, caution,
   hairpin, a cliff's side. Surprises stay off the sheet (the falling tree, the rockfall).
6. **A road book, not a list.** The notes column becomes the right-hand page of a rally road book: ruled rows of number, distance from the
   start in kilometres (and the gap to the next row), a small diagram, the call in large type, a danger mark (!, !!, !!!). For a junction the
   diagram is a tulip, the real shape from the graph seen in the direction of travel (the road you come by enters from below, each branch at its
   real angle, the stage's branch thick with an arrowhead, the other thin with its end symbol): left and right are then read without turning the
   sheet, whichever way the map itself runs. For a corner, its arc with the severity; for a hazard, its pictogram. Calls stay real rally
   language in Turkish and English (check every one with a native ear: "Kavşak: Sol 3, düz değil!" becomes the tulip plus "Sol 3").
7. **Readable from the seat without hands.** At the hold's rest pose the sheet shows the part that matters, large: the map page follows the
   car (the marker in the lower third, the road ahead above it, at a zoom where a call's letters are at least 16 px tall at 1080p and 11 px at
   720p), the road book shows the next rows (the row being driven, then the next five) and moves on by itself; the wheel still zooms, a drag
   still pans, `map_reset` (Home) returns to following; over the road book the wheel scrolls it. On Redline nothing follows by itself: the
   navigator keeps the place (that is the level's game). A key to raise the sheet to the face for a close read (it then hides most of the
   windshield: eyes on the map or eyes on the road) if the rest pose cannot give the sizes above; `PaperMap.hold` and the hands follow.
8. **The trip meter works** (it is on the dash by the navigator's A pillar and blank: nothing that looks like it works may be dead):
   distance since the start and since the last reset, in the road book's units, lit at night, a key to zero it (rebindable, in the strings and
   the hint line), the navigator's hand reaching for it if `CrewRules.hands` makes that cheap. On every peer from what it sees the car do.
9. **A sheet worth a screenshot.** Paper with fibre and wear, printing that looks printed (inks multiplied into the paper, hairlines that stay
   crisp when zoomed: draw at the canvas size the zoom needs or as vectors, no blurry upscaling), the game's own fonts (`assets/fonts`: Saira for
   headings and numbers, Inter for text, JetBrains Mono for the grid), a title block (the event's name from the strings, the stage's name, its
   length, surfaces, the weather and time of day, the crew's number and names in capitals as on the car, a small flag of Turkey from
   `TurkishFlag`, 3:2), a legend, a scale bar, a north arrow that is right when the sheet is turned, the organiser's round stamp. Colour is never
   the only sign (shape too: colour-blind players). At night under the dome lamp it reads; without it only as far as the dials' glow honestly
   lets it.
10. **Cost.** The static sheet is rendered once (and again only when its content changes); the marker, the highlighter's progress and the road
    book's place are cheap layers. Measure it inside one process (`tools\perf.ps1` with a flip for the map if the probe has none yet) and say
    what an open map costs a frame on each level; no hitch when it opens.

Keep what works: the sheet as a 3D object in the hands, lit by the scene; `Cabin`'s map states (closed, open, gone, the replacement), the wind
that takes it, the gesture that folds it; the same sheet on every peer from the stage's seed.

## Parts
- **The map page**: points 1-5, 9 and 10, the difficulty rule of point 3, the landmark list of point 5.
- **The road book, the trip meter and the seat**: points 6-8, the following view, the calls' language, the hint line and the strings.
- **The audit**: go through every screen and state of the real game the way a new player meets them (main menu, create and join a room, the
  room with seats and settings, loading, the countdown, both seats' HUD, the map, the recovery prompt, pause, settings with every tab, results
  with medals, back to the room; Turkish and English; 1920x1080 and 1280x720; `tools\screenshot.ps1` with `--flow-test` and
  `tools\capture_window.ps1`) and list every error of logic (a label that is not true, a control that does nothing, a state that is not
  shown, a number in the wrong unit), of use (unreadable, overflowing, no feedback, a dead end in the menus, a key the hint line names
  wrongly) and of look (misaligned, clipped, inconsistent, placeholder). Fix at once what is a plain error (with a test where it is logic);
  write what needs design into `docs/phases/a7_ui.md` as a dated list under "Audit findings" for the UI phase. The audit also adds the thanks
  the owner asked for wherever the game lists its credits today (and into `a7_ui.md` for the credits screen and `a9_a10.md` for the store
  page if no such place exists yet): in Turkish "İlham için teşekkürler: “Left! Left! LEFT!”. Direksiyonda biri, haritada biri: bu fikrin
  tadını ondan aldık. RADDY bağımsız bir oyundur; o oyunla ve yapımcılarıyla bir bağı yoktur." and in English "Thanks for the inspiration:
  “Left! Left! LEFT!”. One at the wheel, one on the map: we owe the taste for it to that game. RADDY is an independent game, not affiliated
  with it or its makers." (no logo, no art of theirs, nothing but the name).

## Tests and evidence
Pure rules tested on behaviour: what each difficulty shows; a world point to the sheet and back; every spur's line lies on its world
polyline at its width; km ticks, icons and gates at their true distances and on their true sides; the scale bar's length; the north arrow on a
turned sheet; the tulip's angles and which branch is thick; the road book's distances against `RouteTracker`; the trip meter against the car's
real path in a physics test; nothing drawn over anything else (the free-spot rule holds for the new symbols); every string in Turkish and
English. Evidence, in few contact sheets: the whole sheet of all six stages (one image), the seat's view at rest on three stages by day, at
night with and without the dome lamp, at 1080p and 720p, each difficulty; a junction outside and the same junction on the sheet and in the
road book, side by side; before and after.

Done means: `docs/phases/m_map.md` in the repo (this brief), GAME_DESIGN §8 and the pillars' text in step with the decisions, CLAUDE.md's map
section rewritten, DEVELOPMENT_PLAN, CHANGELOG, TEST_PLAN (what only two people on voice can judge: is it fun to navigate by), full GUT,
nettest and a flow test pass, commits on main.
