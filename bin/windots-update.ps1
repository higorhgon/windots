# windots-update [-y] [--prune] [--skip-packages] [--skip-winget] [--skip-herdr-app] [--skip-mise]
# windots:summary=Update windots, winget packages, herdr-app and mise tools
# windots:args=[-y] [--prune] [--skip-packages] [--skip-winget] [--skip-herdr-app] [--skip-mise]
# windots:examples=windots update | windots update -y --prune | windots update -y --skip-winget | windots update -y --skip-packages
#
# Like omarchy-update: updates windots and everything it installed, in this order:
#   1. the windots repo (windots-update-dev: git pull --ff-only + submodules)  like omarchy-update-dev
#   2. winget packages (windots-update-winget, one UAC)     like omarchy-update-system-pkgs
#   3. herdr-app (windots-update-herdr-app --app; retropet only moves with --retropet), and Ghostty
#      when installed (windots-install-terminal ghostty; an open Ghostty is left alone, it says how)
#   4. re-applies windots (windots-install --skip-packages --skip-system):
#      links new dotfiles, merges the Windows Terminal settings, autostart.
#      If this fails the update stops: migrations and the rest need it done.
#   5. migrations this machine has not run yet (windots-migrate)   like omarchy-migrate
#   6. starts again the apps the update closed (windots-update-restart), then runs the
#      per-machine hook post-update if there is one (windots-hook)
#   7. mise tools (windots-update-mise)                     like omarchy-update-mise
#   8. offers a reboot when Windows needs one
#
# Only one update runs at a time (a second one says so and stops), the PC is kept awake while it
# runs, and with packages to upgrade it stops early when the system drive has less than 5 GB free
# (WINDOTS_UPDATE_MIN_FREE_GB changes the limit).
#
#   windots-update       asks before starting and before rebooting
#   windots-update -y    no questions (the UAC prompt for winget still shows)
#   --prune              also remove mise tool versions no config uses (mise prune), freeing disk
#   --skip-winget        skip step 2: no winget upgrade (the slow one, with the UAC prompt)
#   --skip-herdr-app     skip step 3: no herdr-app update
#   --skip-mise          skip step 7: no mise up (and no --prune)
#   --skip-packages      all three at once: update only windots itself (steps 1, 4, 5, 6 and 8). Same
#                        meaning as in windots-install: "packages" is every app and tool windots
#                        installs, mise tools included.
#
# The output is logged to %TEMP%\windots-update.log.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$known = '-y', '--prune', '--skip-packages', '--skip-winget', '--skip-herdr-app', '--skip-mise'
$unknown = @($args | Where-Object { $known -notcontains $_ })
if ($unknown) {   # a typo must not turn into a full update
    Write-Host "windots-update: unknown option $($unknown -join ' ') (see: windots update --help)" -ForegroundColor Red
    exit 1
}
$yes = $args -contains '-y'
$prune = $args -contains '--prune'
$skipPackages = $args -contains '--skip-packages'   # winget + herdr-app + mise
$skipWinget = $skipPackages -or ($args -contains '--skip-winget')
$skipHerdr = $skipPackages -or ($args -contains '--skip-herdr-app')
$skipMise = $skipPackages -or ($args -contains '--skip-mise')

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Green }
function Confirm-Yes($question) {
    if ($yes) { return $true }
    (Read-Host "$question [y/N]") -match '^(y|yes|s|sim)$'
}

if (-not $yes) {
    $parts = @('windots')
    if (-not $skipWinget) { $parts += 'winget packages' }
    if (-not $skipHerdr) { $parts += 'herdr-app' }
    if (-not $skipMise) { $parts += 'mise tools' }
    Write-Host ('Ready to update {0}.' -f ($parts -join ', '))
    if (-not $skipWinget -or -not $skipHerdr) {
        Write-Host '  - Apps being upgraded may close while their installer runs.'
        Write-Host '  - Laptops: keep the charger connected.'
    }
    if (-not (Confirm-Yes 'Continue?')) { Write-Host 'Update cancelled'; exit 1 }
}

# one update at a time (like omarchy's flock)
$createdNew = $false
$lock = New-Object System.Threading.Mutex($false, 'Local\windots-update', [ref]$createdNew)
$haveLock = $false
try { $haveLock = $lock.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $haveLock = $true }
if (-not $haveLock) {
    Write-Host 'windots-update: another update is already running.' -ForegroundColor Red
    exit 1
}

if (-not $skipWinget -or -not $skipHerdr -or -not $skipMise) {
    $minGb = 5
    if ($env:WINDOTS_UPDATE_MIN_FREE_GB -match '^\d+(\.\d+)?$') { $minGb = [double]$env:WINDOTS_UPDATE_MIN_FREE_GB }
    $drive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
    if ($drive -and ($drive.Free / 1GB) -lt $minGb) {
        Write-Host ('windots-update: only {0:N1} GB free on {1}, need {2} GB. Free some space (or set WINDOTS_UPDATE_MIN_FREE_GB).' -f ($drive.Free / 1GB), $env:SystemDrive, $minGb) -ForegroundColor Red
        $lock.ReleaseMutex()
        exit 1
    }
}

# keep the PC awake while it runs (SetThreadExecutionState: ES_CONTINUOUS | ES_SYSTEM_REQUIRED)
try {
    Add-Type -Namespace Windots -Name Power -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -ErrorAction Stop
    [void][Windots.Power]::SetThreadExecutionState([uint32]2147483649)
} catch { Write-Warning "could not keep the PC awake: $($_.Exception.Message)" }

$wingetOk = $true
$miseOk = $true
Start-Transcript -Path (Join-Path $env:TEMP 'windots-update.log') | Out-Null
try {
    # apps that are running now: the upgrades may close some, and they are started again below
    $before = @(& (Join-Path $PSScriptRoot 'windots-update-restart.ps1') --snapshot)

    Step 'Update windots'
    & (Join-Path $PSScriptRoot 'windots-update-dev.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'updating the windots repo failed (above); fix it and run windots-update again.' }

    if ($skipWinget) {
        Write-Host '  - winget packages skipped'
    } else {
        Step 'Update winget packages'
        & (Join-Path $PSScriptRoot 'windots-update-winget.ps1')
        $wingetOk = $LASTEXITCODE -eq 0
    }

    if ($skipHerdr) {
        Write-Host '  - herdr-app skipped'
    } else {
        Step 'Update herdr-app'
        try {
            $global:LASTEXITCODE = 0
            & (Join-Path $PSScriptRoot 'windots-update-herdr-app.ps1') --app
            if ($LASTEXITCODE -ne 0) { Write-Warning "herdr-app was not updated (exit $LASTEXITCODE)" }
        }
        catch { Write-Warning "herdr-app was not updated: $($_.Exception.Message)" }
    }

    if (-not $skipPackages) {
        . (Join-Path $PSScriptRoot 'lib\terminal.ps1')
        if (Get-GhosttyExe) {
            Step 'Update Ghostty'
            $global:LASTEXITCODE = 0
            & (Join-Path $PSScriptRoot 'windots-install-terminal.ps1') ghostty --keep-default
            if ($LASTEXITCODE -ne 0) { Write-Warning "Ghostty was not updated (exit $LASTEXITCODE)" }
        }
    }

    Step 'Re-apply windots'
    $global:LASTEXITCODE = 0
    & (Join-Path $PSScriptRoot 'windots-install.ps1') --skip-packages --skip-system
    if ($LASTEXITCODE -ne 0) { throw 'the re-apply failed (above); fix it and run windots-update again.' }

    Step 'Run migrations'
    $global:LASTEXITCODE = 0
    & (Join-Path $PSScriptRoot 'windots-migrate.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'a migration failed (above); fix it and run windots-update again.' }

    if ($before.Count) {
        Step 'Start again the apps the update closed'
        & (Join-Path $PSScriptRoot 'windots-update-restart.ps1') @before
    }

    Step 'Run the post-update hook'
    & (Join-Path $PSScriptRoot 'windots-hook.ps1') post-update

    if ($skipMise) {
        Write-Host '  - mise tools skipped'
    } else {
        Step 'Update mise tools'
        $global:LASTEXITCODE = 0
        if ($prune) { & (Join-Path $PSScriptRoot 'windots-update-mise.ps1') --prune }
        else { & (Join-Path $PSScriptRoot 'windots-update-mise.ps1') }
        $miseOk = $LASTEXITCODE -eq 0
    }
} catch {
    Write-Host "`nSomething went wrong during the update: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Review the output above (also in %TEMP%\windots-update.log) and run windots-update again.' -ForegroundColor Red
    exit 1
} finally {
    Stop-Transcript | Out-Null
    try { [void][Windots.Power]::SetThreadExecutionState([uint32]2147483648) } catch { }
    try { $lock.ReleaseMutex() } catch { }
}

if (-not $wingetOk) { Write-Warning 'Some winget packages were not upgraded: run windots-update-winget to retry.' }
if (-not $miseOk)   { Write-Warning "Some mise tools were not updated: run windots update mise to retry." }

$rebootKeys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
              'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
if ($rebootKeys | Where-Object { Test-Path $_ }) {
    if ($yes) { Write-Host "`nA reboot is needed to finish the update. Reboot when ready." -ForegroundColor Yellow }
    elseif (Confirm-Yes "`nA reboot is needed to finish the update. Reboot now?") { Restart-Computer }
} else {
    Write-Host "`nUpdate done." -ForegroundColor Green
}
