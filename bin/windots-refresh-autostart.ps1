# windots-refresh-autostart
# windots:summary=Recreate the Startup-folder shortcuts
#
# Recreates the Startup-folder shortcuts (shell:startup).
# Shortcuts hold absolute paths, so they are generated instead of versioned.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$startup = [Environment]::GetFolderPath('Startup')
$shell = New-Object -ComObject WScript.Shell

# pwsh 7 comes from the MSI (Program Files) or the Store/winget package (an alias in WindowsApps).
$pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $pwsh) { $pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe" }

$entries = @(
    @{ Name = 'komorebi';          Target = "$env:ProgramFiles\komorebi\bin\komorebic-no-console.exe"; Args = 'start --whkd --masir' }  # masir: focus follows mouse
    @{ Name = 'komorebi-switcher'; Target = "$env:LOCALAPPDATA\Programs\komorebi-switcher\komorebi-switcher.exe" }
    @{ Name = 'Flow Launcher';     Target = "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe" }
    # conhost --headless: with Windows Terminal as the default terminal, -WindowStyle Hidden
    # can't hide the console and a tab stays open.
    @{ Name = 'windots-float-ontop'; Target = "$env:SystemRoot\System32\conhost.exe"
       Requires = $pwsh
       Args = "--headless `"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\windots-float-ontop.ps1`"" }
    @{ Name = 'windots-hotkeys'; Target = "$PSScriptRoot\windots-hotkeys.ahk" }  # opened by AutoHotkey v2
)

# Shortcuts from older windots versions.
$retired = 'sem-menu-iniciar.ahk', 'komorebi-float-ontop', 'workspaces', 'windots-block-start-menu'
foreach ($name in $retired) {
    $old = Join-Path $startup "$name.lnk"
    if (Test-Path $old) { Remove-Item $old; Write-Host "  - removed $name" }
}

foreach ($e in $entries) {
    $missing = @($e.Target, $e.Requires | Where-Object { $_ -and -not (Test-Path $_) })
    if ($missing) {
        Write-Warning "skipping $($e.Name): $($missing -join ', ') not found"
        continue
    }
    $lnk = $shell.CreateShortcut((Join-Path $startup "$($e.Name).lnk"))
    $lnk.TargetPath = $e.Target
    if ($e.Args) { $lnk.Arguments = $e.Args }
    $lnk.WorkingDirectory = Split-Path $e.Target
    $lnk.Save()
    Write-Host "  - $($e.Name)"
}
