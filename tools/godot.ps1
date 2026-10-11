# Shared paths for the RADDY tool scripts. Dot-source it: . "$PSScriptRoot\godot.ps1"
# Override the engine folder with the GODOT_DIR environment variable.

$GodotDir = if ($env:GODOT_DIR) { $env:GODOT_DIR } else { "C:\Tools\Godot\4.7.2" }
# GUI build: used for windows we launch in the background (no console window, no waiting).
$GodotExe = Join-Path $GodotDir "Godot_v4.7.2-stable_win64.exe"
# Console wrapper: waits for the engine, forwards stdout/stderr and the exit code.
$GodotConsole = Join-Path $GodotDir "Godot_v4.7.2-stable_win64_console.exe"
$ProjectDir = Split-Path -Parent $PSScriptRoot

foreach ($exe in $GodotExe, $GodotConsole) {
    if (-not (Test-Path $exe)) { throw "Godot not found: $exe (set GODOT_DIR to the folder holding both exes)" }
}
