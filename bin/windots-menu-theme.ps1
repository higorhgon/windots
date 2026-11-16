# windots-menu-theme [--pick]
# windots:summary=Pick a theme from a searchable list with a colour preview (like omarchy's theme menu)
# windots:args=[--pick]
# windots:examples=windots menu theme
#
# Like omarchy's theme menu: a floating terminal with fzf, every theme with its colours drawn on the
# right; Enter applies it (windots-theme-set), Esc closes.
#   --pick  run the list in the current terminal (what the floating window runs)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'

if ($args[0] -ne '--pick') {
    $self = $MyInvocation.MyCommand.Path
    & (Join-Path $PSScriptRoot 'windots-launch-or-focus-tui.ps1') --float --title=themes `
        pwsh -NoProfile -ExecutionPolicy Bypass -File $self --pick
    return
}

$fzf = (Get-Command fzf -ErrorAction SilentlyContinue).Source
if (-not $fzf) { $fzf = (mise which fzf 2>$null) }
if (-not $fzf) { Write-Host 'fzf not found (mise use -g fzf)'; Read-Host 'Enter to close' | Out-Null; exit 0 }

# Colors: catppuccin/fzf, the same file the PowerShell profile loads (this runs with -NoProfile).
$fzfTheme = Join-Path $HOME '.config\powershell\catppuccin-fzf-mocha.ps1'
if (Test-Path $fzfTheme) { . $fzfTheme }

. (Join-Path $PSScriptRoot 'lib' | Join-Path -ChildPath 'themes.ps1')
$current = Get-CurrentThemeName
$list = Join-Path $PSScriptRoot 'windots-theme-list.ps1'
$preview = "pwsh -NoProfile -File `"$list`" --preview {1}"
$pick = (Get-ThemeNames) | & $fzf --layout reverse --border rounded --border-label " Theme (now: $current) " --prompt '  ' `
    --header 'Enter applies it   Esc closes' --no-hscroll `
    --preview $preview --preview-window 'right,45%,border-left'
if ($LASTEXITCODE -ne 0 -or -not $pick) { exit 0 }

$name = ([string]$pick).Trim()
& (Join-Path $PSScriptRoot 'windots-theme-set.ps1') $name
Read-Host 'Enter to close' | Out-Null
exit 0
