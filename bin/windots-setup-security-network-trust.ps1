# windots-setup-security-network-trust [--trust | --untrust | --status]
# windots:summary=Mark the current Wi-Fi/network as Private (trusted) so the SSH firewall rule applies
# windots:args=[--trust | --untrust | --status]
# windots:examples=windots setup security network trust | windots setup security network trust --status | windots setup security network trust --untrust
#
# Windows sorts every network into Public or Private. The OpenSSH firewall rule covers Private
# only, so a network Windows calls Public (a company Wi-Fi, a café) blocks incoming ssh. This
# changes the category of the network you are on now (the one with the default route):
#   (no flag), --trust   mark the current network as Private
#   --untrust            mark it as Public again
#   --status             every connected network, its category, and which one is the current one
# Windows remembers the category per network: do it once for each network you trust.
#
# Needs admin: nothing is asked when there is nothing to change, otherwise the script re-runs
# itself through sudo (and turns sudo on first, with windots-setup-security-sudo, when it is off).
#
# What Private means: every device on that network can reach this computer's open ports (ssh on
# 22 when windots-setup-security-ssh is on) and Windows turns network discovery on. On a network
# shared with visitors that is a lot of people who could try your password: only trust networks
# you control, and prefer an SSH key to the account password.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\elevation.ps1')

$flags = @($args)
$known = '--trust', '--untrust', '--status', '--elevated'
foreach ($f in $flags) { if ($known -notcontains $f) { Write-Host "unknown option: $f (see windots setup security network trust --help)" -ForegroundColor Red; exit 2 } }
$action = @($flags | Where-Object { $_ -ne '--elevated' })
if ($action.Count -gt 1) { Write-Host 'pass only one of --trust, --untrust, --status' -ForegroundColor Red; exit 2 }
$mode = if ($action.Count) { $action[0] } else { '--trust' }
$elevated = $flags -contains '--elevated'   # internal: the sudo copy; the parent prints the status

# The interface of the default route with the lowest total metric: the network in use now.
function Get-CurrentIndex {
    $best = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | ForEach-Object {
        $m = (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
        [pscustomobject]@{ Index = $_.InterfaceIndex; Metric = [int]$_.RouteMetric + [int]$m }
    } | Sort-Object Metric | Select-Object -First 1
    if ($best) { $best.Index }
}

function Get-Current {
    $idx = Get-CurrentIndex
    if ($null -eq $idx) { return $null }
    Get-NetConnectionProfile -InterfaceIndex $idx -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Show-Status {
    $current = Get-Current
    $all = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
    if (-not $all.Count) { Write-Host '  !!  no connected network'; return }
    foreach ($p in $all) {
        $cat = "$($p.NetworkCategory)"
        $isCurrent = $current -and $p.InterfaceIndex -eq $current.InterfaceIndex
        $color = if ($cat -eq 'Public') { 'Yellow' } else { 'Green' }
        Write-Host ("  {0}  {1,-9} {2} ({3}){4}" -f $(if ($isCurrent) { '*' } else { ' ' }), $cat, $p.Name, $p.InterfaceAlias,
            $(if ($isCurrent) { '   <- current' } else { '' })) -ForegroundColor $color
    }
    Write-Host '  Private = trusted: the ssh firewall rule applies. Public = incoming connections blocked.'
}

if ($mode -eq '--status') { Show-Status; return }

$current = Get-Current
if (-not $current) { Write-Host 'No connected network found (no default route).' -ForegroundColor Yellow; exit 1 }
$category = "$($current.NetworkCategory)"
if ($category -eq 'DomainAuthenticated') {
    Write-Host "'$($current.Name)' is a domain network: its category is set by the domain, not here." -ForegroundColor Yellow
    exit 1
}

$wanted = if ($mode -eq '--trust') { 'Private' } else { 'Public' }
if ($category -eq $wanted) {
    Write-Host ("  - '{0}' ({1}) is already {2}" -f $current.Name, $current.InterfaceAlias, $wanted)
    if (-not $elevated) { Write-Host ''; Show-Status }
    return
}

if (-not (Test-Admin)) {
    Write-Host ("  - '{0}' ({1}): {2} -> {3}, needs admin" -f $current.Name, $current.InterfaceAlias, $category, $wanted)
    $code = Invoke-Elevated $PSCommandPath @($mode, '--elevated')
    if ($code -ne 0) { Write-Warning "the elevated step failed (exit $code); see above."; exit $code }
    Write-Host ''
    Show-Status
    return
}

Set-NetConnectionProfile -InterfaceIndex $current.InterfaceIndex -NetworkCategory $wanted
Write-Host ("  - '{0}' ({1}) is now {2}" -f $current.Name, $current.InterfaceAlias, $wanted)
if ($wanted -eq 'Private') {
    Write-Host '  - every device on this network can now reach this computer (ssh on port 22 if it is on).' -ForegroundColor Yellow
    Write-Host '    Visitors on a shared Wi-Fi included: prefer an SSH key to the account password.' -ForegroundColor Yellow
}
if (-not $elevated) { Write-Host ''; Show-Status }
