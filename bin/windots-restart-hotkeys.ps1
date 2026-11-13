# windots-restart-hotkeys
# windots:summary=Restart windots-hotkeys, the AutoHotkey script for the keys whkd can't name
# windots:examples=windots restart hotkeys
#
# Like omarchy's omarchy-restart-* commands: stops the AutoHotkey v2 process that runs
# bin\windots-hotkeys.ahk and opens the script again (what its startup shortcut does), so an
# edit to the script takes effect. Also starts it when it was not running.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart hotkeys --help)" -ForegroundColor Red; exit 2 }

$script = Join-Path $PSScriptRoot 'windots-hotkeys.ahk'
function Get-Hotkeys { @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*windots-hotkeys.ahk*' }) }

$running = Get-Hotkeys
if ($running) {
    foreach ($p in $running) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    $running | ForEach-Object { Wait-Process -Id $_.ProcessId -Timeout 5 -ErrorAction SilentlyContinue }
}
# Opened by whatever runs .ahk files (AutoHotkey v2), like the startup shortcut does.
try { Start-Process $script -ErrorAction Stop }
catch {
    Write-Warning "could not open $script ($($_.Exception.Message)): is AutoHotkey v2 installed? (winget install AutoHotkey.AutoHotkey)"
    exit 1
}

$up = $false
foreach ($i in 1..20) {
    Start-Sleep -Milliseconds 500
    if (Get-Hotkeys) { $up = $true; break }
}
if ($up) { Write-Host '  - windots-hotkeys restarted' }
else { Write-Warning 'windots-hotkeys did not start: check that .ahk files open with AutoHotkey v2'; exit 1 }
