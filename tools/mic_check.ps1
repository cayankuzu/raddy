# Mikrofon kontrolü: her mikrofonu 5 saniye dinler. Dinlerken konuş.
#   tools\mic_check.ps1                         bütün mikrofonları sırayla dener
#   tools\mic_check.ps1 -Device "Mikrofon (Realtek(R) Audio)"   sadece birini dener
param([string]$Device = "")
. "$PSScriptRoot\godot.ps1"

$script = Join-Path $PSScriptRoot "mic_check.gd"
$baseArgs = @("--no-header", "--path", $ProjectDir, "--resolution", "320x180", "-s", $script, "--")

$devices = if ($Device) { @($Device) } else {
    & $GodotConsole @baseArgs "--list" 2>&1 | Select-String "^MIC_DEVICE_NAME " | ForEach-Object { $_.Line.Substring(16) }
}

foreach ($d in $devices) {
    Write-Host "`n=== $d ===  (5 saniye konuş)" -ForegroundColor Cyan
    $out = & $GodotConsole @baseArgs $d 2>&1
    $line = $out | Select-String "^MIC_RESULT " | Select-Object -Last 1
    if (-not $line) { $out | ForEach-Object { "$_" }; continue }
    $peak = [double]::Parse(([regex]::Match($line.Line, "peak=([0-9.]+)")).Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    Write-Host $line.Line
    if ($peak -eq 0) {
        Write-Host "SESSİZ: bu cihazdan hiç ses gelmiyor (sessize alınmış, kapalı ya da sanal cihaz)." -ForegroundColor Red
    } elseif ($peak -lt 0.02) {
        Write-Host "ÇOK DÜŞÜK: cihaz çalışıyor ama konuşma duyulmadı. Konuştuysan mikrofon seviyesini yükselt." -ForegroundColor Yellow
    } else {
        Write-Host "ÇALIŞIYOR: konuşma algılandı." -ForegroundColor Green
    }
}
