# windots-install-herdr-app
# windots:summary=Apply the herdr-app keys and settings and copy the retropet layout
#
# herdr-app rewrites keys.json and settings.json while it runs, so they are merged, not
# linked (the same reason as Windows Terminal and Flow Launcher):
#   - keys.json     = default\herdr-app\keys.json (omarchy binds) + the retropet binds
#                     (default\retropet\keys.json), written whole;
#   - settings.json = the live file with default\herdr-app\settings.json laid over it.
# A backup is kept as <file>.bak.<time> when something changes.
#
# retropet (github.com/higorhgon/retropet) is the git submodule default\retropet. Its layout,
# mods and theme are COPIED file by file into ~\.config\herdr-app (as herdr-app's own docs say:
# it refuses a mod whose files resolve outside its folder, which a link into the submodule
# does), so nothing else herdr-app installs there (its own mods and themes) is touched.
# Edit retropet in default\retropet (commit and push there), not in ~\.config\herdr-app:
# the copies are overwritten on the next run (a changed one is kept as <file>.bak.<time>).
# Old links into windots (what this script and tuckr used to make) are replaced.
#
# herdr-app reads all of this at start: restart it to see the change.
# Called by windots-install; safe to run again on its own.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\dotfiles.ps1')
$home_ = Join-Path $HOME '.config\herdr-app'
$retropet = Join-Path $Repo 'default\retropet'
$stamp = [DateTimeOffset]::Now.ToUnixTimeSeconds()

function Read-Json($path) { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json }
# Lays $over over $base, section by section (objects merge, everything else is replaced).
function Merge-Json($base, $over) {
    foreach ($p in $over.PSObject.Properties) {
        $cur = $base.PSObject.Properties[$p.Name]
        if ($cur -and $cur.Value -is [pscustomobject] -and $p.Value -is [pscustomobject]) { Merge-Json $cur.Value $p.Value }
        elseif ($cur) { $cur.Value = $p.Value }   # in place: Add-Member -Force would move it to the end and change the file for nothing
        else { $base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value }
    }
}
# Writes $obj to $path when it differs from what is there (the old file is kept as .bak.<time>).
function Save-Json($path, $obj, $label) {
    $json = $obj | ConvertTo-Json -Depth 32
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($item) {
        $same = $false
        try { $same = ((Read-Json $path | ConvertTo-Json -Depth 32 -Compress) -eq ($obj | ConvertTo-Json -Depth 32 -Compress)) } catch { }
        if ($same -and -not $item.LinkType) { Write-Host "  - $label already applied"; return }
        if (-not $item.LinkType) { Copy-Item -LiteralPath $path "$path.bak.$stamp" }
        Remove-Dotfile $path   # an old tuckr link or a changed file (the Recycle Bin keeps it)
    }
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding $false))
    Write-Host "  - $label applied"
}

# ---------------------------------------------------------------- retropet submodule
$haveRetropet = $false
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning 'git not found on PATH: retropet is skipped. Open a new terminal and run: windots install herdr app'
} else {
    git -C $Repo submodule update --init -- default/retropet 2>&1 | ForEach-Object { Write-Host "  $_" }
    $haveRetropet = Test-Path (Join-Path $retropet 'layouts\retropet.json')
    if (-not $haveRetropet) { Write-Warning 'default\retropet is empty (submodule not fetched?): retropet is skipped.' }
}

# ---------------------------------------------------------------- keys.json + settings.json
New-Item -ItemType Directory -Force $home_ | Out-Null
$keys = Read-Json (Join-Path $Repo 'default\herdr-app\keys.json')
if ($haveRetropet -and (Test-Path (Join-Path $retropet 'keys.json'))) { Merge-Json $keys (Read-Json (Join-Path $retropet 'keys.json')) }
Save-Json (Join-Path $home_ 'keys.json') $keys 'keys.json'

$settingsPath = Join-Path $home_ 'settings.json'
# An old tuckr link whose repo file is gone reads as missing (Test-Path says True for it in pwsh 7).
$settingsItem = Get-Item -LiteralPath $settingsPath -Force -ErrorAction SilentlyContinue
$settings = if ($settingsItem -and -not (Test-StaleRepoLink $settingsItem $Repo)) { Read-Json $settingsPath } else { [pscustomobject]@{} }
Merge-Json $settings (Read-Json (Join-Path $Repo 'default\herdr-app\settings.json'))
Save-Json $settingsPath $settings 'settings.json'

# ---------------------------------------------------------------- retropet files
# Old links into windots (the dotfiles windots used to carry, or retropet files that moved)
# whose target is gone.
foreach ($sub in 'layouts', 'mods', 'themes') {
    $dir = Join-Path $home_ $sub
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem $dir -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { Test-StaleRepoLink $_ $Repo } | ForEach-Object {
            Remove-Dotfile $_.FullName
            Write-Host "  - removed old link $($_.FullName)"
        }
}

if ($haveRetropet) {
    # What herdr-app writes into every mod on each start is not retropet's.
    $skip = 'gpui-kit.d.ts', 'jsconfig.json'
    $files = @(foreach ($sub in 'layouts', 'mods', 'themes') {
        $d = Join-Path $retropet $sub
        if (Test-Path $d) { Get-ChildItem $d -Recurse -Force -File | Where-Object { $skip -notcontains $_.Name } }
    })
    $same = 0; $copied = 0
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($retropet.Length + 1)
        $target = Join-Path $home_ $rel
        $t = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if ($t -and $t.LinkType) {
            Remove-Dotfile $target   # an old link into windots: copy over a link would write through it
            $t = $null
        }
        if ($t) {
            if ((Get-FileHash $target).Hash -eq (Get-FileHash $f.FullName).Hash) { $same++; continue }
            Copy-Item -LiteralPath $target "$target.bak.$stamp"
            Write-Host "  - changed: $target -> .bak.$stamp" -ForegroundColor Yellow
        }
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Copy-Item -LiteralPath $f.FullName $target -Force
        $copied++
    }
    Write-Host "  - retropet: $copied copied, $same already up to date, in $home_"
}

if (Get-Process herdr-app -ErrorAction SilentlyContinue) {
    Write-Host '  - herdr-app is open: restart it to load the changes.' -ForegroundColor Yellow
}
