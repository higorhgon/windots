# windots-theme-current
# windots:summary=Print the name of the current theme
# windots:examples=windots theme current
#
# Like omarchy-theme-current. The name is kept in ~\.local\state\windots\theme.name; catppuccin
# when no theme was ever set.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots theme current --help)" -ForegroundColor Red; exit 2 }
. (Join-Path $PSScriptRoot 'lib\themes.ps1')
Get-CurrentThemeName
exit 0
