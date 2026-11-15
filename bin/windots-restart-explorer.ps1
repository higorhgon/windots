# windots-restart-explorer
# windots:summary=Restart Windows Explorer (taskbar, desktop) and the komorebi-switcher that lives on it
# windots:examples=windots restart explorer
#
# Like omarchy's omarchy-restart-* commands, for the Windows shell: some settings (taskbar colour,
# accent colour, icons) are read only when Explorer starts. This stops explorer.exe, waits for Windows
# to start it again (the shell restarts by itself; if it does not within 8 s, it is started here) and
# then restarts komorebi-switcher, which draws on the taskbar and is lost with it.
# File Explorer windows close and the taskbar blinks for a moment. komorebi is not touched.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots restart explorer --help)" -ForegroundColor Red; exit 2 }

$switcher = [bool](Get-Process -Name komorebi-switcher -ErrorAction SilentlyContinue)
$old = @(Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

function Get-NewExplorer { @(Get-Process -Name explorer -ErrorAction SilentlyContinue | Where-Object { $old -notcontains $_.Id }) }
$up = $false
foreach ($i in 1..16) {
    Start-Sleep -Milliseconds 500
    if (Get-NewExplorer) { $up = $true; break }
}
if (-not $up) {
    Start-Process explorer.exe
    foreach ($i in 1..16) { Start-Sleep -Milliseconds 500; if (Get-NewExplorer) { $up = $true; break } }
}
if (-not $up) { Write-Warning 'Explorer did not start again; run explorer.exe by hand'; exit 1 }
Write-Host '  - Explorer restarted'

if ($switcher) {
    Start-Sleep -Seconds 2   # let the taskbar finish drawing before the switcher attaches to it
    & (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1')
}
exit 0
