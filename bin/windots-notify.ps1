# windots-notify <title> <text> [--launch=<uri>]
# windots:summary=Show a Windows notification (clicking it can open a windots: link)
# windots:args=<title> <text> [--launch=<uri>]
# windots:examples=windots notify "Files" "Restart to apply the theme" --launch=windots:restart-files
#
# A toast notification from the command line. --launch is the link opened when the notification is
# clicked; windots: links run the actions listed in windots-uri.ps1 (windots:restart-files). The toast
# API needs Windows PowerShell 5.1, so under PowerShell 7 this runs itself again in powershell.exe.
# It borrows PowerShell's own app id: the notification shows as coming from "Windows PowerShell".
# Works on Windows PowerShell 5.1 and PowerShell 7.

if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
if ($PSVersionTable.PSEdition -eq 'Core') {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @args
    exit $LASTEXITCODE
}

$words = @(); $launch = ''
foreach ($a in $args) {
    if (([string]$a) -like '--launch=*') { $launch = ([string]$a).Substring(9) }
    elseif (([string]$a).StartsWith('--')) { Write-Host "unknown option: $a (see windots notify --help)" -ForegroundColor Red; exit 2 }
    else { $words += [string]$a }
}
if ($words.Count -lt 2) { Write-Host 'usage: windots notify <title> <text> [--launch=<uri>]' -ForegroundColor Red; exit 2 }

function Esc($s) { [System.Security.SecurityElement]::Escape($s) }
$attr = if ($launch) { ' activationType="protocol" launch="' + (Esc $launch) + '"' } else { '' }
$xml = '<toast' + $attr + '><visual><binding template="ToastGeneric"><text>' + (Esc $words[0]) + '</text><text>' + (Esc $words[1]) + '</text></binding></visual></toast>'

[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
$doc = New-Object Windows.Data.Xml.Dom.XmlDocument
$doc.LoadXml($xml)
$toast = New-Object Windows.UI.Notifications.ToastNotification $doc
$toast.Tag = 'windots'; $toast.Group = 'windots'   # a new one replaces the one still on screen
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
