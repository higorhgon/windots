# windots-setup-security-ssh [--enable-ssh | --disabled-ssh | --status]
# windots:summary=Install the OpenSSH client and server if missing and turn the SSH server on
# windots:args=[--enable-ssh | --disabled-ssh | --status]
# windots:examples=windots setup security ssh | windots setup security ssh --status | windots setup security ssh --disabled-ssh
#
# Like omarchy-setup-security-sshd / omarchy-remove-security-sshd, for Windows:
#   (no flag), --enable-ssh    make sure both OpenSSH features are installed (client and server;
#                              Windows optional features, needs internet), start sshd, make it start
#                              with Windows and open port 22 (the OpenSSH-Server-In-TCP firewall rule)
#   --disabled-ssh             stop sshd, set it to Disabled and close the firewall rule; the client
#                              stays (it is also what `ssh` is)
#   --disable-ssh              the same as --disabled-ssh
#   --status                   what is installed, the service, the firewall, the network, how to connect
#
# Installing the features, changing the service and the firewall need admin: nothing is asked
# when there is nothing to change, otherwise the script re-runs itself through sudo (and turns
# sudo on first, with windots-setup-security-sudo, when it is off).
# The firewall rule Windows ships covers the Private profile only: on a Public network (a café's
# Wi-Fi) the server is not reachable, on purpose. --status says when that is the case.
# Passwords are accepted by default; add an SSH key to use keys (--status says where it goes).
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\elevation.ps1')

$flags = @($args)
$known = '--enable-ssh', '--disabled-ssh', '--disable-ssh', '--status', '--elevated'
foreach ($f in $flags) { if ($known -notcontains $f) { Write-Host "unknown option: $f (see windots setup security ssh --help)" -ForegroundColor Red; exit 2 } }
$action = @($flags | Where-Object { $_ -ne '--elevated' })
if ($action.Count -gt 1) { Write-Host 'pass only one of --enable-ssh, --disabled-ssh, --status' -ForegroundColor Red; exit 2 }
$mode = if ($action.Count) { $action[0] } else { '--enable-ssh' }
if ($mode -eq '--disable-ssh') { $mode = '--disabled-ssh' }
$elevated = $flags -contains '--elevated'   # internal: the sudo copy; the parent prints the status

$openssh = Join-Path $env:SystemRoot 'System32\OpenSSH'
$features = @(
    @{ Name = 'OpenSSH.Client~~~~0.0.1.0'; File = 'ssh.exe';  Label = 'client' }
    @{ Name = 'OpenSSH.Server~~~~0.0.1.0'; File = 'sshd.exe'; Label = 'server' }
)
$ruleName = 'OpenSSH-Server-In-TCP'

# Everything here is readable without admin (the installed features are told by their files:
# Get-WindowsCapability itself needs admin).
function Get-SshState {
    $svc = Get-Service sshd -ErrorAction SilentlyContinue
    $rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Client    = Test-Path (Join-Path $openssh 'ssh.exe')
        Server    = Test-Path (Join-Path $openssh 'sshd.exe')
        Service   = $svc
        Running   = [bool]($svc -and $svc.Status -eq 'Running')
        StartType = $(if ($svc) { "$($svc.StartType)" } else { '' })
        Rule      = $rule
        RuleOn    = [bool]($rule -and "$($rule.Enabled)" -eq 'True')
        Listening = [bool](Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue)
    }
}

function Show-Status {
    $s = Get-SshState
    function Line($ok, $text) {
        if ($ok) { Write-Host "  ok  $text" -ForegroundColor Green } else { Write-Host "  !!  $text" -ForegroundColor Yellow }
    }
    Line $s.Client $(if ($s.Client) { 'client installed (' + (cmd.exe /c "`"$(Join-Path $openssh 'ssh.exe')`" -V 2>&1") + ')' } else { 'client not installed' })
    Line $s.Server $(if ($s.Server) { 'server installed' } else { 'server not installed' })
    if ($s.Service) {
        Line ($s.Running -and $s.StartType -eq 'Automatic') "sshd service: $($s.Service.Status), starts $($s.StartType)"
    } else { Line $false 'sshd service: not there' }
    $profiles = if ($s.Rule) { "$($s.Rule.Profile)" } else { '' }
    Line $s.RuleOn $(if ($s.Rule) { "firewall rule ${ruleName}: $(if ($s.RuleOn) { 'enabled' } else { 'disabled' }) ($profiles networks)" } else { "firewall rule ${ruleName}: missing" })
    Line $s.Listening $(if ($s.Listening) { 'port 22: listening' } else { 'port 22: nobody is listening' })

    # The shipped rule is Private only: a Public network never reaches the server.
    if ($s.Rule -and $profiles -notmatch 'Any|Public') {
        foreach ($c in @(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { "$($_.NetworkCategory)" -eq 'Public' })) {
            Write-Host ("  !!  network '{0}' ({1}) is Public: the firewall rule covers Private only, so ssh is blocked there." -f $c.Name, $c.InterfaceAlias) -ForegroundColor Yellow
            Write-Host '      if you trust that network: windots setup security network trust'
        }
    }

    $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object IPAddress)
    Write-Host ''
    Write-Host "  user:    $env:USERNAME   (computer: $env:COMPUTERNAME)"
    Write-Host ("  connect: ssh {0}@{1}" -f $env:USERNAME, $(if ($ips.Count) { $ips[0] } else { $env:COMPUTERNAME }))
    if ($ips.Count -gt 1) { Write-Host ("           other addresses: {0}" -f ($ips[1..($ips.Count - 1)] -join ', ')) }
    # Windows reads an administrator's keys from one shared file, anyone else's from ~\.ssh.
    $keys = if (Test-AdminAccount) { Join-Path $env:ProgramData 'ssh\administrators_authorized_keys' } else { Join-Path $HOME '.ssh\authorized_keys' }
    $n = if (Test-Path $keys) { @(Get-Content $keys | Where-Object { $_.Trim() -and $_ -notmatch '^\s*#' }).Count } else { 0 }
    Write-Host "  keys:    $n in $keys"
    if (-not $n) { Write-Host '           (no key yet: logins use the account password)' }
}

function Test-Wanted($s) {
    if ($mode -eq '--enable-ssh') { return ($s.Client -and $s.Server -and $s.Running -and $s.StartType -eq 'Automatic' -and $s.RuleOn) }
    # disabled: nothing running, never starting, port closed
    return (-not $s.Running -and (-not $s.Service -or $s.StartType -eq 'Disabled') -and -not $s.RuleOn)
}

if ($mode -eq '--status') { Show-Status; return }

if (Test-Wanted (Get-SshState)) {
    Write-Host ("  - ssh already {0}" -f $(if ($mode -eq '--enable-ssh') { 'enabled' } else { 'disabled' }))
    if (-not $elevated) { Show-Status }
    return
}

# Everything below needs admin.
if (-not (Test-Admin)) {
    Write-Host ("  - {0} the SSH server: needs admin" -f $(if ($mode -eq '--enable-ssh') { 'setting up' } else { 'turning off' }))
    $code = Invoke-Elevated $PSCommandPath @($mode, '--elevated')
    if ($code -ne 0) { Write-Warning "the elevated step failed (exit $code); see above."; exit $code }
    Write-Host ''
    Show-Status
    return
}

if ($mode -eq '--enable-ssh') {
    $restart = $false
    foreach ($f in $features) {
        if (Test-Path (Join-Path $openssh $f.File)) { Write-Host "  - OpenSSH $($f.Label) already installed"; continue }
        Write-Host "  - installing OpenSSH $($f.Label) (a Windows feature: needs internet, takes a minute)"
        $r = Add-WindowsCapability -Online -Name $f.Name
        if ($r.RestartNeeded) { $restart = $true }
        if (-not (Test-Path (Join-Path $openssh $f.File))) { throw "OpenSSH $($f.Label) did not install; try: Add-WindowsCapability -Online -Name $($f.Name)" }
    }

    Write-Host '  - sshd: starts with Windows, running now'
    Set-Service sshd -StartupType Automatic
    if ((Get-Service sshd).Status -ne 'Running') {
        try { Start-Service sshd }
        catch { throw "sshd did not start ($($_.Exception.Message)); check the config with: & '$openssh\sshd.exe' -t" }
    }

    Write-Host "  - firewall: port 22 open ($ruleName)"
    if (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue) { Enable-NetFirewallRule -Name $ruleName }
    else {
        New-NetFirewallRule -Name $ruleName -DisplayName 'OpenSSH SSH Server (sshd)' -Enabled True -Direction Inbound `
            -Protocol TCP -Action Allow -LocalPort 22 -Profile Private, Domain | Out-Null
    }
    if ($restart) { Write-Warning 'Windows asked for a restart to finish installing OpenSSH.' }
} else {
    Write-Host '  - sshd: stopped, will not start'
    if (Get-Service sshd -ErrorAction SilentlyContinue) {
        Stop-Service sshd -Force -ErrorAction SilentlyContinue
        Set-Service sshd -StartupType Disabled
    }
    Write-Host "  - firewall: port 22 closed ($ruleName)"
    if (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue) { Disable-NetFirewallRule -Name $ruleName }
    Write-Host '  - the client stays installed (it is also what ssh is); authorized keys are untouched'
}

if (-not $elevated) { Write-Host ''; Show-Status }
