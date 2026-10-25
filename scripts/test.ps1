# Runs the headless test suite. Set $env:GODOT to override the Godot binary.
$ErrorActionPreference = "Stop"
$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*\Godot_*_console.exe" |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot) { throw "Godot not found. Set `$env:GODOT to the Godot console executable." }

$root = Split-Path $PSScriptRoot -Parent
# Import first so class_name scripts are registered in the global class cache.
& $godot --headless --path $root --import | Out-Null
& $godot --headless --path $root --script res://tests/run_tests.gd
exit $LASTEXITCODE
