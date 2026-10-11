# Imports (or reimports) project assets headless. Run after adding addons, assets or new
# class_name scripts. Exits 1 if the engine reported any ERROR line.
. "$PSScriptRoot\godot.ps1"

$out = & $GodotConsole --headless --path $ProjectDir --import 2>&1
$code = $LASTEXITCODE
$errors = @($out | Select-String -Pattern "^(ERROR|SCRIPT ERROR):")

if ($code -ne 0 -or $errors.Count -gt 0) {
    $out | ForEach-Object { "$_" }
    Write-Host "Import failed (exit $code, $($errors.Count) error lines)." -ForegroundColor Red
    exit 1
}
Write-Host "Import OK." -ForegroundColor Green
exit 0
