---
name: windots
description: Change the Windows desktop setup kept in the windots repo (~\windots) — komorebi tiling, whkd hotkeys, Flow Launcher menus, herdr-app, Windows Terminal, themes, fonts, startup apps, windots-* commands. Use whenever the person asks to add/change a keyboard shortcut, open an app floating or tiled, add a config file or app to the dotfiles, create a windots-* command, change the theme/colors/font, or anything "like omarchy" on Windows.
---

# windots

The Windows dotfiles live in `~\windots` (GitHub `higorhgon/windots`). Read
`~\windots\AGENTS.md` first: layout, rules learned the hard way, testing and
commit conventions. omarchy (`omacom/omarchy`, branch `quattro`) is the
reference for behavior and names, with **Super mapped to Alt**.

Talk to the person in Portuguese; code, comments and commit messages in English.

## Before any change

1. `cd ~\windots; git status` — start from a clean tree (or know what's pending).
2. For each file you touch in `~`, check whether it's linked or a copy:
   `(Get-Item <path>).LinkType`. A copy means: edit the live file **and**
   `Configs\<group>\...` (same content).
3. Look up how omarchy does the same thing and mirror it.

## Recipes

### Add or change a hotkey
1. Check the key is free: `~\.config\whkdrc`, `windots-hotkeys.ahk`, herdr-app
   `keys.json`, Flow `CustomPluginHotkeys`. Alt+number is komorebi's.
2. Add the line in the right `# --- Section ---` of `whkdrc`, with a Portuguese
   description: `alt + ctrl + x : <command>  # Descrição`.
   - Named keys only (`oem_2`, `oem_minus`...). **No hex codes** — they disable
     every hotkey. Unnamed keys (e.g. ABNT2 `/` = `vkC1`) go in
     `bin\windots-hotkeys.ahk`.
3. Copy to `Configs\komorebi\.config\whkdrc` if it isn't linked.
4. Restart whkd with a fresh PATH:
   ```powershell
   $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
   Stop-Process -Name whkd -Force; Start-Process whkd -WindowStyle Hidden
   ```
5. Test the new key and `Alt+1`/`Alt+2` (workspaces) by simulating them; retry
   once if the very first press after the restart is lost.

### Open an app from a hotkey
- Normal app: `start <exe or path>`.
- Single instance, focus if open: `windots-launch-or-focus '^(name)$' <cmd>`.
- Floating (centered, 875x600): add `--float`.
- Terminal app: `windots-launch-or-focus-tui [--float] [--title=t] <cmd>`
  (borderless Windows Terminal, `windots-tui` profile, Catppuccin, focus by title).
- A Settings page: `start ms-settings:<page>`.

### A menu like omarchy's
- Flow Launcher can open with a query (`default\flow-launcher\settings.json`,
  `CustomPluginHotkeys` + plugin `ActionKeywords`), then run
  `windots-install-flow-launcher`. The keyword stays visible in the query box.
- A menu with an empty search box: an fzf TUI script in `bin` (see
  `windots-menu-keybindings`: no args -> launches itself floating; `--pick` ->
  runs fzf; colors from `catppuccin-fzf-mocha.ps1`).

### Add a config file / app to the dotfiles
1. Find where the app keeps its config. If the app saves by *replacing* the file
   (look for `*.bak` / temp files next to it, or test), don't link it: put the
   wanted parts in `default\<app>\` and write `bin\windots-install-<app>.ps1`
   that merges them (backup, idempotent, PS 5.1), then call it from
   `windots-install`.
2. Otherwise copy it into `Configs\<group>\<same path relative to ~>`.
3. Never add secrets, history or app-generated files (see AGENTS.md).
4. Add the group/command to the README tables (Portuguese).

### Add a `windots-*` command
- `bin\windots-<verb>-<thing>.ps1`, usage comment block on top, plain `$args`
  when flags pass through, PS 5.1-compatible if `windots-install` calls it.
- Right after the name line, the metadata `windots` and `windots commands` read
  (like omarchy's `# omarchy:` lines); the route comes from the file name:
  ```powershell
  # windots-toggle-thing [on|off]
  # windots:summary=One line, what it does
  # windots:args=[on | off]
  # windots:examples=windots toggle thing | windots toggle thing on
  ```
- First statement after the comment block, so `--help`/`-h` work:
  ```powershell
  if ('-h', '--help' -contains $args[0]) { & (Join-Path $PSScriptRoot 'windots.ps1') --help-for $PSCommandPath; return }
  ```
  (with a `param()` block, see `windots-install`: `[Alias('h')][switch]$Help`
  plus a `ValueFromRemainingArguments` parameter to catch `--help`).
- Check it shows up: `windots commands`, `windots <group> --help`.
- Syntax-check in both shells; run it for real; document it in the README.

### Packages
- winget: add the id to `default\packages.txt` (installed by `windots reinstall pkgs`,
  which `windots-install` calls).
- CLI tools: prefer mise (`mise use -g <tool>`, then copy
  `~\.config\mise\config.toml` to `Configs\mise\...`).

### Startup apps
Edit the `$entries` list in `bin\windots-refresh-autostart.ps1`; ask the person
to run it (creating startup shortcuts is usually blocked for agents).

## Finish

1. Verify on the desktop (simulated keys, `komorebic state`, screenshots); close
   the windows your tests opened.
2. Commits per responsibility (semantic, lowercase, no Co-Authored-By); check
   `git diff --cached` is empty before starting; push when the person asks.
3. Tell the person what changed, what you tested, and anything they must run
   themselves.
