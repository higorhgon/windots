# windots-install-files [--default | --no-default] [--skip-theme] [--no-restart] [--check]
# windots:summary=Install Files (files.community), set it as the default file manager and apply the theme
# windots:args=[--default | --no-default] [--skip-theme] [--no-restart] [--check]
# windots:examples=windots install files | windots install files --no-default | windots install files --check
#
# Files is the file manager that takes the theme's colours everywhere (Explorer's file list cannot be
# styled, even with Windhawk). This:
#   1. installs Files with winget when it is missing (FilesCommunity.Files)
#   2. --default (the default) makes it the default file manager, what Files' Settings > Advanced switch does:
#      folders, Win+E and "show in folder" open Files. Only HKCU is written, so no UAC. explorer.exe keeps
#      running: it is the taskbar and the desktop. --no-default puts Explorer back.
#   3. applies the current theme (windots-theme-set does it later too): when Files is running it is
#      restarted, or with --no-restart a notification asks, and clicking it restarts Files
#   --skip-theme   leave the colours alone      --check   say what is set; change nothing
# Idempotent. Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\themes.ps1')

$default = $true; $skipTheme = $false; $noRestart = $false; $check = $false
foreach ($a in $args) {
    if ($a -eq '--default') { $default = $true }
    elseif ($a -eq '--no-default') { $default = $false }
    elseif ($a -eq '--skip-theme') { $skipTheme = $true }
    elseif ($a -eq '--no-restart') { $noRestart = $true }
    elseif ($a -eq '--check') { $check = $true }
    else { Write-Host "unknown option: $a (see windots install files --help)" -ForegroundColor Red; exit 2 }
}
function Step($msg) { Write-Host "  - $msg" }

if ($check) {
    $pkg = Get-FilesPackage
    Write-Host ('Files: ' + $(if ($pkg) { "installed ($($pkg.Version))" } else { 'not installed' }))
    Write-Host "running: $(Test-FilesRunning)"
    Write-Host "default file manager: $(Test-FilesDefault)"
    Write-Host "settings file: $(if (@(Get-FilesSettingsPaths).Count) { (Get-FilesSettingsPaths | Select-Object -First 1) } else { '(none yet: start Files once)' })"
    exit 0
}

Write-Host '==> Files' -ForegroundColor Cyan
if (-not (Get-FilesPackage)) {
    winget install --id FilesCommunity.Files --silent --accept-package-agreements --accept-source-agreements
    if (-not (Get-FilesPackage)) { Write-Host 'Files did not install: see the winget output above' -ForegroundColor Red; exit 1 }
}
Step "Files $((Get-FilesPackage).Version) installed"

# the settings file only exists once Files has run
if (-not @(Get-FilesSettingsPaths).Count) {
    Step 'starting Files once, to create its settings'
    Start-Process (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\files-stable.exe')
    foreach ($i in 1..40) { Start-Sleep -Milliseconds 500; if (@(Get-FilesSettingsPaths).Count) { break } }
    Start-Sleep -Seconds 2
}

if ($default -and (Test-FilesDefault)) { Step 'default file manager: already Files' }
elseif ($default) {
    if (Set-FilesDefault $true) { Step 'default file manager: Files (folders, Win+E)' }
    else { Write-Warning 'Files was not set as the default file manager' }
} elseif (Test-FilesDefault) {
    if (Set-FilesDefault $false) { Step 'default file manager: Explorer again' }
    else { Write-Warning 'Explorer was not restored as the default file manager' }
} else { Step 'default file manager: Explorer (--no-default)' }

if (-not $skipTheme) {
    $name = Get-CurrentThemeName
    Step (Update-FilesTheme $name (Read-ThemeColors $name) $noRestart)
}
exit 0
