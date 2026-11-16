# windots-theme-set [<name>] [--skip-taskbar] [--skip-wallpaper] [--skip-files] [--no-restart]
# windots:summary=Apply an omarchy theme: taskbar, komorebi borders and switcher, btop, atuin, fzf, Windows Terminal, Neovim, Files, wallpaper, light/dark mode
# windots:args=[<name>] [--skip-taskbar] [--skip-wallpaper] [--skip-files] [--no-restart]
# windots:examples=windots theme set | windots theme set "Tokyo Night" | windots theme set catppuccin-latte --no-restart
#
# Like omarchy-theme-set: one theme (default\themes\<name>\colors.toml, the palettes omarchy ships)
# paints everything windots themes. With no name it applies the current theme again, which is what
# windots-install does. The names are omarchy's: `windots theme list`. "Tokyo Night", tokyo_night and
# tokyo-night are the same theme.
#   Windows Terminal    the "windots" colour scheme and UI theme, made from the palette
#   taskbar             background = the theme's background; Start logo, tray icons and clock = its foreground, as in
#                       omarchy's bar; the battery's fill = its green (Windhawk Taskbar Styler; needs
#                       windots-install-windhawk; no UAC once it granted the user write access to the mod's settings)
#   light / dark mode   Windows' flags follow the theme's mode, so the taskbar text, the tray and the
#                       switcher numbers stay readable on a light taskbar
#   komorebi borders    active / stack / floating = the theme's active border or accent, monocle = its orange,
#                       unfocused = its inactive border (omarchy's Hyprland borders); changed live, no restart
#   komorebi-switcher   active workspace = the accent, workspaces with windows = the muted colour
#   Neovim (LazyVim)    lua\plugins\theme.lua = the theme's colorscheme (omarchy's neovim.lua, or its aether template
#                       with the palette); open Neovims reload it live. Only when windots-install-lazyvim was run.
#   Files               its colours (windots-install-files): Files reads them only at start, so an open Files gets a
#                       notification and clicking it restarts Files (never restarted on its own; windots restart files)
#   wallpaper           the theme's first image (an image of this theme chosen in the launcher is kept)
# Explorer never restarts: a light/dark change is broadcast and the taskbar follows within seconds. The switcher
# restarts only when its colours changed and its build has no live reload; --no-restart leaves it running.
#   --skip-taskbar   leave the taskbar and the Windows mode alone
#   --skip-wallpaper leave the desktop background alone
#   --skip-files     leave Files alone
#   btop, atuin, fzf   btop4win's themes\windots.theme (omarchy's template), ~\.atuin	hemes\windots.toml and the fzf option file
#                       (FZF_DEFAULT_OPTS_FILE): the next start of each reads the new colours. starship uses the terminal's colours.
# Not themed yet: herdr-app.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\themes.ps1')

$skipTaskbar = $false; $skipWallpaper = $false; $skipFiles = $false; $noRestart = $false; $words = @()
foreach ($a in $args) {
    if ($a -eq '--skip-taskbar') { $skipTaskbar = $true }
    elseif ($a -eq '--skip-wallpaper') { $skipWallpaper = $true }
    elseif ($a -eq '--skip-files') { $skipFiles = $true }
    elseif ($a -eq '--no-restart') { $noRestart = $true }
    elseif (([string]$a).StartsWith('-')) { Write-Host "unknown option: $a (see windots theme set --help)" -ForegroundColor Red; exit 2 }
    else { $words += [string]$a }
}
$name = if ($words.Count) { Resolve-ThemeName ($words -join ' ') } else { Get-CurrentThemeName }
if (-not $name) {
    Write-Host "unknown theme '$($words -join ' ')'. Themes: $((Get-ThemeNames) -join ', ')" -ForegroundColor Red
    exit 1
}
$c = Read-ThemeColors $name
function Step($msg) { Write-Host "  - $msg" }

Write-Host "==> Theme $(Get-ThemeTitle $name) ($($c.mode))" -ForegroundColor Cyan
Set-CurrentThemeName $name

# The taskbar first: it is what the eye is on. The light / dark flags need no restart: Set-WindowsColorMode broadcasts
# the change from a process of its own (Explorer follows) while the rest of the script runs.
$modeChanged = $false
if (-not $skipTaskbar) {
    # the colours before the mode: Windhawk paints the bar, its icons and the clock; the mode only reaches the rest
    if (Test-Path 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler') {
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot 'windots-install-windhawk.ps1') "--color=$($c.background)" "--foreground=$($c.foreground)" "--charging=$($c.green)"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'the taskbar colour was not applied (above)' }
    } else {
        Step 'taskbar colour skipped: Windhawk and its mod are not installed (windots install windhawk)'
    }
    $modeChanged = Set-WindowsColorMode $c.mode
    Step "Windows $($c.mode) mode$(if ($modeChanged) { ': changed' } else { ': already set' })"
}

$switcherChanged = Set-SwitcherColors $c
Step $(if ($switcherChanged) { 'komorebi-switcher: indicator colours changed' } else { 'komorebi-switcher: colours already right' })

switch (Set-TerminalTheme $c) {
    'changed' { Step 'Windows Terminal: scheme and tab theme changed' }
    'same'    { Step 'Windows Terminal: already right' }
    default   { Step 'Windows Terminal settings.json not found: skipped (open it once, then windots theme set)' }
}

# Neovim (LazyVim from windots-install-lazyvim): theme.lua is the new colorscheme; a Neovim that is open reloads it by itself
switch (Set-NeovimTheme $name $c) {
    'changed' { Step 'Neovim (LazyVim): theme changed; open Neovims switch by themselves' }
    'same'    { Step 'Neovim (LazyVim): already right' }
}

if (-not $skipWallpaper) {
    switch (Set-ThemeWallpaper $name) {
        'changed' { Step 'wallpaper: changed' }
        'same'    { Step 'wallpaper: already right' }
        default   { Step 'wallpaper: the theme has no images, left alone' }
    }
}

Step (Set-KomorebiBorders $c)
Step (Set-BtopTheme $c)
Step (Set-AtuinTheme $c)
Step (Set-FzfTheme $c)

if ($switcherChanged -and (Test-SwitcherLiveReload)) {
    Step 'komorebi-switcher takes the new colours by itself (no restart)'
} elseif ($switcherChanged -and $noRestart) {
    Step 'not restarting (--no-restart): run windots restart komorebi switcher to see its colours'
} elseif ($switcherChanged) {
    & (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1')
}

# Last: Files. A theme switch never restarts it (its window would close and come back on its own): an open Files gets a
# notification, and clicking it restarts Files.
if (-not $skipFiles) { Step (Update-FilesTheme $name $c $true) }
exit 0
