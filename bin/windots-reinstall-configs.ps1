# windots-reinstall-configs [-y]
# windots:summary=Reset every windots dotfile to the repo version and link it again
# windots:args=[-y]
# windots:examples=windots reinstall configs | windots reinstall configs -y
#
# Like omarchy-reinstall-configs: resets every windots dotfile in ~ to the repo
# version and links it again, so nothing left over can conflict (destructive).
#   0. folders in ~ that are links into the repo (tuckr "folds" a missing folder) become
#      real folders again, with the files apps wrote into the repo moved back to them,
#      and dotfiles deleted from the repo through those links come back from git;
#   1. for each file git tracks in Configs/<group>/, whatever is at its place in ~ is removed:
#      a copy, an old link, or a link into another folder. A file whose content
#      differs from the repo is saved first as <file>.bak.<unix time> (like
#      omarchy-refresh-config) and its diff is shown;
#   2. links in those folders that point into the repo at files that no longer
#      exist (renamed or removed from Configs) are removed;
#   3. windots-install -SkipPackages -SkipSystem links everything again and
#      re-applies the merged settings (Windows Terminal, Flow Launcher, autostart).
#
#   windots-reinstall-configs       asks before starting
#   windots-reinstall-configs -y    no questions
#
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$configs = Join-Path $Repo 'Configs'
$stamp = [DateTimeOffset]::Now.ToUnixTimeSeconds()

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
# Text compares ignore line endings: git checks files out with CRLF, apps write LF.
function Test-Same($a, $b) {
    if ((Get-FileHash $a).Hash -eq (Get-FileHash $b).Hash) { return $true }
    if ((Get-Item $a).Length -gt 2MB) { return $false }   # images: no line endings to ignore
    $latin1 = [Text.Encoding]::GetEncoding(28591)        # byte-for-byte, any encoding
    [IO.File]::ReadAllText($a, $latin1).Replace("`r", '') -eq [IO.File]::ReadAllText($b, $latin1).Replace("`r", '')
}
. (Join-Path $PSScriptRoot 'lib\dotfiles.ps1')

if ($args -notcontains '-y') {
    Write-Host 'This resets every windots dotfile in your home folder to the repo version and links it again.'
    Write-Host 'Files you changed are kept as <file>.bak.<time>, but the live versions are replaced.'
    if ((Read-Host 'Are you sure? [y/N]') -notmatch '^(y|yes|s|sim)$') { Write-Host 'Cancelled'; exit 1 }
}

# Before removing anything: make sure everything can be linked again.
$null = Assert-CanLink

# Only the files git tracks: apps may have written their own files into Configs.
$targets = @(Get-DotfileTargets $Repo)

Step 'Replacing folder links into the repo with real folders'
Repair-FoldedLinks $Repo $targets
Restore-DeletedDotfiles $Repo

Step 'Removing current dotfiles (backing up changed ones)'
$dirs = @{}
$removed = 0
foreach ($f in $targets) {
    $target = $f.Target
    $dirs[(Split-Path $target)] = $true
    $t = Get-Item $target -Force -ErrorAction SilentlyContinue
    if (-not $t) { continue }
    # Safety: through a folder link, removing ~\...\file would remove the repo's own file.
    $linkedParent = Get-LinkedParent $target
    if ($linkedParent) { Write-Warning "skipping $target ($linkedParent is a link)"; continue }
    if (-not $t.LinkType -and -not (Test-Same $target $f.Source)) {
        Copy-Item $target "$target.bak.$stamp" -Force
        Write-Host "  - changed: $target -> .bak.$stamp" -ForegroundColor Yellow
        if ($t.Length -lt 1MB -and (Get-Command git -ErrorAction SilentlyContinue)) {
            git --no-pager diff --no-index --ignore-cr-at-eol --stat $f.Source $target
        }
    }
    Remove-Dotfile $target
    $removed++
}
Write-Host "  - $removed files removed"

Step 'Removing links to files no longer in the repo'
$orphans = 0
foreach ($d in $dirs.Keys) {
    if (Get-LinkedParent (Join-Path $d 'x')) { continue }
    Get-ChildItem $d -Force -File -ErrorAction SilentlyContinue |
        Where-Object { Test-StaleRepoLink $_ $Repo } | ForEach-Object {
            Remove-Dotfile $_.FullName
            Write-Host "  - $($_.FullName)"
            $orphans++
        }
}
if (-not $orphans) { Write-Host '  - none' }

& (Join-Path $PSScriptRoot 'windots-install.ps1') -SkipPackages -SkipSystem
