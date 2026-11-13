# windots-restart-komorebi-switcher
# windots:summary=Restart komorebi-switcher (it reads its toml only when it starts)
# windots:examples=windots restart komorebi switcher
#
# Like omarchy's omarchy-restart-* commands: stops komorebi-switcher and starts it again, so a
# change in ~\.config\komorebi-switcher.toml (position, colors) shows up. Called by
# windots-center-switcher after it writes the position.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart komorebi switcher --help)" -ForegroundColor Red; exit 2 }

$exe = Join-Path $env:LOCALAPPDATA 'Programs\komorebi-switcher\komorebi-switcher.exe'
if (-not (Test-Path $exe)) {
    Write-Host 'komorebi-switcher is not installed: run windots reinstall pkgs' -ForegroundColor Yellow
    exit 1
}

$running = @(Get-Process komorebi-switcher -ErrorAction SilentlyContinue)
if ($running) {
    $running | Stop-Process -Force
    $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}
Start-Process $exe

# It takes a moment to come up: wait until the process is there.
$up = $false
foreach ($i in 1..15) {
    Start-Sleep -Milliseconds 300
    if (Get-Process komorebi-switcher -ErrorAction SilentlyContinue) { $up = $true; break }
}
if ($up) { Write-Host '  - komorebi-switcher restarted' }
else { Write-Warning "komorebi-switcher did not start; run it by hand: $exe"; exit 1 }
