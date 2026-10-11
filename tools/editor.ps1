# Opens RADDY in the Godot editor. Beckett, the MCP server Claude uses, starts inside it.
#   tools\editor.ps1             normal editor window
#   tools\editor.ps1 -Headless   no window: only serves Beckett for Claude
#   tools\editor.ps1 -Stop       close the headless editor started by this script
param(
    [switch]$Headless,
    [switch]$Stop
)
. "$PSScriptRoot\godot.ps1"

$pidFile = Join-Path $ProjectDir "logs\editor.pid"

if ($Stop) {
    if (Test-Path $pidFile) {
        $id = [int](Get-Content $pidFile)
        $proc = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($proc -and $proc.Path -eq $GodotExe) { Stop-Process -Id $id -Force }
        Remove-Item $pidFile
    }
    Write-Host "Stopped."
    exit 0
}

# A second editor on this project would move Beckett to another port and rewrite .mcp.json.
$running = $null
if (Test-Path $pidFile) {
    $running = Get-Process -Id ([int](Get-Content $pidFile)) -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $GodotExe }
}
$port = if ($env:BECKETT_PORT) { [int]$env:BECKETT_PORT } else { 8770 }
$listening = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($running -or $listening) {
    Write-Host "An editor already serves Beckett on port $port. Close it (or run tools\editor.ps1 -Stop) first." -ForegroundColor Red
    exit 1
}

$editorArgs = @("--editor", "--path", "`"$ProjectDir`"") + $GodotWindowArgs
if ($Headless) {
    New-Item -ItemType Directory -Force (Split-Path $pidFile) | Out-Null
    $log = Join-Path $ProjectDir "logs\editor.log"
    $proc = Start-Process -FilePath $GodotExe -ArgumentList (@("--headless") + $editorArgs + @("--log-file", "`"$log`"")) -PassThru
    $proc.Id | Set-Content $pidFile
    Write-Host "Headless editor started (pid $($proc.Id)), log: $log"
} else {
    Start-Process -FilePath $GodotExe -ArgumentList $editorArgs | Out-Null
    Write-Host "Editor opening."
}
