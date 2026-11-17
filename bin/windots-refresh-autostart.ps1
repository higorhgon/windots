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
    # conhost --headless: with Windows Terminal as the default terminal, -WindowStyle Hidden
    # can't hide the console and a tab stays open.
    @{ Name = 'windots-float-ontop'; Target = "$env:SystemRoot\System32\conhost.exe"
       Requires = $pwsh
       Args = "--headless `"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\windots-float-ontop.ps1`"" }
    # Opens the apps listed in ~\.config\windots\workspaces.json once komorebi is up (nothing when the
    # list is empty). Windows PowerShell: always present.
    @{ Name = 'windots-launch-workspaces'; Target = "$env:SystemRoot\System32\conhost.exe"
       Args = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\windots-launch-workspaces.ps1`" --wait" }
    @{ Name = 'windots-hotkeys'; Target = "$PSScriptRoot\windots-hotkeys.ahk" }  # opened by AutoHotkey v2
    # The menu / launcher (windots install launcher), started hidden so Win+Space opens it at once.
    # Skipped on a machine where it is not installed.
    @{ Name = 'windots-launcher'; Target = "$HOME\.local\share\windots-launcher\windots-launcher.exe"; Args = '--background'; Optional = $true }
)

# Task Manager's (and Settings') on/off switch for each shortcut: a REG_BINARY named after the file, whose
# first byte is odd when it is disabled. It outlives the shortcut, so a komorebi.lnk disabled once stays
# skipped at sign-in however often it is recreated (komorebi, whkd and masir then never start).
$approvedKey = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'

# Shortcuts from older windots versions.
$retired = 'sem-menu-iniciar.ahk', 'komorebi-float-ontop', 'workspaces', 'windots-block-start-menu', 'Flow Launcher', 'windots-center-switcher'
$approved = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($approvedKey, $true)
foreach ($name in $retired) {
    $old = Join-Path $startup "$name.lnk"
    if (Test-Path $old) { Remove-Item $old; Write-Host "  - removed $name" }
    if ($approved) { $approved.DeleteValue("$name.lnk", $false) }
}

foreach ($e in $entries) {
    $missing = @($e.Target, $e.Requires | Where-Object { $_ -and -not (Test-Path $_) })
    if ($missing -and $e.Optional) { continue }   # not installed on this machine: nothing to start
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

    # windots needs every one of these at sign-in: turn back on any that was switched off.
    $state = $null
    if ($approved) { $state = $approved.GetValue("$($e.Name).lnk") }   # not `$state = if ...`: it unrolls the byte[]
    if ($state -is [byte[]] -and $state.Length -and ($state[0] -band 1)) {
        $approved.SetValue("$($e.Name).lnk", [byte[]](@(2) + @(0) * 11), [Microsoft.Win32.RegistryValueKind]::Binary)
        Write-Host "    (was disabled in the startup apps: enabled again)"
    }
}
if ($approved) { $approved.Close() }
