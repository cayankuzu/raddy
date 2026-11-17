# Phase H: keyboard is the body, mouse is the eyes and hands

The owner (2026-11-17): "the game is played with keyboard and mouse, the two used together." Today the mouse only looks, throws (LMB) and
raises the gun (RMB); every cabin job is a key (Q/E windows, T wipers, M map, L dome lamp, F kick, 1-4 gestures). Direction 2's law 6
(`docs/GAME_DESIGN.md`, "Direction 2") decides what changes: what the view ray meets is used with a click and worked with a hold or a drag,
mouse look pauses while a hand holds something, every job keeps its key, a gamepad keeps working. The driver's jobs at speed stay on keys:
nobody looks down at 100 km/h. The navigator's free hands are where the joke lives.

Read first: CLAUDE.md on the cabin, the seat state and the crew's hands; `scripts/gameplay/cabin.gd`, `cabin_input.gd`, `shock_input.gd`,
`crew_rules.gd`; `scripts/vehicles/crew_rig.gd`, `cockpit_camera.gd`, `car_cockpit.gd`, `car_rally_kit.gd` (the trip meter); `scripts/map/paper_map.gd`
(what phase M left: the following view, the wheel and the drag over the sheet); the hint line of `RaceHud`; `Settings` and its key bindings.

## Deliver
1. **Hotspots**, pure and tested (`CabinHotspots` or the like): per seat a list of places in car space (a centre, a radius, the job, how it is
   worked: click, hold, drag), picked by the seat camera's view ray: the nearest within the arm's reach and within a small cone of the view's
   centre, no physics query. The places are measured from the car's own parts (the winder on each door, the glove box's lid, the map where it
   lies folded, the dome lamp's switch, the trip meter's button, the handbrake's lever, the wipers' stalk, the wheel's hub for the horn), so a
   test can ask that each one lies on its part and inside the seat's reach.
2. **Using them.** A click sends the request the job's key sends today (nothing new for the host to trust). A hold works a job that takes
   time (the handbrake's lever while held). A drag winds: the window goes with the hand's turning of the winder (mouse travel, not time: a
   frantic hand winds faster, up to the mechanism's limit the host already enforces), the map pans. While a hand holds a hotspot the view
   stands still and the mouse moves the hand; letting go gives the look back at once. `CrewRules.hands` stays the one rule for what each hand
   holds: a hotspot whose hand is busy answers with a short line in the hint, never silently.
3. **Seeing them.** A small dot in the view's centre for the navigator always and for the driver only while the car stands or crawls; the
   thing the ray meets lights up softly (a rim on the part, no extra draw call where the part's own shader can do it; nothing that reads as a
   game marker in a screenshot of the cabin at rest), and the hint line names it and how to work it, in Turkish and English. The body's hand
   goes to what is used (the rig already reaches for the winder, the stalk, the lever, the map).
4. **Per seat** (law 6): the navigator is mouse-first: the map (click to take and open it, drag to move the sheet, the wheel to zoom or to
   scroll the road book, click the trip meter to zero it), the near window's winder (drag), the glove box and a can (click to take, LMB
   throws as now), the dome lamp, the gun (RMB as now). The driver keeps horn, wipers, handbrake and gears on keys and may click what is rare
   or what he looks at while standing (his winder, the dome lamp, the wheel's hub, the lever).
5. **Settings and devices**: mouse hands on or off, a hold-or-toggle choice for holds, every job's key still bindable; on a gamepad a "use"
   button works the hotspot the stick's look rests on. A lost key or button release never leaves a hand stuck (as `CabinInput` already
   guards for gestures).
6. **The network** is untouched in what it trusts: the same requests, the same host checks, the same seat packets; if a new field is
   needed in the seat state (which hotspot a hand holds, for the partner to see the hand there), it rides in the existing packet and the
   protocol version goes up.

## Tests and evidence
The pick rule (ray against the places: nearest, reach, cone, nothing behind the eye); each hotspot's request equals its key's; the look is
frozen while a hand holds and free after; the hands' rule refuses two jobs for one hand with an answer; a drag winds by travel and never past
the host's limit; no stuck hand after a lost release; the places lie on their parts for both seats. nettest with a scripted mouse job on a
client, a flow test. Evidence: one contact sheet of every hotspot lit, from each seat, by day and at night under the dials' glow; a sequence
of four frames of a window being wound by drag from the partner's seat (the hand is on the winder).

Done means: CLAUDE.md, GAME_DESIGN (law 6 in the section on the seats), the strings, the hint line, CHANGELOG, TEST_PLAN (what a person must
feel: is winding by drag fun, is the dot in the way), DEVELOPMENT_PLAN; full GUT, nettest and a flow test pass; commits on main.
