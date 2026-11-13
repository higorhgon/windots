# windots-dev-add-migration [--no-edit]
# windots:summary=Create a new windots migration in the repo and open it in the editor
# windots:args=[--no-edit]
# windots:examples=windots dev add migration | windots dev add migration --no-edit
#
# Like omarchy-dev-add-migration: creates migrations\<unix time>.ps1 from a template, prints its
# path and opens it in $env:EDITOR (nvim, else notepad). --no-edit only creates it.
# See windots-migrate for what a migration is.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$noEdit = $args -contains '--no-edit'
foreach ($a in $args) { if ($a -ne '--no-edit') { Write-Host "unknown option: $a (see windots dev add migration --help)" -ForegroundColor Red; exit 2 } }

$repo = Split-Path $PSScriptRoot
$dir = Join-Path $repo 'migrations'
New-Item -ItemType Directory -Force $dir | Out-Null
$file = Join-Path $dir ("{0}.ps1" -f [DateTimeOffset]::Now.ToUnixTimeSeconds())

$template = @'
Write-Host 'Describe what this migration changes'

# Runs once per machine (windots migrate), in Windows PowerShell 5.1, with the repo in
# $env:WINDOTS_PATH. Write it to be safe to run again: a failure means it runs again next time.
$ErrorActionPreference = 'Stop'

'@
[IO.File]::WriteAllText($file, ($template -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding $false))
Write-Host $file

if (-not $noEdit) {
    $editor = $env:EDITOR
    if (-not $editor) { $editor = if (Get-Command nvim -ErrorAction SilentlyContinue) { 'nvim' } else { 'notepad' } }
    & $editor $file
}
