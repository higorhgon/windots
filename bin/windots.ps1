# windots <command> [args...]
#
# Like omarchy's command center: one entry point for every bin\windots-* command.
# The words after `windots` are matched against the file names, longest first, and
# the rest is passed on: `windots install font JetBrainsMono` runs
# windots-install-font JetBrainsMono.
#   windots                          this help
#   windots commands [--json]        every command (windots-commands)
#   windots <group> [--help]         the commands of a group (install, launch, ...)
#   windots <command> --help         usage, arguments and examples of a command
# Each command's help comes from its `# windots:` metadata (see windots-commands).
# Plain $args (no param block): flags must reach the command.
# Works on Windows PowerShell 5.1 and PowerShell 7.

$commands = & (Join-Path $PSScriptRoot 'windots-commands.ps1') --objects

$groupInfo = [ordered]@{
    center    = 'komorebi-switcher position in the taskbar'
    commands  = 'List every windots command'
    float     = 'Floating windows'
    install   = 'Install windots and its parts (fonts, themes, apps)'
    launch    = 'Open apps and TUIs: floating, or focus them if open'
    menu      = 'fzf menus'
    refresh   = 'Regenerate generated files'
    reinstall = 'Reset windots dotfiles'
    toggle    = 'Toggle window and system states'
    update    = 'Update windots, winget packages and mise tools'
}

function Write-Table($rows) {
    $rows = @($rows)
    if (-not $rows) { return }
    $width = ($rows | ForEach-Object { $_[0].Length } | Measure-Object -Maximum).Maximum
    foreach ($r in $rows) { Write-Host ('  {0}  {1}' -f $r[0].PadRight($width), $r[1]) }
}

function Show-MainHelp {
    Write-Host @'
windots command center

Usage:
  windots <command> [args...]
  windots commands [--json]
  windots <group> --help
  windots <group> <command> --help

Common commands:
'@
    $common = 'windots-update', 'windots-reinstall-configs', 'windots-install-font',
              'windots-menu-keybindings', 'windots-toggle-dark-mode'
    Write-Table @(foreach ($n in $common) {
        $c = $commands | Where-Object Name -eq $n
        if ($c) { , @($c.Usage, $c.Summary) }
    })
    Write-Host "`nGroups:"
    $groups = @($commands | ForEach-Object Group | Sort-Object -Unique)
    Write-Table @(foreach ($g in $groups) {
        $d = $groupInfo[$g]
        if (-not $d) { $d = ($commands | Where-Object Group -eq $g | Select-Object -First 1).Summary }
        , @($g, $d)
    })
    Write-Host @'

Discovery:
  windots commands         List all commands
  windots commands --json  Machine-readable command list
'@
}

function Show-GroupHelp($group) {
    $d = $groupInfo[$group]
    Write-Host $(if ($d) { "$group commands - ${d}:" } else { "$group commands:" })
    Write-Table @($commands | Where-Object Group -eq $group | ForEach-Object { , @($_.Usage, $_.Summary) })
}

function Show-CommandHelp($c) {
    Write-Host "Usage:`n  $($c.Usage)`n`n$($c.Summary)"
    if ($c.Args) { Write-Host "`nArguments:`n  $($c.Args)" }
    if ($c.Examples) { Write-Host "`nExamples:"; $c.Examples | ForEach-Object { Write-Host "  $_" } }
    Write-Host "`nCommand:`n  $($c.Name)"
    # A group's own command (windots install) also lists the rest of its group, like omarchy.
    if ($c.Route -eq "windots $($c.Group)") {
        $related = @($commands | Where-Object { $_.Group -eq $c.Group -and $_.Name -ne $c.Name })
        if ($related) {
            Write-Host "`nRelated commands:"
            Write-Table @($related | ForEach-Object { , @($_.Usage, $_.Summary) })
        }
    }
}

# Internal: a command's own --help lands here (see the first line of each script).
if ($args[0] -eq '--help-for') {
    $c = $commands | Where-Object Path -eq $args[1]
    if ($c) { Show-CommandHelp $c } else { Write-Host "no windots metadata for $($args[1])" }
    return
}

if ($args.Count -eq 0 -or $args[0] -in '-h', '--help', 'help') { Show-MainHelp; return }

# Longest route first, over the leading words (flags end the route).
$words = @()
foreach ($a in $args) { if ("$a" -like '-*') { break }; $words += "$a" }
for ($n = $words.Count; $n -ge 1; $n--) {
    $name = 'windots-' + ($words[0..($n - 1)] -join '-')
    $c = $commands | Where-Object Name -eq $name
    if (-not $c) { continue }
    $rest = @(if ($args.Count -gt $n) { $args[$n..($args.Count - 1)] })
    if ($rest.Count -and $rest[0] -in '-h', '--help') { Show-CommandHelp $c; return }
    & $c.Path @rest
    return
}

if ($commands | Where-Object Group -eq $args[0]) { Show-GroupHelp $args[0]; return }

Write-Host "windots: unknown command '$($args -join ' ')'. Run: windots commands" -ForegroundColor Red
exit 1
