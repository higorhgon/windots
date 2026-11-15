# windots-update-dev
# windots:summary=Update the windots repository: git pull --ff-only and its submodules
# windots:examples=windots update dev
#
# Like omarchy-update-dev: brings this checkout up to date, nothing else. windots-update runs it first.
# A pull with local changes in the way stops here, with a message, instead of merging over them.
# `git pull` does not move submodules, so the retropet one is brought to the commit the repo records.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots update dev --help)" -ForegroundColor Red; exit 2 }

$repo = Split-Path $PSScriptRoot
git -C $repo pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Host "git pull failed in $repo (local changes?); fix it and run windots update dev again." -ForegroundColor Red
    exit 1
}
git -C $repo submodule update --init
if ($LASTEXITCODE -ne 0) {
    Write-Host 'git submodule update failed; see above.' -ForegroundColor Red
    exit 1
}
exit 0
