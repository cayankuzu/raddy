# Runs the GUT test suite headless (settings come from .gutconfig.json).
#   tools\test.ps1                      import, then run every test under res://tests/
#   tools\test.ps1 -Select route        only test files whose file name contains "route"
#                                       (case-sensitive; folder names are not matched)
#   tools\test.ps1 -SkipImport          skip the import step (faster when no files were added)
# Exit code: 0 = all passed, 1 = a test failed or a test file did not load, 2 = GUT did not run.
param(
    [string]$Select = "",
    [switch]$SkipImport
)
try { . "$PSScriptRoot\godot.ps1" } catch { Write-Host "$_" -ForegroundColor Red; exit 2 }

if (-not $SkipImport) {
    & "$PSScriptRoot\import.ps1"
    if ($LASTEXITCODE -ne 0) { Write-Host "GUT did not run: the import failed." -ForegroundColor Red; exit 2 }
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
# A test file that fails to parse is skipped with a warning, and GUT still exits 0.
if ($out -match 'Ignoring script .* because it does not extend GutTest|Failed to load script "res://tests/') {
    Write-Host "A test file failed to load and was skipped (see output above)." -ForegroundColor Red
    exit 1
}
if ([int]([xml](Get-Content $junit -Raw)).testsuites.tests -eq 0) {
    Write-Host "GUT ran 0 tests (check -Select and the test file names)." -ForegroundColor Red
    exit 2
}
exit $code
