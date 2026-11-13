# windots-install-git
# windots:summary=Install Git for Windows with winget when it is missing
# windots:examples=windots install git
#
# Git comes first: windots itself, windots-update and the retropet submodule all need it, so it
# has its own command (install.ps1, the one-line installer, does the same step before it can
# clone anything). Nothing happens when Git is already installed. winget asks for the UAC prompt
# the Git installer needs. Then run windots-setup-git to set the name and email for commits.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($args.Count) { Write-Host "unknown option: $($args -join ' ') (see windots install git --help)" -ForegroundColor Red; exit 2 }

$ErrorActionPreference = 'Stop'

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

if (Get-Command git.exe -ErrorAction SilentlyContinue) {
    Write-Host "  - git already installed ($((git --version) -join ' '))"
    return
}

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'winget not found: install "App Installer" from the Microsoft Store (Windows 11 has it), then run again.'
}

Write-Host '  - installing Git for Windows with winget (a UAC prompt may show)'
winget install --id Git.Git --exact --source winget --silent --disable-interactivity `
    --accept-package-agreements --accept-source-agreements
# 0x8A15002B / 0x8A150061: winget says it is installed / nothing newer; that is fine here.
$alreadyThere = -1978335189, -1978335135
if ($LASTEXITCODE -ne 0 -and $alreadyThere -notcontains $LASTEXITCODE) {
    throw ("winget could not install Git (exit 0x{0:X8}); try: winget install --id Git.Git" -f $LASTEXITCODE)
}

# This session's PATH is from before the install.
Refresh-Path
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    $cmd = Join-Path $env:ProgramFiles 'Git\cmd'
    if (Test-Path (Join-Path $cmd 'git.exe')) { $env:Path += ";$cmd" }
}
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    throw 'Git was installed but is not on PATH yet: open a new terminal and run again.'
}
Write-Host "  - git installed ($((git --version) -join ' '))"
