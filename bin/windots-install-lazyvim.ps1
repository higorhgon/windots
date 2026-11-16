# windots-install-lazyvim [--appname <name>] [--refresh] [--sync] [--skip-sync]
# windots:summary=Install LazyVim with omarchy's Neovim setup, and its live theme
# windots:args=[--appname <name>] [--refresh] [--sync] [--skip-sync]
# windots:examples=windots install lazyvim | windots install lazyvim --refresh | windots install lazyvim --appname nvim-test
#
# omarchy's Neovim is LazyVim (its omarchy-nvim package: LazyVim's starter plus a few files, in
# omacom/omarchy-pkgs, pkgbuilds/omarchy-nvim). This puts the same on Windows, in the folder Neovim reads here,
# %LOCALAPPDATA%\nvim (data in %LOCALAPPDATA%\nvim-data):
#   - no config yet: LazyVim's starter is cloned (without its .git, like the package does);
#   - a LazyVim config already there: it is kept (your extras, plugins and keymaps stay) and omarchy's files are added
#     to it: lazyvim.json gets omarchy's extras (neo-tree) added to yours, options.lua gets its three lines
#     (remote clipboard, relativenumber off, autoformat off). A file it replaces is saved as <file>.bak.<unix time>;
#   - a config that is not LazyVim: left alone (--refresh backs the folder up as nvim.backup.<time> and starts over).
# The files (default\lazyvim, from omarchy-nvim): lazyvim.json, lua\config\{options,remote_clipboard}.lua,
# lua\plugins\{all-themes,disable-news-alert,lualine-transparent,omarchy-theme-hotreload,snacks-animated-scrolling-off}.lua
# and plugin\after\transparency.lua.
#
# The live theme: lua\plugins\theme.lua is the colorscheme of the current windots theme (windots-theme-set writes it:
# the theme's own neovim.lua when omarchy ships one, else the aether template filled with the palette). lazy.nvim sees
# the file change and omarchy's omarchy-theme-hotreload plugin applies the new colorscheme in every Neovim that is open.
# The theme plugins are installed with `Lazy! install` (only what is missing; nothing you have is updated), so a
# theme switch needs no download later. It runs when the config changed, or with --sync.
#   --appname <name>  install into %LOCALAPPDATA%\<name> (NVIM_APPNAME), to try it beside your own config
#   --refresh         back the config folder up and start from the starter
#   --sync / --skip-sync  always / never run `Lazy! install`
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\themes.ps1')

$Repo = Split-Path $PSScriptRoot
$overlay = Join-Path $Repo 'default\lazyvim'
$app = 'nvim'; $refresh = $false; $sync = $false; $skipSync = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($a -eq '--appname' -and $i + 1 -lt $args.Count) { $app = [string]$args[++$i] }
    elseif ($a -like '--appname=*') { $app = $a.Substring(10) }
    elseif ($a -eq '--refresh') { $refresh = $true }
    elseif ($a -eq '--sync') { $sync = $true }
    elseif ($a -eq '--skip-sync') { $skipSync = $true }
    else { Write-Host "unknown option: $a (see windots install lazyvim --help)" -ForegroundColor Red; exit 2 }
}
if ($app -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Write-Host "--appname must be letters, digits, . _ -: '$app'" -ForegroundColor Red; exit 2 }

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) { Write-Host 'nvim not found on PATH: run windots reinstall pkgs (mise installs neovim)' -ForegroundColor Red; exit 1 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host 'git not found on PATH' -ForegroundColor Red; exit 1 }

$cfg = Join-Path $env:LOCALAPPDATA $app
$unix = [DateTimeOffset]::Now.ToUnixTimeSeconds()
$changed = $false
function Step($msg) { Write-Host "  - $msg" }

# ---- 1. the config folder
if ($refresh -and (Test-Path $cfg)) {
    $bak = "$cfg.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item $cfg $bak
    Step "backed up the old config to $bak"
}
if (-not (Test-Path $cfg)) {
    Step 'cloning LazyVim''s starter'
    git clone --depth 1 https://github.com/LazyVim/starter $cfg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $cfg 'init.lua'))) { Write-Host 'git clone of the LazyVim starter failed' -ForegroundColor Red; exit 1 }
    Remove-Item (Join-Path $cfg '.git') -Recurse -Force
    $changed = $true
} elseif (-not (Test-Path (Join-Path $cfg 'lua\config\lazy.lua'))) {
    Write-Host "$cfg has a Neovim config that is not LazyVim: left alone. --refresh backs it up and installs LazyVim." -ForegroundColor Yellow
    exit 1
} else {
    Step "LazyVim config found in ${cfg}: keeping it, adding omarchy's files"
}

# ---- 2. omarchy's files
function Copy-Overlay($rel) {
    $src = Join-Path $overlay $rel
    $dst = Join-Path $cfg $rel
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    if (Test-Path $dst) {
        if ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) { return }
        Copy-Item $dst "$dst.bak.$unix"
    }
    Copy-Item $src $dst -Force
    $script:changed = $true
    Step "added $rel"
}
foreach ($rel in 'lua\config\remote_clipboard.lua', 'lua\plugins\all-themes.lua', 'lua\plugins\disable-news-alert.lua',
                 'lua\plugins\lualine-transparent.lua', 'lua\plugins\omarchy-theme-hotreload.lua',
                 'lua\plugins\snacks-animated-scrolling-off.lua', 'plugin\after\transparency.lua') { Copy-Overlay $rel }

# lazyvim.json: omarchy's extras added to the ones the person has
$mineJson = Get-Content (Join-Path $overlay 'lazyvim.json') -Raw | ConvertFrom-Json
$jsonPath = Join-Path $cfg 'lazyvim.json'
if (-not (Test-Path $jsonPath)) { Copy-Item (Join-Path $overlay 'lazyvim.json') $jsonPath; $changed = $true; Step 'added lazyvim.json' }
else {
    $cur = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $have = @($cur.extras | Where-Object { $_ })
    $missing = @($mineJson.extras | Where-Object { $have -notcontains $_ })
    if ($missing) {
        Copy-Item $jsonPath "$jsonPath.bak.$unix"
        $cur | Add-Member -NotePropertyName extras -NotePropertyValue @($have + $missing) -Force
        [IO.File]::WriteAllText($jsonPath, ($cur | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding $false))
        $changed = $true
        Step "lazyvim.json: added the extras $($missing -join ', ')"
    }
}

# options.lua: omarchy's three lines, each only when it is not there yet
$optPath = Join-Path $cfg 'lua\config\options.lua'
$opt = if (Test-Path $optPath) { [IO.File]::ReadAllText($optPath) } else { '' }
$add = @()
if ($opt -notmatch 'config\.remote_clipboard') { $add += 'require("config.remote_clipboard").setup()' }
if ($opt -notmatch 'relativenumber') { $add += 'vim.opt.relativenumber = false' }
if ($opt -notmatch 'g\.autoformat') { $add += 'vim.g.autoformat = false' }
if ($add) {
    if (Test-Path $optPath) { Copy-Item $optPath "$optPath.bak.$unix" }
    New-Item -ItemType Directory -Force (Split-Path $optPath) | Out-Null
    $nl = if ($opt -match "`r`n") { "`r`n" } else { "`n" }
    $text = $opt.TrimEnd() + $nl + $nl + '-- omarchy-nvim' + $nl + ($add -join $nl) + $nl
    [IO.File]::WriteAllText($optPath, $text, (New-Object Text.UTF8Encoding $false))
    $changed = $true
    Step "options.lua: added $($add.Count) line(s) of omarchy's"
}

# ---- 3. the theme, and the remembered config folder (windots-theme-set updates every one)
Register-NeovimApp $app
$name = Get-CurrentThemeName
$r = Set-NeovimThemeFile $cfg $name (Read-ThemeColors $name)
Step "theme.lua: $(Get-ThemeTitle $name) ($r)"
if ($r -eq 'changed') { $changed = $true }

# ---- 4. the plugins, so a theme switch does not wait for a download
if ($skipSync -or -not ($changed -or $sync)) {
    Step 'plugins: not touched'
} else {
    Step 'installing the missing plugins (Lazy! install; the first time takes a few minutes)'
    $log = Join-Path $env:TEMP 'windots-lazyvim.log'
    $env:NVIM_APPNAME = if ($app -ne 'nvim') { $app } else { $null }
    $p = Start-Process nvim -ArgumentList '--headless', '"+Lazy! install"', '+qa' -NoNewWindow -PassThru -RedirectStandardError $log -RedirectStandardOutput "$log.out"
    if (-not $p.WaitForExit(900000)) { $p.Kill(); Write-Warning 'Lazy! install took over 15 minutes: stopped (run windots install lazyvim --sync again)' }
    Remove-Item Env:NVIM_APPNAME -ErrorAction SilentlyContinue
    $tail = @(Get-Content $log, "$log.out" -ErrorAction SilentlyContinue | Where-Object { $_ -and $_ -notmatch '^\s*$' } | Select-Object -Last 4)
    $tail | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Step "plugins done (log: $log)"
}
Write-Host "LazyVim is in $cfg"
exit 0
