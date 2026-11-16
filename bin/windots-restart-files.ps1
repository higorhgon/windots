# windots-restart-files [--if-running]
# windots:summary=Restart Files (it reads its colours only when it starts)
# windots:args=[--if-running]
# windots:examples=windots restart files | windots restart files --if-running
#
# Like omarchy's omarchy-restart-* commands: closes Files and starts it again, so the colours the theme
# wrote into its settings show up (Files restores its tabs). The window is asked to close first, then the
# process is stopped: Files keeps running in the background after its last window closes. Anything Files
# was copying is cut off. --if-running starts nothing when Files was not running (it takes the colours at
# its next start anyway).
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ifRunning = $false
foreach ($a in $args) {
    if ($a -eq '--if-running') { $ifRunning = $true }
    else { Write-Host "unknown option: $a (see windots restart files --help)" -ForegroundColor Red; exit 2 }
}

$alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\files-stable.exe'
if (-not (Test-Path $alias)) { Write-Host 'Files is not installed: run windots install files' -ForegroundColor Yellow; exit 1 }

$running = @(Get-Process -Name Files -ErrorAction SilentlyContinue)
if (-not $running.Count -and $ifRunning) { Write-Host '  - Files is not running: nothing to restart'; exit 0 }
if ($running.Count) {
    foreach ($p in $running) { [void]$p.CloseMainWindow() }
    $running | Wait-Process -Timeout 2 -ErrorAction SilentlyContinue
    $left = @(Get-Process -Name Files -ErrorAction SilentlyContinue)
    if ($left.Count) { $left | Stop-Process -Force; $left | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue }
}
Start-Process $alias

$up = $false
foreach ($i in 1..50) {
    Start-Sleep -Milliseconds 300
    if (Get-Process -Name Files -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }) { $up = $true; break }
}
if ($up) { Write-Host '  - Files restarted' }
else { Write-Warning "Files did not show a window; start it by hand: $alias"; exit 1 }
