# windots-uri <windots:action>
# windots:summary=Run a windots: link (what a clicked notification opens); only listed actions run
# windots:args=<windots:action>
# windots:examples=windots uri windots:restart-files
#
# The handler of the windots: protocol (registered in HKCU by windots-install-files / windots-theme-set).
# A link can come from anywhere, a web page too, so only the actions below run, with no arguments taken
# from the link:
#   windots:restart-files   restart Files if it is running (to apply the theme's colours)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$uri = [string]$args[0]
if ($uri -notmatch '^windots:/{0,2}([a-z-]+)/?$') { Write-Host "not a windots: link: $uri" -ForegroundColor Red; exit 2 }
switch ($Matches[1]) {
    'restart-files' { & (Join-Path $PSScriptRoot 'windots-restart-files.ps1') --if-running }
    default { Write-Host "unknown windots: action '$($Matches[1])'" -ForegroundColor Red; exit 2 }
}
