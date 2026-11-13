# windots-install
# windots:summary=Install windots on this machine: packages, links and settings
# windots:args=[-SkipPackages] [-SkipSystem]
# windots:examples=windots install | windots install -SkipPackages
#
# Works on Windows PowerShell 5.1 (fresh machine) and PowerShell 7.
#
#   .\bin\windots-install.ps1                 # everything (first run, from the repo root)
#   windots-install -SkipPackages             # skip winget/herdr/komorebi-switcher installs
#   windots-install -SkipSystem               # skip Windows settings (sudo, Developer Mode, taskbar)
#
# Developer Mode and sudo are machine-wide: each asks for elevation (a UAC prompt) when it has
# something to change; sudo is windots-setup-security-sudo.

[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipSystem,
    [Alias('h')][switch]$Help,
    [Parameter(ValueFromRemainingArguments)]$Rest   # catches --help (a param block can't name it)
)

if ($Help -or $Rest -contains '--help') {
    & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return
}

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
$groups = @($targets | ForEach-Object Group | Sort-Object -Unique)
& $tuckr add @groups --force --assume-yes
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
