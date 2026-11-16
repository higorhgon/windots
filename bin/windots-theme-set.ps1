# windots-theme-set [<name>] [--skip-taskbar] [--skip-wallpaper] [--no-restart]
# windots:summary=Apply an omarchy theme: taskbar, komorebi-switcher, Windows Terminal, Neovim, wallpaper, light/dark mode
# windots:args=[<name>] [--skip-taskbar] [--skip-wallpaper] [--no-restart]
# windots:examples=windots theme set | windots theme set "Tokyo Night" | windots theme set catppuccin-latte --no-restart
#
# Like omarchy-theme-set: one theme (default\themes\<name>\colors.toml, the palettes omarchy ships)
# paints everything windots themes. With no name it applies the current theme again, which is what
# windots-install does. The names are omarchy's: `windots theme list`. "Tokyo Night", tokyo_night and
# tokyo-night are the same theme.
#   Windows Terminal    the "windots" colour scheme and UI theme, made from the palette
#   taskbar             background = the theme's background (Windhawk Taskbar Styler; needs
#                       windots-install-windhawk, and admin unless --allow-user-settings was done)
#   light / dark mode   Windows' flags follow the theme's mode, so the taskbar text, the tray and the
#                       switcher numbers stay readable on a light taskbar
#   komorebi-switcher   active workspace = the accent, workspaces with windows = the muted colour
#   Neovim (LazyVim)    lua\plugins\theme.lua = the theme's colorscheme (omarchy's neovim.lua, or its aether template
#                       with the palette); open Neovims reload it live. Only when windots-install-lazyvim was run.
#   wallpaper           the theme's first image (an image of this theme chosen in the launcher is kept)
# Explorer restarts (its windows close, the taskbar blinks) only when the light/dark mode changed;
# the switcher restarts only when its colours changed. --no-restart changes the files and leaves both.
#   --skip-taskbar   leave the taskbar and the Windows mode alone
#   --skip-wallpaper leave the desktop background alone
# Not themed yet: btop, atuin, fzf, starship, herdr-app, komorebi borders.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\themes.ps1')

$skipTaskbar = $false; $skipWallpaper = $false; $noRestart = $false; $words = @()
foreach ($a in $args) {
    if ($a -eq '--skip-taskbar') { $skipTaskbar = $true }
    elseif ($a -eq '--skip-wallpaper') { $skipWallpaper = $true }
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

$switcherChanged = Set-SwitcherColors $c
Step $(if ($switcherChanged) { 'komorebi-switcher: indicator colours changed' } else { 'komorebi-switcher: colours already right' })

$modeChanged = $false
if (-not $skipTaskbar) {
    $modeChanged = Set-WindowsColorMode $c.mode
    Step "Windows $($c.mode) mode$(if ($modeChanged) { ': changed' } else { ': already set' })"
    if (Test-Path 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler') {
        $global:LASTEXITCODE = 0
        & (Join-Path $PSScriptRoot 'windots-install-windhawk.ps1') "--color=$($c.background)"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'the taskbar colour was not applied (above)' }
    } else {
        Step 'taskbar colour skipped: Windhawk and its mod are not installed (windots install windhawk)'
    }
}

if ($noRestart) {
    if ($modeChanged -or $switcherChanged) { Step 'not restarting (--no-restart): run windots restart explorer to see the changes' }
} elseif ($modeChanged) {
    Step 'restarting Explorer for the light / dark change'
    & (Join-Path $PSScriptRoot 'windots-restart-explorer.ps1')   # restarts the switcher too
} elseif ($switcherChanged) {
    & (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1')
}
exit 0
