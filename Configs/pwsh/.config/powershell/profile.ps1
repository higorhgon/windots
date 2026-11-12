(&mise activate pwsh) | Out-String | Invoke-Expression

Set-Alias tuckr tuckr-x86_64-windows   # winget installs it under this name

Invoke-Expression (&starship init powershell)

# fzf colors (https://github.com/catppuccin/fzf), also used by windots-menu-keybindings
. (Join-Path $PSScriptRoot 'catppuccin-fzf-mocha.ps1')

# Catppuccin (https://github.com/catppuccin/powershell), cloned by windots-reinstall-pkgs into
# ~\.local\share\powershell\Modules (not Documents\PowerShell\Modules: OneDrive backs it up).
$env:PSModulePath = (Join-Path $HOME '.local\share\powershell\Modules') + ';' + $env:PSModulePath
if (Get-Module -ListAvailable Catppuccin) {
    Import-Module Catppuccin
    $Flavor = $Catppuccin['Mocha']

    Set-PSReadLineOption -Colors @{
        ContinuationPrompt     = $Flavor.Teal.Foreground()
        Emphasis               = $Flavor.Red.Foreground()
        Selection              = $Flavor.Surface0.Background()
        InlinePrediction       = $Flavor.Overlay0.Foreground()
        ListPrediction         = $Flavor.Mauve.Foreground()
        ListPredictionSelected = $Flavor.Surface0.Background()
        Command                = $Flavor.Blue.Foreground()
        Comment                = $Flavor.Overlay0.Foreground()
        Default                = $Flavor.Text.Foreground()
        Error                  = $Flavor.Red.Foreground()
        Keyword                = $Flavor.Mauve.Foreground()
        Member                 = $Flavor.Rosewater.Foreground()
        Number                 = $Flavor.Peach.Foreground()
        Operator               = $Flavor.Sky.Foreground()
        Parameter              = $Flavor.Pink.Foreground()
        String                 = $Flavor.Green.Foreground()
        Type                   = $Flavor.Yellow.Foreground()
        Variable               = $Flavor.Lavender.Foreground()
    }

    $PSStyle.Formatting.Debug        = $Flavor.Sky.Foreground()
    $PSStyle.Formatting.Error        = $Flavor.Red.Foreground()
    $PSStyle.Formatting.ErrorAccent  = $Flavor.Blue.Foreground()
    $PSStyle.Formatting.FormatAccent = $Flavor.Teal.Foreground()
    $PSStyle.Formatting.TableHeader  = $Flavor.Rosewater.Foreground()
    $PSStyle.Formatting.Verbose      = $Flavor.Yellow.Foreground()
    $PSStyle.Formatting.Warning      = $Flavor.Peach.Foreground()

    # ls: the module doesn't cover $PSStyle.FileInfo; the default blue-background folders are unreadable
    $PSStyle.FileInfo.Directory = "$($PSStyle.Bold)$($Flavor.Blue.Foreground())"
} else {
    Write-Host 'Catppuccin module missing (colors off): run windots reinstall pkgs' -ForegroundColor Yellow
}

atuin init powershell --disable-up-arrow | Out-String | Invoke-Expression

Set-PSReadlineKeyHandler -Key ctrl+d -Function DeleteCharOrExit

# Tab like bash: completes the common part, a second Tab lists every option
Set-PSReadLineKeyHandler -Key Tab -Function Complete

Set-PSReadLineKeyHandler -Key Ctrl+c -Function CancelLine
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord

# Some terminals send Ctrl+Left/Right as ESC b / ESC f (Linux/macOS style)
Set-PSReadLineKeyHandler -Chord 'Escape,b' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Escape,f' -Function ForwardWord
Set-PSReadLineKeyHandler -Key Alt+b -Function BackwardWord
Set-PSReadLineKeyHandler -Key Alt+f -Function ForwardWord

# zoxide: cd learns the folders you use (cd foo jumps to the best match; cdi picks in fzf)
# Last, as zoxide asks: it wraps cd after everything else is set up.
Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
