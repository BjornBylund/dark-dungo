# Plays many whole missions with random parties, spread over parallel Godot
# processes, and prints how often each mission length is finished, overall and
# for parties with each class. Per-fight numbers: tools/balance_probe.gd.
#   powershell -File scripts/balance.ps1 [-Tier 0] [-Level 0] [-Runs 240] [-Jobs 5] [-NoTalents]
# Tier: 0 Apprentice, 1 Veteran, 2 Champion. Level: the heroes' level; they spend
# their talent points at random unless -NoTalents.
# Runs: missions per length. Jobs: Godot processes per length.
param(
    [int]$Tier = 0,
    [int]$Level = 0,
    [int]$Runs = 240,
    [int]$Jobs = 5,
    [int]$TimeoutSeconds = 300,
    [switch]$NoTalents
)
$ErrorActionPreference = "Stop"
$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*\Godot_*_console.exe" |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot) { throw "Godot not found. Set `$env:GODOT to the Godot console executable." }
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path ([IO.Path]::GetTempPath()) "darko-balance-$PID"
New-Item -ItemType Directory -Force $out | Out-Null

$started = Get-Date
$perJob = [math]::Ceiling($Runs / $Jobs)
$processes = @()
foreach ($length in 0, 1, 2) {
    for ($job = 0; $job -lt $Jobs; $job++) {
        $log = Join-Path $out "$length-$job.log"
        $probeArgs = @('--headless', '--path', $root, '--script', 'res://tools/mission_probe.gd', '--',
            "--length=$length", "--tier=$Tier", "--level=$Level", "--runs=$perJob", "--first-seed=$($job * $perJob)")
        if ($NoTalents) { $probeArgs += '--no-talents' }
        $processes += Start-Process -FilePath $godot -NoNewWindow -PassThru -RedirectStandardOutput $log `
            -RedirectStandardError "$log.err" -ArgumentList $probeArgs
    }
}
foreach ($process in $processes) {
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { $process.Kill(); Write-Warning "a probe timed out" }
}

$names = "Short", "Medium", "Long"
$tiers = "Apprentice", "Veteran", "Champion"
Write-Output ("{0} missions, level {1} heroes{4}, {2} runs per length, {3:N0}s" -f $tiers[$Tier], $Level,
    ($perJob * $Jobs), ((Get-Date) - $started).TotalSeconds, $(if ($NoTalents) { " without talents" } else { "" }))
foreach ($length in 0, 1, 2) {
    $totals = @{ runs = 0; completed = 0; depth = 0; fights = 0; clear_shares = 0 }
    $classes = [ordered]@{}
    foreach ($log in Get-ChildItem (Join-Path $out "$length-*.log")) {
        foreach ($line in Get-Content $log) {
            if ($line -like "RESULT*") {
                foreach ($pair in ($line -split " " | Select-Object -Skip 1)) {
                    $key, $value = $pair -split "="
                    if ($totals.ContainsKey($key)) { $totals[$key] += [int]$value }
                }
            } elseif ($line -like "CLASS*") {
                $fields = $line -split "`t"
                if (-not $classes.Contains($fields[2])) { $classes[$fields[2]] = @(0, 0) }
                $classes[$fields[2]] = @(($classes[$fields[2]][0] + [int]$fields[3]), ($classes[$fields[2]][1] + [int]$fields[4]))
            }
        }
    }
    $runs = [math]::Max($totals.runs, 1)
    Write-Output ("  {0,-6}  finished {1,3:N0}%   got {2,3:N0}% of the way   fight shares won {3:N1}, {4:N1} in a full clear" -f
        $names[$length], (100 * $totals.completed / $runs), ($totals.depth / $runs), ($totals.fights / $runs),
        ($totals.clear_shares / [math]::Max($totals.completed, 1)))
    $rates = foreach ($name in $classes.Keys) { "{0} {1:N0}%" -f $name, (100 * $classes[$name][0] / $classes[$name][1]) }
    Write-Output ("          by class: " + ($rates -join ", "))
}
Get-ChildItem $out -Filter *.err | Where-Object { $_.Length -gt 0 } | ForEach-Object { Get-Content $_.FullName | Select-Object -First 3 }
Remove-Item -Recurse -Force $out
