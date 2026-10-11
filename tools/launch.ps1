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
    $godotArgs = @("--path", $ProjectDir) + $GodotWindowArgs + $windowArgs + @("--log-file", $log)
    if ($Scene) { $godotArgs += $Scene }
    $godotArgs += @("--", "--instance=$index", "--role=$role") + $ExtraArgs
    # ProcessStartInfo.ArgumentList quotes each argument, so spaces in paths or args survive.
    $psi = [System.Diagnostics.ProcessStartInfo]::new($GodotExe)
    foreach ($a in $godotArgs) { $psi.ArgumentList.Add($a) }
    $proc = [System.Diagnostics.Process]::Start($psi)
    [pscustomobject]@{ Instance = $index; Role = $role; Pid = $proc.Id; Log = $log }
}

if ($Stop) { Stop-Instances; Write-Host "Stopped."; exit 0 }
Assert-RunnableScene $Scene
Stop-Instances  # never stack a new session on top of a previous one
New-Item -ItemType Directory -Force $logDir | Out-Null

$started = @()
if ($Server) { $started += Start-Instance 0 "server" @("--headless") }

if ($Clients -gt 0) {
    # Godot places windows in physical pixels from the virtual-desktop origin, so read the
    # screen DPI-aware and from that origin; tiles then line up at any display scaling.
    if (-not ("Raddy.Win" -as [type])) {
        Add-Type -Namespace Raddy -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
'@
    }
    [void][Raddy.Win]::SetThreadDpiAwarenessContext([IntPtr]-4)  # per-monitor v2, like Godot
    Add-Type -AssemblyName System.Windows.Forms
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $origin = [System.Windows.Forms.SystemInformation]::VirtualScreen
    # SM_CYCAPTION + SM_CYFRAME + SM_CXPADDEDBORDER
    $titleBar = [Raddy.Win]::GetSystemMetrics(4) + [Raddy.Win]::GetSystemMetrics(33) + [Raddy.Win]::GetSystemMetrics(92)
    $cols = [int][Math]::Ceiling([Math]::Sqrt($Clients))
    $rows = [int][Math]::Ceiling($Clients / $cols)
    $w = [int][Math]::Floor($area.Width / $cols)
    $h = [int][Math]::Floor($area.Height / $rows) - $titleBar
    for ($i = 0; $i -lt $Clients; $i++) {
        $x = $area.X - $origin.X + ($i % $cols) * $w
        $y = $area.Y - $origin.Y + [Math]::Floor($i / $cols) * ($h + $titleBar) + $titleBar
        $started += Start-Instance ($i + 1) "client" @("--position", "$x,$y", "--resolution", "${w}x${h}")
    }
}

@($started | ForEach-Object { $_.Pid }) | ConvertTo-Json | Set-Content $pidFile
$started | Format-Table -AutoSize
