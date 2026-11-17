# windots-install-terminal <ghostty|windows-terminal> [--close] [--keep-default]
# windots:summary=Install a terminal (or update Ghostty) and make it the default
# windots:args=<ghostty | windows-terminal> [--close] [--keep-default]
# windots:examples=windots install terminal ghostty | windots install terminal windows-terminal
#
# Like omarchy-install-terminal: installs one of the terminals windots supports and makes it the
# default one (windots-default-terminal: Win+Enter, TUIs, the launcher).
#   ghostty            Ghostty for Windows, the newest release of github.com/higorhgon/ghostty: its
#                      setup.exe (SHA-256 checked) installs it for this user, no UAC, in
#                      %LOCALAPPDATA%\Programs\Ghostty. Run again to update it.
#   windows-terminal   Windows Terminal (winget Microsoft.WindowsTerminal); Windows 11 already has it.
#   --close            Ghostty open: let the installer close it (and reopen it). Without it an open
#                      Ghostty is not updated: this may be running inside it.
#   --keep-default     install or update only; the default terminal stays as it is (windots-update)
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\terminal.ps1')

$name = $null; $close = $false; $keepDefault = $false
foreach ($a in $args) {
    if ($a -eq '--close') { $close = $true }
    elseif ($a -eq '--keep-default') { $keepDefault = $true }
    elseif (-not $name -and $WindotsTerminals.Contains([string]$a)) { $name = [string]$a }
    else { Write-Host "unknown option: $a (see windots install terminal --help)" -ForegroundColor Red; exit 2 }
}
if (-not $name) { Write-Host "usage: windots-install-terminal <$($WindotsTerminals.Keys -join '|')>" -ForegroundColor Red; exit 2 }

function Step($msg) { Write-Host "  - $msg" }

if ($name -eq 'windows-terminal') {
    if (Get-WindowsTerminalExe) { Step 'Windows Terminal is already installed' }
    else {
        Step 'installing Windows Terminal with winget'
        winget install --id Microsoft.WindowsTerminal --exact --source winget --silent --disable-interactivity `
            --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0 -and -1978335189, -1978335135 -notcontains $LASTEXITCODE) {
            Write-Host ('winget could not install Windows Terminal (exit 0x{0:X8})' -f $LASTEXITCODE) -ForegroundColor Red; exit 1
        }
    }
}

if ($name -eq 'ghostty') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    try { $all = @(Invoke-RestMethod -Uri $GhosttyReleasesApi -Headers @{ 'User-Agent' = 'windots' }) }
    catch { Write-Host "could not reach GitHub: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
    $release = $null; $asset = $null
    foreach ($r in @($all | ForEach-Object { $_ })) {
        if ($r.draft -or $r.prerelease -or $r.tag_name -notlike 'windows-v*') { continue }
        $asset = @($r.assets | Where-Object { $_.name -like '*-x64-setup.exe' })[0]
        if ($asset) { $release = $r; break }
    }
    if (-not $release) { Write-Host 'no Ghostty release with a setup.exe on github.com/higorhgon/ghostty' -ForegroundColor Red; exit 1 }
    $latest = $release.tag_name.Substring(9)   # windows-v1.4.1.5
    $installed = Get-GhosttyVersion

    if ($installed -and ([version]$installed -ge [version]$latest)) {
        Step "Ghostty $installed is up to date"
    } elseif ($installed -and (Get-Process ghostty -ErrorAction SilentlyContinue) -and -not $close) {
        Write-Host "  - Ghostty $latest is out ($installed here), but Ghostty is open: close it and run" -ForegroundColor Yellow
        Write-Host '    windots install terminal ghostty   (or add --close to let the installer close it)' -ForegroundColor Yellow
    } else {
        $digest = [string]$asset.digest
        if ($digest -notlike 'sha256:*') { Write-Host "the release has no SHA-256 for $($asset.name): not installing it" -ForegroundColor Red; exit 1 }
        $dir = Join-Path ([IO.Path]::GetTempPath()) "windots-ghostty-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory $dir | Out-Null
        try {
            $setup = Join-Path $dir $asset.name
            Step "downloading Ghostty $latest"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $setup -UseBasicParsing
            $hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
            if ($hash -ne $digest.Substring(7).ToLower()) { Write-Host "SHA-256 mismatch for $($asset.name): not installing it" -ForegroundColor Red; exit 1 }
            Step $(if ($installed) { "updating Ghostty $installed -> $latest" } else { "installing Ghostty $latest (for this user, no UAC)" })
            $p = Start-Process -FilePath $setup -Wait -PassThru -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', '/LANG=brazilianportuguese'
            if ($p.ExitCode -ne 0) { Write-Host "the Ghostty installer failed (exit $($p.ExitCode))" -ForegroundColor Red; exit 1 }
        } finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
        if (-not (Get-GhosttyExe)) { Write-Host 'Ghostty was installed but ghostty.exe is not where expected' -ForegroundColor Red; exit 1 }
        Step "Ghostty $(Get-GhosttyVersion) in $(Split-Path (Split-Path (Get-GhosttyExe)))"
    }
}

if (-not $keepDefault) { & (Join-Path $PSScriptRoot 'windots-default-terminal.ps1') $name }
