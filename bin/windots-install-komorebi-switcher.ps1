# windots-install-komorebi-switcher [--build] [--alignment left|center|right] [--workspaces <n>] [--revert] [--check]
# windots:summary=Install windots' build of komorebi-switcher (alignment, persistent workspaces)
# windots:args=[--build] [--alignment left|center|right] [--workspaces <n>] [--revert] [--check]
# windots:examples=windots install komorebi switcher | windots install komorebi switcher --alignment left | windots install komorebi switcher --build
#
# Upstream's komorebi-switcher cannot place itself in the taskbar and shows every workspace. windots builds the
# upstream release (tag v0.10.4) with default\komorebi-switcher\windots.patch, which adds to komorebi-switcher.toml:
#   alignment = "left"|"center"|"right"   left: after the Start button (or at the left edge when Start is in the middle),
#                                         right: before the tray; it follows the taskbar as workspaces come and go
#   persistent_workspaces = N             workspaces 1..N always shown, the others while busy or focused; empty ones dimmed
# A GitHub Actions workflow (.github/workflows/komorebi-switcher.yml) builds it and publishes a release on this repo
# (tag komorebi-switcher-v<upstream>-windots.<n>). This command downloads the newest one, checks its SHA-256 and puts it
# where the installed switcher is, then sets the keys in ~\.config\komorebi-switcher.toml.
#   --build            compile it here instead (git, Rust and the Visual Studio Build Tools; a lighter profile than
#                      upstream's: first build ~7 minutes, the next ones ~2)
#   --alignment <a>    default center        --workspaces <n>   default 5 (1 to 10)
#   --revert           put the original switcher back and remove the keys
#   --check            say what is installed; change nothing
# The original exe is kept as komorebi-switcher.exe.orig. A winget update of the switcher puts upstream back: run this again.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Continue'   # Windows PowerShell 5.1 turns a native command's stderr into an error with 'Stop'

$Tag = 'v0.10.4'
$Upstream = 'https://github.com/amrbashir/komorebi-switcher.git'
$ReleasesApi = 'https://api.github.com/repos/higorhgon/windots/releases?per_page=30'
$Repo = Split-Path $PSScriptRoot -Parent
$Patch = Join-Path $Repo 'default\komorebi-switcher\windots.patch'
$Build = Join-Path $HOME '.local\share\windots-build\komorebi-switcher'
$State = Join-Path $HOME '.local\state\windots\komorebi-switcher.release'
$Exe = Join-Path $env:LOCALAPPDATA 'Programs\komorebi-switcher\komorebi-switcher.exe'
$Orig = "$Exe.orig"
$Toml = Join-Path $HOME '.config\komorebi-switcher.toml'

$n = 5; $alignment = 'center'; $revert = $false; $check = $false; $build = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($a -eq '--workspaces' -and $i + 1 -lt $args.Count) { $n = [int]$args[++$i] }
    elseif ($a -like '--workspaces=*') { $n = [int]$a.Substring(13) }
    elseif ($a -eq '--alignment' -and $i + 1 -lt $args.Count) { $alignment = [string]$args[++$i] }
    elseif ($a -like '--alignment=*') { $alignment = $a.Substring(12) }
    elseif ($a -eq '--build') { $build = $true }
    elseif ($a -eq '--revert') { $revert = $true }
    elseif ($a -eq '--check') { $check = $true }
    else { Write-Host "unknown option: $a (see windots install komorebi switcher --help)" -ForegroundColor Red; exit 2 }
}
if ($n -lt 1 -or $n -gt 10) { Write-Host '--workspaces takes 1 to 10' -ForegroundColor Red; exit 2 }
if ('left', 'center', 'right' -notcontains $alignment) { Write-Host '--alignment takes left, center or right' -ForegroundColor Red; exit 2 }

function Step($msg) { Write-Host "  - $msg" }
function Get-Key($name) { if (Test-Path $Toml) { $m = [regex]::Match([IO.File]::ReadAllText($Toml), "(?m)^\s*$name\s*=\s*`"?(\w+)`"?"); if ($m.Success) { return $m.Groups[1].Value } }; $null }
# keeps the file as it is: only the line of the key changes, and a new one goes after hide_empty_workspaces
function Set-Key($name, $value) {
    if (-not (Test-Path $Toml)) { return }
    $text = [IO.File]::ReadAllText($Toml)
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $text = [regex]::Replace($text, "(?m)^[ \t]*$name[ \t]*=.*\r?\n", '')
    if ($null -ne $value) {
        $line = "$name = $value$nl"
        if ($text -match '(?m)^hide_empty_workspaces[^\r\n]*\r?\n') { $text = [regex]::Replace($text, '(?m)^(hide_empty_workspaces[^\r\n]*\r?\n)', ('$1' + $line.Replace('$', '$$')), 1) }
        else { $text = $line + $text }
    }
    [IO.File]::WriteAllText($Toml, $text, (New-Object Text.UTF8Encoding($false)))
}
function Stop-Switcher {
    $p = @(Get-Process komorebi-switcher -ErrorAction SilentlyContinue)
    if ($p) { $p | Stop-Process -Force; $p | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue }
}
function Invoke-Native($what, [scriptblock]$cmd) { & $cmd; if ($LASTEXITCODE -ne 0) { Write-Host "$what failed (output above)" -ForegroundColor Red; exit 1 } }
function Get-ReleaseInfo {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $all = Invoke-RestMethod -Uri $ReleasesApi -Headers @{ 'User-Agent' = 'windots' } -ErrorAction Stop
        $rel = @($all | Where-Object { $_.tag_name -like 'komorebi-switcher-*' -and -not $_.draft } | Select-Object -First 1)
        if (-not $rel.Count) { return $null }
        $exeAsset = $rel[0].assets | Where-Object { $_.name -eq 'komorebi-switcher.exe' } | Select-Object -First 1
        $shaAsset = $rel[0].assets | Where-Object { $_.name -eq 'komorebi-switcher.exe.sha256' } | Select-Object -First 1
        if (-not $exeAsset -or -not $shaAsset) { return $null }
        return @{ Tag = $rel[0].tag_name; Exe = $exeAsset.browser_download_url; Sha = $shaAsset.browser_download_url }
    } catch { return $null }
}
function Install-Exe($source) {
    Stop-Switcher
    if (-not (Test-Path $Orig)) { Copy-Item $Exe $Orig; Step 'original kept as komorebi-switcher.exe.orig' }
    # the exe stays locked for a moment after the process ends: retry, and say so when it never lets go
    foreach ($try in 1..15) {
        try { Copy-Item $source $Exe -Force -ErrorAction Stop; return $true }
        catch { Stop-Switcher; Start-Sleep -Milliseconds 500 }
    }
    Write-Host "could not replace $Exe (in use?)" -ForegroundColor Red
    return $false
}

if ($check) {
    Write-Host "komorebi-switcher: $(if (Test-Path $Exe) { $Exe } else { 'not installed (windots reinstall pkgs)' })"
    Write-Host "windots build installed: $(Test-Path $Orig)  (the original is kept beside it)"
    Write-Host "release: $(if (Test-Path $State) { (Get-Content $State -Raw).Trim() } else { '(none: built here or not installed)' })"
    Write-Host "alignment: $(if (Get-Key 'alignment') { Get-Key 'alignment' } else { '(not set)' })   persistent_workspaces: $(if (Get-Key 'persistent_workspaces') { Get-Key 'persistent_workspaces' } else { '(not set)' })"
    $latest = Get-ReleaseInfo
    Write-Host "newest release: $(if ($latest) { $latest.Tag } else { '(none found)' })"
    exit 0
}

if (-not (Test-Path $Exe)) { Write-Host 'komorebi-switcher is not installed: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }

if ($revert) {
    Write-Host '==> Reverting komorebi-switcher' -ForegroundColor Cyan
    Set-Key 'alignment' $null; Set-Key 'persistent_workspaces' $null; Step 'alignment and persistent_workspaces removed from the toml'
    if (Test-Path $Orig) {
        Stop-Switcher
        foreach ($try in 1..15) { try { Copy-Item $Orig $Exe -Force -ErrorAction Stop; break } catch { Stop-Switcher; Start-Sleep -Milliseconds 500 } }
        Remove-Item $Orig -Force; Remove-Item $State -Force -ErrorAction SilentlyContinue; Step 'original komorebi-switcher.exe restored'
    } else { Step 'no original kept: nothing to restore' }
    & (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1') | Out-Null
    exit 0
}

Write-Host '==> komorebi-switcher with the windots patch' -ForegroundColor Cyan
$newExe = $null; $releaseTag = $null
if (-not $build) {
    $rel = Get-ReleaseInfo
    if (-not $rel) { Write-Host 'no windots release found on GitHub: run with --build to compile it here' -ForegroundColor Yellow; exit 1 }
    if ((Test-Path $Orig) -and (Test-Path $State) -and ((Get-Content $State -Raw).Trim() -eq $rel.Tag)) { Step "release $($rel.Tag) is already installed"; $releaseTag = $rel.Tag }
    else {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) 'komorebi-switcher-windots'
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $newExe = Join-Path $tmp 'komorebi-switcher.exe'
        Step "downloading $($rel.Tag)"
        try {
            Invoke-WebRequest -Uri $rel.Exe -OutFile $newExe -UseBasicParsing -ErrorAction Stop
            # release assets come as octet-stream: Content is bytes on Windows PowerShell 5.1, a string on 7
            $content = (Invoke-WebRequest -Uri $rel.Sha -UseBasicParsing -ErrorAction Stop).Content
            if ($content -is [byte[]]) { $content = [Text.Encoding]::ASCII.GetString($content) }
            $expected = ([string]$content).Trim().Split(' ')[0]
        } catch { Write-Host "download failed: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
        if ((Get-FileHash $newExe -Algorithm SHA256).Hash -ne $expected.Trim().ToUpper()) { Write-Host 'the SHA-256 of the download does not match: not installed' -ForegroundColor Red; exit 1 }
        Step 'SHA-256 checked'
        $releaseTag = $rel.Tag
    }
} else {
    foreach ($tool in 'git', 'cargo') {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $hint = if ($tool -eq 'cargo') { 'install Rust (winget install Rustlang.Rustup) and the Visual Studio Build Tools with the C++ workload' } else { 'run windots install git' }
            Write-Host "$tool is missing: $hint" -ForegroundColor Red; exit 1
        }
    }
    if (-not (Test-Path $Patch)) { Write-Host "patch not found: $Patch" -ForegroundColor Red; exit 1 }
    if (-not (Test-Path (Join-Path $Build '.git'))) {
        New-Item -ItemType Directory -Force (Split-Path $Build -Parent) | Out-Null
        Step "downloading upstream $Tag"
        Invoke-Native 'git clone' { git clone --quiet --depth 1 --branch $Tag $Upstream $Build }
    }
    # a lighter profile than upstream's (lto, one codegen unit): same program, a bigger file, much less to wait for
    $env:CARGO_PROFILE_RELEASE_LTO = 'thin'; $env:CARGO_PROFILE_RELEASE_CODEGEN_UNITS = '16'
    Push-Location $Build
    try {
        Invoke-Native 'git checkout' { git checkout --quiet -- src Cargo.toml }
        Invoke-Native 'git clean' { git clean -fdq -- src }
        Invoke-Native 'git apply' { git apply --ignore-whitespace $Patch }
        Step 'patch applied; cargo build --release (several minutes the first time)'
        Invoke-Native 'cargo build' { cargo build --release 2>&1 | Select-Object -Last 3 | ForEach-Object { "    $_" } ; if ($LASTEXITCODE -eq 0 -and -not (Test-Path 'target\release\komorebi-switcher.exe')) { $global:LASTEXITCODE = 1 } }
    } finally { Pop-Location }
    $newExe = Join-Path $Build 'target\release\komorebi-switcher.exe'
    if (-not (Test-Path $newExe)) { Write-Host 'the build left no exe' -ForegroundColor Red; exit 1 }
}

if ($newExe) {
    if ((Test-Path $Orig) -and ((Get-FileHash $newExe).Hash -eq (Get-FileHash $Exe).Hash)) { Step 'this build is already installed' }
    else {
        if (-not (Install-Exe $newExe)) { exit 1 }
        Step 'patched komorebi-switcher.exe installed'
    }
    New-Item -ItemType Directory -Force (Split-Path $State -Parent) | Out-Null
    if ($releaseTag) { Set-Content -Path $State -Value $releaseTag } else { Remove-Item $State -Force -ErrorAction SilentlyContinue }
}

if ((Get-Key 'persistent_workspaces') -ne "$n") { Set-Key 'persistent_workspaces' $n; Step "persistent_workspaces = $n" }
if ((Get-Key 'alignment') -ne $alignment) { Set-Key 'alignment' "`"$alignment`""; Step "alignment = $alignment" }
& (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1')
exit 0
