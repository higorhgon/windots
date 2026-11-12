# windots-launch-or-focus [--float] <focus> [command] [args...]
#
# Like omarchy's { launch = ..., float = ..., focus = "^(app)$" }:
# focus the first window whose exe (without .exe) or title matches the regex
# <focus> (case-insensitive), switching to its komorebi workspace; otherwise
# launch [command] (default: <focus>, for a plain name).
# Anchor the regex (^...$) so a browser tab named "user/app" doesn't match.
#   --float  launch through windots-launch-float (floating, centered, shared size).
#
#   windots-launch-or-focus --float '^(omapass)$' "$env:LOCALAPPDATA\Programs\omapass\omapass.exe"
#   windots-launch-or-focus-tui --float btop   (TUIs: see windots-launch-or-focus-tui)

# Plain $args (no param block): flags like -w must reach the command, not this script.
$rest = [Collections.Generic.List[object]]@($args)
$float = $false
if ($rest.Count -and $rest[0] -eq '--float') { $float = $true; $rest.RemoveAt(0) }
if (-not $rest.Count) { throw 'usage: windots-launch-or-focus [--float] <focus-regex> [command] [args...]' }
$focus = [string]$rest[0]
# @(...) around the if: a one-item result must stay an array, or @command splats its characters.
$command = @(if ($rest.Count -gt 1) { $rest | Select-Object -Skip 1 } else { $focus })

Add-Type -Namespace Windots -Name Focus -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
'@

function Set-Foreground([IntPtr]$h) {
    if ([Windots.Focus]::IsIconic($h)) { [void][Windots.Focus]::ShowWindow($h, 9) }  # SW_RESTORE
    # A tap of Alt lets this process take the foreground (Windows foreground lock).
    [Windots.Focus]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [Windots.Focus]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [void][Windots.Focus]::SetForegroundWindow($h)
}

function Test-Match([string]$exe, [string]$title) {
    ([IO.Path]::GetFileNameWithoutExtension($exe) -match $focus) -or ($title -match $focus)
}

# 1. A window komorebi knows about (tiled or floating, any workspace).
$state = komorebic state | ConvertFrom-Json
$mi = 0
foreach ($m in $state.monitors.elements) {
    $wi = 0
    foreach ($ws in $m.workspaces.elements) {
        $windows = @($ws.floating_windows.elements) + @($ws.containers.elements | ForEach-Object { $_.windows.elements })
        $hit = $windows | Where-Object { $_ -and (Test-Match $_.exe $_.title) } | Select-Object -First 1
        if ($hit) {
            komorebic focus-monitor-workspace $mi $wi
            Set-Foreground ([IntPtr][long]$hit.hwnd)
            return
        }
        $wi++
    }
    $mi++
}

# 2. A window komorebi doesn't manage (ignored apps).
$proc = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and (Test-Match $_.ProcessName $_.MainWindowTitle) } |
    Select-Object -First 1
if ($proc) { Set-Foreground $proc.MainWindowHandle; return }

# 3. Not running: launch it.
$exe, $cmdArgs = $command
$cmd = Get-Command $exe -ErrorAction SilentlyContinue
if ($float) { & (Join-Path $PSScriptRoot 'windots-launch-float.ps1') @command }
elseif ($cmd.CommandType -eq 'ExternalScript') { & $cmd.Source @cmdArgs }   # e.g. windots-launch-tui
elseif ($cmdArgs) { Start-Process -FilePath $exe -ArgumentList $cmdArgs }
else { Start-Process -FilePath $exe }
