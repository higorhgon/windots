# windots-install-launcher [--src <folder>]
# windots:summary=Build and install windots-launcher (the menu and launcher: apps, commands, themes)
# windots:args=[--src <folder>]
# windots:examples=windots install launcher | windots install launcher --src ~/Projetos/windots-launcher
#
# windots-launcher is its own project (default ~\Projetos\windots-launcher, WPF on .NET 9). This builds
# it with `dotnet publish` into ~\.local\share\windots-launcher, which is where windots-menu and the
# Win+Space hotkey look for it. A running launcher is stopped first (its files would be locked); the next
# windots menu / Win+Space starts it again. Needs the .NET 9 SDK.
#   --src <folder>   the project folder, if it is not ~\Projetos\windots-launcher
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'

$src = Join-Path $HOME 'Projetos\windots-launcher'
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($a -eq '--src' -and $i + 1 -lt $args.Count) { $src = [string]$args[++$i] }
    elseif ($a -like '--src=*') { $src = $a.Substring(6) }
    else { Write-Host "unknown option: $a (see windots install launcher --help)" -ForegroundColor Red; exit 2 }
}
$src = $src -replace '^~', $HOME
$proj = Join-Path $src 'src\WindotsLauncher\WindotsLauncher.csproj'
if (-not (Test-Path $proj)) { Write-Host "no windots-launcher project at $src (use --src)" -ForegroundColor Red; exit 1 }
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Write-Host 'the .NET SDK is not installed (winget install Microsoft.DotNet.SDK.9)' -ForegroundColor Red; exit 1 }

$dest = Join-Path $HOME '.local\share\windots-launcher'
$exe = Join-Path $dest 'windots-launcher.exe'
if (Get-Process windots-launcher -ErrorAction SilentlyContinue) {
    if (Test-Path $exe) { & $exe quit }
    foreach ($i in 1..10) { if (-not (Get-Process windots-launcher -ErrorAction SilentlyContinue)) { break }; Start-Sleep -Milliseconds 300 }
    Get-Process windots-launcher -ErrorAction SilentlyContinue | Stop-Process -Force
}

Write-Host "==> Publishing windots-launcher to $dest"
dotnet publish $proj -c Release -o $dest --nologo -v q
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { Write-Host 'dotnet publish failed (above)' -ForegroundColor Red; exit 1 }
Write-Host '  - done: windots menu opens it; Win+Space needs windots restart hotkeys once'
exit 0
