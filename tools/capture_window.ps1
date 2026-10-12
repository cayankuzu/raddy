# Saves a PNG of a running window, even when other windows cover it (PrintWindow with
# PW_RENDERFULLCONTENT, which also works for D3D12-rendered game windows).
#   tools\capture_window.ps1 -ProcessId 1234 -Out reports\screenshots\client3.png
#   tools\capture_window.ps1 -Instance 3 -Out ...     a launch.ps1 instance (reads logs\instances.json)
param(
    [int]$ProcessId = 0,
    [int]$Instance = -1,
    [string]$Out = "reports\screenshots\window.png"
)
. "$PSScriptRoot\godot.ps1"

if ($Instance -ge 0) {
    $map = Get-Content (Join-Path $ProjectDir "logs\instances.json") -Raw | ConvertFrom-Json
    $ProcessId = [int]$map."$Instance"
    if ($ProcessId -eq 0) { throw "launch.ps1 has no instance $Instance running" }
}
$proc = Get-Process -Id $ProcessId -ErrorAction Stop
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq 0) { throw "process $ProcessId has no window (headless?)" }

if (-not ("Raddy.WindowCapture" -as [type])) {
    Add-Type -Namespace Raddy -Name WindowCapture -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
'@
}
Add-Type -AssemblyName System.Drawing
[void][Raddy.WindowCapture]::SetThreadDpiAwarenessContext([IntPtr]-4)
$rect = New-Object Raddy.WindowCapture+RECT
[void][Raddy.WindowCapture]::GetClientRect($hwnd, [ref]$rect)
$w = [Math]::Max($rect.Right - $rect.Left, 1)
$h = [Math]::Max($rect.Bottom - $rect.Top, 1)
$bitmap = New-Object System.Drawing.Bitmap $w, $h
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()
[void][Raddy.WindowCapture]::PrintWindow($hwnd, $hdc, 3)  # PW_CLIENTONLY | PW_RENDERFULLCONTENT
$graphics.ReleaseHdc($hdc)
$graphics.Dispose()
$outPath = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $ProjectDir $Out }
New-Item -ItemType Directory -Force (Split-Path $outPath) | Out-Null
$bitmap.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
Write-Host "Captured ${w}x${h} window of pid $ProcessId to $outPath"
