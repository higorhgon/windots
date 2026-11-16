# windots-install-windows-terminal
# windots:summary=Apply the current theme and the windots font to Windows Terminal
#
# Applies the current windots theme (windots-theme-set; catppuccin until another is chosen) to
# Windows Terminal:
#   - the windots-tui profile comes from the windots fragment (Configs\windows-terminal, linked by
#     tuckr; copied here if it isn't yet) and uses the "windots" colour scheme;
#   - settings.json gets what fragments can't carry: the "windots" colour scheme and UI theme (tab
#     row and window), made from the theme's palette and selected as the defaults, and the
#     JetBrainsMonoNL Nerd Font for every profile. A backup is kept as settings.json.bak.<time>.
# Called by windots-install; safe to run again on its own.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/themes.ps1')
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

# The theme: scheme + UI theme from the palette (written by Set-TerminalTheme, with its own backup).
$theme = Get-CurrentThemeName
[void](Set-TerminalTheme (Read-ThemeColors $theme))

# The font for every profile (from windots-install-font).
$settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
$before = $settings | ConvertTo-Json -Depth 32
if (-not $settings.profiles.defaults) { Set-JsonProperty $settings.profiles defaults ([pscustomobject]@{}) }
$font = if ($settings.profiles.defaults.font) { $settings.profiles.defaults.font } else { [pscustomobject]@{} }
Set-JsonProperty $font face $fontFace
Set-JsonProperty $settings.profiles.defaults font $font

$json = $settings | ConvertTo-Json -Depth 32
if ($json -ne $before) {   # back up and write only when the font was not there yet
    Copy-Item $settingsPath "$settingsPath.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
    [IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding $false))
}
Write-Host "  - Windows Terminal: theme '$theme' (scheme 'windots') and font '$fontFace' for all profiles"
