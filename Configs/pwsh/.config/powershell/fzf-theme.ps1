# fzf colours: the current windots theme. windots-theme-set writes ~\.local\state\windots\fzf-colors.opts and fzf reads
# the file at every start (FZF_DEFAULT_OPTS_FILE), so a theme switch reaches fzf in terminals that are already open.
# Before the first theme switch the file does not exist: Catppuccin Mocha (https://github.com/catppuccin/fzf).
$fzfColors = Join-Path $HOME '.local/state/windots/fzf-colors.opts'
if (Test-Path $fzfColors) {
    $ENV:FZF_DEFAULT_OPTS_FILE = $fzfColors
} else {
    $ENV:FZF_DEFAULT_OPTS = @"
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8
--color=selected-bg:#45475A
--color=border:#6C7086,label:#CDD6F4
"@
}
