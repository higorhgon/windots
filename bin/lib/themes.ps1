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
