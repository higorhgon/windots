# windots-setup-wsl [--user=<name>] [--distro=<name>] [--skip-tools] [--reinstall] [-y]
# windots:summary=Set up Arch Linux on WSL with a sudo user, bash and the windots mise tools
# windots:args=[--user=<name>] [--distro=<name>] [--skip-tools] [--reinstall] [-y]
# windots:examples=windots setup wsl | windots setup wsl --user=higor --skip-tools | windots setup wsl --reinstall -y
#
# Gets an Arch Linux distro on WSL ready to work in, the windots way:
#   1. WSL must be there (if not: wsl --install --no-distribution as administrator, restart)
#   2. the distro (default archlinux) is installed when missing (wsl --install archlinux --no-launch)
#   3. you give a user name and a password; Arch's WSL image only has root, and no sudo
#   4. inside it (default\wsl\setup.sh): the pacman keyring and a system update, sudo, base-devel, the en_US and pt_BR locales,
#      git, mise; that user in the wheel group with sudo (asking for its password); that user as the
#      WSL default; the windots mise and starship configs and the Claude commit-message skill linked
#      from this repo (the Claude settings are not: they are for Windows); a ~/.bashrc block; and
#      `mise install` for the tools of the windots config
#   5. the distro is stopped so the new default user applies, and the result is checked
# Safe to run again: the user, the packages and the links are only brought up to date.
#   --user=<name>    the Linux user (asked when missing; lowercase letters, digits, - and _)
#   --distro=<name>  another distro name (default archlinux)
#   --skip-tools     leave `mise install` out (the tools take a while; run mise install later)
#   --reinstall      DELETES the distro and everything in it, installs it again, then sets it up;
#                    asks you to type its name first, unless -y
#   -y               no questions for --reinstall
# The password is asked twice (hidden). Without a terminal, set WINDOTS_WSL_PASSWORD (and --user).
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$user = $null; $distro = 'archlinux'; $skipTools = $false; $reinstall = $false; $yes = $false
foreach ($a in $args) {
    if ($a -like '--user=*') { $user = $a.Substring(7) }
    elseif ($a -like '--distro=*') { $distro = $a.Substring(9) }
    elseif ($a -eq '--skip-tools') { $skipTools = $true }
    elseif ($a -eq '--reinstall') { $reinstall = $true }
    elseif ($a -eq '-y') { $yes = $true }
    else { Write-Host "unknown option: $a (see windots setup wsl --help)" -ForegroundColor Red; exit 2 }
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
$repo = Split-Path $PSScriptRoot
$setupSh = Join-Path $repo 'default\wsl\setup.sh'
if (-not (Test-Path $setupSh)) { throw "missing $setupSh" }
$validUser = '^[a-z_][a-z0-9_-]{0,31}$'
if ($user -and $user -cnotmatch $validUser) { Write-Host "'$user' is not a valid Linux user name (lowercase letters, digits, - and _)" -ForegroundColor Red; exit 2 }
$interactive = -not [Console]::IsInputRedirected

# -cmatch / -cnotmatch: PowerShell's -match ignores case, and a Linux user name must be lowercase.
# wsl.exe prints UTF-16: decode it as such, and drop the NULs a UTF-8 decoding leaves.
function Get-WslDistros {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        $out = & wsl.exe --list --quiet 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }   # no distribution installed
    } finally { [Console]::OutputEncoding = $prev }
    @($out | ForEach-Object { ([string]$_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

# ---------------------------------------------------------------- 1. WSL
Step 'WSL'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'WSL is not installed. As administrator run: wsl --install --no-distribution, restart, and run this again.' -ForegroundColor Yellow
    exit 1
}
& wsl.exe --status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'WSL is not ready. As administrator run: wsl --install --no-distribution, restart, and run this again.' -ForegroundColor Yellow
    exit 1
}
Write-Host '  - WSL is installed'

# ---------------------------------------------------------------- 2. the distro
Step "Distro $distro"
$have = (Get-WslDistros) -contains $distro
if ($have -and $reinstall) {
    if (-not $yes) {
        if (-not $interactive) { Write-Host '--reinstall needs a terminal to confirm, or -y' -ForegroundColor Red; exit 1 }
        Write-Host "This DELETES the distro '$distro' and everything in it (files, packages, users)." -ForegroundColor Yellow
        if ((Read-Host "Type its name to go on ($distro)") -ne $distro) { Write-Host 'Cancelled'; exit 1 }
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
    if (-not $interactive) { Write-Host 'No terminal to ask for the user name: pass --user=<name>' -ForegroundColor Red; exit 1 }
    $default = [Environment]::UserName.ToLower() -replace '[^a-z0-9_-]', ''
    while ($true) {
        $v = (Read-Host "Linux user name [$default]").Trim()
        if (-not $v) { $v = $default }
        if ($v -cmatch $validUser -and $v -ne 'root') { $user = $v; break }
        Write-Host '  lowercase letters, digits, - and _ (not root)' -ForegroundColor Yellow
    }
}
if ($user -eq 'root') { Write-Host 'The user must not be root' -ForegroundColor Red; exit 2 }

$password = $env:WINDOTS_WSL_PASSWORD
if (-not $password) {
    if (-not $interactive) { Write-Host 'No terminal to ask for the password: set WINDOTS_WSL_PASSWORD' -ForegroundColor Red; exit 1 }
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
if ($password -match "[`r`n]") { Write-Host 'The password cannot have a line break' -ForegroundColor Red; exit 2 }

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

# ---------------------------------------------------------------- 5. apply and check
Step 'Check'
& wsl.exe --terminate $distro   # /etc/wsl.conf is read when the distro starts
$who = ([string](& wsl.exe -d $distro --exec whoami | Select-Object -First 1)).Trim()
$groups = ([string](& wsl.exe -d $distro --exec id -nG | Select-Object -First 1)).Trim()
$tools = ([string](& wsl.exe -d $distro --exec bash -lc 'command -v mise sudo git | xargs -n1 basename | tr "\n" " "' | Select-Object -First 1)).Trim()
Write-Host "  - WSL opens as: $who  (expected $user)"
Write-Host "  - groups: $groups"
Write-Host "  - found: $tools"
if ($who -ne $user) { Write-Warning "the default user is $who, not ${user}: run wsl --terminate $distro and try again" }
elseif ($groups -notmatch '\bwheel\b') { Write-Warning "$user is not in wheel: sudo will not work" }
else { Write-Host "`n$distro is ready. Open it with: wsl -d $distro" -ForegroundColor Green }
