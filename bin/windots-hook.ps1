# windots-hook <name> [args...]
# windots:summary=Run the per-machine hook <name>, if there is one
# windots:args=<name> [args...]
# windots:examples=windots hook post-update
#
# Like omarchy-hook: a place for what only this machine needs. If
# ~\.config\windots\hooks\<name>.ps1 exists it runs, with the extra arguments; if not, nothing
# happens. Hooks are not in the repo (they are per machine). windots-update runs `post-update` once
# everything else is done: restart something, copy a file, tell a chat.
# A hook that fails is reported and does not stop the caller.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if (-not $args.Count) { Write-Host 'usage: windots hook <name> [args...]' -ForegroundColor Red; exit 2 }

$name = [string]$args[0]
if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { Write-Host "'$name' is not a hook name (letters, digits, - and _)" -ForegroundColor Red; exit 2 }
$rest = @($args | Select-Object -Skip 1)
$hook = Join-Path $HOME ".config\windots\hooks\$name.ps1"
if (-not (Test-Path -LiteralPath $hook)) { exit 0 }

Write-Host "  - hook $name ($hook)"
try {
    # A script that ends without exit leaves $LASTEXITCODE as the caller had it: zero it first.
    $global:LASTEXITCODE = 0
    & $hook @rest
    if ($LASTEXITCODE -ne 0) { Write-Warning "hook $name exited with $LASTEXITCODE"; exit 1 }
} catch {
    Write-Warning "hook ${name} failed: $($_.Exception.Message)"
    exit 1
}
exit 0
