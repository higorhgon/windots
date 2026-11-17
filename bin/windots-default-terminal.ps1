# windots-default-terminal [ghostty|windows-terminal]
# windots:summary=Show or set the default terminal (Win+Enter, TUIs, the launcher)
# windots:args=[ghostty | windows-terminal]
# windots:examples=windots default terminal | windots default terminal ghostty | windots default terminal windows-terminal
#
# Like omarchy-default-terminal: the terminal windots opens (windots-launch-terminal, Win+Enter;
# windots-launch-tui; the launcher's commands). No argument: prints the current one. A terminal that
# is not installed yet is installed first (windots-install-terminal). The choice is kept per machine
# in ~\.config\windots\terminal; with no choice, Ghostty when installed, else Windows Terminal.
#
# It also sets Windows' own default terminal (HKCU\Console\%%Startup), where a console program started
# with no console (Explorer, Win+R, a shortcut) opens: Ghostty takes it through the same COM handoff
# Windows Terminal uses (Ghostty 1.4.1.6 on), with Windows Terminal's OpenConsole as the console host,
# so Windows Terminal must stay installed. Settings > System > For developers only lists packaged
# terminals, so it may show the choice as blank.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
. (Join-Path $PSScriptRoot 'lib\terminal.ps1')

if (-not $args.Count) { Get-DefaultTerminal; return }
$name = [string]$args[0]
if ($args.Count -gt 1 -or -not $WindotsTerminals.Contains($name)) {
    Write-Host "usage: windots-default-terminal [$($WindotsTerminals.Keys -join '|')]" -ForegroundColor Red; exit 2
}

if (-not (Test-TerminalInstalled $name)) {
    # windots-install-terminal installs it and then runs this again
    & (Join-Path $PSScriptRoot 'windots-install-terminal.ps1') $name
    exit $LASTEXITCODE
}

Set-DefaultTerminal $name
Write-Host "  - default terminal: $($WindotsTerminals[$name])"
Write-Host "  - $(Set-WindowsDefaultTerminal $name)"
& (Join-Path $PSScriptRoot 'windots-notify.ps1') 'Terminal' "$($WindotsTerminals[$name]) is now the default terminal" | Out-Null
