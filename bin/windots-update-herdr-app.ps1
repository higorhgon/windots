# windots-update-herdr-app [--app] [--retropet]
# windots:summary=Update herdr-app and/or the retropet layout (submodule)
# windots:args=[--app] [--retropet]
# windots:examples=windots update herdr app | windots update herdr app --retropet | windots update herdr app --app --retropet
#
#   --app        update herdr-app with the official installer (herdr-core updates itself); works
#                with herdr-app open, which keeps the old version until it restarts
#   --retropet   move the retropet submodule (default\retropet) to the latest commit of
#                github.com/higorhgon/retropet and copy its files again
#   no flag      the same as --app (this is the step windots-update runs)
#
# After --retropet the repo points at a new retropet commit: windots-update-herdr-app shows
# the command to record it, it never commits for you. Local changes inside default\retropet
# stop the update (commit and push them there first).
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$retropet = Join-Path $Repo 'default\retropet'
$doRetropet = $args -contains '--retropet'
$doApp = ($args -contains '--app') -or -not $doRetropet
foreach ($a in $args) { if ('--app', '--retropet' -notcontains $a) { throw "unknown option: $a (see windots update herdr app --help)" } }

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# The version from the exe itself: `herdr-app --version` is a GUI program and panics when its
# output is a pipe.
function Get-AppVersion {
    $exe = (Get-Command herdr-app.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($exe) { (Get-Item $exe).VersionInfo.ProductVersion } else { 'not installed' }
}

if ($doApp) {
    Step 'Updating herdr-app (official installer; also updates herdr-core)'
    # Open is fine: the installer renames the running app's folder (Windows allows that, not
    # overwriting) and the open window keeps running until it quits. herdr-core is updated
    # by the app itself.
    # The installer renames the app folder to herdr-app.old and fails when one is still there,
    # which happens when the previous update ran with the app open (it holds the old exe). Remove
    # leftovers if possible, else move them aside by name (renaming works while in use).
    $programs = Join-Path $env:LOCALAPPDATA 'Programs'
    foreach ($old in @(Get-ChildItem $programs -Directory -Filter 'herdr-app.old*' -ErrorAction SilentlyContinue)) {
        Remove-Item -Recurse -Force $old.FullName -ErrorAction SilentlyContinue
    }
    $stuck = Join-Path $programs 'herdr-app.old'
    if (Test-Path $stuck) {
        Rename-Item $stuck "herdr-app.old-$([DateTimeOffset]::Now.ToUnixTimeSeconds())" -ErrorAction SilentlyContinue
    }
    $before = Get-AppVersion
    powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://releases.herdr.dev/app/install.ps1 | iex"
    Refresh-Path
    $after = Get-AppVersion
    if ($before -eq $after) { Write-Host "  - already up to date ($after)" } else { Write-Host "  - $before -> $after" }
    if (Get-Process herdr-app -ErrorAction SilentlyContinue) {
        Write-Host '  - herdr-app is open: it keeps the old version until you restart it.' -ForegroundColor Yellow
    }
}

if ($doRetropet) {
    Step 'Updating retropet (submodule default\retropet)'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git not found on PATH.' }
    git -C $Repo submodule update --init -- default/retropet
    if (git -C $retropet status --porcelain) {
        throw "default\retropet has local changes: commit and push them there first (git -C default/retropet status)."
    }
    $old = (git -C $retropet rev-parse --short HEAD)
    git -C $Repo submodule update --remote -- default/retropet
    if ($LASTEXITCODE -ne 0) { throw 'could not fetch retropet from GitHub.' }
    $new = (git -C $retropet rev-parse --short HEAD)
    if ($old -eq $new) {
        Write-Host "  - already at the latest commit ($new)"
    } else {
        Write-Host "  - $old -> $new"
        git -C $retropet --no-pager log --oneline "$old..$new"
    }
    Step 'Copying the retropet files again'
    & (Join-Path $PSScriptRoot 'windots-install-herdr-app.ps1')
    if ($old -ne $new) {
        Write-Host "`nThe repo now points at retropet $new. Record it with:" -ForegroundColor Yellow
        Write-Host '  git -C ~/windots add default/retropet; git -C ~/windots commit -m "chore(herdr-app): update retropet"'
    }
}
