# Starts several RADDY instances on this PC for multiplayer tests.
#   tools\launch.ps1 -Clients 2               two windowed clients, tiled on the primary screen
#   tools\launch.ps1 -Clients 3 -Server       plus one headless host (instance 0)
#   tools\launch.ps1 -Scene res://x.tscn      run that scene instead of the main scene
#   tools\launch.ps1 -Stop                    close every instance this script started
# Each instance writes logs\instance_<n>.log and gets these user args after "--":
#   --instance=<n> --role=server|client  (plus -ExtraArgs). Read them with OS.get_cmdline_user_args().
param(
    [ValidateRange(0, 6)][int]$Clients = 2,
    [switch]$Server,
    [string]$Scene = "",
    [string[]]$ExtraArgs = @(),
    [switch]$Stop
)
. "$PSScriptRoot\godot.ps1"

$logDir = Join-Path $ProjectDir "logs"
$pidFile = Join-Path $logDir "instances.json"

function Stop-Instances {
    if (-not (Test-Path $pidFile)) { return }
    foreach ($id in @(Get-Content $pidFile -Raw | ConvertFrom-Json)) {
        $proc = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($proc -and $proc.Path -eq $GodotExe) { Stop-Process -Id $id -Force }
    }
    Remove-Item $pidFile
}

function Start-Instance([int]$index, [string]$role, [string[]]$windowArgs) {
    $log = Join-Path $logDir "instance_$index.log"
    Remove-Item $log -ErrorAction SilentlyContinue
    $argList = @("--path", "`"$ProjectDir`"") + $windowArgs + @("--log-file", "`"$log`"")
    if ($Scene) { $argList += $Scene }
    $argList += @("--", "--instance=$index", "--role=$role") + $ExtraArgs
    $proc = Start-Process -FilePath $GodotExe -ArgumentList $argList -PassThru
    [pscustomobject]@{ Instance = $index; Role = $role; Pid = $proc.Id; Log = $log }
}

if ($Stop) { Stop-Instances; Write-Host "Stopped."; exit 0 }
Stop-Instances  # never stack a new session on top of a previous one
New-Item -ItemType Directory -Force $logDir | Out-Null

$started = @()
if ($Server) { $started += Start-Instance 0 "server" @("--headless") }

if ($Clients -gt 0) {
    Add-Type -AssemblyName System.Windows.Forms
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $cols = [int][Math]::Ceiling([Math]::Sqrt($Clients))
    $rows = [int][Math]::Ceiling($Clients / $cols)
    $titleBar = 32
    $w = [int][Math]::Floor($area.Width / $cols)
    $h = [int][Math]::Floor($area.Height / $rows) - $titleBar
    for ($i = 0; $i -lt $Clients; $i++) {
        $x = $area.X + ($i % $cols) * $w
        $y = $area.Y + [Math]::Floor($i / $cols) * ($h + $titleBar) + $titleBar
        $started += Start-Instance ($i + 1) "client" @("--position", "$x,$y", "--resolution", "${w}x${h}")
    }
}

@($started | ForEach-Object { $_.Pid }) | ConvertTo-Json | Set-Content $pidFile
$started | Format-Table -AutoSize
