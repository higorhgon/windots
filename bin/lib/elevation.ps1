# Helpers to run a windots script elevated (dot-sourced, not a command; bin\lib is not on PATH).
# Works on Windows PowerShell 5.1 and PowerShell 7.
#
# Windows has no sudo until it is turned on (windots-setup-security-sudo), so Invoke-Elevated
# turns it on first when needed. The elevated copy always runs in Windows PowerShell 5.1 (always
# there, and the Dism and NetSecurity cmdlets run natively in it).

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# sudo.exe is there (Windows 11 24H2+) and turned on in Settings > System > Advanced.
function Test-SudoEnabled {
    $on = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' -ErrorAction SilentlyContinue).Enabled -ge 1
    [bool]($on -and (Get-Command sudo.exe -ErrorAction SilentlyContinue))
}

# The account is in the Administrators group (the token may still be unelevated: deny-only).
function Test-AdminAccount {
    [bool](whoami /groups 2>$null | Select-String 'S-1-5-32-544')
}

# Runs `$ScriptPath @ScriptArgs` elevated through sudo, in this console, and returns its exit code.
function Invoke-Elevated($ScriptPath, $ScriptArgs = @()) {
    if (-not (Test-SudoEnabled)) {
        Write-Host '  - sudo is off: turning it on first (one UAC prompt)'
        & (Join-Path (Split-Path $PSScriptRoot) 'windots-setup-security-sudo.ps1')
        if (-not (Test-SudoEnabled)) { throw 'sudo is not on: run windots setup security sudo, or use an elevated terminal.' }
    }
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    # Out-Host: the child's output goes to the console, not into this function's return value.
    sudo.exe $ps51 -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs | Out-Host
    [int]$LASTEXITCODE
}
