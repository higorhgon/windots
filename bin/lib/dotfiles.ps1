# Helpers shared by windots-install and windots-reinstall-configs (dot-sourced, not a command;
# bin\lib is not on PATH). Works on Windows PowerShell 5.1 and PowerShell 7.
#
# Why: when a folder is missing in ~, tuckr links the whole folder into the repo ("folding")
# instead of linking each file. Apps then write their own state (sockets, caches, sessions)
# into the repo, and deleting ~\<folder>\<file> deletes the repo's file. So:
#   - dotfiles are the files git tracks under Configs, never whatever sits in those folders;
#   - folder links into the repo are replaced by real folders before anything is linked or removed.

# Every tracked file under Configs\<group>\ with its place in ~.
function Get-DotfileTargets($Repo) {
    $rel = @()
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $rel = @(git -C $Repo -c core.quotepath=off ls-files -- Configs)
    }
    if (-not $rel) {   # no git (repo downloaded as .zip): everything in Configs
        $rel = @(Get-ChildItem (Join-Path $Repo 'Configs') -Recurse -File -Force |
            ForEach-Object { $_.FullName.Substring($Repo.Length + 1) })
    }
    foreach ($r in $rel) {
        $parts = ($r -replace '/', '\').Split('\')   # Configs, <group>, <path in ~>...
        [pscustomobject]@{
            Group  = $parts[1]
            Source = Join-Path $Repo ($parts -join '\')
            Target = Join-Path $HOME ($parts[2..($parts.Count - 1)] -join '\')
        }
    }
}

# The repo path a link points to, if it points into the repo (directly or via %APPDATA%\dotfiles).
function Get-RepoLinkTarget($Item, $Repo) {
    if (-not $Item -or -not $Item.LinkType) { return $null }
    foreach ($t in @($Item.Target)) {
        if (-not $t) { continue }
        foreach ($root in $Repo, (Join-Path $env:APPDATA 'dotfiles')) {
            if ($t.TrimEnd('\') -eq $root -or $t.StartsWith("$root\", 'OrdinalIgnoreCase')) {
                return $Repo + $t.Substring($root.Length)
            }
        }
    }
    $null
}

# A link into the repo whose repo file is gone (Test-Path on the link itself says True in pwsh 7).
function Test-StaleRepoLink($Item, $Repo) {
    $repoPath = Get-RepoLinkTarget $Item $Repo
    [bool]$repoPath -and -not (Test-Path -LiteralPath $repoPath)
}

# A folder between ~ and the file that is itself a link (anything below it lives elsewhere).
function Get-LinkedParent($Path) {
    $dir = Split-Path $Path
    while ($dir -and $dir.Length -gt $HOME.Length) {
        $i = Get-Item $dir -Force -ErrorAction SilentlyContinue
        if ($i -and $i.LinkType) { return $dir }
        $dir = Split-Path $dir
    }
    $null
}

# The only way windots removes something from ~ (keep it that way):
#   - only a file, never a folder;
#   - never through a folder link (that would remove the repo's own file);
#   - a link is just removed (it holds no data); a real file goes to the Recycle Bin,
#     so a mistake can always be undone.
function Remove-Dotfile($Path) {
    $i = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if (-not $i) { return }
    if ($i.PSIsContainer) { throw "windots refuses to remove a folder: $Path" }
    $linkedParent = Get-LinkedParent $Path
    if ($linkedParent) { throw "windots refuses to remove ${Path}: $linkedParent is a link" }
    if ($i.LinkType) { [IO.File]::Delete($Path); return }
    Add-Type -AssemblyName Microsoft.VisualBasic
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
}

# Folders windots used before and no longer does (OneDrive backs them up, which conflicts
# with links): their links into the repo point at nothing now.
$WindotsOldPlaces = @(
    (Join-Path $HOME 'Documents\PowerShell'),           # profile, now ~\.config\powershell
    (Join-Path $HOME 'Pictures\Wallpapers\catppuccin')  # backgrounds, now ~\.config\windots\backgrounds
)

# File links into the repo, in those folders, whose repo file is gone. Folders are left alone.
function Remove-StaleLinks($Repo, $Dirs) {
    foreach ($d in $Dirs) {
        if (Get-LinkedParent (Join-Path $d 'x')) { continue }
        Get-ChildItem $d -Force -File -ErrorAction SilentlyContinue |
            Where-Object { Test-StaleRepoLink $_ $Repo } | ForEach-Object {
                Remove-Dotfile $_.FullName
                Write-Host "  - removed old link $($_.FullName)"
            }
    }
}

# Tracked dotfiles missing from the repo (deleted through an old folder link) come back from
# git. Changed ones are left alone: with links, a change in the repo is the person's own edit.
function Restore-DeletedDotfiles($Repo) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }
    $deleted = @(git -C $Repo -c core.quotepath=off ls-files --deleted -- Configs)
    if (-not $deleted) { return }
    git -C $Repo checkout -- @deleted
    Write-Host "  - $($deleted.Count) dotfiles missing from the repo restored from git"
}

# Replace folder links into the repo with real folders; files the apps wrote into the repo
# through them (untracked) are moved back to the real folder.
function Repair-FoldedLinks($Repo, $Targets, $AlsoCheck = @()) {
    $folded = @{}
    $paths = @($Targets | ForEach-Object Target) + @($AlsoCheck | ForEach-Object { Join-Path $_ 'x' })
    foreach ($p in $paths) {
        $dir = Split-Path $p
        while ($dir.Length -gt $HOME.Length) {
            $i = Get-Item $dir -Force -ErrorAction SilentlyContinue
            $repoDir = Get-RepoLinkTarget $i $Repo
            if ($repoDir -and $i.PSIsContainer) { $folded[$dir] = $repoDir }
            $dir = Split-Path $dir
        }
    }
    # Outermost first: once it is a real folder, the paths below it are real too.
    foreach ($dir in @($folded.Keys | Sort-Object Length)) {
        $repoDir = $folded[$dir]
        if (-not (Get-Item $dir -Force -ErrorAction SilentlyContinue).LinkType) { continue }
        [IO.Directory]::Delete($dir)   # removes only the link, never what it points to
        New-Item -ItemType Directory -Force $dir | Out-Null
        $relRepoDir = $repoDir.Substring($Repo.Length + 1)
        $moved = 0; $failed = 0
        foreach ($u in @(git -C $Repo -c core.quotepath=off ls-files --others -- ($relRepoDir -replace '\\', '/'))) {
            $u = $u -replace '/', '\'
            $dst = Join-Path $dir $u.Substring($relRepoDir.Length + 1)
            try {
                New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
                Move-Item (Join-Path $Repo $u) $dst -Force -ErrorAction Stop
                $moved++
            } catch { $failed++ }   # e.g. a socket an app still holds open
        }
        Write-Host "  - $dir was a link to the repo folder: now a real folder ($moved app files moved out of the repo)"
        if ($failed) { Write-Warning "$failed files are still in $repoDir (in use?); close the app and run again." }
    }
}
