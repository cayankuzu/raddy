# RADDY

Online 3-team co-op rally game. Godot 4.7.2, GDScript only, Windows x64 desktop, itch.io.
The user writes Turkish: answer in Turkish.

## Engine
- Godot lives in `C:\Tools\Godot\4.7.2\` (override with `GODOT_DIR`). Use `Godot_v4.7.2-stable_win64_console.exe`
  whenever output or the exit code matters; the GUI exe is for windows launched in the background.
- Export templates 4.7.2 are installed in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- `project.godot` pins Jolt Physics, 120 physics ticks, D3D12, `audio/driver/enable_input`, and turns off
  Blender/FBX2glTF import. `tests/unit/test_project_settings.gd` guards these.

## Commands (PowerShell, repo root)
- `pwsh -NoProfile -File tools\import.ps1`: headless import. Run after adding addons, assets or `class_name` scripts.
- `pwsh -NoProfile -File tools\test.ps1 [-Select <part of path>] [-SkipImport]`: GUT suite. Exit 0 pass, 1 fail,
  2 GUT did not run. Tests live in `tests/`, files `test_*.gd`, `extends GutTest`. JUnit: `reports/junit.xml`.
- `tools\launch.ps1 -Clients N [-Server] [-Scene res://x.tscn] [-ExtraArgs ...]` / `tools\launch.ps1 -Stop`:
  multi-instance run, tiled windows, headless host as instance 0. Logs: `logs\instance_<n>.log`.
  User args: `--instance=<n> --role=server|client` (read with `OS.get_cmdline_user_args()`).
- `tools\screenshot.ps1 -Scene res://x.tscn -Frames 120 -Out reports\screenshots\x.png`: Movie Maker capture;
  open the PNG with Read.
- `tools\export_windows.ps1 [-Debug]`: `builds\windows\RADDY.exe` via the "Windows Desktop" preset.
- `tools\editor.ps1 [-Headless | -Stop]`: open the editor (Beckett MCP runs inside it).
- `tools\mic_check.ps1 [-Device <name>]`: input level per microphone (user speaks while it listens).

## Beckett MCP (addons/beckett)
- The editor plugin is the MCP server: `http://127.0.0.1:8770/mcp/<token>`, token auth on. It only runs while an
  editor (GUI, or `tools\editor.ps1 -Headless`) has this project open.
- `.mcp.json`, `.cursor/` and `.beckett/` carry the token: gitignored. Never commit or print them.
- Lite edition: no input simulation, no export, watches one game instance at a time. Use the CLI tools above for
  multi-client runs, tests and exports.
- Keep one editor per project: a second one moves to port 8772 and rewrites `.mcp.json`.

## Gotchas found during setup
- Never pass `-d` in unattended runs: the stdout debugger can hang at a `debug>` prompt.
- `--headless` means the Dummy audio driver and no rendering: mic and screenshot checks need a window.
- Release export templates refuse a scene path on the command line, so exported builds always start at the main scene.
- Smart App Control is ON on this PC. It blocked the unsigned exported console wrapper (the preset exports none);
  the exported `RADDY.exe` itself ran. Players may hit the same block: plan code signing before a public release.
- All instances share `user://` (Godot has no user-data-dir flag): namespace per-instance files by `--instance`.
- Local multiplayer tests: bind the ENet host to `127.0.0.1` (verified: host + 2 clients, RPCs both ways, no
  firewall prompt). Binding `*` for internet play triggers the Windows Firewall prompt.
- Mic API: `AudioServer.set_input_device_active()` / `get_input_frames()` (4.6+, marked experimental).
  Windows default input here is the virtual "iTop Microphone"; the real mics are
  "Mikrofon Dizisi (Realtek(R) Audio)" (laptop array) and "Mikrofon (Realtek(R) Audio)" (jack).
- Stock 4.7.2 cannot step physics manually, so there is no rollback/resimulation of RigidBody vehicles.

## Third-party (pinned)
- `addons/beckett`: Beckett Lite v1.16.0, MIT, GitHub release zip (sha256 35b1274d…20ac). The Asset Library copy is older.
- `addons/gut`: GUT v9.7.1, MIT, the `godot_4_7` line. The Asset Library's 9.6.1 targets 4.6: do not "update" from there.
- Researched, not installed yet: TwoVoIP v6.5 for Opus voice (not 6.6: Windows editor crash, issue #107),
  netfox + noray for NAT punch-through/relay.
