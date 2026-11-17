# Phase D: a demo people try alone, share and come back to with friends

Direction 2's milestone: a free demo on itch.io before the full game, judged by what players do in it. It comes after L2, X, W, H and J,
when the stages are real rally roads, the roadside breaks, the countryside lives, the navigator's hands work and any friend can join.

Read first: GAME_DESIGN "Direction 2"; `docs/phases/a6_chaos.md` item 9 (solo practice: this phase builds it), `a7_ui.md` item 11 (photo
mode), `a9_a10.md` (the launch package: this phase builds the demo's part of it); CLAUDE.md on `Flow`, `RaceSession`, `RouteFollower`,
`PaceNotes`, the results, the export and Smart App Control.

## Deliver
1. **Solo.** "Tek başına" / "Solo" from the main menu: a local one-player session through the same `RaceSession` code with no port opened.
   As the driver: a co-driver body in the other seat who holds the map, points with the gestures and calls the pace notes aloud through
   `DisplayServer.tts_speak` (the voices this Windows has, chosen by the game's language; never blocking; the call also shown as large text
   near the top of the screen when no voice fits or when the player turns voice off), timed by the car's speed so a call comes about 80 m
   before its place (earlier when fast), the junction's call naming the way. As the navigator: the bot drives and obeys the calls the player
   makes with the gesture keys (left, right, straight, slow): it slows before a corner the player has not called and takes the way the player
   points at a fork, so a wrong call costs time. Solo records apart from crew records.
2. **The share card.** At the finish, a picture of the crew's car as it is (the dirt, the damage, the cracked glass) at the finish arch from a
   low trackside angle, with the stage's name, the time, the medal, the awards and the crew's names, in the game's type: saved as PNG in
   `user://screenshots/` with a button that opens the folder; shown on the results.
3. **Photo mode.** From pause in a race or on the results: a free camera within 15 m of one's car (the mouse looks, WASD moves, the wheel
   zooms), the HUD hidden, depth of field and a few grades (none, warm, cold, black and white), one key takes a PNG at the screen's size.
4. **Credits.** A screen generated from `ASSET_LICENSES.md` (every CC BY author with the work's title and address, the CC0 sources, the fonts'
   and addons' licences) and the thanks the owner asked for, in both languages: "İlham için teşekkürler: “Left! Left! LEFT!”. Direksiyonda biri,
   haritada biri: bu fikrin tadını ondan aldık. RADDY bağımsız bir oyundur; o oyunla ve yapımcılarıyla bir bağı yoktur." / "Thanks for the
   inspiration: “Left! Left! LEFT!”. One at the wheel, one on the map: we owe the taste for it to that game. RADDY is an independent game, not
   affiliated with it or its makers." A test checks that every CC BY row of `ASSET_LICENSES.md` reaches the screen.
5. **Pictures for the page.** A tool that captures the shots and clips a store page needs from fixed seeds (route_test `--view`, followers,
   events and gags drawn on purpose; Movie Maker frames), and makes the GIFs with PIL (pure Python): a falling tree, a bonnet flying up, a
   puncture's sparks at night, a flock parting, the crowd diving, a market stall exploding into fruit, the map in the navigator's hands, the
   finish card. Cover and banner from in-game shots with the title in the game's type, in itch.io's sizes.
6. **The demo build.** An export preset "Demo" (two stages: Black Pine and Red Canyon; every mode, solo and online; a "full game" note on the
   menu), `builds/demo/` zipped with the README (how to get past SmartScreen: "More info" then "Run anyway"; how to host and join; the
   controls); the itch.io page text in Turkish and English (`docs/ITCH_PAGE.md`: the pitch, features, controls, requirements, SmartScreen,
   the credits and the thanks). If the owner is signed in to itch.io in Chrome, create the project as a draft with the texts, pictures and
   the zip uploaded (never public: publishing is the owner's one click), and say exactly what is left.

Tests and evidence: solo end to end in a flow test (both seats), the co-driver's call timing as a pure rule, the card's picture and the credits
as tests where they can be, the demo export run once on this PC (it starts, a solo stage finishes). Done means: CLAUDE.md, DEVELOPMENT_PLAN,
CHANGELOG, TEST_PLAN, the strings, `docs/ITCH_PAGE.md`; full GUT, nettest and flow tests pass; commits on main.
