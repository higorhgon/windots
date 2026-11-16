# windots-theme-list [--names | --preview <name>]
# windots:summary=List the omarchy themes windots has (the current one is marked)
# windots:args=[--names | --preview <name>]
# windots:examples=windots theme list | windots theme list --names | windots theme list --preview tokyo-night
#
# Like omarchy-theme-list. Each line is the theme name, its mode and a strip of its colours; the
# current theme has a *.
#   --names            only the names (for scripts and menus)
#   --preview <name>   the palette of one theme, drawn in the terminal (the menu's preview)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\themes.ps1')

$esc = [char]27
function Get-Swatch($hex, $width = 2) {
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16); $g = [Convert]::ToInt32($hex.Substring(3, 2), 16); $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
    "$esc[48;2;$r;$g;${b}m$(' ' * $width)$esc[0m"
}

if ($args[0] -eq '--preview') {
    $n = Resolve-ThemeName (@($args | Select-Object -Skip 1) -join ' ')
    if (-not $n) { exit 1 }
    $c = Read-ThemeColors $n
    "$(Get-ThemeTitle $n)  ($($c.mode))"
    ''
    foreach ($k in 'background', 'foreground', 'accent', 'muted', 'selection') { '{0}  {1,-11} {2}' -f (Get-Swatch $c[$k] 6), $k, $c[$k] }
    ''
    (('red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'magenta') | ForEach-Object { Get-Swatch $c[$_] 4 }) -join ' '
    exit 0
}
if ($args.Count -and $args[0] -ne '--names') { Write-Host "unknown option: $($args -join ' ') (see windots theme list --help)" -ForegroundColor Red; exit 2 }

$current = Get-CurrentThemeName
foreach ($n in Get-ThemeNames) {
    if ($args[0] -eq '--names') { $n; continue }
    $c = Read-ThemeColors $n
    $strip = (('background', 'accent', 'red', 'yellow', 'green', 'blue', 'magenta') | ForEach-Object { Get-Swatch $c[$_] }) -join ''
    '{0} {1,-18} {2,-5} {3}' -f $(if ($n -eq $current) { '*' } else { ' ' }), $n, $c.mode, $strip
}
exit 0
