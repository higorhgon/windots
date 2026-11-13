# windots-restart-masir
# windots:summary=Restart masir, which makes the focus follow the mouse
# windots:examples=windots restart masir
#
# Like omarchy's omarchy-restart-* commands: stops masir and starts it again, the way
# `komorebic start --masir` does (a background process with no window). Also starts it when it
# was not running, so this is the way to get focus-follows-mouse back.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart masir --help)" -ForegroundColor Red; exit 2 }

$exe = (Get-Command masir.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $exe) { Write-Host 'masir is not installed: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }

$running = @(Get-Process masir -ErrorAction SilentlyContinue)
if ($running) {
    $running | Stop-Process -Force
    $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}
Start-Process $exe -WindowStyle Hidden

$up = $false
foreach ($i in 1..15) {
    Start-Sleep -Milliseconds 300
    if (Get-Process masir -ErrorAction SilentlyContinue) { $up = $true; break }
}
if ($up) { Write-Host '  - masir restarted (focus follows the mouse)' }
else { Write-Warning "masir did not start; run it by hand: $exe"; exit 1 }
