# windots-restart-float-ontop
# windots:summary=Restart windots-float-ontop, which keeps floating windows above tiled ones
# windots:examples=windots restart float ontop
#
# Like omarchy's omarchy-restart-* commands: stops windots-float-ontop and starts it again,
# the way its startup shortcut does (a headless pwsh, no console window). It listens to
# komorebi through a named pipe, so it has to be restarted whenever komorebi is
# (windots-restart-komorebi does that). Also starts it when it was not running.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart float ontop --help)" -ForegroundColor Red; exit 2 }

$script = Join-Path $PSScriptRoot 'windots-float-ontop.ps1'
# pwsh 7 comes from the MSI (Program Files) or the Store/winget package (an alias in WindowsApps).
$pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $pwsh) { $pwsh = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
if (-not (Test-Path $pwsh)) { Write-Host 'pwsh 7 not found: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }

function Get-OnTop { @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*windots-float-ontop.ps1*' }) }

$running = Get-OnTop
if ($running) {
    foreach ($p in $running) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    $running | ForEach-Object { Wait-Process -Id $_.ProcessId -Timeout 5 -ErrorAction SilentlyContinue }
}
# conhost --headless: with Windows Terminal as the default terminal, -WindowStyle Hidden can't
# hide the console and a tab stays open.
Start-Process (Join-Path $env:SystemRoot 'System32\conhost.exe') -WindowStyle Hidden `
    -ArgumentList "--headless `"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$script`""

$up = $false
foreach ($i in 1..20) {
    Start-Sleep -Milliseconds 500
    if (Get-OnTop) { $up = $true; break }
}
if ($up) { Write-Host '  - windots-float-ontop restarted' }
else { Write-Warning "windots-float-ontop did not start; run it by hand: $pwsh -File $script"; exit 1 }
