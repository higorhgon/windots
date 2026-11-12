# windots-toggle-dark-mode [light|dark]
#
# Switch Windows between dark and light mode (apps + taskbar/Start), or set one.
# Writes the registry directly, so it also works when Windows isn't activated
# (Settings > Personalization is locked then), and tells running apps to repaint.
# Works on Windows PowerShell 5.1 and PowerShell 7.

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

$current = (Get-ItemProperty $key -ErrorAction SilentlyContinue).AppsUseLightTheme
$mode = switch ($args[0]) {
    'light' { 'light' }
    'dark' { 'dark' }
    $null { if ($current -eq 0) { 'light' } else { 'dark' } }   # unset means light (Windows default)
    default { throw 'usage: windots-toggle-dark-mode [light|dark]' }
}
$light = [int]($mode -eq 'light')

Set-ItemProperty -Path $key -Name AppsUseLightTheme -Value $light -Type DWord
Set-ItemProperty -Path $key -Name SystemUsesLightTheme -Value $light -Type DWord

# Broadcast WM_SETTINGCHANGE("ImmersiveColorSet") so apps, the taskbar and Start follow now.
Add-Type -Namespace Windots -Name Mode -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam,
    uint flags, uint timeout, out UIntPtr result);
'@
$result = [UIntPtr]::Zero
[void][Windots.Mode]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'ImmersiveColorSet', 0x0002, 1000, [ref]$result)

Write-Host "windows is now in $mode mode"
