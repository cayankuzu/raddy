# Runs the GUT test suite headless (settings come from .gutconfig.json).
#   tools\test.ps1                      import, then run every test under res://tests/
#   tools\test.ps1 -Select route        only scripts whose path contains "route"
#   tools\test.ps1 -SkipImport          skip the import step (faster when no files were added)
# Exit code: 0 = all passed, 1 = failures, 2 = GUT did not actually run.
param(
    [string]$Select = "",
    [switch]$SkipImport
)
. "$PSScriptRoot\godot.ps1"

if (-not $SkipImport) {
    & "$PSScriptRoot\import.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$junit = Join-Path $ProjectDir "reports\junit.xml"
New-Item -ItemType Directory -Force (Split-Path $junit) | Out-Null
Remove-Item $junit -ErrorAction SilentlyContinue

$gutArgs = @("--headless", "--path", $ProjectDir, "-s", "res://addons/gut/gut_cmdln.gd", "-gexit")
if ($Select) { $gutArgs += "-gselect=$Select" }

$out = & $GodotConsole @gutArgs 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { "$_" }

# GUT exits 0 without running anything in these cases, so a bare exit code is not proof.
if ($out -match "Please restart the Editor|Main loop did not start in time" -or -not (Test-Path $junit)) {
    Write-Host "GUT did not run the suite (see output above)." -ForegroundColor Red
    exit 2
}
exit $code
