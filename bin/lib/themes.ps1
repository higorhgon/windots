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
        dark_foreground = 'muted'; light_foreground = 'foreground'
        selection_background = 'selection'; selection_foreground = 'bright_foreground'
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

# --- komorebi borders ---------------------------------------------------------------------
# omarchy's Hyprland borders: active = the theme's `hyprland_active_border` or its accent, inactive = `hyprland_inactive_border`
# or #595959 (default\themed\hyprland.lua.tpl). Hyprland takes a gradient ("rgba(..) rgba(..) 45deg"); komorebi one colour,
# so the first one of it. `komorebic border-colour` changes it in the running komorebi: nothing restarts. komorebi.json has
# the same colours for the next start, and windots-float-ontop applies the theme's again whenever komorebi comes up.
function ConvertFrom-HyprColor($Value) {
    $m = [regex]::Match([string]$Value, 'rgba?\(([0-9a-fA-F]{6})')
    if ($m.Success) { return '#' + $m.Groups[1].Value }
    $null
}

function Set-KomorebiBorders($c) {
    $k = (Get-Command komorebic.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $k) { return 'komorebi borders: komorebi is not installed, skipped' }
    $active = ConvertFrom-HyprColor $c.hyprland_active_border; if (-not $active) { $active = $c.accent }
    $inactive = ConvertFrom-HyprColor $c.hyprland_inactive_border; if (-not $inactive) { $inactive = '#595959' }
    $kinds = [ordered]@{ single = $active; stack = $active; floating = $active; monocle = $c.orange; unfocused = $inactive }
    foreach ($kind in $kinds.Keys) {
        $hex = ([string]$kinds[$kind]).TrimStart('#')
        $rgb = foreach ($i in 0, 2, 4) { [Convert]::ToInt32($hex.Substring($i, 2), 16) }
        # komorebi answers late when it is busy (right after Files was restarted, say): try a few times before saying it is down
        $ok = $false
        foreach ($try in 1..8) {
            & $k border-colour --window-kind $kind $rgb[0] $rgb[1] $rgb[2] 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $ok = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ok) { return 'komorebi borders: komorebi is not running (or not answering), they are applied when it starts' }
    }
    "komorebi borders: active $active, monocle $($c.orange), inactive $inactive"
}

# --- komorebi-switcher --------------------------------------------------------------------
# The switcher keeps the colour of its indicators in a [colors] section of
# ~\.config\komorebi-switcher.toml (its text and background follow Windows' light / dark mode and the
# taskbar). This file is per machine (monitors differ), so it is a real file, seeded from
# default\komorebi\komorebi-switcher.toml, and only the [colors] section is ever rewritten here.
$script:SwitcherToml = Join-Path $HOME '.config\komorebi-switcher.toml'

# windots' komorebi-switcher from release -windots.2 on (or built here) reads its toml again when the file changes: a colour
# change then needs no restart. The marker is written by windots-install-komorebi-switcher.
function Test-SwitcherLiveReload {
    $marker = Join-Path $HOME '.local\state\windots\komorebi-switcher.release'
    if (-not (Test-Path $marker)) { return $false }
    $tag = (Get-Content $marker -Raw).Trim()
    if ($tag -eq 'built-here') { return $true }
    $m = [regex]::Match($tag, 'windots\.(\d+)$')
    $m.Success -and [int]$m.Groups[1].Value -ge 2
}

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

# --- Neovim (LazyVim, windots-install-lazyvim) --------------------------------------------
# Like omarchy: lua\plugins\theme.lua in the Neovim config is the colorscheme spec of the current theme. The theme's own
# neovim.lua when omarchy ships one (14 of the 23 themes), else the aether template (default\lazyvim\neovim.lua.tpl)
# filled with the palette. lazy.nvim notices the file change and omarchy's omarchy-theme-hotreload plugin applies it in
# every Neovim that is open.
$script:NeovimAppsFile = Join-Path $HOME '.local\state\windots\nvim-apps'

# NVIM_APPNAMEs that windots-install-lazyvim set up (the folders windots-theme-set writes theme.lua into).
function Get-NeovimApps {
    $apps = @()
    if (Test-Path $script:NeovimAppsFile) { $apps = @(Get-Content $script:NeovimAppsFile | Where-Object { $_ -and $_.Trim() }) }
    @($apps | Select-Object -Unique)
}

function Register-NeovimApp($App) {
    if ((Get-NeovimApps) -contains $App) { return }
    New-Item -ItemType Directory -Force (Split-Path $script:NeovimAppsFile) | Out-Null
    Add-Content -Path $script:NeovimAppsFile -Value $App
}

function Get-NeovimThemeSpec($Name, $c) {
    $own = Join-Path $script:ThemesDir "$Name\neovim.lua"
    if (Test-Path $own) { return [IO.File]::ReadAllText($own) }
    $tpl = [IO.File]::ReadAllText((Join-Path $script:ThemeRepo 'default\lazyvim\neovim.lua.tpl'))
    [regex]::Replace($tpl, '\{\{\s*(\w+)\s*\}\}', { param($m) $v = $c[$m.Groups[1].Value]; if ($v) { $v } else { $m.Value } })
}

# Writes theme.lua into one Neovim config folder. Returns 'changed', 'same' or 'none' (no windots LazyVim there).
function Set-NeovimThemeFile($Dir, $Name, $c) {
    if (-not (Test-Path (Join-Path $Dir 'lua\plugins\omarchy-theme-hotreload.lua'))) { return 'none' }
    $spec = Get-NeovimThemeSpec $Name $c
    $target = Join-Path $Dir 'lua\plugins\theme.lua'
    if ((Test-Path $target) -and ([IO.File]::ReadAllText($target) -ceq $spec)) { return 'same' }
    $tmp = "$target.tmp"
    [IO.File]::WriteAllText($tmp, $spec, (New-Object Text.UTF8Encoding $false))
    Move-Item $tmp $target -Force   # one replace, which is what lazy.nvim's change detection sees
    'changed'
}

# Every registered Neovim config (and the default one). 'changed' if any changed, 'same', or 'none'.
function Set-NeovimTheme($Name, $c) {
    $result = 'none'
    foreach ($app in (@('nvim') + (Get-NeovimApps) | Select-Object -Unique)) {
        $r = Set-NeovimThemeFile (Join-Path $env:LOCALAPPDATA $app) $Name $c
        if ($r -eq 'changed') { $result = 'changed' } elseif ($r -eq 'same' -and $result -eq 'none') { $result = 'same' }
    }
    $result
}

# ---- wallpaper ----------------------------------------------------------------------------------
# The theme's background: its first image (default\themes\<name>\backgrounds, then
# ~\.config\windots\backgrounds\<name>), like omarchy. An image of this theme chosen earlier (the
# launcher's Style > Background) is kept, so re-applying the theme does not undo the person's choice.
# The state file ~\.local\state\windots\background holds the chosen source, as the launcher writes it.
# Windows takes jpg/png/bmp; a WebP or GIF is written once as a JPEG as wide as the screen (WPF decodes it).
function Get-ThemeBackgrounds($Name) {
    $seen = @{}; $out = @()
    foreach ($dir in @((Join-Path $script:ThemesDir "$Name\backgrounds"), (Join-Path $HOME ".config\windots\backgrounds\$Name"))) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($f in (Get-ChildItem $dir -File | Where-Object { '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp' -contains $_.Extension.ToLower() } | Sort-Object Name)) {
            if (-not $seen.ContainsKey($f.Name.ToLower())) { $seen[$f.Name.ToLower()] = 1; $out += $f.FullName }
        }
    }
    $out
}

function Set-ThemeWallpaper($Name) {
    $images = @(Get-ThemeBackgrounds $Name)
    if (-not $images.Count) { return 'none' }
    $state = Join-Path $HOME '.local\state\windots\background'
    $current = if (Test-Path $state) { (Get-Content $state -Raw).Trim() } else { '' }
    $source = if ($current -and ($images -contains $current)) { $current } else { $images[0] }

    $file = $source
    if ('.webp', '.gif' -contains [IO.Path]::GetExtension($source).ToLower()) {
        Add-Type -AssemblyName System.Windows.Forms, PresentationCore
        $width = [Math]::Min(3840, [Math]::Max(1920, [Windows.Forms.Screen]::PrimaryScreen.Bounds.Width))
        $info = Get-Item $source
        $md5 = [Security.Cryptography.MD5]::Create()
        $key = [BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes("$source|$($info.Length)|$($info.LastWriteTimeUtc.Ticks)|$width"))).Replace('-', '').ToLower()
        $dir = Join-Path $HOME '.local\state\windots\wallpaper'
        $file = Join-Path $dir "$key.jpg"
        if (-not (Test-Path $file)) {
            New-Item -ItemType Directory -Force $dir | Out-Null
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit(); $bmp.UriSource = New-Object Uri $source; $bmp.DecodePixelWidth = $width; $bmp.CacheOption = 'OnLoad'; $bmp.EndInit(); $bmp.Freeze()
            $enc = New-Object Windows.Media.Imaging.JpegBitmapEncoder; $enc.QualityLevel = 92
            $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
            $fs = [IO.File]::Create($file); try { $enc.Save($fs) } finally { $fs.Dispose() }
            Get-ChildItem $dir -Filter '*.jpg' | Where-Object { $_.FullName -ne $file } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not ('WindotsWallpaper' -as [type])) {
        Add-Type -Namespace '' -Name WindotsWallpaper -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)] public static extern bool SystemParametersInfo(uint a, uint p, string v, uint w);'
    }
    $key = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty $key WallpaperStyle '10'; Set-ItemProperty $key TileWallpaper '0'   # fill
    [void][WindotsWallpaper]::SystemParametersInfo(0x14, 0, $file, 3)   # SPI_SETDESKWALLPAPER, update the profile and tell everyone
    New-Item -ItemType Directory -Force (Split-Path $state) | Out-Null
    Set-Content $state $source -NoNewline
    if ($source -eq $current) { 'same' } else { 'changed' }
}


# ---- Files (files.community) ----------------------------------------------------------------
# Files keeps its colours in LocalState\settings\user_settings.json (AppTheme*BackgroundColor, AppThemeMode), the keys
# catppuccin's own installer writes: base on the address bar, toolbar and file area, mantle on the sidebar and the
# window. It reads them when it starts (an edit in the file is not noticed by a running Files: measured, 40 s), so a
# running Files is restarted, or a notification asks the person to (click = restart).
$script:FilesFamily = 'Files_1y0xx7n9077q4'   # the stable package, the one winget installs
$script:FilesPackages = @($script:FilesFamily, 'FilesDev_ykqwq8d6ps0ag', 'Files_wvne1zexy08sa', 'FilesPreview_1y0xx7n9077q4',
    '49306atecsolution.FilesUWP_et10x9a9vyk8t', '49306atecsolution.FilesPreview_et10x9a9vyk8t')

function Get-FilesSettingsPaths {
    $out = @()
    foreach ($p in $script:FilesPackages) {
        $f = Join-Path $env:LOCALAPPDATA "Packages\$p\LocalState\settings\user_settings.json"
        if (Test-Path $f) { $out += $f }
    }
    $out
}

function Get-FilesPackage {
    Get-AppxPackage -Name Files -ErrorAction SilentlyContinue | Where-Object { $_.PackageFamilyName -eq $script:FilesFamily } | Select-Object -First 1
}

function Test-FilesRunning { [bool](Get-Process -Name Files -ErrorAction SilentlyContinue) }

# mantle = the background darkened toward black: catppuccin's own mantle is base x 0.8 (mocha) and x 0.96 (latte)
function ConvertTo-FilesColors($c) {
    $dark = $c.mode -ne 'light'
    $f = if ($dark) { 0.8 } else { 0.96 }
    $hex = ([string]$c.background).TrimStart('#')
    $rgb = foreach ($i in 0, 2, 4) { [int][Math]::Round([Convert]::ToInt32($hex.Substring($i, 2), 16) * $f) }
    $mantle = '#{0:x2}{1:x2}{2:x2}' -f $rgb[0], $rgb[1], $rgb[2]
    $base = ([string]$c.background).ToLower()
    [ordered]@{
        AppThemeMode                     = $(if ($dark) { 'Dark' } else { 'Light' })
        AppThemeBackgroundColor          = $mantle
        AppThemeAddressBarBackgroundColor = $base
        AppThemeToolbarBackgroundColor   = $base
        AppThemeFileAreaBackgroundColor  = $base
        AppThemeSidebarBackgroundColor   = $mantle
    }
}

# Writes the colours into user_settings.json, as text, so the rest of the file stays as Files wrote it.
# 'changed', 'same' or 'none' (Files has no settings file: not installed, or never started).
function Set-FilesTheme($c) {
    $paths = @(Get-FilesSettingsPaths)
    if (-not $paths.Count) { return 'none' }
    $want = ConvertTo-FilesColors $c
    $result = 'same'
    foreach ($path in $paths) {
        $text = [IO.File]::ReadAllText($path)
        $new = $text
        foreach ($k in $want.Keys) {
            $pattern = '("' + $k + '"\s*:\s*)"[^"]*"'
            if ($new -match $pattern) { $new = [regex]::Replace($new, $pattern, ('${1}"' + $want[$k] + '"')) }
            else { $new = [regex]::Replace($new, '^\s*\{', ('{' + "`n" + '  "' + $k + '": "' + $want[$k] + '",'), 1) }
        }
        if ($new -ne $text) {
            $backup = "$path.windots-original"
            if (-not (Test-Path $backup)) { Copy-Item $path $backup }   # once: how the file was before windots
            [IO.File]::WriteAllText($path, $new, (New-Object Text.UTF8Encoding $false))
            $result = 'changed'
        }
    }
    $result
}

# windots:<action> links, for what a notification does when it is clicked. Only the actions listed in
# windots-uri.ps1 run, so a link on a web page cannot start anything else.
function Register-WindotsProtocol {
    $handler = Join-Path $script:ThemeRepo 'bin\windots-uri.ps1'
    $cmd = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $handler + '" "%1"'
    $key = 'HKCU:\Software\Classes\windots'
    if ((Test-Path "$key\shell\open\command") -and ((Get-ItemProperty "$key\shell\open\command").'(default)' -eq $cmd)) { return }
    New-Item "$key\shell\open\command" -Force | Out-Null
    Set-ItemProperty $key '(default)' 'URL:windots'
    Set-ItemProperty $key 'URL Protocol' ''
    Set-ItemProperty "$key\shell\open\command" '(default)' $cmd
}

# After a theme change: Files running -> restart it, or (--no-restart) ask with a notification. Returns the line to print.
function Update-FilesTheme($Name, $c, $NoRestart) {
    switch (Set-FilesTheme $c) {
        'none' { return 'Files: not installed (windots install files), skipped' }
        'same' { return 'Files: already right' }
    }
    if (-not (Test-FilesRunning)) { return 'Files: colours changed; they show the next time it starts' }
    # no window = only its background process: stop it (so the next start reads the colours), open nothing
    if (-not (Get-Process -Name Files -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })) {
        & (Join-Path $script:ThemeRepo 'bin\windots-restart-files.ps1') --if-running | Out-Null
        return 'Files: colours changed; no window open, they show the next time it starts'
    }
    if ($NoRestart) {
        Register-WindotsProtocol
        $title = 'Files: new theme ' + (Get-ThemeTitle $Name)
        $text = 'Restart Files to apply the colours. Clicking this notification restarts Files now (windows and tabs come back).'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:ThemeRepo 'bin\windots-notify.ps1') $title $text '--launch=windots:restart-files' | Out-Null
        return 'Files: colours changed; notification sent (clicking it restarts Files)'
    }
    & (Join-Path $script:ThemeRepo 'bin\windots-restart-files.ps1') --if-running | Out-Null
    'Files: restarted to apply the colours'
}

# ---- Files as the default file manager ------------------------------------------------------
# What Files' own Settings > Advanced switch does: copies Assets\FilesOpenDialog (the launcher and two .reg files) to
# %LOCALAPPDATA%\Files and imports SetFilesAsDefault.reg, which only writes under HKCU (so no UAC): folders, Win+E and
# "show in folder" open Files. Unset... puts Explorer back.
function Test-FilesDefault {
    $k = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey('Folder\shell\open\command')
    if (-not $k) { return $false }
    $v = [string]$k.GetValue('')
    $k.Close()
    $v -like '*Files.App.Launcher.exe*'
}

function Set-FilesDefault($Enable) {
    $dest = Join-Path $env:LOCALAPPDATA 'Files'
    if ($Enable) {
        $pkg = Get-FilesPackage
        if (-not $pkg) { throw 'Files is not installed' }
        New-Item -ItemType Directory -Force $dest | Out-Null
        Copy-Item (Join-Path $pkg.InstallLocation 'Assets\FilesOpenDialog\*') $dest -Recurse -Force
        [IO.File]::WriteAllText((Join-Path $dest 'Branch.txt'), 'files-stable', (New-Object Text.UTF8Encoding $false))
        $reg = Join-Path $dest 'SetFilesAsDefault.reg'
    } else {
        $reg = Join-Path $dest 'UnsetFilesAsDefault.reg'
        if (-not (Test-Path $reg)) {
            $pkg = Get-FilesPackage
            if (-not $pkg) { return $false }
            New-Item -ItemType Directory -Force $dest | Out-Null
            Copy-Item (Join-Path $pkg.InstallLocation 'Assets\FilesOpenDialog\UnsetFilesAsDefault.reg') $reg -Force
        }
    }
    & reg.exe import $reg 2>&1 | Out-Null
    (Test-FilesDefault) -eq [bool]$Enable
}
