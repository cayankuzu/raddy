# Phase A5b: a crew that looks like a real rally crew

The owner's bar: AAA premium, realistic-leaning and NOT low-poly, every flag Turkish, real details everywhere. Phase A5 made the crew work (CrewBody,
CrewPose, CrewRig, CrewHelmet, CarRallyKit; CLAUDE.md describes them). How they look is not at the bar yet: from the other seat
(`reports/screenshots/a5_hands/driver_at_nav_map.png`, `nav_at_driver_steer.png`) the Quaternius mannequin's flat facets show, the suit reads as glossy
red plastic, the helmet as a ball with a black slot. Fix the look; keep everything that works (poses, IK, gestures and their signs, sync, own-head
hiding, mirrors, the cage that A5's fixer made visible: nothing of the new helmet, HANS or suit may poke through the cage's head padding or the seat's wings).

BODY_SOURCE: `mannequin` (the owner did not approve the Universal Base Characters download; the `ubc` path below is only for when they do).

1. **A smooth body.** BODY_SOURCE above says which. `mannequin`: subdivide the mannequin once when it is baked (`tools/make_crew_mannequin.gd`): Loop
   subdivision (or an equivalent that rounds the silhouette), skin weights and bones carried to the new vertices, hard edges kept only where they belong
   (fingers' tips, the soles), about 4x the triangles; measure the skinning cost with three crews. `ubc` (only once approved): Quaternius Universal Base
   Characters (Standard, CC0) replaces the mannequin: inspect its rig first with a headless script, map CrewPose's bones (UAL-compatible), keep the
   hidden-head and suit regions working, one surface per body.
2. **A race suit.** Fireproof fabric: matte with a soft sheen at grazing angles, a fine weave in the normal (generated, no download), panels in a darker
   shade of the team colour down the sides and the arms' insides, stitched seams, stretch panels at shoulders and knees, a collar. On the upper left
   sleeve the Turkish flag patch (crews carry their national flag), on the chest the player's name embroidered (from the roster, the same source as
   the livery's names; nothing if a seat has no name). No real brand. Still one draw call per body.
3. **Gloves and boots.** Race gloves with a contrasting palm and a stitched cuff; thin-soled race boots.
4. **A real rally helmet** (`CrewHelmet.mesh()`, still the one place a downloaded model would replace): a proper shell profile (taller crown, longer nape,
   a face opening), a clear visor with a light tint over a fireproof balaclava (the eyes' area dark but not a void: a faint glint where the eyes are), a
   chin bar, an intercom boom microphone in front of the mouth, the HANS tethers from the helmet's sides to the collar, the team colour with a stripe,
   the name and a small Turkish flag on the side, a gloss clearcoat. Smooth enough at the closest distance a partner sees it. One draw call.
5. **The crowd too.** The spectators are the same mannequin baked standing (`Spectators.body_mesh`, `CrewPose.stand`): A5's reviewers found them, from the
   grid at 8-10 m during the countdown, a faceless bodybuilder with clothes painted on the skin, arms held out from the body. They take the smooth body;
   clothes with a silhouette of their own (a shirt or jacket standing 1-2 cm off the body, looser trousers, the hem and cuffs), arms resting nearer the body,
   the faces A5 drew (eyes, the shadow under the nose, a mouth) made to read at 8 m by day; the levels of detail regenerated and checked by eye; still one
   MultiMesh and one draw call a place.
6. **Looked at** from both seats close up, from outside through the side window, in the interior mirror, by day, at night under the dome lamp; a rival
   crew from a following car; the crowd from the grid and from the roadside. Perf, inside one process (the method in CLAUDE.md: `tools\perf.ps1 -ExtraArgs
   "--follower=14+28,--flip-crew=0.5"` and `--flip-crowd=0.5`, each run twice): at most ~0.5 ms more than A5's crew and crowd.

7. **What A5's final check left for a look phase.** At night the hot band of the beams still turns straw bales and concrete blocks into white halos and,
   from outside, the car's own headlight glass reads as flat white (A4's `HEAD_GLOW`): `shaders/lamp_cap.gdshaderinc` (no lamp gives a surface more
   than the day's sun) already keeps the flags and the guard rails themselves; give the bales and the blocks the same, and make a lit headlight read as a
   lamp (reflector, lens, a hot core) rather than a white plate; before/after crops at night, the road no less readable.

Tests: the subdivision keeps weights summing to one and bones per vertex within the engine's limit; the name and flag patches come from the roster;
the helmet's mesh stays one surface; whatever was tested in A5 still passes. Done means: full GUT, nettest, flow test pass; commits on main; CLAUDE.md
(crew paragraph), DEVELOPMENT_PLAN, CHANGELOG, ASSET_LICENSES (if UBC) updated.
