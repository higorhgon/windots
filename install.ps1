# windots: one line installs it on a new Windows machine (Windows PowerShell is enough, no Git needed):
#
#   irm https://raw.githubusercontent.com/higorhgon/windots/main/install.ps1 | iex
#
# Like omarchy's `curl -fsSL https://omarchy.org/install | bash`. In order:
#   1. Git, when missing (winget; the Git installer asks for a UAC prompt)
#   2. windots cloned with its submodules into ~\windots (updated instead when it is there)
#   3. the name and email git puts on commits, asked unless git already has them
#   4. windots-install: packages, links, settings (it asks for UAC prompts of its own)
#   5. the migrations marked as done: a new machine already has what they would change
# Then restart, or sign out and in, so the startup apps come up.
#
# Settings, as environment variables set before the line above (this runs through iex, so no flags):
#   WINDOTS_PATH         where to clone (default ~\windots; keep it short: some files in the repo
#                        have long paths, and Windows stops at 260 characters)
#   WINDOTS_REPO         another repository URL (a fork)
#   WINDOTS_REF          a branch or tag (default main)
#   WINDOTS_GIT_NAME, WINDOTS_GIT_EMAIL   the git name and email, so nothing is asked
#   WINDOTS_NO_INSTALL   1 stops after step 3: only Git, the clone and the git setup
# Works on Windows PowerShell 5.1 and PowerShell 7. No exit and no param block: under iex, exit
# would close the person's window, and a param block would not see the variables above.

# Its own scope: under `irm | iex` it would otherwise set the caller's variables.
& {
$ErrorActionPreference = 'Stop'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
# A new machine's Windows PowerShell does not run script files (execution policy): -ExecutionPolicy Bypass.
function Invoke-Windots($file, $fileArgs) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file @fileArgs
    if ($LASTEXITCODE -ne 0) { throw "$(Split-Path $file -Leaf) failed (exit $LASTEXITCODE); see above." }
}

$repoUrl = if ($env:WINDOTS_REPO) { $env:WINDOTS_REPO } else { 'https://github.com/higorhgon/windots.git' }
$ref = if ($env:WINDOTS_REF) { $env:WINDOTS_REF } else { 'main' }
$dest = if ($env:WINDOTS_PATH) { $env:WINDOTS_PATH } else { Join-Path $HOME 'windots' }

# ---------------------------------------------------------------- git
Step 'Git'
if (Get-Command git.exe -ErrorAction SilentlyContinue) {
    Write-Host "  - already installed ($((git --version) -join ' '))"
} else {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'winget not found: install "App Installer" from the Microsoft Store (Windows 11 has it), then run this again.'
    }
    Write-Host '  - installing Git for Windows with winget (a UAC prompt may show)'
    winget install --id Git.Git --exact --source winget --silent --disable-interactivity `
        --accept-package-agreements --accept-source-agreements
    $alreadyThere = -1978335189, -1978335135   # 0x8A15002B / 0x8A150061: installed / nothing newer
    if ($LASTEXITCODE -ne 0 -and $alreadyThere -notcontains $LASTEXITCODE) {
        throw ("winget could not install Git (exit 0x{0:X8}); try: winget install --id Git.Git" -f $LASTEXITCODE)
    }
    Refresh-Path
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        $cmd = Join-Path $env:ProgramFiles 'Git\cmd'
        if (Test-Path (Join-Path $cmd 'git.exe')) { $env:Path += ";$cmd" }
    }
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw 'Git was installed but is not on PATH yet: open a new terminal and run this again.'
    }
    Write-Host "  - installed ($((git --version) -join ' '))"
}

# ---------------------------------------------------------------- the repository
Step "windots in $dest"
if (Test-Path (Join-Path $dest '.git')) {
    Write-Host '  - already there: updating it'
    git -C $dest pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull failed in $dest (local changes?); fix it and run this again." }
    git -C $dest submodule update --init
    if ($LASTEXITCODE -ne 0) { throw 'git submodule update failed; see above.' }
} elseif ((Test-Path $dest) -and @(Get-ChildItem $dest -Force).Count) {
    throw "$dest exists, is not empty and is not a windots clone: move it away, or set WINDOTS_PATH to another folder."
} else {
    git clone --recurse-submodules --branch $ref $repoUrl $dest
    if ($LASTEXITCODE -ne 0) { throw "git clone failed ($repoUrl, $ref); see above." }
}
$bin = Join-Path $dest 'bin'
if (-not (Test-Path (Join-Path $bin 'windots-install.ps1'))) { throw "$dest does not look like windots (no bin\windots-install.ps1)." }

# ---------------------------------------------------------------- git identity
Step 'Git name and email'
$gitArgs = @()
if ($env:WINDOTS_GIT_NAME) { $gitArgs += "--name=$($env:WINDOTS_GIT_NAME)" }
if ($env:WINDOTS_GIT_EMAIL) { $gitArgs += "--email=$($env:WINDOTS_GIT_EMAIL)" }
Invoke-Windots (Join-Path $bin 'windots-setup-git.ps1') $gitArgs

if ($env:WINDOTS_NO_INSTALL -eq '1') {
    Write-Host "`nStopped before windots-install (WINDOTS_NO_INSTALL=1). To finish: powershell -ExecutionPolicy Bypass -File $bin\windots-install.ps1" -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------- windots
Step 'windots-install'
Invoke-Windots (Join-Path $bin 'windots-install.ps1') @()

Step 'Migrations: a new machine has what they change'
Invoke-Windots (Join-Path $bin 'windots-migrate.ps1') @('--mark-all')

Write-Host "`nwindots is installed. Restart (or sign out and in) so komorebi and the other startup apps come up." -ForegroundColor Green
Write-Host 'Then try: windots commands' -ForegroundColor Green
}
