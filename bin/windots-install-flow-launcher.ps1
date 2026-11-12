# windots-install-flow-launcher
#
# Applies windots' Flow Launcher settings (default\flow-launcher\settings.json):
#   - main hotkey and the custom query hotkeys, like omarchy's menus:
#     Alt+Esc system menu (sys), Win+Alt+Space apps (app), Ctrl+Alt+Space plugins (?);
#   - the extra action keywords those hotkeys use (Program: app, System Commands: sys),
#     keeping "*" so everything still shows in the normal search.
# Merged into Flow's Settings.json (the rest is left as is). Not linked by tuckr: Flow saves
# that file by replacing it, which would turn a symlink back into a plain file.
# Flow rewrites Settings.json when it exits, so it is closed first and started again after.
# A backup is kept as Settings.json.bak.<time>.
# Called by windots-install; safe to run again on its own.
# Works on Windows PowerShell 5.1 and PowerShell 7.

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$want = Get-Content -Raw (Join-Path $Repo 'default\flow-launcher\settings.json') | ConvertFrom-Json
$settingsPath = Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json'
$exe = Join-Path $env:LOCALAPPDATA 'FlowLauncher\Flow.Launcher.exe'

if (-not (Test-Path $settingsPath)) {
    Write-Warning 'Flow Launcher Settings.json not found: start Flow Launcher once and run windots-install-flow-launcher again.'
    return
}

$wasRunning = [bool](Get-Process Flow.Launcher -ErrorAction SilentlyContinue)
if ($wasRunning) { Get-Process Flow.Launcher | Stop-Process -Force; Start-Sleep -Seconds 2 }

$settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
$settings | Add-Member -NotePropertyName Hotkey -NotePropertyValue $want.Hotkey -Force
$settings | Add-Member -NotePropertyName CustomPluginHotkeys -NotePropertyValue @($want.CustomPluginHotkeys) -Force

foreach ($p in $want.PluginActionKeywords.PSObject.Properties) {
    $plugin = $settings.PluginSettings.Plugins.($p.Name)
    if ($plugin) { $plugin | Add-Member -NotePropertyName ActionKeywords -NotePropertyValue @($p.Value.keywords) -Force }
    else { Write-Warning "Flow plugin $($p.Value.name) not found; its keywords were not set." }
}

Copy-Item $settingsPath "$settingsPath.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
Write-Host "  - Flow Launcher: $(@($want.CustomPluginHotkeys).Count) query hotkeys and plugin keywords applied"

if ($wasRunning -and (Test-Path $exe)) { Start-Process $exe }
