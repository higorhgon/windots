# windots-restart-komorebi [--only]
# windots:summary=Restart komorebi with whkd and masir, and what listens to komorebi
# windots:args=[--only]
# windots:examples=windots restart komorebi | windots restart komorebi --only
#
# Like omarchy's omarchy-restart-* commands: stops komorebi and starts it again the way the
# startup shortcut does (`komorebic start --whkd --masir`, so whkd and masir restart too), which
# is what a change in ~\komorebi.json or applications.json needs.
# Every window is managed again from scratch: tiles are redone and floating overrides and
# per-workspace layers are lost, so use it when you mean it.
# komorebi-switcher and windots-float-ontop subscribe to komorebi when they start, so the ones
# that were running are restarted after it (--only leaves them alone).
#   --only   restart komorebi, whkd and masir only
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$only = $args -contains '--only'
foreach ($a in $args) { if ($a -ne '--only') { Write-Host "unknown option: $a (see windots restart komorebi --help)" -ForegroundColor Red; exit 2 } }

$komorebic = (Get-Command komorebic.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $komorebic) { Write-Host 'komorebi is not installed: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }
# The startup shortcut uses the no-console build: no console window flashes.
$startExe = Join-Path (Split-Path $komorebic) 'komorebic-no-console.exe'
if (-not (Test-Path $startExe)) { $startExe = $komorebic }

# What listens to komorebi, noted before anything stops.
$hadSwitcher = [bool](Get-Process komorebi-switcher -ErrorAction SilentlyContinue)
$hadOnTop = [bool](Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*windots-float-ontop.ps1*' })

Write-Host '  - stopping komorebi, whkd and masir (hidden windows are restored)'
& $komorebic stop --whkd --masir 2>&1 | Out-Null
$gone = $false
foreach ($i in 1..20) {
    if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) { $gone = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $gone) {
    Write-Warning 'komorebi did not stop: killing it'
    Get-Process komorebi -ErrorAction SilentlyContinue | Stop-Process -Force
}

Write-Host '  - starting komorebi, whkd and masir'
& $startExe start --whkd --masir 2>&1 | Out-Null

# It is up when it answers.
$up = $false
foreach ($i in 1..30) {
    Start-Sleep -Milliseconds 500
    if (Get-Process komorebi -ErrorAction SilentlyContinue) {
        $null = & $komorebic state 2>&1
        if ($LASTEXITCODE -eq 0) { $up = $true; break }
    }
}
if (-not $up) { Write-Warning 'komorebi did not come back: run `komorebic start --whkd --masir` by hand'; exit 1 }
Write-Host '  - komorebi restarted'

if (-not $only) {
    if ($hadOnTop) { & (Join-Path $PSScriptRoot 'windots-restart-float-ontop.ps1') }
    if ($hadSwitcher) { & (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1') }
}
