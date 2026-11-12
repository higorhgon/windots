# windots-update [-y] [--prune]
# windots:summary=Update windots, winget packages and mise tools
# windots:args=[-y] [--prune]
# windots:examples=windots update | windots update -y --prune
#
# Like omarchy-update: updates windots and everything it installed, in this order:
#   1. the windots repo (git pull --ff-only)                like omarchy-update-dev
#   2. winget packages (windots-update-winget, one UAC)     like omarchy-update-system-pkgs
#   3. re-applies windots (windots-install -SkipPackages -SkipSystem):
#      links new dotfiles, merges Windows Terminal / Flow settings, autostart
#                                                           like omarchy-migrate
#   4. mise tools (mise up; with --prune also mise prune)   like omarchy-update-mise
#   5. offers a reboot when Windows needs one               like omarchy-update-restart
#
#   windots-update       asks before starting and before rebooting
#   windots-update -y    no questions (the UAC prompt for winget still shows)
#   --prune              also remove mise tool versions no config uses (mise prune), freeing disk
#
# The output is logged to %TEMP%\windots-update.log.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$yes = $args -contains '-y'
$prune = $args -contains '--prune'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Green }
function Confirm-Yes($question) {
    if ($yes) { return $true }
    (Read-Host "$question [y/N]") -match '^(y|yes|s|sim)$'
}

if (-not $yes) {
    Write-Host 'Ready to update windots, winget packages and mise tools.'
    Write-Host '  - Apps being upgraded may close while their installer runs.'
    Write-Host '  - Laptops: keep the charger connected.'
    if (-not (Confirm-Yes 'Continue?')) { Write-Host 'Update cancelled'; exit 1 }
}

Start-Transcript -Path (Join-Path $env:TEMP 'windots-update.log') | Out-Null
try {
    Step 'Update windots'
    git -C $Repo pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull failed in $Repo (local changes?); fix it and run windots-update again." }

    Step 'Update winget packages'
    & (Join-Path $PSScriptRoot 'windots-update-winget.ps1')
    $wingetOk = $LASTEXITCODE -eq 0

    Step 'Re-apply windots'
    & (Join-Path $PSScriptRoot 'windots-install.ps1') -SkipPackages -SkipSystem

    Step 'Update mise tools'
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        # mise holds back very new releases; updating means wanting them now (omarchy does the same).
        $env:MISE_MINIMUM_RELEASE_AGE = '0'
        mise up
        $miseOk = $LASTEXITCODE -eq 0
        if ($prune) {
            Step 'Remove unused mise versions'
            mise prune --yes
        }
    } else { Write-Warning 'mise not found on PATH'; $miseOk = $false }
} catch {
    Write-Host "`nSomething went wrong during the update: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Review the output above (also in %TEMP%\windots-update.log) and run windots-update again.' -ForegroundColor Red
    exit 1
} finally {
    Stop-Transcript | Out-Null
}

if (-not $wingetOk) { Write-Warning 'Some winget packages were not upgraded: run windots-update-winget to retry.' }
if (-not $miseOk)   { Write-Warning "Some mise tools were not updated: run 'mise up' to retry." }

$rebootKeys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
              'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
if ($rebootKeys | Where-Object { Test-Path $_ }) {
    if ($yes) { Write-Host "`nA reboot is needed to finish the update. Reboot when ready." -ForegroundColor Yellow }
    elseif (Confirm-Yes "`nA reboot is needed to finish the update. Reboot now?") { Restart-Computer }
} else {
    Write-Host "`nUpdate done." -ForegroundColor Green
}
