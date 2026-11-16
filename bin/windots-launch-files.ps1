# windots-launch-files
# windots:summary=Open the file manager: Files (focus it if open) when installed, else Explorer
# windots:examples=windots launch files
#
# The Alt+Shift+F hotkey (omarchy's Super+Shift+F opens nautilus). Files is the file manager that
# takes the theme (windots install files); on a machine without it this opens Explorer.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots launch files --help)" -ForegroundColor Red; exit 2 }

$alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\files-stable.exe'
if (Test-Path $alias) { & (Join-Path $PSScriptRoot 'windots-launch-or-focus.ps1') '^(Files)$' $alias }
else { Start-Process explorer.exe }
