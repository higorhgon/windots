# windots-install-windhawk [--color=#rrggbb] [--check] [--allow-user-settings | --block-user-settings]
# windots:summary=Install Windhawk and its Windows 11 Taskbar Styler mod, set the taskbar colour (no window to click)
# windots:args=[--color=#rrggbb] [--check] [--allow-user-settings | --block-user-settings]
# windots:examples=windots install windhawk | windots install windhawk --color=#1e1e2e | windots install windhawk --check | windots install windhawk --allow-user-settings
#
# Windhawk is the only tool that paints the Windows 11 taskbar a solid colour on this machine
# (TranslucentTB cannot hook the taskbar on this Windows build; the accent palette comes out darker).
# Windhawk has no command line to install a mod, so this does what its window does:
#   1. installs Windhawk with winget when it is missing (its installer asks for UAC)
#   2. downloads the Taskbar Styler mod from mods.windhawk.net (source + precompiled DLL, the same
#      files the window downloads), copies them into C:\ProgramData\Windhawk and registers the mod in
#      HKLM\SOFTWARE\Windhawk\Engine\Mods: this needs admin, so it runs through sudo (one UAC prompt)
#   3. writes the mod settings from default/windhawk/taskbar-styler.json, with {color} replaced
#   4. restarts Windhawk (windhawk.exe -restart -tray-only) so the engine loads the mod
#   --color=#rrggbb   the taskbar colour (default: the one in default/windhawk/taskbar-styler.json)
#   --check           say what is installed and which colour is set; change nothing
#   --allow-user-settings   let this user change the mod's settings without admin (one UAC now, none
#                     when a theme changes the colour later). A deliberate trade-off, never done by
#                     default: any program running as this user could then restyle the taskbar.
#                     --block-user-settings takes the permission back.
# Idempotent: with the same mod version and settings nothing is downloaded or rewritten.
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\elevation.ps1')

$Repo = Split-Path $PSScriptRoot
$data = Get-Content (Join-Path $Repo 'default\windhawk\taskbar-styler.json') -Raw | ConvertFrom-Json
$modId = $data.mod
$exe = Join-Path $env:ProgramFiles 'Windhawk\windhawk.exe'
$regMod = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$modId"
$check = $false; $apply = $false; $color = $data.color; $allow = $false; $block = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($a -eq '--check') { $check = $true }
    elseif ($a -eq '--apply') { $apply = $true }          # internal: the elevated half
    elseif ($a -eq '--allow-user-settings') { $allow = $true }
    elseif ($a -eq '--block-user-settings') { $block = $true }
    elseif ($a -like '--color=*') { $color = $a.Substring(8) }
    else { Write-Host "unknown option: $a (see windots install windhawk --help)" -ForegroundColor Red; exit 2 }
}
if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { Write-Host "--color must look like #1e1e2e, not '$color'" -ForegroundColor Red; exit 2 }
$color = $color.ToLower()

# the settings the mod gets, as the flat name = value pairs Windhawk keeps in the registry
function Get-ModSettings {
    $s = [ordered]@{ theme = ''; 'styleConstants[0]' = '' }
    for ($i = 0; $i -lt @($data.controlStyles).Count; $i++) {
        $c = @($data.controlStyles)[$i]
        $s["controlStyles[$i].target"] = [string]$c.target
        for ($j = 0; $j -lt @($c.styles).Count; $j++) { $s["controlStyles[$i].styles[$j]"] = ([string]@($c.styles)[$j]).Replace('{color}', $color) }
    }
    $s['themeResourceVariables[0]'] = ''
    $s['clickThroughTaskbar'] = 0
    $s['xamlDiagnosticsHandling'] = 'alert'
    $s
}
function Test-SettingsMatch {
    $k = Get-Item "$regMod\Settings" -ErrorAction SilentlyContinue
    if (-not $k) { return $false }
    $want = Get-ModSettings
    if (@($k.GetValueNames()).Count -ne $want.Count) { return $false }
    foreach ($n in $want.Keys) { if ("$($k.GetValue($n))" -ne "$($want[$n])") { return $false } }
    $true
}
function Get-ModVersion { (Get-ItemProperty $regMod -ErrorAction SilentlyContinue).Version }

# Can this process write the mod's settings (admin, or --allow-user-settings was done)?
function Test-SettingsWritable {
    foreach ($sub in "SOFTWARE\Windhawk\Engine\Mods\$modId\Settings", "SOFTWARE\Windhawk\Engine\Mods\$modId") {
        try { $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub, $true) } catch { return $false }
        if (-not $k) { return $false }
        $k.Close()
    }
    $true
}

# Writes the settings in place (values only: the keys keep their permissions) and tells the mod.
function Write-ModSettings {
    $sk = "$regMod\Settings"
    if (-not (Test-Path $sk)) { New-Item $sk -Force | Out-Null }
    $s = Get-ModSettings
    $have = Get-Item $sk
    foreach ($n in @($have.GetValueNames())) { if (-not $s.Contains($n)) { Remove-ItemProperty $sk $n } }
    foreach ($n in $s.Keys) {
        if ($s[$n] -is [int]) { Set-ItemProperty $sk $n $s[$n] -Type DWord } else { Set-ItemProperty $sk $n ([string]$s[$n]) -Type String }
    }
    Set-ItemProperty $regMod SettingsChangeTime ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Type DWord
}

function Set-UserSettingsAccess($Allow) {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    foreach ($key in "$regMod\Settings", $regMod) {
        $acl = Get-Acl $key
        $rule = New-Object Security.AccessControl.RegistryAccessRule($sid, [Security.AccessControl.RegistryRights]::SetValue, 'None', 'None', 'Allow')
        if ($Allow) { $acl.AddAccessRule($rule) } else { [void]$acl.RemoveAccessRule($rule) }
        Set-Acl $key $acl
    }
}

if ($check) {
    Write-Host ("Windhawk: " + $(if (Test-Path $exe) { "installed ($((Get-Item $exe).VersionInfo.ProductVersion))" } else { 'not installed' }))
    $v = Get-ModVersion
    Write-Host ("mod ${modId}: " + $(if ($v) { "version $v" } else { 'not installed' }))
    if ($v) {
        $st = Get-Item "$regMod\Settings" -ErrorAction SilentlyContinue
        $fill = if ($st) { $st.GetValue('controlStyles[0].styles[0]') }
        Write-Host "taskbar style: $fill"
        Write-Host ("settings match --color=${color}: " + (Test-SettingsMatch))
        Write-Host ("this user can change the settings without admin: " + (Test-SettingsWritable))
    }
    exit 0
}

# ---- the elevated half: files, registry ------------------------------------------------------
if ($apply) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $root = 'https://mods.windhawk.net/mods/'
    $pd = Join-Path $env:ProgramData 'Windhawk'
    $winVer = [version]((Get-Item $exe).VersionInfo.ProductVersion -replace '[^0-9.].*$', '')

    $json = (Invoke-WebRequest -Uri "$root$modId/versions.json" -UseBasicParsing).Content
    $versions = @($json | ConvertFrom-Json | ForEach-Object { $_ })
    $latest = $versions | Sort-Object { [version]($_.version -replace '[^0-9.].*$', '') } | Select-Object -Last 1
    $ver = [string]$latest.version
    if ($latest.minWindhawkVersion -and $winVer -lt [version]($latest.minWindhawkVersion -replace '[^0-9.].*$', '')) {
        throw "mod $modId $ver needs Windhawk $($latest.minWindhawkVersion) or later (this is $winVer): update Windhawk"
    }
    $have = Get-ItemProperty $regMod -ErrorAction SilentlyContinue
    $dll = if ($have) { Join-Path $pd "Engine\Mods\64\$($have.LibraryFileName)" }
    if ($have -and $have.Version -eq $ver -and (Test-Path -LiteralPath $dll)) {
        Write-Host "  - mod $modId $ver already installed"
    } else {
        Write-Host "  - downloading $modId $ver"
        $src = (Invoke-WebRequest -Uri "$root$modId.wh.cpp" -UseBasicParsing).Content
        $bin = (Invoke-WebRequest -Uri "$root$modId/${ver}_64.dll" -UseBasicParsing).Content
        New-Item -ItemType Directory -Force (Join-Path $pd 'ModsSource'), (Join-Path $pd 'Engine\Mods\64') | Out-Null
        $name = '{0}_{1}_{2}.dll' -f $modId, $ver, (Get-Random -Minimum 100000 -Maximum 999999)
        [IO.File]::WriteAllBytes((Join-Path $pd "Engine\Mods\64\$name"), $bin)
        [IO.File]::WriteAllText((Join-Path $pd "ModsSource\$modId.wh.cpp"), $src, (New-Object Text.UTF8Encoding $false))
        if (-not (Test-Path $regMod)) { New-Item $regMod -Force | Out-Null }
        Set-ItemProperty $regMod LibraryFileName $name -Type String
        Set-ItemProperty $regMod Disabled 0 -Type DWord
        Set-ItemProperty $regMod Include 'explorer.exe' -Type String
        Set-ItemProperty $regMod Exclude '' -Type String
        Set-ItemProperty $regMod Architecture 'x86-64' -Type String
        Set-ItemProperty $regMod Version $ver -Type String
        # the old DLLs of this mod (same rule as Windhawk's own cleanup: <id>_..._<digits>.dll)
        Get-ChildItem (Join-Path $pd 'Engine\Mods\64') -Filter "${modId}_*.dll" |
            Where-Object { $_.Name -ne $name -and $_.BaseName.Substring($modId.Length + 1) -match '(^|_)[0-9]+$' } |
            Remove-Item -Force
        $up = Join-Path $pd 'userprofile.json'
        if (Test-Path $up) {
            $o = Get-Content $up -Raw | ConvertFrom-Json
            if (-not $o.mods) { $o | Add-Member -NotePropertyName mods -NotePropertyValue ([pscustomobject]@{}) }
            $o.mods | Add-Member -NotePropertyName $modId -NotePropertyValue ([pscustomobject]@{ version = $ver }) -Force
            [IO.File]::WriteAllText($up, ($o | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
        }
    }
    if (Test-SettingsMatch) { Write-Host '  - settings already applied' }
    else { Write-ModSettings; Write-Host "  - taskbar colour $color applied" }
    if ($allow) { Set-UserSettingsAccess $true; Write-Host '  - this user can now change the settings without admin' }
    if ($block) { Set-UserSettingsAccess $false; Write-Host '  - the settings need admin again' }
    exit 0
}

# ---- the normal half ------------------------------------------------------------------------
if (-not (Test-Path $exe)) {
    Write-Host '==> Installing Windhawk'
    winget install --id RamenSoftware.Windhawk --silent --accept-package-agreements --accept-source-agreements
    if (-not (Test-Path $exe)) { Write-Host 'Windhawk did not install: see the winget output above' -ForegroundColor Red; exit 1 }
}
Write-Host '==> Installing the Taskbar Styler mod'
$fresh = -not (Get-ModVersion)
$changed = $fresh -or -not (Test-SettingsMatch)
$flags = @("--color=$color")
if ($allow) { $flags += '--allow-user-settings' }
if ($block) { $flags += '--block-user-settings' }
if (-not $fresh -and -not $allow -and -not $block -and (Test-SettingsMatch)) {
    Write-Host '  - already installed with these settings'; $code = 0
} elseif (-not $fresh -and -not $allow -and -not $block -and (Test-SettingsWritable)) {
    Write-ModSettings; Write-Host "  - taskbar colour $color applied (no admin needed)"; $code = 0   # the theme path: no UAC
} elseif (Test-Admin) { & $PSCommandPath --apply @flags; $code = $LASTEXITCODE }
else { $code = Invoke-Elevated $PSCommandPath (@('--apply') + $flags) }
if ($code -ne 0) { Write-Host 'installing the mod failed (above)' -ForegroundColor Red; exit 1 }
if ($changed) {
    Write-Host '==> Starting Windhawk to load the mod'
    # -restart only restarts a running Windhawk; when it is stopped, start it (in the tray, no window)
    if (Get-Process windhawk -ErrorAction SilentlyContinue) { & $exe -restart -tray-only } else { Start-Process $exe -ArgumentList '-tray-only' }
    Start-Sleep -Seconds 3
    # a new colour shows within seconds, but a mod that was not there before only styles the taskbar
    # once Explorer builds it again
    if ($fresh) {
        Write-Host '==> Restarting Explorer so the taskbar picks the mod up'
        & (Join-Path $PSScriptRoot 'windots-restart-explorer.ps1')
    }
}
exit 0
