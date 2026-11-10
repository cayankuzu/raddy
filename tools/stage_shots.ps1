# Shots of every place worth a look on the stages (tools\list_stage_spots.gd) from the driver's seat, in
# one process per stage, weather and time of day (tools\stage_shots.gd: about a minute a stage), plus an overview
# per stage, into reports\screenshots\stages\<Tag>\<stage>\w<weather>t<time>\.
#   tools\stage_shots.ps1 [-Stage n] [-Quality 1] [-Weather 0 | -OwnWeathers] [-Time 0 | -AllTimes] [-Kinds "corner,junction"]
#                         [-Tag now] [-Chase] [-Sheet] [-Compare <tag>] [-RoadLight] [-ExtraArgs "--a,--b"]
# -Kinds keeps the first place of each kind named; -Sheet adds a contact sheet per stage and weather (tools\contact_sheet.gd: a row
# per place, a column per time of day) into <Tag>\sheets\; -Compare <tag> one per stage, weather and time with the shots of that
# earlier tag beside these (before and after). -RoadLight prints how far the road reads ahead in each shot (ROADLIGHT lines).
param(
    [int]$Stage = -1,
    [int]$Quality = 1,
    [int]$Weather = 0,
    [switch]$OwnWeathers,
    [int]$Time = 0,
    [switch]$AllTimes,
    [string]$Kinds = "",
    [string]$Tag = "now",
    [switch]$Chase,
    [switch]$Sheet,
    [string]$Compare = "",
    [switch]$RoadLight,
    [string[]]$ExtraArgs = @()
)
# From a command line only the first token after -ExtraArgs binds: callers pass one comma-joined string.
$ExtraArgs = @($ExtraArgs | ForEach-Object { $_ -split '[ ,]+' } | Where-Object { $_ })
. "$PSScriptRoot\godot.ps1"

$dir = Join-Path $ProjectDir "reports\screenshots\stages\$Tag"
$listArgs = @("--headless", "--path", $ProjectDir, "-s", "res://tools/list_stage_spots.gd")
if ($Stage -ge 0) { $listArgs += @("--", "--stage=$Stage") }
$lines = & $GodotConsole @listArgs 2>&1 | ForEach-Object { "$_" }
$stages = @($lines | Select-String "^WEATHERS " | ForEach-Object { ($_.Line.Trim() -split '\s+')[1] })
$times = if ($AllTimes) { 0..3 } else { @($Time) }
foreach ($s in $stages) {
    $weathers = if ($OwnWeathers) {
        ($lines | Select-String "^WEATHERS $s " | Select-Object -First 1).Line.Trim() -split '\s+' | Select-Object -Skip 2
    } else { @($Weather) }
    $found = @($lines | Select-String "^SPOT $s " | ForEach-Object { , ($_.Line.Trim() -split '\s+') })
    if ($Kinds) {
        $found = @($Kinds -split ',' | ForEach-Object { $k = $_; $found | Where-Object { $_[3] -eq $k } | Select-Object -First 1 })
    }
    $spots = @($found | ForEach-Object { "--spot=$($_[2]):$($_[3])" })
    foreach ($w in $weathers) {
        foreach ($t in $times) {
            $shotArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "1152x648", "--fixed-fps", "60",
                "-s", "res://tools/stage_shots.gd", "--", "--stage=$s", "--quality=$Quality", "--weather=$w", "--time=$t",
                "--out=$(Join-Path $dir "$s\w${w}t$t")") + $spots
            if ($Chase) { $shotArgs += "--chase" }
            if ($RoadLight) { $shotArgs += "--road-light" }
            $shotArgs += $ExtraArgs
            & $GodotConsole @shotArgs 2>&1 | Select-String "SCRIPT ERROR|^ERROR:|^ROADLIGHT" | ForEach-Object {
                if ("$_" -like "ROADLIGHT*") { Write-Host "stage $s w$w t${t}: $_" } else { Write-Host "$_" -ForegroundColor Red }
            }
            if ($Compare) {
                $sheets = Join-Path $dir "sheets"
                New-Item -ItemType Directory -Force $sheets | Out-Null
                $before = Join-Path $ProjectDir "reports\screenshots\stages\$Compare\$s\w${w}t$t"
                $sheetArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "640x360", "-s", "res://tools/contact_sheet.gd", "--",
                    "--column=$Compare|$before", "--column=$Tag|$(Join-Path $dir "$s\w${w}t$t")", "--weather=$w",
                    "--out=$(Join-Path $sheets "stage${s}_w${w}t${t}_vs_$Compare.png")")
                & $GodotConsole @sheetArgs 2>&1 | Select-String "SCRIPT ERROR|^ERROR:|^SHEET" | ForEach-Object { Write-Host "$_" }
            }
            Write-Host ("stage {0} weather {1} time {2}: {3} shots" -f $s, $w, $t, $spots.Count)
        }
        if ($Sheet) {
            $sheets = Join-Path $dir "sheets"
            New-Item -ItemType Directory -Force $sheets | Out-Null
            $sheetArgs = @("--path", $ProjectDir) + $GodotWindowArgs + @("--resolution", "640x360", "-s", "res://tools/contact_sheet.gd", "--",
                "--dir=$(Join-Path $dir $s)", "--weather=$w", "--out=$(Join-Path $sheets "stage${s}_w$w.png")")
            & $GodotConsole @sheetArgs 2>&1 | Select-String "SCRIPT ERROR|^ERROR:|^SHEET" | ForEach-Object { Write-Host "$_" }
        }
    }
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot "screenshot.ps1") -Scene "res://scenes/dev/route_test.tscn" -Frames 60 `
        -Out (Join-Path $dir "$s\overview.png") -ExtraArgs "--stage=$s,--overview,--quality=$Quality" | Out-Null
    Write-Host ("stage {0} overview" -f $s)
}
Write-Host "Shots in $dir"
