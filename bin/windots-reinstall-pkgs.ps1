# windots-reinstall-pkgs
# windots:summary=Install every default windots app that is missing
# windots:examples=windots reinstall pkgs
#
# Like omarchy-reinstall-pkgs: makes sure every default app is installed, without
# touching any config:
#   - the winget packages in default\packages.txt (one UAC prompt, through sudo);
#   - komorebi-switcher (GitHub release), when missing;
#   - herdr-app (official installer, which also installs herdr-core), when missing;
#   - the mise tools in ~\.config\mise\config.toml (mise install).
# Apps already installed are left as they are (windots-update upgrades them).
# Called by windots-install; safe to run again on its own.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

$packages = @(Get-Content (Join-Path $Repo 'default\packages.txt') |
    ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ })

# Internal: the winget part, run elevated (see below).
if ($args[0] -eq '--winget') {
    $alreadyThere = -1978335189, -1978335135   # 0x8A15002B, 0x8A150061: installed / nothing newer
    $failed = 0
    foreach ($id in $packages) {
        Write-Host "  - $id"
        # --no-upgrade: only install what is missing; upgrading is windots-update's job.
        winget install --id $id --exact --source winget --silent --disable-interactivity --no-upgrade `
            --accept-package-agreements --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -ne 0 -and $alreadyThere -notcontains $LASTEXITCODE) {
            Write-Warning ("winget could not install $id (exit 0x{0:X8}); run: winget install --id $id" -f $LASTEXITCODE)
            $failed++
        }
    }
    exit $failed
}

Step 'Installing winget packages'
# Machine-wide packages need admin: one sudo for all of them instead of a UAC prompt each.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$shell = (Get-Process -Id $PID).Path
$sudoOn = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' -ErrorAction SilentlyContinue).Enabled -ge 1
if (-not $isAdmin -and $sudoOn -and (Get-Command sudo.exe -ErrorAction SilentlyContinue)) {
    sudo.exe $shell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath --winget
} else {
    & $shell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath --winget
}
Refresh-Path

Step 'Installing komorebi-switcher (GitHub release)'
$exe = Join-Path $env:LOCALAPPDATA 'Programs\komorebi-switcher\komorebi-switcher.exe'
if (Test-Path $exe) {
    Write-Host '  - already installed'
} else {
    $release = Invoke-RestMethod 'https://api.github.com/repos/amrbashir/komorebi-switcher/releases/latest'
    $asset = $release.assets | Where-Object name -eq 'komorebi-switcher.exe'
    New-Item -ItemType Directory -Force (Split-Path $exe) | Out-Null
    Invoke-WebRequest $asset.browser_download_url -OutFile $exe -UseBasicParsing
    Write-Host "  - $($release.tag_name) -> $exe"
}

Step 'Installing herdr-app (official installer; also installs herdr-core)'
if (Get-Command herdr-app -ErrorAction SilentlyContinue) {
    Write-Host '  - already installed'
} else {
    powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://releases.herdr.dev/app/install.ps1 | iex"
    Refresh-Path
}

Step 'Installing mise tools'
if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Warning 'mise not found on PATH; open a new terminal and run: mise install'
} elseif (-not (Test-Path (Join-Path $HOME '.config\mise\config.toml'))) {
    Write-Host '  - no ~\.config\mise\config.toml yet (windots-install links it, then installs them)'
} else {
    mise install --yes
}
