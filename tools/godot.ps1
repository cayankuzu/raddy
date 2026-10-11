# Shared paths for the RADDY tool scripts. Dot-source it: . "$PSScriptRoot\godot.ps1"
# Override the engine folder with the GODOT_DIR environment variable.

$GodotDir = if ($env:GODOT_DIR) { $env:GODOT_DIR } else { "C:\Tools\Godot\4.7.2" }
# GUI build: used for windows we launch in the background (no console window, no waiting).
$GodotExe = Join-Path $GodotDir "Godot_v4.7.2-stable_win64.exe"
# Console wrapper: waits for the engine, forwards stdout/stderr and the exit code.
$GodotConsole = Join-Path $GodotDir "Godot_v4.7.2-stable_win64_console.exe"
$ProjectDir = Split-Path -Parent $PSScriptRoot
# Godot 4.7.2's AccessKit integration panics at window creation when the Windows global atom
# table is full (SetPropW fails with ERROR_NOT_ENOUGH_MEMORY; seen on this PC after ~17 days of
# uptime). Every window we open for tooling skips it; a reboot clears the table.
$GodotWindowArgs = @("--accessibility", "disabled")

foreach ($exe in $GodotExe, $GodotConsole) {
    if (-not (Test-Path $exe)) { throw "Godot not found: $exe (set GODOT_DIR to the folder holding both exes)" }
}

# Without a scene argument Godot runs the main scene, and with none set it shows a blocking
# "no main scene" message box. Fail fast in the console instead.
function Assert-RunnableScene([string]$Scene) {
    if ($Scene) { return }
    if (-not (Select-String -LiteralPath (Join-Path $ProjectDir "project.godot") -Pattern '^run/main_scene=' -Quiet)) {
        throw "project.godot has no main scene yet. Pass -Scene res://path.tscn."
    }
}
