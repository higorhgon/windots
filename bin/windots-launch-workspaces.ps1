# windots-launch-workspaces [--config <file>] [--dry-run] [--wait]
# windots:summary=Open the apps listed in workspaces.json, each in its komorebi workspace
# windots:args=[--config <file>] [--dry-run] [--wait]
# windots:examples=windots launch workspaces | windots launch workspaces --dry-run | windots launch workspaces --wait
#
# komorebi never opens apps. This opens the ones listed in ~\.config\windots\workspaces.json and
# puts each window on its workspace, like Hyprland's `exec-once = [workspace 2 silent; float;
# size 900 600; move 100 100] app`. The file stays on this machine (not in the repo: the apps of one machine must not open
# on another; an example is in default\komorebi\workspaces.example.json). It is a list; each entry:
#   "workspace"  1-10, the number of Alt+number (required)
#   "monitor"    1 = the first (default)
#   "command"    what to run: a program on PATH or a full path; %VARIABLES% are expanded (required)
#   "args"       a list of arguments for it (optional)
#   "match"      how to recognize its window: {"exe": "msedge.exe"}, or {"class": "..."} or
#                {"title": "..."} (exact text) (required)
#   "silent"     true (default): the focus goes back to where it was, so you are not thrown to
#                the new window's workspace; false: you land on it
#   "float"      true: the window opens floating (only this launch floats)
#   "size"       [width, height]: pixels (scaled by the screen's DPI) or percent of the monitor's
#                work area, e.g. [1200, 800] or ["60%", "70%"]; floating windows only
#   "position"   "center", or [x, y] from the work area's top-left, pixels or percent; floating only
#   "delay"      seconds to wait before opening it
#   "wait"       seconds to wait for its window (default 15)
#   "machines"   only on these computer names (default: every machine)
# How: the app opens, komorebi picks the window up on the workspace you are on, and it is sent to
# its workspace with `komorebic send-to-monitor-workspace` (so it may show for an instant where you
# are). No komorebi rule is registered: a rule would stay and move every later window of that app,
# and komorebi has no way to remove just one.
# An app already open (a window that matches) is left alone, so running this again, or after
# komorebi restarts, only opens what is missing.
#   --config <file>   another file (also --config=<file>)   --dry-run   show what would happen
#   --wait            wait up to 2 minutes for komorebi to be up (what the startup shortcut uses)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$config = Join-Path $HOME '.config\windots\workspaces.json'
$dryRun = $false; $waitKomorebi = $false
$cli = @($args)
for ($i = 0; $i -lt $cli.Count; $i++) {
    $a = [string]$cli[$i]
    if ($a -eq '--config') {
        $i++
        if ($i -ge $cli.Count) { Write-Host '--config needs a file' -ForegroundColor Red; exit 2 }
        $config = [string]$cli[$i]
    } elseif ($a -like '--config=*') {
        $config = $a.Substring(9)
        # PowerShell cuts --config=C:\x at the colon into "--config=C" and "\x": join them again.
        if ($config -match '^[A-Za-z]$' -and $i + 1 -lt $cli.Count -and ([string]$cli[$i + 1]) -match '^[\\/]') { $i++; $config = "${config}:" + $cli[$i] }
    }
    elseif ($a -eq '--dry-run') { $dryRun = $true }
    elseif ($a -eq '--wait') { $waitKomorebi = $true }
    else { Write-Host "unknown option: $a (see windots launch workspaces --help)" -ForegroundColor Red; exit 2 }
}

if (-not (Test-Path $config)) { Write-Host "  - no ${config}: nothing to open"; return }
try { $entries = @(Get-Content -Raw -Encoding UTF8 $config | ConvertFrom-Json | ForEach-Object { $_ }) }   # 5.1 hands a JSON list over as one object: unroll it
catch { Write-Host "$config is not valid JSON: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
if (-not $entries.Count -or ($entries.Count -eq 1 -and -not $entries[0])) { Write-Host '  - workspaces.json is empty: nothing to open'; return }

# Entries that are wrong are reported and skipped; the others still run.
$todo = @()
$n = 0
foreach ($e in $entries) {
    $n++
    $problem = $null
    if (-not $e.workspace -or [int]$e.workspace -lt 1) { $problem = 'needs a "workspace" (1, 2, ...)' }
    elseif (-not $e.command) { $problem = 'needs a "command"' }
    elseif (-not $e.match -or -not (@($e.match.PSObject.Properties | Where-Object { 'exe', 'class', 'title' -contains $_.Name -and $_.Value }))) { $problem = 'needs a "match" with exe, class or title' }
    if ($problem) { Write-Warning "entry $n ${problem}: skipped"; continue }
    if ($e.machines -and (@($e.machines) -notcontains $env:COMPUTERNAME)) { continue }   # -contains ignores case
    $todo += , $e
}
if (-not $todo.Count) { Write-Host '  - nothing for this machine'; return }

$komorebic = (Get-Command komorebic.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $komorebic) { Write-Host 'komorebi is not installed: run windots reinstall pkgs' -ForegroundColor Yellow; exit 1 }

function Test-KomorebiUp { $null = & $komorebic state 2>&1; $LASTEXITCODE -eq 0 }
$deadline = (Get-Date).AddSeconds($(if ($waitKomorebi) { 120 } else { 0 }))
while (-not (Test-KomorebiUp)) {
    if ((Get-Date) -ge $deadline) { Write-Host 'komorebi is not running: start it, or use --wait' -ForegroundColor Yellow; exit 1 }
    Start-Sleep -Seconds 2
}

Add-Type -Namespace Windots -Name Ws -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public int dwFlags; }
[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
[DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
[DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT r, int size);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
'@

# Every window komorebi manages: where it is (monitor and workspace, from 0) and whether it floats.
function Get-KomorebiWindows {
    $state = & $komorebic state | ConvertFrom-Json
    $mi = 0
    foreach ($m in $state.monitors.elements) {
        $wi = 0
        foreach ($ws in $m.workspaces.elements) {
            foreach ($w in @($ws.floating_windows.elements)) { if ($w) { [pscustomobject]@{ Hwnd = [long]$w.hwnd; Exe = $w.exe; Class = $w.class; Title = $w.title; Monitor = $mi; Workspace = $wi; Floating = $true } } }
            foreach ($c in @($ws.containers.elements)) { foreach ($w in @($c.windows.elements)) { if ($w) { [pscustomobject]@{ Hwnd = [long]$w.hwnd; Exe = $w.exe; Class = $w.class; Title = $w.title; Monitor = $mi; Workspace = $wi; Floating = $false } } } }
            $wi++
        }
        $mi++
    }
}
function Get-Kind($match) {
    foreach ($k in 'exe', 'class', 'title') { if ($match.$k) { return @($k, [string]$match.$k) } }
}
function Test-Window($w, $kind, $id) {
    switch ($kind) { 'exe' { $w.Exe -ieq $id } 'class' { $w.Class -ieq $id } 'title' { $w.Title -ieq $id } }
}
function Set-Foreground([IntPtr]$h) {
    if (-not [Windots.Ws]::IsWindow($h)) { return }
    # A tap of Alt lets this process take the foreground (Windows foreground lock).
    [Windots.Ws]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [Windots.Ws]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [void][Windots.Ws]::SetForegroundWindow($h)
}
# 800 (px, scaled by DPI) or "60%" (of $total) to pixels.
function Convert-Length($v, $total, $scale) {
    if ($v -is [string] -and $v -match '^\s*(\d+(\.\d+)?)\s*%\s*$') { return [int]($total * [double]$Matches[1] / 100) }
    [int]([double]$v * $scale)
}
function Get-QueryIndex($what) { $o = & $komorebic query $what 2>&1 | Select-Object -First 1; $v = 0; if ([int]::TryParse(([string]$o).Trim(), [ref]$v)) { $v } else { -1 } }

# komorebi only has a *toggle* for float override: one floating launch at a time (the same lock as
# windots-launch-float), and every flip is checked against the current state.
$mutex = New-Object Threading.Mutex($false, 'Local\windots-launch-float')

# Silent: give the focus back to where it was. Not silent: go to the new window. Reads the loop's variables.
function Restore-Focus($window) {
    if ($silent -or -not $window) {
        if ($focusMonitor -ge 0 -and $focusWorkspace -ge 0) { & $komorebic focus-monitor-workspace $focusMonitor $focusWorkspace 2>&1 | Out-Null }
        Set-Foreground $focusHwnd
    } else {
        & $komorebic focus-monitor-workspace $monitor $workspace 2>&1 | Out-Null
        Set-Foreground ([IntPtr]$window.Hwnd)
    }
}

$opened = 0; $skipped = 0; $failed = 0
foreach ($e in $todo) {
    $kind, $id = Get-Kind $e.match
    $monitor = if ($e.monitor) { [int]$e.monitor - 1 } else { 0 }
    $workspace = [int]$e.workspace - 1
    $silent = if ($null -ne $e.silent) { [bool]$e.silent } else { $true }
    $float = [bool]$e.float
    $waitSec = if ($e.wait) { [int]$e.wait } else { 15 }
    $exe = [Environment]::ExpandEnvironmentVariables([string]$e.command)
    $cmdArgs = @($e.args | Where-Object { $null -ne $_ } | ForEach-Object { [Environment]::ExpandEnvironmentVariables([string]$_) })
    $label = "workspace $($e.workspace): $exe"

    $before = @(Get-KomorebiWindows)
    $running = $before | Where-Object { Test-Window $_ $kind $id } | Select-Object -First 1
    if ($running) { Write-Host "  - $label already open (workspace $($running.Workspace + 1)): left alone"; $skipped++; continue }

    if ($dryRun) {
        $how = @(); if ($silent) { $how += 'silent' }; if ($float) { $how += 'float' }
        if ($e.size) { $how += "size $($e.size -join ' x ')" }; if ($e.position) { $how += "position $($e.position -join ', ')" }
        Write-Host "  - would open $label on monitor $($monitor + 1) [$kind=$id] $($how -join ', ')"
        continue
    }

    if ($e.delay) { Start-Sleep -Seconds ([double]$e.delay) }

    # Where the focus is now, to give it back.
    $focusMonitor = Get-QueryIndex 'focused-monitor-index'
    $focusWorkspace = Get-QueryIndex 'focused-workspace-index'
    $focusHwnd = [Windots.Ws]::GetForegroundWindow()

    $overrideOn = $false
    $owned = $false
    if ($float) {
        try { $owned = $mutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $owned = $true }
        $state = & $komorebic state | ConvertFrom-Json
        if (-not [bool]$state.float_override) {
            & $komorebic toggle-float-override; $overrideOn = $true
            # komorebi takes the toggle from its socket a moment later: opening the app now could
            # beat it, and the window would be tiled. Wait until the state says it is on.
            $until = (Get-Date).AddSeconds(3)
            while (-not [bool]((& $komorebic state | ConvertFrom-Json).float_override) -and (Get-Date) -lt $until) { Start-Sleep -Milliseconds 80 }
        }
    }
    $new = $null
    try {
        try {
            if ($cmdArgs.Count) { Start-Process -FilePath $exe -ArgumentList $cmdArgs } else { Start-Process -FilePath $exe }
        } catch { Write-Warning "$label did not start: $($_.Exception.Message)"; $failed++; Restore-Focus $null; continue }
        $until = (Get-Date).AddSeconds($waitSec)
        while (-not $new -and (Get-Date) -lt $until) {
            Start-Sleep -Milliseconds 200
            $new = Get-KomorebiWindows | Where-Object { (Test-Window $_ $kind $id) -and ($before.Hwnd -notcontains $_.Hwnd) } | Select-Object -First 1
        }
    } finally {
        if ($overrideOn) { $s = & $komorebic state | ConvertFrom-Json; if ([bool]$s.float_override) { & $komorebic toggle-float-override } }
        if ($owned) { $mutex.ReleaseMutex() }
    }
    if (-not $new) {
        Write-Warning "${label}: komorebi saw no window matching $kind=$id in ${waitSec}s (is the app one komorebi ignores?)"
        $failed++; Restore-Focus $null; continue
    }
    $h = [IntPtr]$new.Hwnd

    # To its workspace. send-to-monitor-workspace moves the FOCUSED window, so the new one is
    # focused and checked first: never move whatever else happens to be in front.
    if ($new.Monitor -ne $monitor -or $new.Workspace -ne $workspace) {
        $focused = $false
        foreach ($try in 1..10) {
            Set-Foreground $h
            Start-Sleep -Milliseconds 150
            if ([Windots.Ws]::GetForegroundWindow() -eq $h) { $focused = $true; break }
        }
        if ($focused) {
            & $komorebic send-to-monitor-workspace $monitor $workspace 2>&1 | Out-Null
            $until = (Get-Date).AddSeconds(3)
            do {
                Start-Sleep -Milliseconds 150
                $now = Get-KomorebiWindows | Where-Object { $_.Hwnd -eq $new.Hwnd } | Select-Object -First 1
            } while ($now -and ($now.Monitor -ne $monitor -or $now.Workspace -ne $workspace) -and (Get-Date) -lt $until)
            if ($now) { $new = $now }
        } else {
            Write-Warning "$label opened but could not be focused, so it was not moved (it stays on workspace $($new.Workspace + 1))"
        }
    }

    # Floating geometry, like Hyprland's size / move, on the work area of the window's monitor.
    if ($float -and $new.Floating -and ($e.size -or $e.position)) {
        $info = New-Object Windots.Ws+MONITORINFO
        $info.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($info)
        [void][Windots.Ws]::GetMonitorInfo([Windots.Ws]::MonitorFromWindow($h, 2), [ref]$info)
        $scale = [Windots.Ws]::GetDpiForWindow($h) / 96
        $work = $info.rcWork; $ww = $work.Right - $work.Left; $wh = $work.Bottom - $work.Top
        # What you see is smaller than the window rectangle (Windows 11 windows have invisible resize
        # borders), so the rectangle is widened by those borders: size and position are the visible ones.
        $win = New-Object Windots.Ws+RECT; $vis = New-Object Windots.Ws+RECT
        [void][Windots.Ws]::GetWindowRect($h, [ref]$win)
        $il = 0; $it = 0; $ir = 0; $ib = 0
        if ([Windots.Ws]::DwmGetWindowAttribute($h, 9, [ref]$vis, 16) -eq 0) {   # 9 = DWMWA_EXTENDED_FRAME_BOUNDS
            $il = $vis.Left - $win.Left; $it = $vis.Top - $win.Top; $ir = $win.Right - $vis.Right; $ib = $win.Bottom - $vis.Bottom
        } else { $vis = $win }
        $cx = $vis.Right - $vis.Left; $cy = $vis.Bottom - $vis.Top   # the current size, for "center" without a size
        $flags = 0x0004 -bor 0x0010   # NOZORDER | NOACTIVATE
        if ($e.size) { $cx = Convert-Length @($e.size)[0] $ww $scale; $cy = Convert-Length @($e.size)[1] $wh $scale } else { $flags = $flags -bor 0x0001 }   # NOSIZE
        $x = 0; $y = 0
        if ($e.position) {
            if ($e.position -is [string] -and $e.position -ieq 'center') {
                $x = $work.Left + [int](($ww - $cx) / 2); $y = $work.Top + [int](($wh - $cy) / 2)
            } else {
                $x = $work.Left + (Convert-Length @($e.position)[0] $ww $scale); $y = $work.Top + (Convert-Length @($e.position)[1] $wh $scale)
            }
        } else { $flags = $flags -bor 0x0002 }   # NOMOVE
        [void][Windots.Ws]::SetWindowPos($h, [IntPtr]::Zero, $x - $il, $y - $it, $cx + $il + $ir, $cy + $it + $ib, $flags)
    } elseif ($float -and -not $new.Floating) {
        Write-Warning "$label opened but is not floating (komorebi tiled it): size and position skipped"
    }

    if ($new.Monitor -ne $monitor -or $new.Workspace -ne $workspace) {
        Write-Warning "$label is on workspace $($new.Workspace + 1), not $($e.workspace)"
    }

    Restore-Focus $new
    Write-Host "  - opened $label (workspace $($new.Workspace + 1)$(if ($new.Floating) { ', floating' }))"
    $opened++
}
$mutex.Dispose()
if (-not $dryRun) { Write-Host ("  {0} opened, {1} already open, {2} failed" -f $opened, $skipped, $failed) }
