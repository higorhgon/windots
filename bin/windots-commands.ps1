# windots-commands [--json]
# windots:summary=List every windots command
# windots:args=[--json]
# windots:examples=windots commands | windots commands --json
#
# Like `omarchy commands`: reads the metadata at the top of each bin\windots-*.ps1
#   # windots:summary=<one line>
#   # windots:args=<usage after the command>
#   # windots:examples=<example> | <example>
# The route comes from the file name: windots-install-font -> windots install font.
#   --json     machine-readable list
#   --objects  the commands as PowerShell objects (what windots.ps1 reads)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

function Read-WindotsCommand($file) {
    $meta = @{}
    $fallback = $null
    foreach ($line in [IO.File]::ReadLines($file.FullName)) {
        if ($line -match '^\s*$') { continue }
        if ($line -notmatch '^\s*#') { break }   # metadata lives in the leading comment block
        if ($line -match '^\s*#\s*windots:([\w-]+)=(.*)$') { $meta[$Matches[1]] = $Matches[2].Trim() }
        elseif (-not $fallback -and $line -match '^\s*#\s*(\S.*)$' -and $Matches[1] -notlike 'windots-*') {
            $fallback = $Matches[1]
        }
    }
    $stem = $file.BaseName.Substring('windots-'.Length)
    $route = 'windots ' + $stem.Replace('-', ' ')
    $summary = if ($meta.summary) { $meta.summary } elseif ($fallback) { $fallback } else { "Run $($file.BaseName)" }
    [pscustomobject]@{
        Name     = $file.BaseName
        Route    = $route
        Group    = $stem.Split('-')[0]
        Summary  = $summary
        Args     = $meta.args
        Usage    = if ($meta.args) { "$route $($meta.args)" } else { $route }
        Examples = @(if ($meta.examples) { $meta.examples -split '\s*\|\s*' })
        Path     = $file.FullName
    }
}

$commands = @(Get-ChildItem $PSScriptRoot -Filter 'windots-*.ps1' |
    ForEach-Object { Read-WindotsCommand $_ } | Sort-Object Route)

if ($args -contains '--objects') { return $commands }
if ($args -contains '--json') {
    $commands | Select-Object Name, Route, Group, Summary, Args, Usage, Examples | ConvertTo-Json -Depth 3
    return
}

$width = ($commands | ForEach-Object { $_.Usage.Length } | Measure-Object -Maximum).Maximum
Write-Host 'windots commands:'
foreach ($c in $commands) { Write-Host ('  {0}  {1}' -f $c.Usage.PadRight($width), $c.Summary) }
