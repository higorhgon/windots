# windots-install-backgrounds
# windots:summary=List the windots backgrounds in Settings > Personalization
#
# Lists the windots backgrounds in Settings > Personalization:
#   - Themes: one "windots <name>" theme per folder in ~\.config\windots\backgrounds
#     (like omarchy's ~/.config/omarchy/backgrounds), a slideshow of every image in it
#     (keeps the current dark/light mode and accent color);
#   - Background: up to 5 still images in "Recent images" (the most Windows shows).
# Not in Pictures: OneDrive backs it up (and may redirect it), which conflicts with links.
# Images missing from ~\.config\windots\backgrounds (tuckr not linked yet) are copied there.
# Called by windots-install; safe to run again on its own.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot
$source = Join-Path $Repo 'Configs\backgrounds\.config\windots\backgrounds'
$target = Join-Path $HOME '.config\windots\backgrounds'
$themesDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes'
$images = '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'

if (-not (Test-Path $source)) { throw "no backgrounds in $source" }
New-Item -ItemType Directory -Force $themesDir | Out-Null

# Keep what the person has now: dark/light mode and accent color.
$personalize = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue
$appMode = if ($personalize.AppsUseLightTheme -eq 1) { 'Light' } else { 'Dark' }
$systemMode = if ($personalize.SystemUsesLightTheme -eq 1) { 'Light' } else { 'Dark' }
$accent = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction SilentlyContinue).ColorizationColor
$accentHex = if ($null -ne $accent) { '0X{0:X8}' -f [uint32]($accent -band 0xFFFFFFFF) } else { '0XC40078D4' }

$recent = New-Object System.Collections.Generic.List[string]

foreach ($dir in Get-ChildItem $source -Directory) {
    $name = $dir.Name
    $dest = Join-Path $target $name
    New-Item -ItemType Directory -Force $dest | Out-Null
    $files = Get-ChildItem $dir.FullName -File | Where-Object { $images -contains $_.Extension.ToLower() } | Sort-Object Name
    foreach ($f in $files) {
        $to = Join-Path $dest $f.Name
        if (-not (Test-Path $to)) { Copy-Item $f.FullName $to }
    }
    if (-not $files) { continue }

    # Windows shows only the first frame of a gif: prefer still images.
    $still = @($files | Where-Object { $_.Extension -ne '.gif' })
    foreach ($f in $still) { if ($recent.Count -lt 5) { $recent.Add((Join-Path $dest $f.Name)) } }
    $first = if ($still) { $still[0] } else { $files[0] }

    $theme = @"
[Theme]
DisplayName=windots $name

[Control Panel\Desktop]
Wallpaper=$(Join-Path $dest $first.Name)
TileWallpaper=0
WallpaperStyle=10
Pattern=

[Slideshow]
Interval=1800000
Shuffle=1
ImagesRootPath=$dest

[VisualStyles]
Path=%SystemRoot%\resources\themes\Aero\Aero.msstyles
ColorStyle=NormalColor
Size=NormalSize
AutoColorization=0
ColorizationColor=$accentHex
SystemMode=$systemMode
AppMode=$appMode
VisualStyleVersion=10

[MasterThemeSelector]
MTSM=RJSPBS
"@
    $file = Join-Path $themesDir "windots-$name.theme"
    [IO.File]::WriteAllText($file, $theme, [Text.Encoding]::Unicode)   # .theme files are UTF-16
    Write-Host "  - theme 'windots $name' ($($files.Count) images, slideshow)"
}

# Settings > Personalization > Background > Recent images.
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
for ($i = 0; $i -lt $recent.Count; $i++) {
    Set-ItemProperty -Path $key -Name "BackgroundHistoryPath$i" -Value $recent[$i]
}
Write-Host "  - $($recent.Count) images in Recent images"
