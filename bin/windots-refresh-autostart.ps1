# windots-refresh-autostart
#
# Recreates the Startup-folder shortcuts (shell:startup).
# Shortcuts hold absolute paths, so they are generated instead of versioned.

$startup = [Environment]::GetFolderPath('Startup')
$shell = New-Object -ComObject WScript.Shell

$entries = @(
    @{ Name = 'komorebi';          Target = "$env:ProgramFiles\komorebi\bin\komorebic-no-console.exe"; Args = 'start --whkd --masir' }  # masir: focus follows mouse
    @{ Name = 'komorebi-switcher'; Target = "$env:LOCALAPPDATA\Programs\komorebi-switcher\komorebi-switcher.exe" }
    @{ Name = 'Flow Launcher';     Target = "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe" }
    @{ Name = 'windots-float-ontop'; Target = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
       Args = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\windots-float-ontop.ps1`"" }
    @{ Name = 'windots-block-start-menu'; Target = "$PSScriptRoot\windots-block-start-menu.ahk" }  # opened by AutoHotkey v2
)

# Shortcuts from older windots versions.
$retired = 'sem-menu-iniciar.ahk', 'komorebi-float-ontop', 'workspaces'
foreach ($name in $retired) {
    $old = Join-Path $startup "$name.lnk"
    if (Test-Path $old) { Remove-Item $old; Write-Host "  - removed $name" }
}

foreach ($e in $entries) {
    if (-not (Test-Path $e.Target)) {
        Write-Warning "skipping $($e.Name): $($e.Target) not found"
        continue
    }
    $lnk = $shell.CreateShortcut((Join-Path $startup "$($e.Name).lnk"))
    $lnk.TargetPath = $e.Target
    if ($e.Args) { $lnk.Arguments = $e.Args }
    $lnk.WorkingDirectory = Split-Path $e.Target
    $lnk.Save()
    Write-Host "  - $($e.Name)"
}
