# windots-setup-security-ssh [--enable-ssh | --disabled-ssh | --status | --allow-user-links | --block-user-links] [--shell=pwsh|powershell|cmd]
# windots:summary=Install the OpenSSH client and server if missing, turn the SSH server on, and make pwsh its shell
# windots:args=[--enable-ssh | --disabled-ssh | --status | --allow-user-links | --block-user-links] [--shell=pwsh|powershell|cmd]
# windots:examples=windots setup security ssh | windots setup security ssh --status | windots setup security ssh --shell=cmd | windots setup security ssh --allow-user-links | windots setup security ssh --disabled-ssh
#
# Like omarchy-setup-security-sshd / omarchy-remove-security-sshd, for Windows:
#   (no flag), --enable-ssh    make sure both OpenSSH features are installed (client and server;
#                              Windows optional features, needs internet), start sshd, make it start
#                              with Windows and open port 22 (the OpenSSH-Server-In-TCP firewall rule)
#   --disabled-ssh             stop sshd, set it to Disabled and close the firewall rule; the client
#                              stays (it is also what `ssh` is)
#   --disable-ssh              the same as --disabled-ssh
#   --status                   what is installed, the service, the firewall, the network, how to connect
#   --shell=pwsh|powershell|cmd  the shell an ssh login opens (default pwsh; Windows' own default is cmd).
#                              pwsh is PowerShell 7 (the MSI install, else the one on PATH, else Windows
#                              PowerShell); the choice is checked to start before it is saved, and
#                              --shell=cmd puts Windows' default back. It applies to the next login.
#                              scp (the old protocol) runs through that shell, so noisy profile output
#                              can break it: sftp and ssh itself are fine.
#   --allow-user-links         let ssh sessions follow links and junctions made by a normal user
#                              (turns RedirectionGuard off for sshd.exe only, then restarts sshd: ssh
#                              sessions open at that moment are closed). Needed for this setup's dotfile
#                              links and for tools installed through links (winget's mise.exe, mise's
#                              "latest" junctions), which fail in an ssh session with "untrusted mount
#                              point" otherwise. It is a security trade-off, so it is never done by the
#                              default run: RedirectionGuard stops a low-privileged local user from
#                              planting a link that a privileged process follows; with it off, that is
#                              possible again inside processes started by sshd. Reasonable on a
#                              single-user machine, better with key-only logins. Windows updates of
#                              OpenSSH can turn it back on: run this again then.
#   --block-user-links         turn RedirectionGuard back on for sshd.exe (the undo)
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
$known = '--enable-ssh', '--disabled-ssh', '--disable-ssh', '--status', '--allow-user-links', '--block-user-links', '--elevated'
$shellChoice = 'pwsh'
$shellFlag = @()
foreach ($f in $flags) {
    if ($f -like '--shell=*') {
        $shellChoice = $f.Substring(8)
        if ('pwsh', 'powershell', 'cmd' -notcontains $shellChoice) { Write-Host "unknown shell '$shellChoice' (pwsh, powershell or cmd)" -ForegroundColor Red; exit 2 }
        $shellFlag = @($f)
    }
}
foreach ($f in $flags) { if ($f -like '--shell=*') { continue }; if ($known -notcontains $f) { Write-Host "unknown option: $f (see windots setup security ssh --help)" -ForegroundColor Red; exit 2 } }
$action = @($flags | Where-Object { $_ -ne '--elevated' -and $_ -notlike '--shell=*' })
if ($action.Count -gt 1) { Write-Host 'pass only one of --enable-ssh, --disabled-ssh, --status, --allow-user-links, --block-user-links' -ForegroundColor Red; exit 2 }
$mode = if ($action.Count) { $action[0] } else { '--enable-ssh' }
if ($mode -eq '--disable-ssh') { $mode = '--disabled-ssh' }
$elevated = $flags -contains '--elevated'   # internal: the sudo copy; the parent prints the status

$openssh = Join-Path $env:SystemRoot 'System32\OpenSSH'
$features = @(
    @{ Name = 'OpenSSH.Client~~~~0.0.1.0'; File = 'ssh.exe';  Label = 'client' }
    @{ Name = 'OpenSSH.Server~~~~0.0.1.0'; File = 'sshd.exe'; Label = 'server' }
)
$ruleName = 'OpenSSH-Server-In-TCP'

# RedirectionGuard (Windows' RedirectionTrust mitigation) is on for sshd.exe: its bit is byte 18 (0x10)
# of the 19-byte MitigationOptions value under the Image File Execution Options key of sshd.exe, and
# every ssh session inherits it. Readable without admin.
$guardKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sshd.exe'
$guardByte = 18
$guardBit = 0x10
function Get-GuardOn {
    $b = @((Get-ItemProperty $guardKey -ErrorAction SilentlyContinue).MitigationOptions)
    [bool]($b.Count -gt $guardByte -and ($b[$guardByte] -band $guardBit))
}

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
        # A listener is a port-22 entry with remote port 0. Not -State Listen: sshd sometimes listens on [::] only
        # (it takes IPv4 too) and Get-NetTCPConnection then gives that listener an empty state; and .NET
        # Framework's GetActiveTcpListeners (Windows PowerShell 5.1) leaves IPv6 listeners out.
        Listening = [bool](Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Where-Object { $_.RemotePort -eq 0 })
        Shell     = [string](Get-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -ErrorAction SilentlyContinue).DefaultShell
        GuardOn   = Get-GuardOn
    }
}

# The path of the shell for --shell=..., or '' for Windows' default (cmd). pwsh: the MSI install, else the
# one on PATH (a Store install is an alias in the user's WindowsApps: it only works for that user),
# else Windows PowerShell.
function Resolve-Shell($choice) {
    $winps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($choice -eq 'cmd') { return '' }
    if ($choice -eq 'powershell') { return $winps }
    $msi = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (Test-Path $msi) { return $msi }
    $onPath = (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($onPath) { return $onPath }
    $winps
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
    $shellNow = if ($s.Shell) { $s.Shell } else { 'cmd.exe (Windows default)' }
    Line ([bool]$s.Shell) "login shell: $shellNow"
    if ($s.GuardOn) {
        Line $false 'RedirectionGuard on for sshd: ssh sessions cannot follow links or junctions made by a normal user ("untrusted mount point")'
        Write-Host '      to allow it (a security trade-off, see --help): windots setup security ssh --allow-user-links'
    } else {
        Line $true 'RedirectionGuard off for sshd: ssh sessions follow links and junctions (undo: --block-user-links)'
    }

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
    if ($mode -eq '--allow-user-links') { return (-not $s.GuardOn) }
    if ($mode -eq '--block-user-links') { return $s.GuardOn }
    if ($mode -eq '--enable-ssh') { return ($s.Client -and $s.Server -and $s.Running -and $s.StartType -eq 'Automatic' -and $s.RuleOn -and $s.Shell -eq (Resolve-Shell $shellChoice)) }
    # disabled: nothing running, never starting, port closed
    return (-not $s.Running -and (-not $s.Service -or $s.StartType -eq 'Disabled') -and -not $s.RuleOn)
}

if ($mode -eq '--status') { Show-Status; return }

if (Test-Wanted (Get-SshState)) {
    $done = switch ($mode) { '--enable-ssh' { 'ssh already enabled' } '--disabled-ssh' { 'ssh already disabled' } '--allow-user-links' { 'RedirectionGuard already off for sshd' } default { 'RedirectionGuard already on for sshd' } }
    Write-Host "  - $done"
    if (-not $elevated) { Show-Status }
    return
}

# Everything below needs admin.
if (-not (Test-Admin)) {
    $doing = switch ($mode) { '--enable-ssh' { 'setting up the SSH server' } '--disabled-ssh' { 'turning off the SSH server' } '--allow-user-links' { 'turning RedirectionGuard off for sshd' } default { 'turning RedirectionGuard on for sshd' } }
    Write-Host "  - ${doing}: needs admin"
    $code = Invoke-Elevated $PSCommandPath (@($mode, '--elevated') + $shellFlag)
    if ($code -ne 0) { Write-Warning "the elevated step failed (exit $code); see above."; exit $code }
    Write-Host ''
    Show-Status
    return
}

if ($mode -eq '--allow-user-links' -or $mode -eq '--block-user-links') {
    # Only the RedirectionTrust bit changes; every other byte of the value stays as Windows wrote it.
    $b = [byte[]]@((Get-ItemProperty $guardKey -ErrorAction SilentlyContinue).MitigationOptions)
    if ($b.Count -le $guardByte) { $b = New-Object byte[] ($guardByte + 1) }
    $b[$guardByte] = if ($mode -eq '--allow-user-links') { [byte]($b[$guardByte] -band (0xFF -bxor $guardBit)) } else { [byte]($b[$guardByte] -bor $guardBit) }
    if (-not (Test-Path $guardKey)) { New-Item -Path $guardKey -Force | Out-Null }
    New-ItemProperty -Path $guardKey -Name MitigationOptions -PropertyType Binary -Value $b -Force | Out-Null
    if ($mode -eq '--allow-user-links') {
        Write-Host '  - RedirectionGuard off for sshd.exe: ssh sessions follow links and junctions again'
        Write-Host '    (the trade-off: a local low-privileged user could plant a link that a process started by sshd follows)' -ForegroundColor Yellow
    } else { Write-Host '  - RedirectionGuard on for sshd.exe again' }
    # The setting is read when sshd starts a session's process tree: restart it (open ssh sessions close).
    if ((Get-Service sshd -ErrorAction SilentlyContinue).Status -eq 'Running') {
        Write-Host '  - sshd restarted (new ssh logins use the new setting)'
        Restart-Service sshd -Force
    }
} elseif ($mode -eq '--enable-ssh') {
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
    $shell = Resolve-Shell $shellChoice
    $key = 'HKLM:\SOFTWARE\OpenSSH'
    if ($shell) {
        # A shell that does not start would lock every ssh login out: prove it runs first.
        $probe = (cmd.exe /c "`"$shell`" -NoProfile -NoLogo -Command `"Write-Output windots-ok`" 2>&1") -join ' '
        if ($probe -notmatch 'windots-ok') {
            Write-Warning "$shell did not start ($probe): the login shell stays as it is. Use --shell=powershell or --shell=cmd."
        } else {
            Write-Host "  - login shell: $shell"
            if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
            New-ItemProperty -Path $key -Name DefaultShell -Value $shell -PropertyType String -Force | Out-Null
        }
    } else {
        Write-Host '  - login shell: cmd.exe (Windows default)'
        Remove-ItemProperty -Path $key -Name DefaultShell -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $key -Name DefaultShellCommandOption -ErrorAction SilentlyContinue
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
