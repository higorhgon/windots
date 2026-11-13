# windots-setup-security-sudo [--enable-sudo | --disable-sudo | --status]
# windots:summary=Turn on sudo for Windows (inline mode), the base for every elevated windots command
# windots:args=[--enable-sudo | --disable-sudo | --status]
# windots:examples=windots setup security sudo | windots setup security sudo --status | windots setup security sudo --disable-sudo
#
# Like omarchy's setup-security scripts, but here the point is the opposite of "sudoless":
# Windows has sudo.exe (24H2+) and it is off. Windows commands that need admin (OpenSSH,
# winget machine-wide packages, Developer Mode) re-run themselves through it, so there is one
# UAC prompt per command and the output stays in the same terminal.
#   (no flag), --enable-sudo   turn sudo on in inline mode (same as Settings > System > Advanced >
#                              Enable sudo > Inline); nothing happens when it is already on
#   --disable-sudo             turn it off
#   --status                   show whether it is on, and in which mode
#
# Turning it on or off needs admin and sudo can't be used to turn on sudo, so this is the one
# script that asks for a UAC prompt directly (no prompt when there is nothing to change).
# Called by windots-install.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\elevation.ps1')

$flags = @($args)
$known = '--enable-sudo', '--disable-sudo', '--status', '--elevated'
foreach ($f in $flags) { if ($known -notcontains $f) { Write-Host "unknown option: $f (see windots setup security sudo --help)" -ForegroundColor Red; exit 2 } }
$action = @($flags | Where-Object { $_ -ne '--elevated' })
if ($action.Count -gt 1) { Write-Host 'pass only one of --enable-sudo, --disable-sudo, --status' -ForegroundColor Red; exit 2 }
$mode = if ($action.Count) { $action[0] } else { '--enable-sudo' }
$elevated = $flags -contains '--elevated'

$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo'
$modes = @{ 0 = 'off'; 1 = 'new window'; 2 = 'input disabled'; 3 = 'inline' }
function Get-SudoMode { $v = (Get-ItemProperty $key -ErrorAction SilentlyContinue).Enabled; if ($null -eq $v) { 0 } else { [int]$v } }
function Show-Status {
    $sudoExe = Get-Command sudo.exe -ErrorAction SilentlyContinue
    $m = Get-SudoMode
    if (-not $sudoExe) { Write-Host '  !! sudo.exe not found: needs Windows 11 24H2 or newer' -ForegroundColor Yellow; return }
    $label = $modes[$m]; if (-not $label) { $label = "mode $m" }
    $color = if ($m -ge 1) { 'Green' } else { 'Yellow' }
    Write-Host ("  sudo: {0} ({1})" -f $(if ($m -ge 1) { 'on' } else { 'off' }), $label) -ForegroundColor $color
}

if ($mode -eq '--status') { Show-Status; return }

if (-not (Get-Command sudo.exe -ErrorAction SilentlyContinue)) {
    Write-Warning 'sudo.exe not found (needs Windows 11 24H2 or newer); skipped.'
    exit 1
}

$current = Get-SudoMode
$wanted = if ($mode -eq '--enable-sudo') { 3 } else { 0 }
# Inline (3), not another mode: it is what keeps an elevated command's output in this terminal.
if ($current -eq $wanted) {
    Write-Host ("  - sudo already {0}" -f $(if ($wanted -eq 3) { 'on (inline)' } else { 'off' }))
    return
}

# The change itself, which needs admin.
$apply = if ($wanted -eq 3) {
    "& '$((Get-Command sudo.exe).Source)' config --enable normal"
} else {
    "Set-ItemProperty -Path '$key' -Name Enabled -Value 0 -Type DWord"
}

if (Test-Admin) {
    Invoke-Expression $apply
} else {
    Write-Host ("  - {0} sudo: needs admin (UAC prompt)" -f $(if ($wanted -eq 3) { 'turning on' } else { 'turning off' }))
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($apply))
    try {
        Start-Process powershell.exe -Verb RunAs -Wait -WindowStyle Hidden `
            -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
    } catch { Write-Warning 'Elevation was declined; sudo was not changed.'; exit 1 }
}

if ((Get-SudoMode) -ne $wanted) {
    Write-Warning 'sudo did not change; run it again from an elevated terminal.'
    exit 1
}
if (-not $elevated) { Show-Status }
