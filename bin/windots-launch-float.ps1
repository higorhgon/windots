# windots-launch-float <command> [args...]
#
# Launch a command whose new window opens floating, centered, at the shared
# floating size (875x600, omarchy's floating-window size, scaled by DPI).
# Only this launch floats: komorebi's float override is switched on just long
# enough for komorebi to pick up the new window.

$Width = 875
$Height = 600

# Plain $args (no param block): flags like -w must reach the command, not this script.
$exe, $rest = $args
if (-not $exe) { throw 'usage: windots-launch-float <command> [args...]' }

Add-Type -Namespace Windots -Name Float -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public int dwFlags; }
[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
[DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
'@

function Get-FloatingWindows {
    $state = komorebic state | ConvertFrom-Json
    $hwnds = foreach ($m in $state.monitors.elements) {
        foreach ($w in $m.workspaces.elements) { foreach ($f in $w.floating_windows.elements) { [long]$f.hwnd } }
    }
    [pscustomobject]@{ Override = [bool]$state.float_override; Hwnds = @($hwnds) }
}

# komorebi only has a *toggle* for float override, so two launches at once could flip
# it twice and leave it on (every new window floating). One floating launch at a time,
# and every flip is checked against the current state.
$mutex = New-Object Threading.Mutex($false, 'Local\windots-launch-float')
try { [void]$mutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { }

$before = Get-FloatingWindows
$new = $null
$weTurnedItOn = $false
if (-not $before.Override) { komorebic toggle-float-override; $weTurnedItOn = $true }
try {
    # A windots script (e.g. windots-launch-tui) runs in-process; anything else is started.
    $cmd = Get-Command $exe -ErrorAction SilentlyContinue
    if ($cmd.CommandType -eq 'ExternalScript') { & $cmd.Source @rest }
    elseif ($rest) { Start-Process -FilePath $exe -ArgumentList $rest } else { Start-Process -FilePath $exe }
    $deadline = (Get-Date).AddSeconds(5)
    while (-not $new -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        $new = (Get-FloatingWindows).Hwnds | Where-Object { $_ -notin $before.Hwnds } | Select-Object -First 1
    }
} finally {
    # Only turn it off if we turned it on and it is still on.
    if ($weTurnedItOn -and (Get-FloatingWindows).Override) { komorebic toggle-float-override }
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
if (-not $new) { return }

# Same size for every floating launch, centered on the window's monitor work area.
$h = [IntPtr]$new
$info = New-Object Windots.Float+MONITORINFO
$info.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($info)
[void][Windots.Float]::GetMonitorInfo([Windots.Float]::MonitorFromWindow($h, 2), [ref]$info)
$scale = [Windots.Float]::GetDpiForWindow($h) / 96
$w = [int]($Width * $scale); $hh = [int]($Height * $scale)
$work = $info.rcWork
$x = $work.Left + [int](($work.Right - $work.Left - $w) / 2)
$y = $work.Top + [int](($work.Bottom - $work.Top - $hh) / 2)
[void][Windots.Float]::SetWindowPos($h, [IntPtr]::Zero, $x, $y, $w, $hh, 0x0004 -bor 0x0010)  # NOZORDER | NOACTIVATE
