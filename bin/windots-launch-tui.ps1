# windots-launch-tui [--float] [--title=<title>] <command> [args...]
# windots:summary=Run a TUI in its own window of the default terminal
# windots:args=[--float] [--title=<title>] <command> [args...]
# windots:examples=windots launch tui nvim | windots launch tui --float btop
#
# Like omarchy-launch-tui: run a TUI in its own window of the default terminal
# (windots-default-terminal). Windows Terminal: no title or tab bar (focus mode), the
# windots-tui profile (no padding; from the windows-terminal group). Ghostty: a window
# of its own, closed when the TUI quits. The window title is fixed to <title>
# (default: the command's name), so it can be found again: see
# windots-launch-or-focus-tui. --float opens it floating and centered.
#
#   windots-launch-tui nvim
#   windots-launch-tui --float btop

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$rest = [Collections.Generic.List[object]]@($args)
$float = $false; $title = $null
while ($rest.Count -and ([string]$rest[0]).StartsWith('--')) {
    $flag = [string]$rest[0]
    if ($flag -eq '--float') { $float = $true }
    elseif ($flag -like '--title=*') { $title = $flag.Substring(8) }
    else { break }
    $rest.RemoveAt(0)
}
if (-not $rest.Count) { throw 'usage: windots-launch-tui [--float] [--title=<title>] <command> [args...]' }
if (-not $title) { $title = [IO.Path]::GetFileNameWithoutExtension([string]$rest[0]) }

# Run symlinked commands (winget's WinGet\Links aliases) from their real folder: apps like
# btop4win read their config and themes next to the exe they were started as.
$app = Get-Command ([string]$rest[0]) -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($app) {
    $item = Get-Item $app.Source
    if ($item.LinkType -eq 'SymbolicLink' -and $item.Target) {
        $target = [string]@($item.Target)[0]
        # winget links hold absolute targets; resolve relative ones against the link's folder
        if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path (Split-Path $app.Source) $target }
        $rest[0] = [IO.Path]::GetFullPath($target)
    }
}

# In the default terminal (lib\terminal.ps1). Windows Terminal: the hidden windots-tui profile from the
# windots fragment (no padding) in focus mode. Ghostty: a window of its own with the fixed title.
. (Join-Path $PSScriptRoot 'lib\terminal.ps1')
$command = @($rest | ForEach-Object { [string]$_ })
if ($float) {
    # windots-launch-float runs the script block in-process and watches for the new floating window
    &(Join-Path $PSScriptRoot 'windots-launch-float.ps1') { param($c, $t) [void](Start-Terminal -Command $c -Title $t -Tui) } $command $title
} else { [void](Start-Terminal -Command $command -Title $title -Tui) }
