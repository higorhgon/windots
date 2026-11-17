# windots-launch-terminal [--dir=<folder>] [--title=<title>] [command] [args...]
# windots:summary=Open the default terminal (Ghostty or Windows Terminal)
# windots:args=[--dir=<folder>] [--title=<title>] [command] [args...]
# windots:examples=windots launch terminal | windots launch terminal nvim | windots launch terminal --dir=~/windots
#
# Like omarchy-launch-terminal: a new window of the default terminal (windots-default-terminal),
# in --dir (default: home). With a command, the window runs it and closes when it ends.
#
#   windots-launch-terminal              # Win+Enter
#   windots-launch-terminal nvim         # Win+Shift+N

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
. (Join-Path $PSScriptRoot 'lib\terminal.ps1')

# Plain $args (no param block): flags like -w must reach the command, not this script.
$rest = [Collections.Generic.List[object]]@($args)
$dir = $null; $title = $null
while ($rest.Count -and ([string]$rest[0]).StartsWith('--')) {
    $flag = [string]$rest[0]
    if ($flag -like '--dir=*') { $dir = $flag.Substring(6) }
    elseif ($flag -like '--title=*') { $title = $flag.Substring(8) }
    else { break }
    $rest.RemoveAt(0)
}
if ($dir) { $dir = (Resolve-Path ($dir -replace '^~', $HOME)).Path }

[void](Start-Terminal -Command @($rest | ForEach-Object { [string]$_ }) -Title $title -Directory $dir)
