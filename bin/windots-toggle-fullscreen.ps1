# windots-toggle-fullscreen
# windots:summary=Make the focused window fill the monitor, or restore it
#
# Like omarchy's Super+F: the focused window fills the whole monitor, over the taskbar.
# komorebi has no real fullscreen (monocle and maximize keep the taskbar), so:
#   - the window is floated (komorebi stops placing it),
#   - its title bar and frame are removed,
#   - it is sized to the full monitor; Windows hides the taskbar under a foreground
#     window that covers the whole monitor.
# Run again on that window to restore its style, size, position and tiling.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$komorebic = 'komorebic'
$stateFile = Join-Path ([IO.Path]::GetTempPath()) 'windots-fullscreen.json'

Add-Type -Namespace Windots -Name Full -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public int dwFlags; }
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
[DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hwnd, int index);
[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hwnd, int index, int value);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
'@
$GWL_STYLE = -16
$WS_CAPTION = 0x00C00000; $WS_THICKFRAME = 0x00040000
$SWP_FRAMECHANGED = 0x0020; $SWP_NOOWNERZORDER = 0x0200; $SWP_NOZORDER = 0x0004

function Read-State {
    $s = @{}
    if (Test-Path $stateFile) {
        (Get-Content -Raw $stateFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $s[$_.Name] = $_.Value }
    }
    $s
}
function Save-State($s) { ($s | ConvertTo-Json -Depth 4) | Set-Content $stateFile }
function Test-Floating([long]$hwnd) {
    $state = & $komorebic state | ConvertFrom-Json
    foreach ($m in $state.monitors.elements) { foreach ($w in $m.workspaces.elements) {
        foreach ($f in $w.floating_windows.elements) { if ([long]$f.hwnd -eq $hwnd) { return $true } } } }
    $false
}

$h = [Windots.Full]::GetForegroundWindow()
if ($h -eq [IntPtr]::Zero) { return }
$key = ([long]$h).ToString()
$saved = Read-State
foreach ($k in @($saved.Keys)) { if (-not [Windots.Full]::IsWindow([IntPtr][long]$k)) { $saved.Remove($k) } }   # closed windows

if ($saved.ContainsKey($key)) {
    # --- restore ---
    $s = $saved[$key]
    [void][Windots.Full]::SetWindowLong($h, $GWL_STYLE, [int]$s.Style)
    [void][Windots.Full]::SetWindowPos($h, [IntPtr]::Zero, $s.Left, $s.Top, $s.Width, $s.Height, $SWP_FRAMECHANGED -bor $SWP_NOZORDER -bor $SWP_NOOWNERZORDER)
    if (-not $s.WasFloating) { [void][Windots.Full]::SetForegroundWindow($h); & $komorebic toggle-float }   # back to the tiling
    $saved.Remove($key)
    Save-State $saved
    return
}

# --- go fullscreen ---
if ([Windots.Full]::IsZoomed($h)) { [void][Windots.Full]::ShowWindow($h, 9) }   # un-maximize first
$r = New-Object Windots.Full+RECT
[void][Windots.Full]::GetWindowRect($h, [ref]$r)
$style = [Windots.Full]::GetWindowLong($h, $GWL_STYLE)
$wasFloating = Test-Floating ([long]$h)
$saved[$key] = [pscustomobject]@{
    Style = $style; Left = $r.Left; Top = $r.Top; Width = $r.Right - $r.Left; Height = $r.Bottom - $r.Top; WasFloating = $wasFloating
}
Save-State $saved

if (-not $wasFloating) { & $komorebic toggle-float; Start-Sleep -Milliseconds 150 }

$info = New-Object Windots.Full+MONITORINFO
$info.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($info)
[void][Windots.Full]::GetMonitorInfo([Windots.Full]::MonitorFromWindow($h, 2), [ref]$info)
$mon = $info.rcMonitor
[void][Windots.Full]::SetWindowLong($h, $GWL_STYLE, ($style -band (-bnot ($WS_CAPTION -bor $WS_THICKFRAME))))
[void][Windots.Full]::SetWindowPos($h, [IntPtr]::Zero, $mon.Left, $mon.Top, $mon.Right - $mon.Left, $mon.Bottom - $mon.Top,
    $SWP_FRAMECHANGED -bor $SWP_NOOWNERZORDER)
[void][Windots.Full]::SetForegroundWindow($h)
