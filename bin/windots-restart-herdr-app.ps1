# windots-restart-herdr-app [--force]
# windots:summary=Restart herdr-app (it reads keys, settings, layouts and mods only when it starts)
# windots:args=[--force]
# windots:examples=windots restart herdr app | windots restart herdr app --force
#
# Like omarchy's omarchy-restart-* commands: closes the herdr-app window and opens it again, so
# what windots-install-herdr-app or windots-update-herdr-app changed shows up. Only the window
# restarts: the terminals run in herdr-core, which keeps them (and the agents) alive.
# It closes the window the way the close button does, so herdr-app can save its state first.
#   --force   if the window has not closed after a few seconds (a confirmation dialog, say),
#             kill it
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$force = $args -contains '--force'
foreach ($a in $args) { if ($a -ne '--force') { Write-Host "unknown option: $a (see windots restart herdr app --help)" -ForegroundColor Red; exit 2 } }

$exe = (Get-Command herdr-app.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $exe) { $exe = Join-Path $env:LOCALAPPDATA 'Programs\herdr-app\herdr-app.exe' }
if (-not (Test-Path $exe)) {
    Write-Host 'herdr-app is not installed: run windots reinstall pkgs' -ForegroundColor Yellow
    exit 1
}

$running = @(Get-Process herdr-app -ErrorAction SilentlyContinue)
if ($running) {
    Write-Host '  - closing herdr-app (the terminals keep running in herdr-core)'
    foreach ($p in $running) { [void]$p.CloseMainWindow() }
    $running | Wait-Process -Timeout 8 -ErrorAction SilentlyContinue
    $left = @(Get-Process herdr-app -ErrorAction SilentlyContinue)
    if ($left) {
        if (-not $force) {
            Write-Warning 'herdr-app did not close (a confirmation dialog?): close it yourself, or run again with --force.'
            exit 1
        }
        $left | Stop-Process -Force
        $left | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
    }
}
Start-Process $exe
Write-Host '  - herdr-app started'
