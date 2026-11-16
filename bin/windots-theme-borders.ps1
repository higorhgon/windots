# windots-theme-borders
# windots:summary=Paint komorebi's window borders with the current theme (live, no restart)
# windots:examples=windots theme borders
#
# omarchy changes Hyprland's border colours when the theme changes. This does the same to the running komorebi
# (`komorebic border-colour`): active, stack and floating = the theme's active border or its accent, monocle = its
# orange, unfocused = its inactive border or #595959. windots-theme-set calls it, and windots-float-ontop calls it
# whenever komorebi comes up, since komorebi starts with the colours of komorebi.json.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots theme borders --help)" -ForegroundColor Red; exit 2 }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/themes.ps1')

$name = Get-CurrentThemeName
Write-Host "  - $(Set-KomorebiBorders (Read-ThemeColors $name))"
