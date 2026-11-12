# Run a command whose new window should open floating and centered, only this time.
# Uses komorebi's float override + "float_override_placement": "Center".
#
#   komorebi-float.ps1 wt -w new --title btop btop

# Plain $args (no param block): flags like -w must reach the command, not this script.
$Command = $args
if (-not $Command) { throw 'usage: komorebi-float.ps1 <command> [args...]' }

function Get-FloatingCount {
    $state = komorebic state | ConvertFrom-Json
    $n = 0
    foreach ($m in $state.monitors.elements) {
        foreach ($w in $m.workspaces.elements) { $n += @($w.floating_windows.elements).Count }
    }
    [pscustomobject]@{ Override = [bool]$state.float_override; Floating = $n }
}

$before = Get-FloatingCount
if (-not $before.Override) { komorebic toggle-float-override }
try {
    $exe, $rest = $Command
    if ($rest) { Start-Process -FilePath $exe -ArgumentList $rest } else { Start-Process -FilePath $exe }
    # wait until komorebi has picked up the new floating window (max 5s)
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline -and (Get-FloatingCount).Floating -le $before.Floating) {
        Start-Sleep -Milliseconds 100
    }
} finally {
    if (-not $before.Override) { komorebic toggle-float-override }
}
