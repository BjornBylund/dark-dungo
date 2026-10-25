# Runs the headless test suite. Set $env:GODOT to override the Godot binary.
#   powershell -File scripts/test.ps1 [-Only text]
# -Only runs just the tests whose file or method name contains the text.
param([string]$Only = "")
$ErrorActionPreference = "Stop"
$godot = $env:GODOT
if (-not $godot) {
    $godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*\Godot_*_console.exe" |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot) { throw "Godot not found. Set `$env:GODOT to the Godot console executable." }

$root = Split-Path $PSScriptRoot -Parent
# Import so class_name scripts are registered in the global class cache, but
# only when a project file changed since the last import.
$stamp = Join-Path $root ".godot\test-import-stamp"
$changed = -not (Test-Path $stamp)
if (-not $changed) {
    $since = (Get-Item $stamp).LastWriteTime
    $changed = [bool](Get-ChildItem $root -Recurse -File -Exclude *.import, *.uid |
        Where-Object { $_.FullName -notmatch '\\(\.godot|\.git|build)\\' -and $_.LastWriteTime -gt $since } |
        Select-Object -First 1)
}
if ($changed) {
    & $godot --headless --path $root --import | Out-Null
    New-Item -ItemType File -Force $stamp | Out-Null
}
& $godot --headless --path $root --script res://tests/run_tests.gd -- "--only=$Only"
exit $LASTEXITCODE
