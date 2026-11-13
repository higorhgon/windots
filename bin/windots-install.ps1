# windots-install
# windots:summary=Install windots on this machine: packages, links and settings
# windots:args=[--skip-packages] [--skip-system]
# windots:examples=windots install | windots install --skip-packages
#
# Works on Windows PowerShell 5.1 (fresh machine) and PowerShell 7.
#
#   .\bin\windots-install.ps1                 # everything (first run, from the repo root)
#   windots-install --skip-packages           # skip winget/herdr/komorebi-switcher installs
#   windots-install --skip-system             # skip Windows settings (sudo, Developer Mode, taskbar)
#
# Developer Mode and sudo are machine-wide: each asks for elevation (a UAC prompt) when it has
# something to change; sudo is windots-setup-security-sudo.
# Flags are Linux style (--skip-packages), read from $args: no param() block.
#
# On a new machine, with no Git and no clone, this same file is the one-line installer:
#
#   irm https://raw.githubusercontent.com/higorhgon/windots/main/bin/windots-install.ps1 | iex
#
# Like omarchy's `curl -fsSL https://omarchy.org/install | bash`. Outside a clone (under iex, or the
# file downloaded alone) it only bootstraps, in order:
#   1. Git, when missing (winget; the Git installer asks for a UAC prompt)
#   2. windots cloned with its submodules into ~\windots (updated instead when it is there)
#   3. the name and email git puts on commits (windots-setup-git), asked unless git already has them
#   4. its own copy from the clone runs: the install below, with the same flags
#   5. the migrations marked as done, the first time only (a new machine already has what they change)
# Then restart, or sign out and in, so the startup apps come up.
# Settings, as environment variables set before the line above (under iex there are no flags):
#   WINDOTS_PATH          where to clone (default ~\windots; keep it short: some files in the repo have
#                         long paths and Windows stops at 260 characters)
#   WINDOTS_REPO, WINDOTS_REF   another repository URL (a fork), a branch or tag (default main)
#   WINDOTS_GIT_NAME, WINDOTS_GIT_EMAIL   the git name and email, so nothing is asked
#   WINDOTS_INSTALL_ARGS  flags for the install, e.g. "--skip-packages"
#   WINDOTS_NO_INSTALL    1 stops after step 3: only Git, the clone and the git setup

# ---------------------------------------------------------------- outside a clone: bootstrap
# Under `irm | iex` $PSScriptRoot is empty; a file downloaded alone has no Configs\ next to it.
$bootArgs = @($args)
$inRepo = [bool]$PSScriptRoot -and (Test-Path (Join-Path (Split-Path $PSScriptRoot) 'Configs'))
if (-not $inRepo) {
    # No exit and its own scope: under iex, exit would close the person's window and variables would leak.
    & {
        $ErrorActionPreference = 'Stop'
        function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
        # A new machine's Windows PowerShell does not run script files (execution policy): -ExecutionPolicy Bypass.
        function Invoke-Windots($file, $fileArgs) {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file @fileArgs
            if ($LASTEXITCODE -ne 0) { throw "$(Split-Path $file -Leaf) failed (exit $LASTEXITCODE); see above." }
        }
        $repoUrl = if ($env:WINDOTS_REPO) { $env:WINDOTS_REPO } else { 'https://github.com/higorhgon/windots.git' }
        $ref = if ($env:WINDOTS_REF) { $env:WINDOTS_REF } else { 'main' }
        $dest = if ($env:WINDOTS_PATH) { $env:WINDOTS_PATH } else { Join-Path $HOME 'windots' }

        Step 'Git'
        if (Get-Command git.exe -ErrorAction SilentlyContinue) {
            Write-Host "  - already installed ($((git --version) -join ' '))"
        } else {
            if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
                throw 'winget not found: install "App Installer" from the Microsoft Store (Windows 11 has it), then run this again.'
            }
            Write-Host '  - installing Git for Windows with winget (a UAC prompt may show)'
            winget install --id Git.Git --exact --source winget --silent --disable-interactivity `
                --accept-package-agreements --accept-source-agreements
            $alreadyThere = -1978335189, -1978335135   # 0x8A15002B / 0x8A150061: installed / nothing newer
            if ($LASTEXITCODE -ne 0 -and $alreadyThere -notcontains $LASTEXITCODE) {
                throw ("winget could not install Git (exit 0x{0:X8}); try: winget install --id Git.Git" -f $LASTEXITCODE)
            }
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
                $cmd = Join-Path $env:ProgramFiles 'Git\cmd'
                if (Test-Path (Join-Path $cmd 'git.exe')) { $env:Path += ";$cmd" }
            }
            if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
                throw 'Git was installed but is not on PATH yet: open a new terminal and run this again.'
            }
            Write-Host "  - installed ($((git --version) -join ' '))"
        }

        Step "windots in $dest"
        if (Test-Path (Join-Path $dest '.git')) {
            Write-Host '  - already there: updating it'
            git -C $dest pull --ff-only
            if ($LASTEXITCODE -ne 0) { throw "git pull failed in $dest (local changes?); fix it and run this again." }
            git -C $dest submodule update --init
            if ($LASTEXITCODE -ne 0) { throw 'git submodule update failed; see above.' }
        } elseif ((Test-Path $dest) -and @(Get-ChildItem $dest -Force).Count) {
            throw "$dest exists, is not empty and is not a windots clone: move it away, or set WINDOTS_PATH to another folder."
        } else {
            git clone --recurse-submodules --branch $ref $repoUrl $dest
            if ($LASTEXITCODE -ne 0) { throw "git clone failed ($repoUrl, $ref); see above." }
        }
        $bin = Join-Path $dest 'bin'
        if (-not (Test-Path (Join-Path $bin 'windots-install.ps1'))) { throw "$dest does not look like windots (no bin\windots-install.ps1)." }

        Step 'Git name and email'
        $gitArgs = @()
        if ($env:WINDOTS_GIT_NAME) { $gitArgs += "--name=$($env:WINDOTS_GIT_NAME)" }
        if ($env:WINDOTS_GIT_EMAIL) { $gitArgs += "--email=$($env:WINDOTS_GIT_EMAIL)" }
        Invoke-Windots (Join-Path $bin 'windots-setup-git.ps1') $gitArgs

        if ($env:WINDOTS_NO_INSTALL -eq '1') {
            Write-Host "`nStopped before the install (WINDOTS_NO_INSTALL=1). To finish: powershell -ExecutionPolicy Bypass -File $bin\windots-install.ps1" -ForegroundColor Yellow
            return
        }

        # This same file, from the clone: now it is inside a repo, so it does the real install.
        $forward = @($bootArgs) + @(([string]$env:WINDOTS_INSTALL_ARGS) -split '\s+' | Where-Object { $_ })
        Step 'windots-install'
        Invoke-Windots (Join-Path $bin 'windots-install.ps1') $forward

        # Only the first time: a machine that already had windots may have migrations it never ran.
        $stateDir = if ($env:WINDOTS_MIGRATION_STATE) { $env:WINDOTS_MIGRATION_STATE } else { Join-Path $HOME '.local\state\windots\migrations' }
        if (-not (Test-Path $stateDir)) {
            Step 'Migrations: a new machine has what they change'
            Invoke-Windots (Join-Path $bin 'windots-migrate.ps1') @('--mark-all')
        }

        Write-Host "`nwindots is installed. Restart (or sign out and in) so komorebi and the other startup apps come up." -ForegroundColor Green
        Write-Host 'Then try: windots commands' -ForegroundColor Green
    }
    return
}
# ---------------------------------------------------------------- end of the bootstrap

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

# -SkipPackages / -SkipSystem: the old names, still sent by a windots-update that ran
# git pull before this change (it calls the new windots-install). Not documented.
$known = '--skip-packages', '--skip-system', '-SkipPackages', '-SkipSystem'
$unknown = @($args | Where-Object { $known -notcontains $_ })
if ($unknown) {   # a typo must not turn into a full install
    Write-Host "windots-install: unknown option $($unknown -join ' ') (see: windots install --help)" -ForegroundColor Red
    exit 1
}
$SkipPackages = ($args -contains '--skip-packages') -or ($args -contains '-SkipPackages')
$SkipSystem = ($args -contains '--skip-system') -or ($args -contains '-SkipSystem')

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot   # this script lives in <repo>\bin

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Set-Reg($path, $name, $value) {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    try { Set-ItemProperty -Path $path -Name $name -Value $value -Type DWord -Force }
    catch { Write-Warning "could not set $path\$name ($($_.Exception.Message))" }
}

# ---------------------------------------------------------------- windows settings
if (-not $SkipSystem) {
    Step 'Enabling Developer Mode and the Widgets policy - needs admin'
    $elevated = @'
$ErrorActionPreference = 'Continue'
# Developer Mode (lets tuckr create symlinks without admin)
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
# Widgets off by policy: HKCU TaskbarDa is protected on recent Windows 11 and can't be set
$k = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name AllowNewsAndInterests -Value 0 -Type DWord
'@
    $isAdminNow = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdminNow) {
        Invoke-Expression $elevated
    } else {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($elevated))
        try {
            Start-Process powershell.exe -Verb RunAs -Wait -WindowStyle Hidden `
                -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
        } catch { Write-Warning 'Elevation was declined; Developer Mode was not changed.' }
    }

    Step 'Turning on sudo (inline mode)'
    & (Join-Path $PSScriptRoot 'windots-setup-security-sudo.ps1')

    Step 'Taskbar: top, small, icons left, no Task View / Widgets / Chat / Copilot / search'
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-Reg $adv 'TaskbarLocation'    1   # 1 = top
    Set-Reg $adv 'TaskbarSize'        1   # 1 = small
    Set-Reg $adv 'TaskbarAl'          0   # 0 = left aligned
    Set-Reg $adv 'ShowTaskViewButton' 0
    # Widgets: turned off by policy in the elevated block (HKCU TaskbarDa is write-protected)
    Set-Reg $adv 'TaskbarMn'          0   # Chat
    Set-Reg $adv 'ShowCopilotButton'  0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 2
    # Explorer only reads these at startup; it relaunches by itself.
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- packages
# The default apps (default\packages.txt, komorebi-switcher, herdr-app): windots-reinstall-pkgs.
if (-not $SkipPackages) { & (Join-Path $PSScriptRoot 'windots-reinstall-pkgs.ps1') }

Refresh-Path

# ---------------------------------------------------------------- windots bin
# Like omarchy's bin: the repo's scripts are commands on PATH (windots-*), no links needed.
Step 'Adding windots\bin to the user PATH'
$bin = Join-Path $Repo 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $bin) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ";$bin"), 'User')
    Write-Host "  - added $bin"
} else { Write-Host '  - already there' }
Refresh-Path

# ---------------------------------------------------------------- tuckr dir
# tuckr looks for %APPDATA%\dotfiles; point it at this repo with a junction (no admin needed).
Step 'Pointing %APPDATA%\dotfiles at this repo'
$dotfiles = Join-Path $env:APPDATA 'dotfiles'
$item = Get-Item $dotfiles -Force -ErrorAction SilentlyContinue
if (-not $item) {
    New-Item -ItemType Junction -Path $dotfiles -Target $Repo | Out-Null
    Write-Host "  - created junction $dotfiles -> $Repo"
} elseif ($item.LinkType -and ($item.Target -eq $Repo -or $item.Target -contains $Repo)) {
    Write-Host '  - already linked'
} else {
    throw "$dotfiles already exists and is not a link to $Repo. Move it away and run again."
}

# ---------------------------------------------------------------- symlinks
. (Join-Path $PSScriptRoot 'lib\dotfiles.ps1')
$tuckr = Assert-CanLink   # Developer Mode and tuckr, before anything in ~ changes
$configs = Join-Path $Repo 'Configs'
$targets = @(Get-DotfileTargets $Repo)   # files git tracks, not what apps wrote into Configs

Step 'Replacing folder links into the repo with real folders'
Repair-FoldedLinks $Repo $targets $WindotsOldPlaces
Restore-DeletedDotfiles $Repo
Remove-StaleLinks $Repo $WindotsOldPlaces

Step 'Backing up existing files that will be replaced'
foreach ($t in $targets) {
    $i = Get-Item $t.Target -Force -ErrorAction SilentlyContinue
    if ($i -and -not $i.LinkType) {
        Copy-Item $t.Target "$($t.Target).pre-windots" -Force
        Write-Host "  - $($t.Target) -> .pre-windots"
    }
    # Every folder must exist: tuckr fails on missing ones (os error 3) or links the whole
    # folder into the repo, and then apps write their state into the repo.
    New-Item -ItemType Directory -Force (Split-Path $t.Target) | Out-Null
}

Step 'Linking dotfiles with tuckr'
# tuckr add --force deletes a link that points straight at the repo (as Repoint-DotfileLinks
# leaves them) and makes no new one: a second run used to leave ~ with no dotfiles. So tuckr
# only runs for groups with a file not linked yet, and their direct links are removed first.
$isLinked = { param($t) (Get-RepoLinkTarget (Get-Item -LiteralPath $t.Target -Force -ErrorAction SilentlyContinue) $Repo) -eq $t.Source }
$groups = @($targets | Where-Object { -not (& $isLinked $_) } | ForEach-Object Group | Sort-Object -Unique)
if ($groups) {
    foreach ($t in @($targets | Where-Object { $groups -contains $_.Group })) {
        if (& $isLinked $t) { Remove-Dotfile $t.Target }   # a link: removed, tuckr makes it again
    }
    & $tuckr add @groups --force --assume-yes
}
# tuckr status lists a group as symlinked even when some of its files failed: check each file.
$notLinked = @($targets | Where-Object { -not (Get-Item $_.Target -Force -ErrorAction SilentlyContinue).LinkType })
if ($notLinked) {
    Write-Warning "$($notLinked.Count) files were not linked:"
    $notLinked | ForEach-Object { Write-Host "    $($_.Target)" -ForegroundColor Yellow }
} else { Write-Host "  - all $($targets.Count) files linked" }

Step 'Pointing the links straight at the repo (no junction in the way)'
$repointed = Repoint-DotfileLinks $Repo $targets
Write-Host "  - $repointed links repointed"

Step 'Pointing the PowerShell profile at ~\.config\powershell'
# PowerShell only reads $PROFILE from Documents, which OneDrive backs up (and may redirect).
# windots keeps nothing there but this one-line loader: a plain file, not a link.
$profilePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
$loader = "try { . (Join-Path `$HOME '.config\powershell\profile.ps1') } catch { . '$(Join-Path $Repo 'Configs\pwsh\.config\powershell\profile.ps1')' }   # windots: the profile lives in ~\.config\powershell"
$current = Get-Item $profilePath -Force -ErrorAction SilentlyContinue
if ($current -and $current.LinkType) { Remove-Dotfile $profilePath; $current = $null }   # an old windots link
if ($current -and (Get-Content $profilePath -Raw).Trim() -eq $loader) {
    Write-Host '  - already there'
} else {
    New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
    if ($current) {
        $bak = "$profilePath.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
        Copy-Item $profilePath $bak
        Write-Host "  - kept the previous profile as $bak"
    }
    [IO.File]::WriteAllText($profilePath, "$loader`r`n", (New-Object Text.UTF8Encoding $false))
    Write-Host "  - $profilePath loads ~\.config\powershell\profile.ps1"
}

# ---------------------------------------------------------------- backgrounds
Step 'Listing backgrounds in Settings > Personalization'
& (Join-Path $PSScriptRoot 'windots-install-backgrounds.ps1')

# ---------------------------------------------------------------- font
Step 'Installing JetBrainsMono Nerd Font (Windows Terminal and herdr-app use the NL variant)'
if (Test-Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts\JetBrainsMonoNLNerdFont-Regular.ttf')) {
    Write-Host '  - already installed'   # skips the download when run again (windots-update)
} else { & (Join-Path $PSScriptRoot 'windots-install-font.ps1') JetBrainsMono }

# ---------------------------------------------------------------- windows terminal
Step 'Applying Catppuccin Mocha to Windows Terminal'
& (Join-Path $PSScriptRoot 'windots-install-windows-terminal.ps1')

# ---------------------------------------------------------------- herdr-app
Step 'Applying herdr-app keys and settings, linking the retropet layout'
& (Join-Path $PSScriptRoot 'windots-install-herdr-app.ps1')

# ---------------------------------------------------------------- flow launcher
Step 'Applying Flow Launcher hotkeys (system menu, apps, plugins)'
& (Join-Path $PSScriptRoot 'windots-install-flow-launcher.ps1')

# ---------------------------------------------------------------- mise tools
Step 'Installing mise tools (atuin, starship, neovim, ...)'
if (Get-Command mise -ErrorAction SilentlyContinue) { mise install --yes }
else { Write-Warning 'mise not found on PATH; open a new terminal and run: mise install' }

# ---------------------------------------------------------------- autostart
Step 'Creating autostart shortcuts'
& (Join-Path $Repo 'bin\windots-refresh-autostart.ps1')

# Only works when komorebi and the switcher are already running (a re-run); on a new machine
# the login shortcut above does it after the first restart.
Step 'Centering komorebi-switcher on this machine''s monitors'
try { & (Join-Path $Repo 'bin\windots-center-switcher.ps1') 3>$null }
catch { Write-Host "  - skipped ($($_.Exception.Message)); it runs at login" }

Write-Host "`nDone. Open a new PowerShell 7 terminal to load the profile." -ForegroundColor Green
