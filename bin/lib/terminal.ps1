# The default terminal, like omarchy's xdg-terminals.list: which terminal windots opens
# (Win+Enter, TUIs, the launcher's commands). Dot-sourced by windots-*-terminal and windots-launch-tui.
# Works on Windows PowerShell 5.1 and PowerShell 7.
#
# The choice is one word in ~\.config\windots\terminal (per machine, never versioned): ghostty or
# windows-terminal. With no file, Ghostty when it is installed, else Windows Terminal.

$WindotsTerminals = [ordered]@{
    'ghostty'          = 'Ghostty'
    'windows-terminal' = 'Windows Terminal'
}
$WindotsTerminalFile = Join-Path $HOME '.config\windots\terminal'
# Ghostty for Windows, from github.com/higorhgon/ghostty: an Inno Setup installer for the current user.
$GhosttyReleasesApi = 'https://api.github.com/repos/higorhgon/ghostty/releases?per_page=20'
$GhosttyUninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{6F3B8A52-4D1C-4E7B-9C2A-7D5E1F0A3B91}_is1'

function Get-GhosttyExe {
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Ghostty\bin\ghostty.exe'
    $key = Get-ItemProperty $GhosttyUninstallKey -ErrorAction SilentlyContinue
    if ($key -and $key.InstallLocation) { $exe = Join-Path $key.InstallLocation 'bin\ghostty.exe' }
    if (Test-Path $exe) { return $exe }
    $cmd = Get-Command ghostty.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $cmd.Source } else { $null }
}

function Get-GhosttyVersion {
    $key = Get-ItemProperty $GhosttyUninstallKey -ErrorAction SilentlyContinue
    if ($key) { [string]$key.DisplayVersion } else { $null }
}

function Get-WindowsTerminalExe {
    $cmd = Get-Command wt.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $cmd.Source } else { $null }
}

function Test-TerminalInstalled([string]$name) {
    switch ($name) {
        'ghostty' { [bool](Get-GhosttyExe) }
        'windows-terminal' { [bool](Get-WindowsTerminalExe) }
        default { $false }
    }
}

function Get-DefaultTerminal {
    if (Test-Path $WindotsTerminalFile) {
        $name = ([IO.File]::ReadAllText($WindotsTerminalFile)).Trim()
        if ($WindotsTerminals.Contains($name)) { return $name }
    }
    if (Get-GhosttyExe) { 'ghostty' } else { 'windows-terminal' }
}

function Set-DefaultTerminal([string]$name) {
    New-Item -ItemType Directory -Force (Split-Path $WindotsTerminalFile) | Out-Null
    [IO.File]::WriteAllText($WindotsTerminalFile, "$name`n", (New-Object Text.UTF8Encoding $false))
}

# One argument as CreateProcess reads it back (the rules of CommandLineToArgvW).
function ConvertTo-CommandLineArg([string]$arg) {
    if ($arg -and $arg -notmatch '[\s"]') { return $arg }
    $out = New-Object Text.StringBuilder '"'
    $slashes = 0
    foreach ($c in $arg.ToCharArray()) {
        if ($c -eq '\') { $slashes++; continue }
        if ($c -eq '"') { [void]$out.Append('\', 2 * $slashes + 1) } elseif ($slashes) { [void]$out.Append('\', $slashes) }
        $slashes = 0
        [void]$out.Append($c)
    }
    if ($slashes) { [void]$out.Append('\', 2 * $slashes) }
    [void]$out.Append('"')
    $out.ToString()
}

# Opens a new window of the default terminal. $command (optional) runs instead of the shell and the
# window closes when it ends; $title fixes the window title (windots-launch-or-focus finds it by that);
# $tui: Windows Terminal's borderless windots-tui profile. Returns the started process.
function Start-Terminal {
    param([string[]]$Command = @(), [string]$Title, [string]$Directory, [switch]$Tui, [string]$Terminal)
    if (-not $Terminal) { $Terminal = Get-DefaultTerminal }
    if (-not $Directory) { $Directory = $HOME }
    if ($Terminal -eq 'ghostty' -and -not (Get-GhosttyExe)) { $Terminal = 'windows-terminal' }   # uninstalled since
    $list = @()
    if ($Terminal -eq 'ghostty') {
        $exe = Get-GhosttyExe
        $list += "--working-directory=$Directory"
        if ($Title) { $list += "--title=$Title" }
        if ($Command.Count) {
            # Ghostty starts the command itself (CreateProcess): a full path also finds .cmd shims (npm's)
            $app = Get-Command $Command[0] -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($app) { $Command[0] = $app.Source }
            $list += '-e'; $list += $Command
        }
    } else {
        $exe = Get-WindowsTerminalExe
        if (-not $exe) { throw 'no terminal found: windots install terminal ghostty' }
        $list += '-w', 'new'
        if ($Tui) { $list += '--focus', '-p', 'windots-tui' }
        $list += '-d', $Directory
        if ($Title) { $list += '--title', $Title, '--suppressApplicationTitle' }
        # wt reads a bare ; as "next command" (a new tab), even inside quotes: \; keeps it in the command
        $list += @($Command | ForEach-Object { ([string]$_).Replace(';', '\;') })
    }
    # One command line, quoted here: Windows PowerShell 5.1 joins -ArgumentList without quoting.
    $line = (@($list) | ForEach-Object { ConvertTo-CommandLineArg ([string]$_) }) -join ' '
    Start-Process -FilePath $exe -ArgumentList $line -WorkingDirectory $Directory -PassThru
}
