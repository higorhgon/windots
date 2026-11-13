# windots-restart-whkd
# windots:summary=Restart whkd, the hotkey daemon (it reads ~\.config\whkdrc only when it starts)
# windots:examples=windots restart whkd
#
# Like omarchy's omarchy-restart-* commands: after editing ~\.config\whkdrc, whkd must be
# restarted. The PATH is refreshed first, so the windots-* commands its hotkeys run are found
# (a whkd started from an old terminal does not see the PATH of windots-install).
# The first key right after a restart is sometimes dropped: press it again.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart whkd --help)" -ForegroundColor Red; exit 2 }

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')
$exe = (Get-Command whkd.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $exe) { Write-Host 'whkd is not installed: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }

$running = @(Get-Process whkd -ErrorAction SilentlyContinue)
if ($running) {
    $running | Stop-Process -Force
    $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
}
Start-Process $exe -WindowStyle Hidden

$up = $false
foreach ($i in 1..15) {
    Start-Sleep -Milliseconds 300
    if (Get-Process whkd -ErrorAction SilentlyContinue) { $up = $true; break }
}
if ($up) { Write-Host '  - whkd restarted (the first key may be dropped: press it again)' }
else { Write-Warning "whkd did not start; run it by hand: $exe"; exit 1 }
