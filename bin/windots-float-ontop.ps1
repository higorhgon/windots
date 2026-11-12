# Keep komorebi's floating windows above tiled ones.
#
# Subscribes to komorebi events through a named pipe; every event carries the full
# state, so on each one: floating windows become always-on-top (HWND_TOPMOST) and
# windows that went back to tiling lose it. Reconnects when komorebi restarts.
# Started hidden at login (shortcut made by windots-refresh-autostart).

$ErrorActionPreference = 'Stop'
$pipeName = 'komorebi-float-ontop'
$komorebic = Join-Path $env:ProgramFiles 'komorebi\bin\komorebic.exe'

Add-Type -Namespace KFO -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
'@
$TOPMOST = [IntPtr]-1; $NOTOPMOST = [IntPtr]-2
$FLAGS = 0x0001 -bor 0x0002 -bor 0x0010   # SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE

$onTop = [Collections.Generic.HashSet[long]]::new()

function Update-OnTop($state) {
    $floating = [Collections.Generic.HashSet[long]]::new()
    foreach ($m in $state.monitors.elements) {
        foreach ($w in $m.workspaces.elements) {
            foreach ($f in $w.floating_windows.elements) { [void]$floating.Add([long]$f.hwnd) }
        }
    }
    foreach ($h in $floating) {
        if ($onTop.Add($h)) { [void][KFO.Win32]::SetWindowPos([IntPtr]$h, $TOPMOST, 0, 0, 0, 0, $FLAGS) }
    }
    foreach ($h in @($onTop)) {
        if (-not $floating.Contains($h)) {
            if ([KFO.Win32]::IsWindow([IntPtr]$h)) {
                [void][KFO.Win32]::SetWindowPos([IntPtr]$h, $NOTOPMOST, 0, 0, 0, 0, $FLAGS)
            }
            [void]$onTop.Remove($h)
        }
    }
}

while ($true) {
    $server = $null
    try {
        $server = [IO.Pipes.NamedPipeServerStream]::new($pipeName, [IO.Pipes.PipeDirection]::In, 1,
            [IO.Pipes.PipeTransmissionMode]::Byte, [IO.Pipes.PipeOptions]::Asynchronous)
        & $komorebic subscribe-pipe $pipeName 2>$null
        $connect = $server.WaitForConnectionAsync()
        if (-not $connect.Wait(5000)) { throw 'komorebi did not connect' }
        $reader = [IO.StreamReader]::new($server)
        while ($null -ne ($line = $reader.ReadLine())) {
            if (-not $line) { continue }
            try { Update-OnTop ($line | ConvertFrom-Json).state } catch { }
        }
    } catch {
        # komorebi not running yet, or it restarted: retry below
    } finally {
        if ($server) { $server.Dispose() }
    }
    Start-Sleep -Seconds 3
}
