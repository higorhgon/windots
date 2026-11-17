# Tool init scripts are cached. Running `mise activate`, `starship init`, `atuin init`... and evaluating their output
# took ~3 s per shell: starting a process is slow on Windows, and Invoke-Expression compiles the text every time.
# The output only changes when the tool or its config does, so it is written once to ~\.cache\windots\pwsh and
# dot-sourced after that, the way nushell setups save `starship init nu` to a file. The first line of each file
# records its sources (path, size, time); when one of them changes the file is generated again.
$WindotsInitCache = Join-Path $HOME '.cache\windots\pwsh'

function Get-WindotsInit([string] $Name, [string[]] $Sources, [scriptblock] $Generate) {
    $key = '# windots-cache ' + (@(foreach ($s in $Sources) {
        $i = if ($s) { Get-Item -LiteralPath $s -Force -ErrorAction Ignore }
        if ($i) { '{0}|{1}|{2}' -f $i.FullName, $i.LastWriteTimeUtc.Ticks, $(if ($i.PSIsContainer) { 0 } else { $i.Length }) }
    }) -join ';')
    $file = Join-Path $WindotsInitCache "$Name.ps1"
    if ((Get-Content -LiteralPath $file -TotalCount 1 -ErrorAction Ignore) -ne $key) {
        $text = & $Generate | Out-String
        if (-not $text.Trim()) { return }   # tool missing or failing: no init
        $null = New-Item -ItemType Directory -Force $WindotsInitCache
        Set-Content -LiteralPath $file -Value "$key`n$text" -NoNewline
    }
    $file
}

function Get-WindotsExe([string] $Name) {
    (Get-Command $Name -CommandType Application -ErrorAction Ignore | Select-Object -First 1).Source
}

# mise: the PATH entries and variables of the global tools (`mise env`), without `mise activate`'s hook, which ran
# `mise hook-env` (~0.5 s) at start and before every prompt. No project here has its own mise.toml; for one that
# does, run `mise env -s pwsh | Out-String | Invoke-Expression` inside it. Not the shims (`--shims`): every call
# through one costs ~0.8 s more, and atuin runs at every command, zoxide at every cd. A new tool or version changes
# its folder under installs, which makes the cache stale.
$miseExe = Get-WindotsExe mise
if ($miseExe) {
    $miseInstalls = Join-Path ($env:MISE_DATA_DIR ?? (Join-Path $env:LOCALAPPDATA 'mise')) 'installs'
    $miseSources = @($miseExe, (Join-Path $HOME '.config\mise\config.toml'), (Join-Path $HOME '.config\mise\config.local.toml')) +
        @(Get-ChildItem -LiteralPath $miseInstalls -Directory -ErrorAction Ignore | ForEach-Object FullName)
    $init = Get-WindotsInit mise $miseSources {
        $vars = & $miseExe env --json 2>$null | ConvertFrom-Json
        if (-not $vars) { return }
        $q = { "'" + ($args[0] -replace "'", "''") + "'" }
        foreach ($v in $vars.PSObject.Properties) {
            if ($v.Name -eq 'PATH') {
                $paths = @($v.Value -split ';' | Where-Object { $_ -like "$miseInstalls\*" } | Select-Object -Unique)
                '$miseBins = @(' + (($paths | ForEach-Object { & $q $_ }) -join ', ') + ')'
                '$env:Path = (@($miseBins) + @($env:Path -split '';'' | Where-Object { $_ -and $miseBins -notcontains $_ })) -join '';'''
            } else {
                '$env:{0} = {1}' -f $v.Name, (& $q $v.Value)
            }
        }
    }
    if ($init) { . $init }
}

Set-Alias tuckr tuckr-x86_64-windows   # winget installs it under this name

$exe = Get-WindotsExe starship
if ($exe -and ($init = Get-WindotsInit starship @($exe) { & $exe init powershell --print-full-init })) { . $init }

# fzf colors (https://github.com/catppuccin/fzf), also used by windots-menu-keybindings
. (Join-Path $PSScriptRoot 'fzf-theme.ps1')

# Colors: the terminal's 16 ANSI colors, never RGB, so they follow the windots theme (the Windows Terminal scheme that
# windots-theme-set writes) and the terminal's own theme, like starship. The roles are the ones the Catppuccin module
# (dropped: fixed Mocha RGB, ~0.25 s to load) gave them. $PSStyle.Formatting is ANSI by default already.
$e = [char]27
Set-PSReadLineOption -Colors @{
    ContinuationPrompt     = "$e[36m"    # cyan
    Emphasis               = "$e[31m"    # red
    Selection              = "$e[100m"   # bright black background
    InlinePrediction       = "$e[90m"    # bright black
    ListPrediction         = "$e[35m"    # magenta
    ListPredictionSelected = "$e[100m"
    Command                = "$e[34m"    # blue
    Comment                = "$e[90m"
    Default                = "$e[39m"    # the terminal's foreground
    Error                  = "$e[31m"
    Keyword                = "$e[35m"
    Member                 = "$e[37m"    # white
    Number                 = "$e[33m"    # yellow
    Operator               = "$e[36m"
    Parameter              = "$e[95m"    # bright magenta
    String                 = "$e[32m"    # green
    Type                   = "$e[33m"
    Variable               = "$e[94m"    # bright blue
}
# ls: the default blue-background folders are unreadable
$PSStyle.FileInfo.Directory = "$($PSStyle.Bold)$($PSStyle.Foreground.Blue)"

$exe = Get-WindotsExe atuin
if ($exe -and ($init = Get-WindotsInit atuin @($exe) { & $exe init powershell --disable-up-arrow })) { . $init }

Set-PSReadlineKeyHandler -Key ctrl+d -Function DeleteCharOrExit

# Tab like bash: completes the common part, a second Tab lists every option
Set-PSReadLineKeyHandler -Key Tab -Function Complete

Set-PSReadLineKeyHandler -Key Ctrl+c -Function CancelLine
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord

# Some terminals send Ctrl+Left/Right as ESC b / ESC f (Linux/macOS style)
Set-PSReadLineKeyHandler -Chord 'Escape,b' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Escape,f' -Function ForwardWord
Set-PSReadLineKeyHandler -Key Alt+b -Function BackwardWord
Set-PSReadLineKeyHandler -Key Alt+f -Function ForwardWord

# zoxide: cd learns the folders you use (cd foo jumps to the best match; cdi picks in fzf)
# Last, as zoxide asks: it wraps cd after everything else is set up.
$exe = Get-WindotsExe zoxide
if ($exe -and ($init = Get-WindotsInit zoxide @($exe) { & $exe init --cmd cd powershell })) { . $init }

Remove-Variable e, exe, init, miseExe, miseInstalls, miseSources -ErrorAction Ignore
