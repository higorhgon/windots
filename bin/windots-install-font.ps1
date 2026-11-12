# windots-install-font [--pick | name]
# windots:summary=Install a Nerd Font for the current user
# windots:args=[--pick | <name>]
# windots:examples=windots install font | windots install font JetBrainsMono
#
# Like omarchy-install-font: install a Nerd Font for the current user (no admin),
# from the latest ryanoasis/nerd-fonts release.
#   (nothing)  open the font list as a floating TUI (what Alt+Ctrl+Shift+F runs)
#   --pick     pick one in fzf in the current terminal (what that window runs)
#   name       install it directly, e.g. JetBrainsMono ("JetBrainsMono Nerd Font")
# Installs the regular family (not the Mono / Propo variants); already installed
# files are skipped. windots-install calls it with JetBrainsMono.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'

if (-not $args[0]) {
    & (Join-Path $PSScriptRoot 'windots-launch-or-focus-tui.ps1') --float --title=fonts `
        pwsh -NoProfile -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path --pick
    return
}

$picked = $args[0] -eq '--pick'
$name = if ($picked) { $null } else { $args[0] }

if ($picked) {
    $fzf = (Get-Command fzf -ErrorAction SilentlyContinue).Source
    if (-not $fzf) { $fzf = (mise which fzf 2>$null) }
    if (-not $fzf) { throw 'fzf not found (mise use -g fzf); or pass a font name: windots-install-font JetBrainsMono' }

    $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
    $fonts = $release.assets | Where-Object { $_.name -like '*.zip' -and $_.name -ne 'FontPatcher.zip' } |
        Sort-Object name | ForEach-Object { '{0,-28}{1,6} MB' -f $_.name.Replace('.zip', ''), [math]::Round($_.size / 1MB) }

    $fzfTheme = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\catppuccin-fzf-mocha.ps1'
    if (Test-Path $fzfTheme) { . $fzfTheme }
    $pick = $fonts | & $fzf --layout reverse --border rounded --border-label " Nerd Fonts $($release.tag_name) " `
        --prompt '  ' --header 'Enter installs it   Esc cancels'
    if ($LASTEXITCODE -ne 0 -or -not $pick) { return }
    $name = ($pick -split '\s+')[0]
}
$url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$name.zip"
$fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

$tmp = Join-Path ([IO.Path]::GetTempPath()) "windots-font-$name-$PID"
New-Item -ItemType Directory -Force $tmp | Out-Null
try {
    Write-Host "  - downloading $name Nerd Font"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest $url -OutFile "$tmp\font.zip" -UseBasicParsing
    Expand-Archive "$tmp\font.zip" "$tmp\files" -Force

    $files = Get-ChildItem "$tmp\files" -Recurse -Include '*.ttf', '*.otf' |
        Where-Object { $_.BaseName -match 'NerdFont-' -and $_.BaseName -notmatch 'NerdFont(Mono|Propo)-' }
    if (-not $files) { throw "no Nerd Font files found in $name.zip" }

    New-Item -ItemType Directory -Force $fontsDir | Out-Null
    if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
    Add-Type -Namespace Windots -Name Font -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string file);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
'@

    $installed = 0
    foreach ($f in $files) {
        $dest = Join-Path $fontsDir $f.Name
        if (Test-Path $dest) { continue }
        Copy-Item $f.FullName $dest
        $type = if ($f.Extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
        Set-ItemProperty -Path $regKey -Name "$($f.BaseName) ($type)" -Value $dest
        [void][Windots.Font]::AddFontResource($dest)
        $installed++
    }
    # WM_FONTCHANGE: running apps pick the new fonts up without signing out.
    $r = [UIntPtr]::Zero
    [void][Windots.Font]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$r)
    Write-Host "  - $name Nerd Font: $installed new files ($($files.Count - $installed) already installed)"
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
# Picked from the list (e.g. Alt+Ctrl+Shift+F's floating window): keep the result on screen.
if ($picked) {
    Write-Host "`n  Use it as `"$name Nerd Font`" (or `"$($name)NL Nerd Font`" when there is an NL variant)."
    Read-Host '  Enter to close' | Out-Null
}
