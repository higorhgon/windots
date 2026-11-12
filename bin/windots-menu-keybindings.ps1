# windots-menu-keybindings [--pick | --list]
# windots:summary=Searchable list of every hotkey (Alt+K)
# windots:args=[--pick | --list]
# windots:examples=windots menu keybindings | windots menu keybindings --list
#
# Like omarchy's Super+K: a searchable list of every hotkey (whkd + windots-hotkeys.ahk).
# Opens a floating terminal with fzf; Enter runs the selected whkd binding, Esc closes.
#   --pick  run the list in the current terminal (what the floating window runs)
#   --list  just print it

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$whkdrc = Join-Path $HOME '.config\whkdrc'
$ahk = Join-Path $PSScriptRoot 'windots-hotkeys.ahk'

if ($args[0] -notin '--pick', '--list') {
    $self = $MyInvocation.MyCommand.Path
    & (Join-Path $PSScriptRoot 'windots-launch-or-focus-tui.ps1') --float --title=keybindings `
        pwsh -NoProfile -ExecutionPolicy Bypass -File $self --pick
    return
}

$keyNames = @{
    'oem_2' = '/'; 'oem_minus' = '-'; 'oem_plus' = '='; 'return' = 'Enter'; 'tab' = 'Tab'
    'left' = 'Left'; 'right' = 'Right'; 'up' = 'Up'; 'down' = 'Down'
}
function Format-Keys([string]$keys) {
    ($keys -split '\+' | ForEach-Object {
        $k = $_.Trim().ToLower()
        if ($keyNames.ContainsKey($k)) { $keyNames[$k] }
        elseif ($k.Length -eq 1) { $k.ToUpper() }
        else { (Get-Culture).TextInfo.ToTitleCase($k) }
    }) -join ' + '
}
function Format-Command([string]$cmd) {
    # "...\Programs\omapass\omapass.exe" -> omapass.exe
    $cmd -replace '"[^"]*\\([^\\"]+\.exe)"', '$1'
}

$rows = New-Object System.Collections.Generic.List[object]

# whkd: "# --- Section ---" headers, "keys : command  # description" bindings
# (the trailing comment, when there is one, is shown instead of the command)
$section = ''
foreach ($line in Get-Content $whkdrc) {
    # section names drop their "(...)" hints: "Foco (Alt+setas)" -> "Foco"
    if ($line -match '^#\s*---\s*(.+?)\s*---') { $section = $Matches[1] -replace '\s*\(.*\)$', ''; continue }
    if ($line -match '^#\s*(.+)$') { if ($section) { $section = $Matches[1] -replace '\s*\(.*\)$', '' }; continue }
    if ($line -match '^([^:#.][^:]*?)\s+:\s+(.+)$') {
        $keys = $Matches[1]; $body = $Matches[2]
        $cmd = ($body -replace '\s+#.*$', '').Trim()
        $note = if ($body -match '\s+#\s*(.+)$') { $Matches[1].Trim() } else { $null }
        $desc = if ($note) { $note } else { Format-Command $cmd }
        $rows.Add([pscustomobject]@{ Keys = Format-Keys $keys; Section = $section; Desc = $desc; Run = $cmd })
    }
}

# Flow Launcher: its main hotkey and the custom query hotkeys (shown, not run)
$flowSettings = Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json'
if (Test-Path $flowSettings) {
    $flow = Get-Content -Raw $flowSettings | ConvertFrom-Json
    $flowDesc = @{
        'sys' = 'Menu do sistema (desligar, reiniciar, bloquear...)'; 'app' = 'Aplicativos'
        '?' = 'Menu de plugins do Flow'; 's som' = 'Configurações de som'; 's bluetooth' = 'Configurações de bluetooth'
        's rede' = 'Configurações de rede'; 's energia' = 'Configurações de energia'
    }
    if ($flow.Hotkey) { $rows.Add([pscustomobject]@{ Keys = $flow.Hotkey; Section = 'Flow Launcher'; Desc = 'Buscar apps, arquivos e contas'; Run = '' }) }
    foreach ($h in $flow.CustomPluginHotkeys) {
        $q = ([string]$h.ActionKeyword).Trim()
        $desc = if ($flowDesc.ContainsKey($q)) { $flowDesc[$q] } else { "Flow: $q" }
        $rows.Add([pscustomobject]@{ Keys = $h.Hotkey; Section = 'Flow Launcher'; Desc = $desc; Run = '' })
    }
}

# AutoHotkey: "; --- Section ---" headers, "mods+key::" hotkeys (shown, not run)
$ahkMods = @{ '!' = 'Alt'; '+' = 'Shift'; '^' = 'Ctrl'; '#' = 'Win' }
$ahkKeys = @{ 'LButton' = 'Left drag'; 'RButton' = 'Right drag'; 'LWin' = 'Win'; 'RWin' = 'Win'; 'vkC1' = '/ (ABNT2)' }
$section = ''
if (Test-Path $ahk) {
    foreach ($line in Get-Content $ahk) {
        if ($line -match '^;\s*---\s*(.+?)\s*---') { $section = $Matches[1]; continue }
        if ($line -match '^\s*([~*$!+^#]*)(\w+)::') {
            $mods = ($Matches[1].ToCharArray() | ForEach-Object { $ahkMods[[string]$_] } | Where-Object { $_ }) + @()
            $key = if ($ahkKeys.ContainsKey($Matches[2])) { $ahkKeys[$Matches[2]] } else { $Matches[2] }
            $keys = (@($mods) + $key) -join ' + '
            if ($rows | Where-Object { $_.Keys -eq $keys }) { continue }   # Win listed twice (LWin/RWin)
            $rows.Add([pscustomobject]@{ Keys = $keys; Section = 'AutoHotkey'; Desc = $section; Run = '' })
        }
    }
}

$kw = ($rows | ForEach-Object { $_.Keys.Length } | Measure-Object -Maximum).Maximum + 2
$sw = ($rows | ForEach-Object { $_.Section.Length } | Measure-Object -Maximum).Maximum + 2
$lines = $rows | ForEach-Object { '{0}{1}{2}{3}{4}' -f $_.Keys.PadRight($kw), $_.Section.PadRight($sw), $_.Desc, "`t", $_.Run }
if ($args[0] -eq '--list') { $lines | ForEach-Object { ($_ -split "`t")[0] }; exit 0 }

$fzf = (Get-Command fzf -ErrorAction SilentlyContinue).Source
if (-not $fzf) { $fzf = (mise which fzf 2>$null) }
if (-not $fzf) { Write-Host 'fzf not found (mise use -g fzf)'; Read-Host 'Enter to close' | Out-Null; exit 0 }

# Colors: catppuccin/fzf, the same file the PowerShell profile loads (this runs with -NoProfile).
$fzfTheme = Join-Path $HOME '.config\powershell\catppuccin-fzf-mocha.ps1'
if (Test-Path $fzfTheme) { . $fzfTheme }
$pick = $lines | & $fzf --delimiter "`t" --with-nth 1 --layout reverse --border rounded --border-label ' Keybindings ' `
    --prompt '  ' --header 'Enter runs it   Esc closes' --no-hscroll
if ($LASTEXITCODE -ne 0 -or -not $pick) { exit 0 }

$run = ($pick -split "`t", 2)[1]
if ($run) { Start-Process pwsh -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $run }
exit 0
