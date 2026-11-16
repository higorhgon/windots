# Helpers for windots themes (dot-sourced, not a command; bin\lib is not on PATH).
# Works on Windows PowerShell 5.1 and PowerShell 7.
#
# A theme is default\themes\<name>\colors.toml, the same files omarchy ships (omacom/omarchy,
# themes/<name>/colors.toml): one palette per theme, and every app gets its colours from it, the
# way omarchy's templates do. The name of the current theme is kept in
# ~\.local\state\windots\theme.name (state of this machine, never versioned).

$script:ThemeRepo = Split-Path (Split-Path $PSScriptRoot)
$script:ThemesDir = Join-Path $script:ThemeRepo 'default\themes'
$script:ThemeStateFile = Join-Path $HOME '.local\state\windots\theme.name'
$script:DefaultTheme = 'catppuccin'

function Get-ThemeNames { @(Get-ChildItem $script:ThemesDir -Directory | Sort-Object Name | ForEach-Object { $_.Name }) }

# "Tokyo Night", "tokyo_night" and "tokyo-night" are the same theme (omarchy accepts the first).
function Resolve-ThemeName($Text) {
    $n = ([string]$Text).Trim().ToLower() -replace '[\s_]+', '-'
    @(Get-ThemeNames) | Where-Object { $_ -eq $n } | Select-Object -First 1
}

function Get-ThemeTitle($Name) {
    (($Name -split '-') | ForEach-Object { if ($_.Length) { $_.Substring(0, 1).ToUpper() + $_.Substring(1) } }) -join ' '
}

function Get-CurrentThemeName {
    if (Test-Path $script:ThemeStateFile) {
        $n = Resolve-ThemeName ((Get-Content $script:ThemeStateFile -Raw).Trim())
        if ($n) { return $n }
    }
    $script:DefaultTheme
}

function Set-CurrentThemeName($Name) {
    New-Item -ItemType Directory -Force (Split-Path $script:ThemeStateFile) | Out-Null
    [IO.File]::WriteAllText($script:ThemeStateFile, $Name, (New-Object Text.UTF8Encoding $false))
}

# colors.toml -> hashtable of key = '#rrggbb' (mode stays 'dark' / 'light'). Keys a theme leaves out
# get the value omarchy's own templates would fall back to.
function Read-ThemeColors($Name) {
    $path = Join-Path $script:ThemesDir "$Name\colors.toml"
    if (-not (Test-Path $path)) { throw "theme '$Name' has no colors.toml" }
    $c = @{}
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]*)"') { $c[$Matches[1]] = $Matches[2] }
    }
    foreach ($k in 'background', 'foreground', 'accent', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan') {
        if (-not $c[$k]) { throw "theme '$Name': colors.toml has no '$k'" }
    }
    if (-not $c.mode) { $c.mode = 'dark' }
    $fallback = [ordered]@{
        muted = 'foreground'; selection = 'muted'; bright_foreground = 'foreground'
        dark_background = 'background'; darker_background = 'dark_background'; lighter_background = 'background'
        orange = 'yellow'; brown = 'orange'
        bright_red = 'red'; bright_green = 'green'; bright_yellow = 'yellow'
        bright_blue = 'blue'; bright_magenta = 'magenta'; bright_cyan = 'cyan'
    }
    foreach ($k in $fallback.Keys) { if (-not $c[$k]) { $c[$k] = $c[$fallback[$k]] } }
    $c
}

function ConvertTo-Upper($Hex) { ([string]$Hex).ToUpper() }

# --- Windows Terminal ---------------------------------------------------------------------
# The scheme the way omarchy's alacritty template maps the palette (normal black is the
# background, bright black the muted colour), and a UI theme for the tab row and window.
function ConvertTo-TerminalScheme($c) {
    [ordered]@{
        name = 'windots'
        cursorColor = ConvertTo-Upper $c.bright_foreground
        selectionBackground = ConvertTo-Upper $c.selection
        background = ConvertTo-Upper $c.background
        foreground = ConvertTo-Upper $c.foreground
        black = ConvertTo-Upper $c.background
        red = ConvertTo-Upper $c.red; green = ConvertTo-Upper $c.green; yellow = ConvertTo-Upper $c.yellow
        blue = ConvertTo-Upper $c.blue; purple = ConvertTo-Upper $c.magenta; cyan = ConvertTo-Upper $c.cyan
        white = ConvertTo-Upper $c.foreground
        brightBlack = ConvertTo-Upper $c.muted
        brightRed = ConvertTo-Upper $c.bright_red; brightGreen = ConvertTo-Upper $c.bright_green
        brightYellow = ConvertTo-Upper $c.bright_yellow; brightBlue = ConvertTo-Upper $c.bright_blue
        brightPurple = ConvertTo-Upper $c.bright_magenta; brightCyan = ConvertTo-Upper $c.bright_cyan
        brightWhite = ConvertTo-Upper $c.bright_foreground
    }
}

function ConvertTo-TerminalUiTheme($c) {
    [ordered]@{
        name = 'windots'
        tab = [ordered]@{ background = (ConvertTo-Upper $c.background) + 'FF'; showCloseButton = 'always'; unfocusedBackground = $null }
        tabRow = [ordered]@{ background = (ConvertTo-Upper $c.dark_background) + 'FF'; unfocusedBackground = (ConvertTo-Upper $c.darker_background) + 'FF' }
        window = [ordered]@{ applicationTheme = $c.mode }
    }
}

# Sets a property of a parsed JSON object without moving it: Add-Member -Force removes and re-adds the
# property at the end, so the file would change order on every run.
function Set-JsonProperty($Object, $Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Get-TerminalSettingsPath {
    @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# Puts the "windots" scheme and UI theme in settings.json (a file Windows Terminal replaces when it
# saves, so it is merged, never linked), and makes them the default. Returns 'none' when there is no
# settings.json yet, 'same' when nothing needed changing, 'changed' otherwise. Backs the file up only
# when something changes.
function Set-TerminalTheme($c) {
    $path = Get-TerminalSettingsPath
    if (-not $path) { return 'none' }
    $settings = Get-Content -Raw $path | ConvertFrom-Json
    $before = $settings | ConvertTo-Json -Depth 32
    $scheme = ConvertTo-TerminalScheme $c
    $ui = ConvertTo-TerminalUiTheme $c
    $schemes = @($settings.schemes | Where-Object { $_ -and $_.name -ne 'windots' }) + ([pscustomobject]$scheme)
    $themes = @($settings.themes | Where-Object { $_ -and $_.name -ne 'windots' }) + ([pscustomobject]$ui)
    Set-JsonProperty $settings schemes $schemes
    Set-JsonProperty $settings themes $themes
    Set-JsonProperty $settings theme 'windots'
    if (-not $settings.profiles.defaults) { Set-JsonProperty $settings.profiles defaults ([pscustomobject]@{}) }
    Set-JsonProperty $settings.profiles.defaults colorScheme 'windots'
    $json = $settings | ConvertTo-Json -Depth 32
    if ($json -eq $before) { return 'same' }   # same serializer on both sides: nothing changed
    Copy-Item $path "$path.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding $false))
    'changed'
}

# --- komorebi-switcher --------------------------------------------------------------------
# The switcher keeps the colour of its indicators in a [colors] section of
# ~\.config\komorebi-switcher.toml (its text and background follow Windows' light / dark mode and the
# taskbar). This file is per machine (monitors differ), so it is a real file, seeded from
# default\komorebi\komorebi-switcher.toml, and only the [colors] section is ever rewritten here.
$script:SwitcherToml = Join-Path $HOME '.config\komorebi-switcher.toml'

function Initialize-SwitcherConfig {
    $item = Get-Item -LiteralPath $script:SwitcherToml -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {   # an older install linked it into the repo: keep the content, make it a real file
        $txt = $null
        try { $txt = [IO.File]::ReadAllText($script:SwitcherToml) } catch { }   # a link whose target left the repo
        $item.Delete()
        if ($null -ne $txt) { [IO.File]::WriteAllText($script:SwitcherToml, $txt, (New-Object Text.UTF8Encoding $false)) }
        else { $item = $null }
    }
    if (-not $item) {
        New-Item -ItemType Directory -Force (Split-Path $script:SwitcherToml) | Out-Null
        Copy-Item (Join-Path $script:ThemeRepo 'default\komorebi\komorebi-switcher.toml') $script:SwitcherToml
    }
}

function ConvertTo-SwitcherColors($c) {
    # active workspace = the accent; workspaces with windows = the muted colour, a little transparent
    "[colors]`nactive_indicator = `"$($c.accent.ToLower())`"`nbusy_indicator = `"$($c.muted.ToLower())99`"`n"
}

# Rewrites the [colors] section (before the first [monitors...] table, where the global keys end).
# Returns $true when the file changed.
function Set-SwitcherColors($c) {
    Initialize-SwitcherConfig
    $old = [IO.File]::ReadAllText($script:SwitcherToml)
    $nl = if ($old -match "`r`n") { "`r`n" } else { "`n" }
    $lines = @($old -split "`r?`n")
    $keep = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*\[colors\]\s*$') { $skip = $true; continue }
        if ($skip -and $l -match '^\s*\[') { $skip = $false }
        if (-not $skip) { $keep.Add($l) }
    }
    $block = @((ConvertTo-SwitcherColors $c).TrimEnd() -split "`n") + ''
    $at = -1
    for ($i = 0; $i -lt $keep.Count; $i++) { if ($keep[$i] -match '^\s*\[monitors') { $at = $i; break } }
    if ($at -lt 0) { $keep.AddRange([string[]](@('') + $block)) }
    else {
        while ($at -gt 0 -and $keep[$at - 1].Trim() -eq '') { $keep.RemoveAt($at - 1); $at-- }   # no blank run before it
        $keep.InsertRange($at, [string[]](@('') + $block))
    }
    $new = (($keep -join $nl).TrimEnd()) + $nl
    if ($new -eq $old) { return $false }
    [IO.File]::WriteAllText($script:SwitcherToml, $new, (New-Object Text.UTF8Encoding $false))
    $true
}

# --- Windows light / dark mode ------------------------------------------------------------
# The taskbar text, tray icons and the switcher's numbers are white or dark by this setting, so a
# light theme turns both flags on. Returns $true when a flag changed (Explorer must restart to show it).
function Set-WindowsColorMode($Mode) {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $want = if ($Mode -eq 'light') { 1 } else { 0 }
    $changed = $false
    foreach ($n in 'SystemUsesLightTheme', 'AppsUseLightTheme') {
        if ((Get-ItemProperty $key -ErrorAction SilentlyContinue).$n -ne $want) {
            Set-ItemProperty $key $n $want -Type DWord
            $changed = $true
        }
    }
    $changed
}
