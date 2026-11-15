# windots-setup-wsl [--user=<name>] [--distro=<name>] [--skip-tools] [--reinstall] [-y] [--network=mirrored|nat] [--lan-ports=<ports>] [--check]
# windots:summary=Install WSL if missing and set up Arch Linux on it with a sudo user, bash and the windots mise tools
# windots:args=[--user=<name>] [--distro=<name>] [--skip-tools] [--reinstall] [-y] [--network=mirrored|nat] [--lan-ports=<ports>] [--check]
# windots:examples=windots setup wsl | windots setup wsl --check | windots setup wsl --user=higor --skip-tools | windots setup wsl --network=mirrored --lan-ports=2222,8080 | windots setup wsl --reinstall -y
#
# Gets an Arch Linux distro on WSL ready to work in, the windots way:
#   1. WSL: installed when missing (wsl --install --no-distribution, one UAC prompt). A restart is only
#      needed when no hypervisor is running yet (WSL 2 needs one, and it starts at boot): then the setup
#      is scheduled to continue by itself when you sign in again (a RunOnce entry that opens a terminal).
#      With a hypervisor already running (Docker Desktop, Windows Sandbox...) there is no restart at all.
#   2. the distro (default archlinux) is installed when missing (wsl --install archlinux --no-launch)
#   3. you give a user name and a password; Arch's WSL image only has root, and no sudo
#   4. inside it (default\wsl\setup.sh): the pacman keyring and a system update, sudo, base-devel, the
#      en_US and pt_BR locales, git, mise; that user in the wheel group with sudo (asking for its
#      password); that user as the WSL default; the windots mise and starship configs and the Claude
#      commit-message skill linked from this repo (the Claude settings are not: they are for Windows);
#      a ~/.bashrc block; and `mise install` for the tools of the windots config
#   5. the distro is stopped so the new default user applies, and the result is checked
# Safe to run again: the user, the packages and the links are only brought up to date.
#   --user=<name>    the Linux user (asked when missing; lowercase letters, digits, - and _)
#   --distro=<name>  another distro name (default archlinux)
#   --skip-tools     leave `mise install` out (the tools take a while; run mise install later)
#   --reinstall      DELETES the distro and everything in it, installs it again, then sets it up;
#                    asks you to type its name first, unless -y
#   -y               no questions for --reinstall
#   --check          show what is installed, the network mode and what this would do; change nothing
# Network (opt in; the default stays NAT, which is what WSL does without a ~\.wslconfig):
#   --network=mirrored   WSL shares the Windows network interfaces (Windows 11 22H2+): its services answer
#                        at the Windows IP, and localhost works both ways. It does NOT get an IP of its
#                        own: "bridged" (own IP on the LAN) is deprecated since WSL 2.4.5 and needs a
#                        Hyper-V external switch, which Windows Home does not have. The Windows and WSL
#                        port spaces are one: a WSL sshd cannot use 22 while the Windows sshd does.
#   --network=nat        back to the default (removes the line from ~\.wslconfig)
#   --lan-ports=22,8080  open those TCP ports of the WSL VM to the network (a Hyper-V firewall rule per
#                        port, named windots-wsl-<port>; one UAC prompt). Needs mirrored. Nothing is open
#                        unless listed, and an open port is reachable by everyone on the network, visitors
#                        included. --lan-ports=none removes every rule windots made. Not verified: whether
#                        Windows Defender Firewall or the network being Public also stops it.
# With only network options (no --user, --distro, --skip-tools, --reinstall) nothing else is touched: no
# distro steps and no password. Changing the network mode runs `wsl --shutdown` (all distros stop).
# The password is asked twice (hidden). Without a terminal, set WINDOTS_WSL_PASSWORD (and --user).
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\elevation.ps1')

# The Hyper-V "creator id" of the WSL VM: the firewall rules for WSL name it.
$wslVmCreatorId = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
$runOnceKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'

# ---------------------------------------------------------------- pure helpers (unit-testable)

# What step 1 must do. Hypervisor running = WSL 2 can start now, whatever else happened.
function Resolve-WslAction($installed, $hypervisor, $restartPending, $justInstalled) {
    if (-not $installed) { return 'install' }
    if ($hypervisor) { return 'ready' }
    if ($justInstalled -or $restartPending) { return 'restart' }
    'virtualization-off'   # installed, nothing pending, still no hypervisor: not a restart problem
}

# "22, 8080" / "22,8080" / "none" -> sorted unique port numbers; "none" -> an empty list; bad -> $null.
function ConvertTo-PortList([string]$text) {
    if ($text.Trim() -ieq 'none') { return , @() }
    $ports = @()
    foreach ($p in ($text -split '[,;\s]+' | Where-Object { $_ })) {
        if ($p -notmatch '^\d{1,5}$' -or [int]$p -lt 1 -or [int]$p -gt 65535) { return $null }
        $ports += [int]$p
    }
    if (-not $ports.Count) { return $null }
    , @($ports | Sort-Object -Unique)
}

# Set (or, with $null, remove) key=value in [section] of an INI text. Everything else stays: other
# lines, comments, sections, and the file's line endings. Returns the new text.
function Set-IniValue([string]$text, [string]$section, [string]$key, $value) {
    $eol = if ($text -match "`r`n") { "`r`n" } elseif ($text -match "`n") { "`n" } else { "`r`n" }
    $lines = New-Object System.Collections.Generic.List[string]
    if ($text) {
        foreach ($l in ($text -split "`r?`n")) { $lines.Add($l) }
        if ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    }
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[(.+?)\]\s*$') {
            if ($start -ge 0) { $end = $i; break }
            if ($Matches[1] -ieq $section) { $start = $i }
        }
    }
    if ($start -lt 0) {
        if ($null -eq $value) { return $text }
        if ($lines.Count) { $lines.Add('') }
        $lines.Add("[$section]"); $lines.Add("$key=$value")
    } else {
        $at = -1
        for ($i = $start + 1; $i -lt $end; $i++) { if ($lines[$i] -match "^\s*$([regex]::Escape($key))\s*=") { $at = $i; break } }
        if ($at -ge 0) {
            if ($null -eq $value) { $lines.RemoveAt($at) } else { $lines[$at] = "$key=$value" }
        } elseif ($null -ne $value) {
            $lines.Insert($start + 1, "$key=$value")
        }
    }
    ($lines -join $eol) + $eol
}

# The value of key in [section], or $null.
function Get-IniValue([string]$text, [string]$section, [string]$key) {
    $in = $false
    foreach ($l in ($text -split "`r?`n")) {
        if ($l -match '^\s*\[(.+?)\]\s*$') { $in = ($Matches[1] -ieq $section); continue }
        if ($in -and $l -match "^\s*$([regex]::Escape($key))\s*=\s*(.*?)\s*$") { return $Matches[1] }
    }
    $null
}

# The RunOnce command that continues this setup at the next sign-in. Never a password, never --reinstall.
function Register-Resume([string]$key, [string[]]$flags) {
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $q = { param($s) if ($s -match '\s') { '"' + $s + '"' } else { $s } }
    $cmd = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" --resumed {2}' -f $ps51, $PSCommandPath, ((@($flags | ForEach-Object { & $q $_ })) -join ' ')
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    New-ItemProperty -Path $key -Name 'windots-setup-wsl' -Value $cmd.TrimEnd() -PropertyType String -Force | Out-Null
    $cmd.TrimEnd()
}

# ---------------------------------------------------------------- WSL facts and actions

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# wsl.exe prints UTF-16: decode it as such, and drop the NULs a UTF-8 decoding leaves.
function Invoke-WslText([string[]]$wslArgs) {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $out = & wsl.exe @wslArgs 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
    } finally { [Console]::OutputEncoding = $prev }
    @($out | ForEach-Object { ([string]$_ -replace "`0", '').Trim() } | Where-Object { $_ })
}
function Get-WslDistros { Invoke-WslText @('--list', '--quiet') }
function Get-WslVersion {
    $line = Invoke-WslText @('--version') | Select-Object -First 1
    if ($line -and $line -match '(\d+\.\d+\.\d+(\.\d+)?)') { [version]$Matches[1] } else { $null }
}
function Test-WslInstalled {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    & wsl.exe --status *> $null
    $LASTEXITCODE -eq 0
}
function Test-Hypervisor { [bool](Get-CimInstance Win32_ComputerSystem).HypervisorPresent }
function Test-RestartPending {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                   'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        if (Test-Path $k) { return $true }
    }
    $false
}

# Runs elevated (this script re-runs itself through sudo, or does it directly when already admin).
function Install-Wsl {
    & wsl.exe --install --no-distribution | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  - retrying with --web-download (WSL from GitHub instead of the Store)'
        & wsl.exe --install --no-distribution --web-download | Out-Host
    }
    [int]$LASTEXITCODE
}

# Makes the Hyper-V firewall rules windots-wsl-<port> be exactly $ports. Needs admin.
function Sync-LanRules($ports) {
    $existing = @(Get-NetFirewallHyperVRule -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'windots-wsl-*' })
    foreach ($p in $ports) {
        if ($existing.Name -contains "windots-wsl-$p") { Write-Host "  - port $p already open to the network"; continue }
        New-NetFirewallHyperVRule -Name "windots-wsl-$p" -DisplayName "windots: WSL port $p" -Direction Inbound `
            -VMCreatorId $script:wslVmCreatorId -Protocol TCP -LocalPorts $p -Action Allow | Out-Null
        Write-Host "  - port $p open to the network (TCP, inbound to WSL)"
    }
    foreach ($r in $existing) {
        $p = $r.Name -replace '^windots-wsl-', ''
        if ($ports -notcontains ([int]$p)) { Remove-NetFirewallHyperVRule -Name $r.Name; Write-Host "  - port $p closed again" }
    }
}

# ---------------------------------------------------------------- internal modes (the elevated copies)
if ($args -contains '--install-wsl') { exit (Install-Wsl) }
$lanArg = @($args | Where-Object { [string]$_ -like '--apply-lan-rules=*' })
if ($lanArg.Count) {
    $ports = ConvertTo-PortList (([string]$lanArg[0]).Substring(18))
    if ($null -eq $ports) { Write-Host 'bad ports' -ForegroundColor Red; exit 2 }
    Sync-LanRules $ports
    exit 0
}

# ---------------------------------------------------------------- arguments
# PowerShell hands `--lan-ports=22,8080` over as a LIST when it is typed unquoted (and `--lan-ports 22,8080`
# too): turn every list back into the text it was typed as.
$cli = @(foreach ($a in $args) { if ($a -is [array]) { ($a -join ',') } else { [string]$a } })

$user = $null; $distro = 'archlinux'; $skipTools = $false; $reinstall = $false; $yes = $false
$network = $null; $lanText = $null; $check = $false; $resumed = $false
for ($i = 0; $i -lt $cli.Count; $i++) {
    $a = $cli[$i]
    if ($a -like '--user=*') { $user = $a.Substring(7) }
    elseif ($a -like '--distro=*') { $distro = $a.Substring(9) }
    elseif ($a -eq '--skip-tools') { $skipTools = $true }
    elseif ($a -eq '--reinstall') { $reinstall = $true }
    elseif ($a -eq '-y') { $yes = $true }
    elseif ($a -eq '--check') { $check = $true }
    elseif ($a -eq '--resumed') { $resumed = $true }
    elseif ($a -like '--network=*') { $network = $a.Substring(10) }
    elseif ($a -eq '--network') { $i++; if ($i -ge $cli.Count) { Write-Host '--network needs mirrored or nat' -ForegroundColor Red; exit 2 }; $network = $cli[$i] }
    elseif ($a -like '--lan-ports=*') { $lanText = $a.Substring(12) }
    elseif ($a -eq '--lan-ports') { $i++; if ($i -ge $cli.Count) { Write-Host '--lan-ports needs ports, e.g. 2222,8080, or none' -ForegroundColor Red; exit 2 }; $lanText = $cli[$i] }
    else { Write-Host "unknown option: $a (see windots setup wsl --help)" -ForegroundColor Red; exit 2 }
}

$interactive = -not [Console]::IsInputRedirected
# The one way out once the arguments are read: a resumed run (a window opened at sign-in) waits for Enter.
function Quit([int]$code) {
    if ($resumed -and $interactive) { [void](Read-Host 'Press Enter to close this window') }
    exit $code
}
trap { Write-Host $_.Exception.Message -ForegroundColor Red; Quit 1 }

$repo = Split-Path $PSScriptRoot
$setupSh = Join-Path $repo 'default\wsl\setup.sh'
if (-not (Test-Path $setupSh)) { throw "missing $setupSh" }
$validUser = '^[a-z_][a-z0-9_-]{0,31}$'
# -cmatch / -cnotmatch: PowerShell's -match ignores case, and a Linux user name must be lowercase.
if ($user -and $user -cnotmatch $validUser) { Write-Host "'$user' is not a valid Linux user name (lowercase letters, digits, - and _)" -ForegroundColor Red; exit 2 }
if ($network -and $network -cnotmatch '^(mirrored|nat)$') { Write-Host "--network is mirrored or nat, not '$network'" -ForegroundColor Red; exit 2 }
$lanPorts = $null
if ($null -ne $lanText) {
    $lanPorts = ConvertTo-PortList $lanText
    if ($null -eq $lanPorts) { Write-Host "--lan-ports needs TCP ports from 1 to 65535 (22,8080) or none, not '$lanText'" -ForegroundColor Red; exit 2 }
}
# Only network options asked: leave the distro and the user alone (no password to type).
$distroGiven = [bool]($cli | Where-Object { $_ -like '--distro=*' })
$networkOnly = (($network -or ($null -ne $lanPorts)) -and -not ($user -or $skipTools -or $reinstall -or $distroGiven))

$wslConfig = Join-Path $HOME '.wslconfig'
function Get-NetworkMode {
    $text = if (Test-Path $wslConfig) { [IO.File]::ReadAllText($wslConfig) } else { '' }
    $v = Get-IniValue $text 'wsl2' 'networkingMode'
    if ($v) { $v.ToLower() } else { 'nat' }
}

# ---------------------------------------------------------------- 1. WSL
Step 'WSL'
if ($resumed) {   # at sign-in the network may not be up yet, and the distro download needs it
    $until = (Get-Date).AddSeconds(60)
    while (-not [Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable() -and (Get-Date) -lt $until) { Start-Sleep -Seconds 2 }
}
$installed = Test-WslInstalled
$hypervisor = Test-Hypervisor
$pending = Test-RestartPending
$action = Resolve-WslAction $installed $hypervisor $pending $false

if ($check) {
    $ver = if ($installed) { Get-WslVersion } else { $null }
    Write-Host ("  WSL installed:           {0}{1}" -f $(if ($installed) { 'yes' } else { 'no' }), $(if ($ver) { " ($ver)" } else { '' }))
    Write-Host ("  hypervisor running:      {0}" -f $(if ($hypervisor) { 'yes (WSL 2 starts without a restart)' } else { 'no' }))
    Write-Host ("  Windows restart pending: {0}" -f $(if ($pending) { 'yes' } else { 'no' }))
    Write-Host ("  step 1 would:            {0}" -f @{ install = 'install WSL (one UAC prompt)'; ready = 'nothing, WSL is ready'; restart = 'ask for a restart and continue at the next sign-in'; 'virtualization-off' = 'stop: virtualization is off in the firmware (or hypervisorlaunchtype)' }[$action])
    if ($installed) {
        Write-Host ("  distro {0}: {1}" -f $distro, $(if ((Get-WslDistros) -contains $distro) { 'installed' } else { 'not installed' }))
    }
    Write-Host ("  network mode:            {0}  (~\.wslconfig; no file or no line = nat)" -f (Get-NetworkMode))
    $rules = @(try { Get-NetFirewallHyperVRule -ErrorAction Stop | Where-Object { $_.Name -like 'windots-wsl-*' } } catch { $null })
    Write-Host ("  ports open to the LAN:   {0}" -f $(if ($rules.Count) { ($rules | ForEach-Object { $_.Name -replace '^windots-wsl-', '' }) -join ', ' } else { 'none' }))
    return
}

if ($action -eq 'install') {
    Write-Host '  - WSL is not installed: installing it (one UAC prompt)'
    $code = if (Test-Admin) { Install-Wsl } else { Invoke-Elevated $PSCommandPath @('--install-wsl') }
    if ($code -ne 0) { throw "wsl --install failed (exit $code); see above. Try as administrator: wsl --install --no-distribution" }
    # Decide again with what is true now: a hypervisor already running means no restart at all.
    $action = Resolve-WslAction (Test-WslInstalled) (Test-Hypervisor) (Test-RestartPending) $true
    if ($action -eq 'ready') { Write-Host '  - WSL installed and ready: no restart needed (a hypervisor is already running)' }
}
switch ($action) {
    'ready' { if (-not (Test-WslInstalled)) { throw 'WSL is not answering yet; try again in a minute' }; if ($installed) { Write-Host '  - WSL is installed' } }
    'restart' {
        # Continue by itself at the next sign-in, with the same options (never --reinstall, never a password).
        $flags = @(); if ($user) { $flags += "--user=$user" }; if ($distro -ne 'archlinux') { $flags += "--distro=$distro" }
        if ($skipTools) { $flags += '--skip-tools' }; if ($network) { $flags += "--network=$network" }; if ($null -ne $lanText) { $flags += "--lan-ports=$lanText" }
        [void](Register-Resume $runOnceKey $flags)
        Write-Host '  - WSL needs a restart of Windows before it can run (no hypervisor is running yet)' -ForegroundColor Yellow
        Write-Host '  - the setup is scheduled to continue by itself when you sign in again (a terminal opens and asks for the user and password)'
        if ($interactive) {
            if ((Read-Host 'Restart now? [y/N]') -match '^(y|yes|s|sim)$') { Restart-Computer; Quit 0 }
        }
        Write-Host '  - restart when it suits you; nothing else is needed' -ForegroundColor Yellow
        Quit 0
    }
    'virtualization-off' {
        Write-Host '  - WSL is installed but no hypervisor is running and no restart is pending: virtualization is off.' -ForegroundColor Yellow
        Write-Host '    Turn on virtualization (Intel VT-x / AMD SVM) in the BIOS/UEFI; if it is on, as administrator run: bcdedit /set hypervisorlaunchtype auto, then restart.'
        Quit 1
    }
}

# ---------------------------------------------------------------- network (opt in)
function Update-Network {
    $changed = $false
    if ($network) {
        if ($network -ceq 'mirrored') {
            $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
            $wslVersion = Get-WslVersion
            if ($build -lt 22621) { throw "mirrored networking needs Windows 11 22H2 (build 22621) or newer; this is build $build" }
            if ($wslVersion -and $wslVersion -lt [version]'2.0.0') { throw "mirrored networking needs WSL 2.0.0 or newer; this is $wslVersion (run: wsl --update)" }
        }
        $old = if (Test-Path $wslConfig) { [IO.File]::ReadAllText($wslConfig) } else { '' }
        $value = if ($network -ceq 'mirrored') { 'mirrored' } else { $null }
        $new = Set-IniValue $old 'wsl2' 'networkingMode' $value
        if ($new -ne $old -and -not ($old -eq '' -and $new -eq '')) {
            if (Test-Path $wslConfig) { Copy-Item $wslConfig "$wslConfig.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())" }
            [IO.File]::WriteAllText($wslConfig, $new, (New-Object Text.UTF8Encoding $false))
            Write-Host "  - ~\.wslconfig: networkingMode=$network"
            $changed = $true
        } else { Write-Host "  - ~\.wslconfig already has networkingMode=$network" }
    }
    if ($null -ne $lanPorts) {
        $effective = if ($network) { $network } else { Get-NetworkMode }
        if ($lanPorts.Count -and $effective -ne 'mirrored') {
            throw 'opening ports to the network needs the mirrored mode: add --network=mirrored (NAT hides WSL behind Windows)'
        }
        foreach ($p in $lanPorts) {
            if (Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue | Where-Object { $_.RemotePort -eq 0 }) {
                Write-Warning "port $p is already used on Windows (the shared port space): a service in WSL cannot use it; pick another"
            }
        }
        $code = if (Test-Admin) { Sync-LanRules $lanPorts; 0 } else { Invoke-Elevated $PSCommandPath @("--apply-lan-rules=$(if ($lanPorts.Count) { $lanPorts -join ',' } else { 'none' })") }
        if ($code -ne 0) { throw "the firewall rules were not applied (exit $code); see above" }
        if ($lanPorts.Count) { Write-Host '  - these ports are reachable by everyone on the network (visitors included)' -ForegroundColor Yellow }
    }
    $changed
}

if ($networkOnly) {
    Step 'Network'
    $changed = Update-Network
    if ($changed) {
        Write-Host '  - wsl --shutdown: every WSL distro stops, so the new mode applies when they start again'
        & wsl.exe --shutdown
    }
    Write-Host "`nNetwork mode now: $(Get-NetworkMode)" -ForegroundColor Green
    Quit 0
}

# ---------------------------------------------------------------- 2. the distro
Step "Distro $distro"
$have = (Get-WslDistros) -contains $distro
if ($have -and $reinstall) {
    if (-not $yes) {
        if (-not $interactive) { Write-Host '--reinstall needs a terminal to confirm, or -y' -ForegroundColor Red; Quit 1 }
        Write-Host "This DELETES the distro '$distro' and everything in it (files, packages, users)." -ForegroundColor Yellow
        if ((Read-Host "Type its name to go on ($distro)") -ne $distro) { Write-Host 'Cancelled'; Quit 1 }
    }
    & wsl.exe --unregister $distro
    if ($LASTEXITCODE -ne 0) { throw "wsl --unregister $distro failed" }
    Write-Host "  - $distro deleted"
    $have = $false
}
if ($have) {
    Write-Host "  - $distro is already installed"
} else {
    Write-Host "  - installing $distro (a download of a few hundred MB)"
    & wsl.exe --install $distro --no-launch
    if ($LASTEXITCODE -ne 0) { throw "wsl --install $distro failed (exit $LASTEXITCODE); try: wsl --list --online" }
    if ((Get-WslDistros) -notcontains $distro) { throw "$distro was not registered; try: wsl --install $distro" }
}
# The first start registers the distro for real (and starts it).
& wsl.exe -d $distro -u root --exec true
if ($LASTEXITCODE -ne 0) { throw "could not start $distro" }

# ---------------------------------------------------------------- 3. user and password
Step 'User'
if (-not $user) {
    if (-not $interactive) { Write-Host 'No terminal to ask for the user name: pass --user=<name>' -ForegroundColor Red; Quit 1 }
    $default = [Environment]::UserName.ToLower() -replace '[^a-z0-9_-]', ''
    while ($true) {
        $v = (Read-Host "Linux user name [$default]").Trim()
        if (-not $v) { $v = $default }
        if ($v -cmatch $validUser -and $v -ne 'root') { $user = $v; break }
        Write-Host '  lowercase letters, digits, - and _ (not root)' -ForegroundColor Yellow
    }
}
if ($user -eq 'root') { Write-Host 'The user must not be root' -ForegroundColor Red; Quit 2 }

$password = $env:WINDOTS_WSL_PASSWORD
if (-not $password) {
    if (-not $interactive) { Write-Host 'No terminal to ask for the password: set WINDOTS_WSL_PASSWORD' -ForegroundColor Red; Quit 1 }
    function ConvertTo-Plain($secure) {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
    while ($true) {
        $p1 = ConvertTo-Plain (Read-Host "Password for $user (also for sudo)" -AsSecureString)
        if (-not $p1) { Write-Host '  the password cannot be empty' -ForegroundColor Yellow; continue }
        $p2 = ConvertTo-Plain (Read-Host 'Again' -AsSecureString)
        if ($p1 -eq $p2) { $password = $p1; break }
        Write-Host '  they differ: again' -ForegroundColor Yellow
    }
}
if ($password -match "[`r`n]") { Write-Host 'The password cannot have a line break' -ForegroundColor Red; Quit 2 }

# ---------------------------------------------------------------- 4. inside the distro
Step "Setting up $distro (as root, inside it)"
$repoLinux = ([string](& wsl.exe -d $distro --exec wslpath -a $repo | Select-Object -First 1)).Trim()
if (-not $repoLinux) { throw 'wslpath did not give the windots folder: is the Windows drive mounted in WSL?' }

# The script goes in through stdin (no dependence on /mnt/c here), with any CR removed; the password
# goes in on stdin too, so it never shows up in a process list.
$utf8 = New-Object Text.UTF8Encoding $false
$OutputEncoding = $utf8
$scriptText = ([IO.File]::ReadAllText($setupSh) -replace "`r`n", "`n")
$scriptText | & wsl.exe -d $distro -u root --exec bash -c "tr -d '\r' > /tmp/windots-wsl-setup.sh && chmod 0700 /tmp/windots-wsl-setup.sh"
if ($LASTEXITCODE -ne 0) { throw 'could not copy the setup script into the distro' }

$setupArgs = @("--user=$user", '--password-stdin', "--repo=$repoLinux")
if ($skipTools) { $setupArgs += '--skip-tools' }
$password | & wsl.exe -d $distro -u root --exec bash /tmp/windots-wsl-setup.sh @setupArgs
$code = $LASTEXITCODE
$password = $null
& wsl.exe -d $distro -u root --exec rm -f /tmp/windots-wsl-setup.sh
if ($code -ne 0) { throw "the setup inside $distro failed (exit $code); see above. Run it again: it only brings things up to date." }

# ---------------------------------------------------------------- 5. network, apply and check
$netChanged = $false
if ($network -or ($null -ne $lanPorts)) { Step 'Network'; $netChanged = Update-Network }
Step 'Check'
if ($netChanged) {
    Write-Host '  - wsl --shutdown: every WSL distro stops, so the new network mode applies when they start again'
    & wsl.exe --shutdown
} else {
    & wsl.exe --terminate $distro   # /etc/wsl.conf is read when the distro starts
}
$who = ([string](& wsl.exe -d $distro --exec whoami | Select-Object -First 1)).Trim()
$groups = ([string](& wsl.exe -d $distro --exec id -nG | Select-Object -First 1)).Trim()
$tools = ([string](& wsl.exe -d $distro --exec bash -lc 'command -v mise sudo git | xargs -n1 basename | tr "\n" " "' | Select-Object -First 1)).Trim()
Write-Host "  - WSL opens as: $who  (expected $user)"
Write-Host "  - groups: $groups"
Write-Host "  - found: $tools"
if ($who -ne $user) { Write-Warning "the default user is $who, not ${user}: run wsl --terminate $distro and try again" }
elseif ($groups -notmatch '\bwheel\b') { Write-Warning "$user is not in wheel: sudo will not work" }
else { Write-Host "`n$distro is ready. Open it with: wsl -d $distro" -ForegroundColor Green }
Quit 0
