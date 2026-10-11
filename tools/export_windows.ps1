# Exports the Windows x64 build with the "Windows Desktop" preset into builds\windows\.
#   tools\export_windows.ps1            release build
#   tools\export_windows.ps1 -Debug     debug build (keeps asserts and debug output)
# Run exported builds with --log-file <path> to capture output: Smart App Control on this PC
# blocks the unsigned console wrapper, so the preset does not export one.
param([switch]$Debug)
. "$PSScriptRoot\godot.ps1"

$outDir = Join-Path $ProjectDir "builds\windows"
New-Item -ItemType Directory -Force $outDir | Out-Null
$mode = if ($Debug) { "--export-debug" } else { "--export-release" }

$out = & $GodotConsole --headless --path $ProjectDir $mode "Windows Desktop" (Join-Path $outDir "RADDY.exe") 2>&1
$code = $LASTEXITCODE
$errors = @($out | Select-String -Pattern "^(ERROR|SCRIPT ERROR):")
if ($code -ne 0 -or $errors.Count -gt 0 -or -not (Test-Path (Join-Path $outDir "RADDY.exe"))) {
    $out | ForEach-Object { "$_" }
    Write-Host "Export failed (exit $code, $($errors.Count) error lines)." -ForegroundColor Red
    exit 1
}
Get-ChildItem $outDir | Select-Object Name, @{ n = "MB"; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
Write-Host "Export OK: $outDir" -ForegroundColor Green
exit 0
