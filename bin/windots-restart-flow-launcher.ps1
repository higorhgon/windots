# windots-restart-flow-launcher
# windots:summary=Restart Flow Launcher (it reads its settings only when it starts)
# windots:examples=windots restart flow launcher
#
# Like omarchy's omarchy-restart-* commands: closes Flow Launcher and opens it again, the way
# the startup shortcut does. Flow rewrites its Settings.json when it quits, so run this
# after windots-install-flow-launcher has merged the windots hotkeys: Flow then reads them.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart flow launcher --help)" -ForegroundColor Red; exit 2 }

# The launcher stub (as in the startup shortcut): it starts the current app-<version>.
$exe = Join-Path $env:LOCALAPPDATA 'FlowLauncher\Flow.Launcher.exe'
if (-not (Test-Path $exe)) { Write-Host 'Flow Launcher is not installed: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }

$running = @(Get-Process Flow.Launcher -ErrorAction SilentlyContinue)
if ($running) {
    foreach ($p in $running) { [void]$p.CloseMainWindow() }
    $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
    $left = @(Get-Process Flow.Launcher -ErrorAction SilentlyContinue)
    if ($left) { $left | Stop-Process -Force; $left | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue }
}
Start-Process $exe

$up = $false
foreach ($i in 1..20) {
    Start-Sleep -Milliseconds 500
    if (Get-Process Flow.Launcher -ErrorAction SilentlyContinue) { $up = $true; break }
}
if ($up) { Write-Host '  - Flow Launcher restarted' }
else { Write-Warning "Flow Launcher did not start; run it by hand: $exe"; exit 1 }
