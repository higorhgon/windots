# windots-center-switcher
# windots:summary=Center komorebi-switcher in the taskbar of every monitor
# windots:args=[--wait]
# windots:examples=windots center switcher | windots center switcher --wait
#
# Centers komorebi-switcher in the taskbar of every monitor of this machine.
# komorebi-switcher keys its position by monitor id ([monitors."<id>"] in
# ~/.config/komorebi-switcher.toml) and has no "center" option, so this measures
# each taskbar and the running switcher (DPI included) and writes x / y / height.
# Sections for monitors of other machines are kept, so one file serves all of them.
# komorebi and komorebi-switcher must be running (both start at login). Nothing is rewritten
# (and the switcher is not restarted) when the file is already right.
#   windots-center-switcher          # measure what is running now
#   windots-center-switcher --wait   # wait for them to start (used by the login shortcut)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$tomlPath = Join-Path $HOME '.config\komorebi-switcher.toml'

Add-Type -Namespace Windots -Name Switcher -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hwnd);
[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
'@
function Get-Class([IntPtr]$h) { $sb = New-Object Text.StringBuilder 256; [void][Windots.Switcher]::GetClassName($h, $sb, 256); $sb.ToString() }
function Get-Rect([IntPtr]$h) { $r = New-Object Windots.Switcher+RECT; [void][Windots.Switcher]::GetWindowRect($h, [ref]$r); $r }

function Measure-Sections {
    # Taskbars (primary + secondary) and the switcher host inside each.
    $taskbars = New-Object System.Collections.Generic.List[object]
    [void][Windots.Switcher]::EnumWindows({ param($h, $l)
        $c = Get-Class $h
        if ($c -eq 'Shell_TrayWnd' -or $c -eq 'Shell_SecondaryTrayWnd') {
            $found = New-Object System.Collections.Generic.List[IntPtr]
            [void][Windots.Switcher]::EnumChildWindows($h, { param($ch, $l2)
                if ((Get-Class $ch) -eq 'komorebi-switcher::host' -and [Windots.Switcher]::GetParent($ch) -eq $h) { $found.Add($ch) }
                $true }, [IntPtr]::Zero)
            $hostHwnd = if ($found.Count) { $found[0] } else { [IntPtr]::Zero }
            $taskbars.Add([pscustomobject]@{ Hwnd = $h; Rect = (Get-Rect $h); Host = $hostHwnd })
        }
        $true }, [IntPtr]::Zero)
    $result = @{ Sections = [ordered]@{}; Missing = 0; Lines = @() }
    if (-not $taskbars.Count -or -not (Get-Command komorebic -ErrorAction SilentlyContinue)) { $result.Missing = 1; return $result }
    $monitors = @(try { komorebic monitor-information 2>$null | ConvertFrom-Json } catch { })
    if (-not $monitors.Count) { $result.Missing = 1; return $result }
    foreach ($m in $monitors) {
        $id = if ($m.serial_number_id) { $m.serial_number_id } elseif ($m.device_id) { $m.device_id } else { $m.name }
        $cx = ($m.size.left + $m.size.right) / 2
        $tb = $taskbars | Where-Object { $cx -ge $_.Rect.Left -and $cx -lt $_.Rect.Right -and
            $_.Rect.Top -ge $m.size.top -and $_.Rect.Bottom -le $m.size.bottom } | Select-Object -First 1
        if (-not $tb -or $tb.Host -eq [IntPtr]::Zero) { $result.Missing++; continue }

        $scale = [Windots.Switcher]::GetDpiForWindow($tb.Hwnd) / 96
        $tbW = $tb.Rect.Right - $tb.Rect.Left; $tbH = $tb.Rect.Bottom - $tb.Rect.Top
        $hostW = (Get-Rect $tb.Host).Right - (Get-Rect $tb.Host).Left
        $contentH = [int][Math]::Ceiling(44 * $scale)        # 8px padding + 28px buttons + 8px padding
        $result.Sections[$id] = [ordered]@{
            auto_width = 'true'; auto_height = 'false'
            x = [int](($tbW - $hostW) / 2); y = [int](($tbH - $contentH) / 2)
            width = $hostW; height = $contentH
        }
        $result.Lines += ("  - {0}: taskbar {1}x{2}, switcher {3}px at {4:P0} -> x={5} y={6}" -f $id, $tbW, $tbH, $hostW, $scale, $result.Sections[$id].x, $result.Sections[$id].y)
    }
    $result
}

# --wait: at login komorebi and the switcher are still starting; wait until every monitor
# has its switcher (up to 2 minutes). Without it, measure once with what is running.
$deadline = (Get-Date).AddSeconds($(if ($args -contains '--wait') { 120 } else { 0 }))
do {
    $r = Measure-Sections
    if (-not $r.Missing) { break }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)
$sections = $r.Sections
$r.Lines | ForEach-Object { Write-Host $_ }
if ($r.Missing) { Write-Warning 'komorebi or komorebi-switcher is not running on every monitor; start them (or log in again) and run windots-center-switcher' }
if (-not $sections.Count) { return }

# Rewrite the toml: global lines as they are, other machines' monitor sections kept,
# this machine's sections replaced.
$global = New-Object System.Collections.Generic.List[string]
$others = [ordered]@{}; $current = $null
foreach ($line in (Get-Content $tomlPath -ErrorAction SilentlyContinue)) {
    if ($line -match '^\[monitors\."?([^"\]]+)"?\]') { $current = $Matches[1]; if (-not $sections.Contains($current)) { $others[$current] = New-Object System.Collections.Generic.List[string]; $others[$current].Add($line) }; continue }
    if ($null -eq $current) { $global.Add($line) }
    elseif ($others.Contains($current)) { $others[$current].Add($line) }
}
$out = New-Object System.Collections.Generic.List[string]
$global | ForEach-Object { $out.Add($_) }
while ($out.Count -and -not $out[$out.Count - 1].Trim()) { $out.RemoveAt($out.Count - 1) }
foreach ($id in $others.Keys) { $out.Add(''); $others[$id] | Where-Object { $_.Trim() } | ForEach-Object { $out.Add($_) } }
foreach ($id in $sections.Keys) {
    $out.Add(''); $out.Add("[monitors.`"$id`"]")
    foreach ($k in $sections[$id].Keys) { $out.Add(('{0,-11} = {1}' -f $k, $sections[$id][$k])) }
}
# WriteAllText follows the tuckr symlink, so the repo copy is what gets updated.
$newText = ($out -join "`n") + "`n"
$oldText = if (Test-Path $tomlPath) { [IO.File]::ReadAllText($tomlPath) -replace "`r`n", "`n" } else { '' }
if ($oldText -eq $newText) { Write-Host '  already centered'; return }
[IO.File]::WriteAllText($tomlPath, $newText, (New-Object Text.UTF8Encoding $false))

# It reads its toml only when it starts.
& (Join-Path $PSScriptRoot 'windots-restart-komorebi-switcher.ps1')
