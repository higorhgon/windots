Write-Host 'Remove the Windows themes and recent images that windots-install-backgrounds added'

# Runs once per machine (windots migrate), in Windows PowerShell 5.1, with the repo in
# $env:WINDOTS_PATH. Write it to be safe to run again: a failure means it runs again next time.
$ErrorActionPreference = 'Stop'

# The script that listed the windots backgrounds in Settings > Personalization is gone (the
# windots-launcher picks the background now): its "windots <theme>" slideshow themes ...
$themes = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes'
Get-ChildItem $themes -Filter 'windots-*.theme' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Force
    Write-Host "  - removed theme $($_.Name)"
}

# ... and the "recent images" it put in Settings > Personalization > Background (only those from its folder).
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
if (Test-Path $key) {
    $props = Get-ItemProperty $key
    foreach ($name in (Get-Item $key).GetValueNames() | Where-Object { $_ -like 'BackgroundHistoryPath*' }) {
        if ($props.$name -match '\\\.config\\windots\\backgrounds\\') {
            Remove-ItemProperty -Path $key -Name $name
            Write-Host "  - removed recent image $name"
        }
    }
}