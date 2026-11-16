# windots-menu [toggle | summon | close | refresh | quit] [route]
# windots:summary=Open the windots menu (windots-launcher), like omarchy-menu
# windots:args=[toggle|summon|close|refresh|quit] [route]
# windots:examples=windots menu | windots menu summon style.theme | windots menu summon keys | windots menu close
#
# Like omarchy-menu: opens the windots-launcher menu, in the process that is already running (it keeps
# one, so the menu shows at once), or starts it. The route is a menu id (`style.theme`) or one of its
# aliases (`theme`, `keys`); without one it is the root menu. Verbs:
#   toggle [route]   open at the route, or close if it is open (default)
#   summon [route]   always open
#   close            close the menu        refresh   read the menu files again
#   quit             stop the launcher process
# The menu is in windots-launcher's menus\default.jsonc, extended by ~\.config\windots\menu.jsonc.
# Not installed? windots-install-launcher builds and installs it.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$exe = Join-Path $HOME '.local\share\windots-launcher\windots-launcher.exe'
if (-not (Test-Path $exe)) {
    Write-Host 'windots-launcher is not installed: run windots install launcher' -ForegroundColor Yellow
    exit 1
}
$words = @($args | ForEach-Object { [string]$_ })
if ($words.Count) { Start-Process -FilePath $exe -ArgumentList $words } else { Start-Process -FilePath $exe }
exit 0
