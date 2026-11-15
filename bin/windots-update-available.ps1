# windots-update-available
# windots:summary=Say whether the windots repository has commits this machine does not
# windots:examples=windots update available
#
# Like omarchy-update-available: fetches, then compares with the branch this checkout follows.
# Nothing is changed in the working tree. Exit code: 0 when an update is available (and what is
# new is listed), 1 when you are up to date, 2 when it could not tell (offline, no upstream).
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots update available --help)" -ForegroundColor Red; exit 2 }

$repo = Split-Path $PSScriptRoot
git -C $repo fetch --quiet 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host 'Could not fetch (offline?): cannot tell.' -ForegroundColor Yellow; exit 2 }
$upstream = (git -C $repo rev-parse --abbrev-ref '@{upstream}' 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $upstream) { Write-Host 'This branch follows no upstream: cannot tell.' -ForegroundColor Yellow; exit 2 }
$behind = [int](git -C $repo rev-list --count "HEAD..$upstream")
$ahead = [int](git -C $repo rev-list --count "$upstream..HEAD")
if ($behind -eq 0) {
    $extra = if ($ahead) { " ($ahead local commit$(if ($ahead -ne 1) { 's' }) not pushed)" } else { '' }
    Write-Host "windots is up to date$extra."
    exit 1
}
Write-Host ("{0} new commit{1} on {2}:" -f $behind, $(if ($behind -ne 1) { 's' }), $upstream) -ForegroundColor Green
git -C $repo --no-pager log --oneline "HEAD..$upstream" | Select-Object -First 15 | ForEach-Object { "  $_" }
if ($behind -gt 15) { Write-Host "  ... and $($behind - 15) more" }
Write-Host 'Run: windots update'
exit 0
