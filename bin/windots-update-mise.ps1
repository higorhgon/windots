# windots-update-mise [--prune]
# windots:summary=Update the mise tools (mise up), and optionally remove the versions nothing uses
# windots:args=[--prune]
# windots:examples=windots update mise | windots update mise --prune
#
# Like omarchy-update-mise: updates the tools of the windots mise config (atuin, starship, neovim...).
# mise holds back very new releases; updating means wanting them now, so the hold is lifted for this
# run (omarchy does the same). A failure here is the update's to report, not to stop on:
# windots-update goes on and tells you to run this again.
#   --prune   also remove tool versions no config uses (mise prune), freeing disk
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$prune = $args -contains '--prune'
foreach ($a in $args) { if ($a -ne '--prune') { Write-Host "unknown option: $a (see windots update mise --help)" -ForegroundColor Red; exit 2 } }

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Host 'mise not found on PATH: run windots reinstall pkgs' -ForegroundColor Yellow
    exit 1
}
$env:MISE_MINIMUM_RELEASE_AGE = '0'
mise up
$code = $LASTEXITCODE
if ($prune) {
    Write-Host "`nRemoving unused mise versions"
    mise prune --yes
    if ($LASTEXITCODE -ne 0 -and $code -eq 0) { $code = $LASTEXITCODE }
}
exit $code
