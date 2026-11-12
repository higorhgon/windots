# Recreates the Startup-folder shortcuts (shell:startup).
# Shortcuts hold absolute paths, so they are generated instead of versioned.

$startup = [Environment]::GetFolderPath('Startup')
$shell = New-Object -ComObject WScript.Shell

$entries = @(
    @{ Name = 'komorebi';          Target = "$env:ProgramFiles\komorebi\bin\komorebic-no-console.exe"; Args = 'start --whkd' }
    @{ Name = 'komorebi-switcher'; Target = "$env:LOCALAPPDATA\Programs\komorebi-switcher\komorebi-switcher.exe" }
    @{ Name = 'Flow Launcher';     Target = "$env:LOCALAPPDATA\FlowLauncher\Flow.Launcher.exe" }
    @{ Name = 'sem-menu-iniciar.ahk'; Target = "$HOME\.config\sem-menu-iniciar.ahk" }  # opened by AutoHotkey v2
)

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
