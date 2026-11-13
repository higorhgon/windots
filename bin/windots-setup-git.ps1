# windots-setup-git [--name=<name>] [--email=<email>] [--force]
# windots:summary=Set the name and email git puts on commits, unless they are already set
# windots:args=[--name=<name>] [--email=<email>] [--force]
# windots:examples=windots setup git | windots setup git --name="Ada Lovelace" --email=ada@example.com | windots setup git --force
#
# Git refuses to commit without a name and an email. This asks for them (the way omarchy's
# installer used to) and saves them as the global user.name and user.email. When both are
# already set it only says so and stops.
#   --name=, --email=   give them on the command line, so nothing is asked (a script, a new
#                       machine's first run); either one alone is enough when the other is set
#   --force             ask again even when set: Enter keeps the current value
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$name = $null; $email = $null; $force = $false
foreach ($a in $args) {
    if ($a -like '--name=*') { $name = $a.Substring(7) }
    elseif ($a -like '--email=*') { $email = $a.Substring(8) }
    elseif ($a -eq '--force') { $force = $true }
    else { Write-Host "unknown option: $a (see windots setup git --help)" -ForegroundColor Red; exit 2 }
}
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'git is not installed: run windots install git' -ForegroundColor Yellow
    exit 1
}

function Get-GitValue($key) { $v = git config --global $key 2>$null; if ($v) { ([string]$v).Trim() } else { '' } }
$curName = Get-GitValue 'user.name'
$curEmail = Get-GitValue 'user.email'

if ($curName -and $curEmail -and -not $force -and -not $name -and -not $email) {
    Write-Host "  - git already set up: $curName <$curEmail>"
    return
}

function Read-Value($label, $current, $valid, $why) {
    if ([Console]::IsInputRedirected) {
        Write-Host "Nothing can be asked here (no terminal) and git still needs: $label. Run: windots setup git --name=... --email=..." -ForegroundColor Red
        exit 1
    }
    while ($true) {
        $prompt = if ($current) { "$label [$current]" } else { $label }
        $v = (Read-Host $prompt).Trim()
        if (-not $v) { $v = $current }
        if ($v -and (& $valid $v)) { return $v }
        Write-Host "  $why" -ForegroundColor Yellow
    }
}
$nameOk = { param($v) $v.Length -ge 2 }
$emailOk = { param($v) $v -match '^[^\s@]+@[^\s@]+\.[^\s@]+$' }

# A value on the command line is used as is; the rest is asked (the current one is the default).
if ($name -and -not (& $nameOk $name)) { Write-Host "that is not a name: $name" -ForegroundColor Red; exit 2 }
if ($email -and -not (& $emailOk $email)) { Write-Host "that is not an email: $email" -ForegroundColor Red; exit 2 }
if (-not $name -and ($force -or -not $curName)) {
    if (-not $force -and $curName) { $name = $curName } else {
        $name = Read-Value 'Your name (for git commits)' $curName $nameOk 'Type your name (at least 2 characters).'
    }
}
if (-not $email -and ($force -or -not $curEmail)) {
    $email = Read-Value 'Your email (for git commits)' $curEmail $emailOk 'Type an email like you@example.com.'
}
if (-not $name) { $name = $curName }
if (-not $email) { $email = $curEmail }

git config --global user.name $name
git config --global user.email $email
Write-Host "  - git set up: $name <$email>"
