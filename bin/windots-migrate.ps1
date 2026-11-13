# windots-migrate [--pending | --mark-all]
# windots:summary=Run the windots migrations this machine has not run yet
# windots:args=[--pending | --mark-all]
# windots:examples=windots migrate | windots migrate --pending | windots migrate --mark-all
#
# Like omarchy-migrate: a migration is a script in the repo's migrations\ folder named by the
# Unix time it was written (migrations\1794518371.ps1). It changes what a new windots needs on a
# machine that already has an older one: a setting that moved, a file that is gone. Each runs
# once per machine, in order; a marker per migration in ~\.local\state\windots\migrations\ says it
# ran. A migration that fails stops the run and has no marker, so the next run tries it again:
# write them to be safe to repeat.
#   (no flag)    run the pending ones; windots-update does this after re-applying windots
#   --pending    list the pending ones; exit 0 when there are some, 1 when there are none
#   --mark-all   mark every migration as done without running it: a machine that was just
#                installed already has everything they would change (the one-line installer does this)
# New one: windots-dev-add-migration.
# Each migration runs in Windows PowerShell 5.1 with $env:WINDOTS_PATH set to the repo.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$known = '--pending', '--check', '--mark-all'
$unknown = @($args | Where-Object { $known -notcontains $_ })
if ($unknown) { Write-Host "windots-migrate: unknown option $($unknown -join ' ') (see: windots migrate --help)" -ForegroundColor Red; exit 2 }
if ($args.Count -gt 1) { Write-Host 'windots-migrate: pass only one option' -ForegroundColor Red; exit 2 }
$mode = if ($args -contains '--mark-all') { 'mark-all' } elseif ($args.Count) { 'pending' } else { 'run' }

$ErrorActionPreference = 'Stop'
$repo = if ($env:WINDOTS_PATH) { $env:WINDOTS_PATH } else { Split-Path $PSScriptRoot }
$migrationsDir = Join-Path $repo 'migrations'
$stateDir = if ($env:WINDOTS_MIGRATION_STATE) { $env:WINDOTS_MIGRATION_STATE } else { Join-Path $HOME '.local\state\windots\migrations' }

# Oldest first: the names are Unix times of the same length for a long time, but sort them as numbers.
$all = @(if (Test-Path $migrationsDir) {
    Get-ChildItem $migrationsDir -Filter '*.ps1' -File | Sort-Object { [int64]($_.BaseName -replace '\D', '0') }, Name
})
$pending = @($all | Where-Object { -not (Test-Path (Join-Path $stateDir $_.Name)) })

if ($mode -eq 'pending') {
    $pending | ForEach-Object { $_.Name }
    if ($pending) { exit 0 } else { exit 1 }
}

New-Item -ItemType Directory -Force $stateDir | Out-Null

if ($mode -eq 'mark-all') {
    foreach ($m in $pending) { New-Item -ItemType File -Force (Join-Path $stateDir $m.Name) | Out-Null }
    Write-Host ("  - {0} migrations marked as done" -f $pending.Count)
    return
}

if (-not $pending) { Write-Host '  - no pending migrations'; return }

$ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$env:WINDOTS_PATH = $repo
foreach ($m in $pending) {
    Write-Host ("`nRunning migration ({0})" -f $m.BaseName) -ForegroundColor Green
    & $ps51 -NoProfile -ExecutionPolicy Bypass -File $m.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("Migration {0} failed (exit {1}); it will run again next time." -f $m.BaseName, $LASTEXITCODE) -ForegroundColor Red
        exit 1
    }
    New-Item -ItemType File -Force (Join-Path $stateDir $m.Name) | Out-Null
}
