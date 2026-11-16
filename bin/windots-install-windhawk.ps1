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
#   4. restarts Windhawk (windhawk.exe -restart -tray-only) so the engine loads the mod, and Explorer, only
#      when the mod was just installed: a new colour in an installed mod shows ~0.3 s after the settings write
#   --color=#rrggbb   the taskbar colour (default: the one in default/windhawk/taskbar-styler.json)
#   --foreground=#rrggbb   the colour of the Start logo, the tray icons (chevron, network, volume, battery) and the
#                     clock, like the foreground of omarchy's bar. The Start logo cannot be tinted (an animation), so it
#                     is replaced by a picture of it in this colour (~\.local\state\windots\taskbar\start-<hex>.png).
#                     Icons that apps put in the tray are pictures of their own and keep their colours.
#   --charging=#rrggbb     the fill of the battery icon (Windows' own green otherwise)
#   --check           say what is installed and which colour is set; change nothing
#   --allow-user-settings   let this user change the mod's settings without admin: the default (one UAC the
#                     first time, none when a theme changes the colour later). A deliberate trade-off, chosen
#                     by the person: any program running as this user can restyle the taskbar. It is kept
#                     off for good by --block-user-settings (state file windhawk-no-user-settings) until
#                     --allow-user-settings is given again.
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
$check = $false; $apply = $false; $color = $data.color; $foreground = $data.foreground; $charging = $data.charging; $allow = $false; $block = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($a -eq '--check') { $check = $true }
    elseif ($a -eq '--apply') { $apply = $true }          # internal: the elevated half
    elseif ($a -eq '--allow-user-settings') { $allow = $true }
    elseif ($a -eq '--block-user-settings') { $block = $true }
    elseif ($a -like '--color=*') { $color = $a.Substring(8) }
    elseif ($a -like '--foreground=*') { $foreground = $a.Substring(13) }
    elseif ($a -like '--charging=*') { $charging = $a.Substring(11) }
    else { Write-Host "unknown option: $a (see windots install windhawk --help)" -ForegroundColor Red; exit 2 }
}
# the person's choice, kept between runs: user settings are allowed unless --block-user-settings was given
$optOut = Join-Path $HOME '.local\state\windots\windhawk-no-user-settings'
if ($allow -and $block) { Write-Host '--allow-user-settings and --block-user-settings together make no sense' -ForegroundColor Red; exit 2 }
if (-not $apply) {
    if ($block) { New-Item -ItemType Directory -Force (Split-Path $optOut) | Out-Null; Set-Content $optOut 'blocked' }
    if ($allow) { Remove-Item $optOut -ErrorAction SilentlyContinue }
}
$wantAccess = $allow -or (-not $block -and -not (Test-Path $optOut))
if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { Write-Host "--color must look like #1e1e2e, not '$color'" -ForegroundColor Red; exit 2 }
if ($foreground -notmatch '^#[0-9A-Fa-f]{6}$') { Write-Host "--foreground must look like #cdd6f4, not '$foreground'" -ForegroundColor Red; exit 2 }
if ($charging -notmatch '^#[0-9A-Fa-f]{6}$') { Write-Host "--charging must look like #a6e3a1, not '$charging'" -ForegroundColor Red; exit 2 }
$color = $color.ToLower(); $foreground = $foreground.ToLower(); $charging = $charging.ToLower()

# The Start button's logo is an animation with its colours inside: it cannot be tinted. So it is hidden and the button
# gets a picture of the logo in the foreground colour, one file per colour (a new name makes Explorer load it).
$startIcon = Join-Path $HOME ".local\state\windots\taskbar\start6-$($foreground.TrimStart('#')).png"   # start<n>: the version of the drawing
function Initialize-StartIcon {
    if (Test-Path $startIcon) { return }
    Add-Type -AssemblyName System.Drawing
    New-Item -ItemType Directory -Force (Split-Path $startIcon) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap 256, 256
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($foreground))
    $clear = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        # The shape of Windows' own logo (SystemApps\MicrosoftWindows.Client.Core_*\Icons\WindowsLogo.svg, which an
        # ImageBrush does not load): four squares, a thin gap, only the four outer corners round. Its place is the one
        # the taskbar gives the original, measured at 100 % scale: the button's Border is 26 px (this canvas / 26 = one
        # screen pixel, $e; the picture starts at x 11.5, y 3) and the logo covers 15 x 15 of them, squares of 7 with a
        # 1 px gap, 5.5 px from the left and 6 from the top. Drawn on whole screen pixels so the edges and the gap stay
        # sharp; a solid light colour that is any larger looks bigger than the original (its edge pixels are faint).
        $e = 256 / 26
        $x0 = [single](5.5 * $e); $y0 = [single](6 * $e); $side = [single](15 * $e); $r = [single](1.4 * $e)   # $r: a corner's diameter
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddArc($x0, $y0, $r, $r, 180, 90); $p.AddArc($x0 + $side - $r, $y0, $r, $r, 270, 90)
        $p.AddArc($x0 + $side - $r, $y0 + $side - $r, $r, $r, 0, 90); $p.AddArc($x0, $y0 + $side - $r, $r, $r, 90, 90)
        $p.CloseFigure(); $g.FillPath($brush, $p); $p.Dispose()
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy   # the cross between the squares
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $g.FillRectangle($clear, [single]($x0 + 7 * $e), $y0, [single]$e, $side); $g.FillRectangle($clear, $x0, [single]($y0 + 7 * $e), $side, [single]$e)
        $bmp.Save($startIcon, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $brush.Dispose(); $clear.Dispose(); $g.Dispose(); $bmp.Dispose() }
    # the pictures of the colours used before
    Get-ChildItem (Split-Path $startIcon) -Filter 'start*.png' | Where-Object { $_.FullName -ne $startIcon } | Remove-Item -Force -ErrorAction SilentlyContinue
}

# the settings the mod gets, as the flat name = value pairs Windhawk keeps in the registry
function Get-ModSettings {
    $s = [ordered]@{ theme = ''; 'styleConstants[0]' = '' }
    for ($i = 0; $i -lt @($data.controlStyles).Count; $i++) {
        $c = @($data.controlStyles)[$i]
        $s["controlStyles[$i].target"] = [string]$c.target
        for ($j = 0; $j -lt @($c.styles).Count; $j++) {
            $s["controlStyles[$i].styles[$j]"] = ([string]@($c.styles)[$j]).Replace('{color}', $color).Replace('{foreground}', $foreground).Replace('{charging}', $charging).Replace('{start_icon}', $startIcon)
        }
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

# The registry keys of the mod, opened with SetValue + QueryValues only: that is all the permission --allow-user-settings
# gives, and PowerShell's registry provider asks for more (Set-ItemProperty fails with "Requested registry access is
# not allowed"), so the settings are written through .NET.
function Open-ModKey($Sub) {
    [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        ([Security.AccessControl.RegistryRights]::SetValue -bor [Security.AccessControl.RegistryRights]::QueryValues))
}

# Can this process write the mod's settings (admin, or --allow-user-settings was done)?
function Test-SettingsWritable {
    foreach ($sub in "SOFTWARE\Windhawk\Engine\Mods\$modId\Settings", "SOFTWARE\Windhawk\Engine\Mods\$modId") {
        try { $k = Open-ModKey $sub } catch { return $false }
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
    $k = Open-ModKey "SOFTWARE\Windhawk\Engine\Mods\$modId\Settings"
    try {
        foreach ($n in @($k.GetValueNames())) { if (-not $s.Contains($n)) { $k.DeleteValue($n) } }
        foreach ($n in $s.Keys) {
            if ($s[$n] -is [int]) { $k.SetValue($n, [int]$s[$n], [Microsoft.Win32.RegistryValueKind]::DWord) }
            else { $k.SetValue($n, [string]$s[$n], [Microsoft.Win32.RegistryValueKind]::String) }
        }
    } finally { $k.Close() }
    $m = Open-ModKey "SOFTWARE\Windhawk\Engine\Mods\$modId"
    try { $m.SetValue('SettingsChangeTime', [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $m.Close() }
}

# Does an ACL rule already let this user write the mod's settings (not just: can this process, which admin always can)?
# Read through .NET, not Get-Acl: a Windows PowerShell 5.1 started by a pwsh 7 process inherits its PSModulePath and
# cannot load Microsoft.PowerShell.Security; Get-Acl failed, this said "no access" and a theme switch asked for UAC.
function Test-UserAccess {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    foreach ($sub in "SOFTWARE\Windhawk\Engine\Mods\$modId\Settings", "SOFTWARE\Windhawk\Engine\Mods\$modId") {
        try {
            $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::Default,
                [Security.AccessControl.RegistryRights]::ReadPermissions)
            if (-not $k) { return $false }
            try { $rules = $k.GetAccessControl([Security.AccessControl.AccessControlSections]::Access).GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) }
            finally { $k.Close() }
        } catch { return $false }
        $hit = @($rules | Where-Object {
            $_.AccessControlType -eq 'Allow' -and ($_.RegistryRights -band [Security.AccessControl.RegistryRights]::SetValue) -and
            $_.IdentityReference -eq $sid })
        if (-not $hit.Count) { return $false }
    }
    $true
}

# Windhawk's own ACLs are not in canonical order, so the .NET AddAccessRule refuses them: edit the SDDL text instead.
# The rule is "allow SetValue (0x2) to this user", on the mod's key and its Settings key, and nothing else.
function Set-UserSettingsAccess($Allow) {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $ace = "(A;;0x2;;;$sid)"
    foreach ($key in "$regMod\Settings", $regMod) {
        $acl = Get-Acl $key
        $sddl = $acl.GetSecurityDescriptorSddlForm('Access')
        if ($Allow) { if (-not $sddl.Contains($ace)) { $sddl = $sddl -replace '^(D:[A-Z]*)', ('${1}' + $ace) } }
        else { $sddl = $sddl.Replace($ace, '') }
        $acl.SetSecurityDescriptorSddlForm($sddl, 'Access')
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
$haveAccess = (-not $fresh) -and (Test-UserAccess)
$accessChange = if ($wantAccess) { -not $haveAccess } else { $haveAccess }   # the permission has to be granted or taken back
$flags = @("--color=$color", "--foreground=$foreground", "--charging=$charging")
Initialize-StartIcon
if ($wantAccess -and -not $haveAccess) { $flags += '--allow-user-settings' }
if (-not $wantAccess -and $haveAccess) { $flags += '--block-user-settings' }
if (-not $fresh -and -not $accessChange -and (Test-SettingsMatch)) {
    Write-Host '  - already installed with these settings'; $code = 0
} elseif (-not $fresh -and -not $accessChange -and (Test-SettingsWritable)) {
    Write-ModSettings; Write-Host "  - taskbar colour $color applied (no admin needed)"; $code = 0   # the theme path: no UAC
} elseif (Test-Admin) { & $PSCommandPath --apply @flags; $code = $LASTEXITCODE }
else { $code = Invoke-Elevated $PSCommandPath (@('--apply') + $flags) }
if ($code -ne 0) { Write-Host 'installing the mod failed (above)' -ForegroundColor Red; exit 1 }
if ($fresh) {
    # only a mod that was not there before needs the engine restarted (measured: a new colour in an installed mod
    # shows ~0.3 s after the registry write, with no restart and no wait) and Explorer to build the taskbar again
    Write-Host '==> Starting Windhawk to load the mod'
    # -restart only restarts a running Windhawk; when it is stopped, start it (in the tray, no window)
    if (Get-Process windhawk -ErrorAction SilentlyContinue) { & $exe -restart -tray-only } else { Start-Process $exe -ArgumentList '-tray-only' }
    Start-Sleep -Seconds 3
    Write-Host '==> Restarting Explorer so the taskbar picks the mod up'
    & (Join-Path $PSScriptRoot 'windots-restart-explorer.ps1')
}
exit 0
