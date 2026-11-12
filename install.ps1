# windots installer
# Works on Windows PowerShell 5.1 (fresh machine) and PowerShell 7.
#
#   .\install.ps1                 # everything
#   .\install.ps1 -SkipPackages   # skip winget/herdr/komorebi-switcher installs
#   .\install.ps1 -SkipSystem     # skip Windows settings (sudo, Developer Mode, taskbar)
#
# Developer Mode and sudo are machine-wide: the script asks for elevation (UAC) once.

[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipSystem
)

$ErrorActionPreference = 'Stop'
$Repo = $PSScriptRoot

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
    Step 'Enabling Developer Mode and sudo (inline mode) - needs admin'
    $elevated = @'
$ErrorActionPreference = 'Continue'
# Developer Mode (lets tuckr create symlinks without admin)
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
# sudo for Windows, inline mode (same as Settings > System > Advanced > Enable sudo > Inline)
if (Get-Command sudo.exe -ErrorAction SilentlyContinue) { sudo.exe config --enable normal }
else { Write-Warning 'sudo.exe not found (needs Windows 11 24H2 or newer)' }
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
        } catch { Write-Warning 'Elevation was declined; Developer Mode and sudo were not changed.' }
    }

    Step 'Taskbar: top, small, icons left, no Task View / Widgets / Chat / Copilot / search'
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-Reg $adv 'TaskbarLocation'    1   # 1 = top
    Set-Reg $adv 'TaskbarSize'        1   # 1 = small
    Set-Reg $adv 'TaskbarAl'          0   # 0 = left aligned
    Set-Reg $adv 'ShowTaskViewButton' 0
    Set-Reg $adv 'TaskbarDa'          0   # Widgets
    Set-Reg $adv 'TaskbarMn'          0   # Chat
    Set-Reg $adv 'ShowCopilotButton'  0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 2
    # Explorer only reads these at startup; it relaunches by itself.
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- packages
$Packages = @(
    'Microsoft.PowerShell'          # PowerShell 7
    'Git.Git'
    'jdx.mise'
    'RaphGL.Tuckr'
    'LGUG2Z.komorebi'
    'LGUG2Z.whkd'
    'AutoHotkey.AutoHotkey'
    'Flow-Launcher.Flow-Launcher'
    'DEVCOM.JetBrainsMonoNerdFont'  # glyphs used by starship
)

if (-not $SkipPackages) {
    Step 'Installing winget packages'
    foreach ($id in $Packages) {
        Write-Host "  - $id"
        winget install --id $id --exact --source winget --silent `
            --accept-package-agreements --accept-source-agreements | Out-Null
        # winget returns non-zero when the package is already installed; that's fine.
    }

    Step 'Installing komorebi-switcher (GitHub release)'
    $dir = Join-Path $env:LOCALAPPDATA 'Programs\komorebi-switcher'
    $exe = Join-Path $dir 'komorebi-switcher.exe'
    $release = Invoke-RestMethod 'https://api.github.com/repos/amrbashir/komorebi-switcher/releases/latest'
    $asset = $release.assets | Where-Object name -eq 'komorebi-switcher.exe'
    New-Item -ItemType Directory -Force $dir | Out-Null
    Get-Process komorebi-switcher -ErrorAction SilentlyContinue | Stop-Process -Force
    Invoke-WebRequest $asset.browser_download_url -OutFile $exe
    Write-Host "  - $($release.tag_name) -> $exe"

    Step 'Installing herdr-app (official installer; also installs herdr-core if missing)'
    powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://releases.herdr.dev/app/install.ps1 | iex"
}

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
$devMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
    -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not ($devMode -or $isAdmin)) {
    Write-Warning ('Developer Mode is off, so symlinks cannot be created. Enable it in ' +
        'Settings > System > Advanced > Developer Mode and run: .\install.ps1 -SkipPackages')
    exit 1
}

Step 'Backing up existing files that will be replaced'
$configs = Join-Path $Repo 'Configs'
Get-ChildItem $configs -Recurse -File -Force | ForEach-Object {
    $group = $_.FullName.Substring($configs.Length + 1).Split('\')[0]
    $rel = $_.FullName.Substring((Join-Path $configs $group).Length + 1)
    $target = Join-Path $HOME $rel
    $t = Get-Item $target -Force -ErrorAction SilentlyContinue
    if ($t -and -not $t.LinkType) {
        Copy-Item $target "$target.pre-windots" -Force
        Write-Host "  - $target -> .pre-windots"
    }
}

Step 'Linking dotfiles with tuckr'
$tuckr = (Get-Command tuckr, tuckr-x86_64-windows -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $tuckr) { throw 'tuckr not found on PATH (open a new terminal after installing it).' }
$groups = (Get-ChildItem $configs -Directory).Name
& $tuckr add @groups --force --assume-yes
& $tuckr status

# ---------------------------------------------------------------- mise tools
Step 'Installing mise tools (atuin, starship, neovim, ...)'
if (Get-Command mise -ErrorAction SilentlyContinue) { mise install --yes }
else { Write-Warning 'mise not found on PATH; open a new terminal and run: mise install' }

# ---------------------------------------------------------------- autostart
Step 'Creating autostart shortcuts'
& (Join-Path $Repo 'autostart.ps1')

Write-Host "`nDone. Open a new PowerShell 7 terminal to load the profile." -ForegroundColor Green
