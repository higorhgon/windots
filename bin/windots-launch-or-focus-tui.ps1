# windots-launch-or-focus-tui [--float] [--title=<title>] <command> [args...]
# windots:summary=Focus a TUI's window, or launch it
# windots:args=[--float] [--title=<title>] <command> [args...]
# windots:examples=windots launch or focus tui --float btop
#
# Like omarchy-launch-or-focus-tui: focus the TUI's window if it's open (found by
# its fixed title, default: the command's name), otherwise windots-launch-tui it.
#
#   windots-launch-or-focus-tui --float btop

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$rest = [Collections.Generic.List[object]]@($args)
$float = @(); $title = $null
while ($rest.Count -and ([string]$rest[0]).StartsWith('--')) {
    $flag = [string]$rest[0]
    if ($flag -eq '--float') { $float = @('--float') }
    elseif ($flag -like '--title=*') { $title = $flag.Substring(8) }
    else { break }
    $rest.RemoveAt(0)
}
if (-not $rest.Count) { throw 'usage: windots-launch-or-focus-tui [--float] [--title=<title>] <command> [args...]' }
if (-not $title) { $title = [IO.Path]::GetFileNameWithoutExtension([string]$rest[0]) }

& (Join-Path $PSScriptRoot 'windots-launch-or-focus.ps1') @float "^($([regex]::Escape($title)))$" `
    (Join-Path $PSScriptRoot 'windots-launch-tui.ps1') "--title=$title" @rest
