# windots-reinstall-configs [-y]
#
# Like omarchy-reinstall-configs: resets every windots dotfile in ~ to the repo
# version and links it again, so nothing left over can conflict (destructive).
#   1. for each file in Configs/<group>/, whatever is at its place in ~ is removed:
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
function Test-LinkInto($item, $dir) {
    $item.LinkType -and (@($item.Target) | Where-Object { $_ -and $_.StartsWith($dir, 'OrdinalIgnoreCase') })
}

if ($args -notcontains '-y') {
    Write-Host 'This resets every windots dotfile in your home folder to the repo version and links it again.'
    Write-Host 'Files you changed are kept as <file>.bak.<time>, but the live versions are replaced.'
    if ((Read-Host 'Are you sure? [y/N]') -notmatch '^(y|yes|s|sim)$') { Write-Host 'Cancelled'; exit 1 }
}

Step 'Removing current dotfiles (backing up changed ones)'
$files = @(Get-ChildItem $configs -Recurse -File -Force)
$dirs = @{}
$removed = 0
foreach ($f in $files) {
    $group = $f.FullName.Substring($configs.Length + 1).Split('\')[0]
    $target = Join-Path $HOME $f.FullName.Substring((Join-Path $configs $group).Length + 1)
    $dirs[(Split-Path $target)] = $true
    $t = Get-Item $target -Force -ErrorAction SilentlyContinue
    if (-not $t) { continue }
    if (-not $t.LinkType -and -not (Test-Same $target $f.FullName)) {
        Copy-Item $target "$target.bak.$stamp" -Force
        Write-Host "  - changed: $target -> .bak.$stamp" -ForegroundColor Yellow
        if ($f.Length -lt 1MB -and (Get-Command git -ErrorAction SilentlyContinue)) {
            git --no-pager diff --no-index --ignore-cr-at-eol --stat $f.FullName $target
        }
    }
    Remove-Item $target -Force
    $removed++
}
Write-Host "  - $removed files removed"

Step 'Removing links to files no longer in the repo'
$orphans = 0
foreach ($d in $dirs.Keys) {
    Get-ChildItem $d -Force -File -ErrorAction SilentlyContinue | Where-Object {
        (Test-LinkInto $_ $Repo) -or (Test-LinkInto $_ (Join-Path $env:APPDATA 'dotfiles'))
    } | Where-Object { -not (Test-Path $_.FullName) } | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Host "  - $($_.FullName)"
        $orphans++
    }
}
if (-not $orphans) { Write-Host '  - none' }

& (Join-Path $PSScriptRoot 'windots-install.ps1') -SkipPackages -SkipSystem
