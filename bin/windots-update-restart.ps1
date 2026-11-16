# windots-update-restart [--snapshot | <app> <app>...]
# windots:summary=Start again the apps an update closed (komorebi stack, switcher)
# windots:args=[--snapshot | <app> <app>...]
# windots:examples=windots update restart --snapshot | windots update restart whkd masir
#
# Like omarchy-update-restart --services-only, for Windows: an installer closes the app it is
# replacing, and nothing opens it again. So windots-update notes which of these apps are running before
# it upgrades anything, and afterwards starts the ones that are gone.
#   --snapshot   print the apps running now, one per line
#   <app>...     start each of these that is not running now (running ones are left alone)
# Apps: komorebi, whkd, masir, komorebi-switcher. komorebi comes first, since it brings
# whkd and masir with it. Left out on purpose: herdr-app (it is the person's session, and its installer
# does not close it) and anything else that is not a startup app.
# A start that fails is reported and does not stop the others.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

# app (= process name) -> the windots command that starts it
$apps = [ordered]@{
    'komorebi'          = 'windots-restart-komorebi.ps1'
    'whkd'              = 'windots-restart-whkd.ps1'
    'masir'             = 'windots-restart-masir.ps1'
    'komorebi-switcher' = 'windots-restart-komorebi-switcher.ps1'
}
function Test-Running($name) { [bool](Get-Process -Name $name -ErrorAction SilentlyContinue) }

if ($args.Count -eq 1 -and $args[0] -eq '--snapshot') {
    foreach ($n in $apps.Keys) { if (Test-Running $n) { $n } }
    exit 0
}

$wanted = @($args | ForEach-Object { [string]$_ })
foreach ($n in $wanted) {
    if (-not $apps.Contains($n)) { Write-Host "unknown app '$n' (one of: $($apps.Keys -join ', '))" -ForegroundColor Red; exit 2 }
}
$failed = 0
foreach ($n in $apps.Keys) {
    if ($wanted -notcontains $n) { continue }
    if (Test-Running $n) { Write-Host "  - $n is running"; continue }   # komorebi may have brought it back
    Write-Host "  - $n was closed: starting it again"
    $global:LASTEXITCODE = 0   # a script that ends without exit leaves the caller's old value
    & (Join-Path $PSScriptRoot $apps[$n])
    if ($LASTEXITCODE -ne 0) { Write-Warning "$n did not start again"; $failed++ }
}
if ($failed) { exit 1 }
exit 0
