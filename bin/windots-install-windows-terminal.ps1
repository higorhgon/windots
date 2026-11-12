# windots-install-windows-terminal
#
# Applies Catppuccin Mocha (catppuccin/windows-terminal) to Windows Terminal:
#   - the color scheme and the windots-tui profile come from the windots fragment
#     (Configs\windows-terminal, linked by tuckr; copied here if it isn't yet);
#   - settings.json gets what fragments can't carry: the "Catppuccin Mocha" UI theme
#     (tab row and window, default\windows-terminal) selected as "theme", and the
#     scheme and the JetBrainsMonoNL Nerd Font as defaults for every profile.
#     A backup is kept as settings.json.bak.<time>.
# Called by windots-install; safe to run again on its own.
# Works on Windows PowerShell 5.1 and PowerShell 7.

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$scheme = 'Catppuccin Mocha'
$fontFace = 'JetBrainsMonoNL Nerd Font'

# Fragment (scheme + windots-tui profile)
$fragRel = 'AppData\Local\Microsoft\Windows Terminal\Fragments\windots\windots.json'
$fragDest = Join-Path $HOME $fragRel
if (-not (Test-Path $fragDest)) {
    New-Item -ItemType Directory -Force (Split-Path $fragDest) | Out-Null
    Copy-Item (Join-Path $Repo "Configs\windows-terminal\$fragRel") $fragDest
    Write-Host '  - copied the windots fragment'
}

# settings.json (Store install first, then the unpackaged one)
$candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)
$settingsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $settingsPath) {
    Write-Warning 'Windows Terminal settings.json not found: open Windows Terminal once and run windots-install-windows-terminal again.'
    return
}

$settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
$uiTheme = Get-Content -Raw (Join-Path $Repo 'default\windows-terminal\catppuccin-mocha-theme.json') | ConvertFrom-Json

# UI theme: replace any theme with the same name, then select it.
$themes = @($settings.themes | Where-Object { $_ -and $_.name -ne $uiTheme.name }) + $uiTheme
$settings | Add-Member -NotePropertyName themes -NotePropertyValue $themes -Force
$settings | Add-Member -NotePropertyName theme -NotePropertyValue $uiTheme.name -Force

# Scheme and font for every profile (font from windots-install-font).
if (-not $settings.profiles.defaults) { $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force }
$settings.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $scheme -Force
$font = if ($settings.profiles.defaults.font) { $settings.profiles.defaults.font } else { [pscustomobject]@{} }
$font | Add-Member -NotePropertyName face -NotePropertyValue $fontFace -Force
$settings.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue $font -Force

Copy-Item $settingsPath "$settingsPath.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
$json = $settings | ConvertTo-Json -Depth 32
[IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding $false))
Write-Host "  - Windows Terminal: theme '$($uiTheme.name)', color scheme '$scheme' and font '$fontFace' for all profiles"
