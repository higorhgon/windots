# windots-update-winget
# windots:summary=Upgrade every winget package with no questions (one UAC)
#
# Upgrades every winget package with no questions, like pacman -Syu --noconfirm.
# Machine-wide packages (Program Files) need admin, so it re-runs itself through
# sudo: one UAC prompt instead of one per package. Called by windots-update.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$sudoOn = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' -ErrorAction SilentlyContinue).Enabled -ge 1
if (-not $isAdmin -and $sudoOn -and (Get-Command sudo.exe -ErrorAction SilentlyContinue)) {
    $shell = (Get-Process -Id $PID).Path
    sudo.exe $shell -NoProfile -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path
    exit $LASTEXITCODE
}

winget upgrade --all --silent --include-unknown --disable-interactivity `
    --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) {
    Write-Warning ('some packages were not upgraded (exit 0x{0:X8}); see above. An app that ' +
        'was open may have blocked its installer: close it and run windots-update-winget again.' -f $LASTEXITCODE)
}
exit $LASTEXITCODE
