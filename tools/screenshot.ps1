# Renders a scene for N frames with Movie Maker (fixed 60 fps, no real-time wait) and keeps
# the last frame as a PNG that Claude can open.
#   tools\screenshot.ps1 -Scene res://scenes/x.tscn -Frames 120 -Out reports\screenshots\x.png
# A window opens briefly: the renderer draws nothing when headless or minimized.
# The PNG always has the project's viewport size (display/window/size/viewport_*, 1152x648 by
# default); -Resolution only sizes the window, so keep it at the same aspect ratio.
param(
    [string]$Scene = "",
    [int]$Frames = 120,
    [string]$Out = "reports\screenshots\shot.png",
    [string]$Resolution = "1152x648",
    [string[]]$ExtraArgs = @()
)
# From a command line (pwsh -File ...) only the first token after -ExtraArgs binds, so callers
# pass one comma- or space-joined string; split it here. Arrays from PowerShell callers also work.
$ExtraArgs = @($ExtraArgs | ForEach-Object { $_ -split '[ ,]+' } | Where-Object { $_ })
. "$PSScriptRoot\godot.ps1"
Assert-RunnableScene $Scene

$outPath = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $ProjectDir $Out }
$frameDir = Join-Path (Split-Path $outPath) ("_frames_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $frameDir | Out-Null

$shotArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", $Resolution,
    "--write-movie", (Join-Path $frameDir "frame.png"), "--quit-after", $Frames)
if ($Scene) { $shotArgs += $Scene }
if ($ExtraArgs) { $shotArgs += @("--") + $ExtraArgs }

$out = & $GodotConsole @shotArgs 2>&1
$code = $LASTEXITCODE
$last = Get-ChildItem $frameDir -Filter "frame*.png" | Sort-Object Name | Select-Object -Last 1
if (-not $last) {
    $out | ForEach-Object { "$_" }
    Remove-Item $frameDir -Recurse -Force
    Write-Host "No frame was written (exit $code)." -ForegroundColor Red
    exit 1
}
Move-Item $last.FullName $outPath -Force
Remove-Item $frameDir -Recurse -Force
Write-Host "Screenshot: $outPath"
exit 0
