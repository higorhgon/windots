# AGENTS.md

Guide for coding agents working on **windots**: the Windows dotfiles of this
machine, in the spirit of [omarchy](https://github.com/basecamp/omarchy). The
README (Portuguese) is for the person; this file is for you. For step-by-step
recipes (add a hotkey, an app, a group, a command...) use the `windots` skill.

## What this is

A Windows 11 desktop that behaves like omarchy: komorebi (tiling) + whkd
(hotkeys) + masir (focus follows mouse), Flow Launcher, herdr-app, Windows
Terminal, all in Catppuccin Mocha. **omarchy is the reference**: when adding or
changing something, look at how omarchy does it (`omacom/omarchy`, branch
`quattro`: `default/hypr/bindings/*.lua`, `bin/omarchy-*`) and mirror it, with
**Super mapped to Alt**.

## Layout

| Path | What |
|---|---|
| `Configs/<group>/` | dotfiles linked by [tuckr](https://github.com/RaphGL/Tuckr); each group mirrors `~` (`Configs/starship/.config/starship.toml` -> `~\.config\starship.toml`) |
| `bin/windots-*` | commands, like omarchy's `bin`; `~\windots\bin` is on the user PATH |
| `default/<app>/` | data the `windots-install-*` scripts merge into files that can't be linked |
| `README.md` | the person's docs (Portuguese): groups, commands, install steps |

tuckr looks for `%APPDATA%\dotfiles`; `windots-install` makes it a junction to this
repo. Groups: `pwsh`, `mise`, `starship`, `komorebi` (komorebi, whkd,
komorebi-switcher), `backgrounds`, `herdr-app`, `atuin`, `btop`,
`windows-terminal`, `claude`.

## Live files vs repo copies (check before editing)

Links only exist after Developer Mode + `windots-install`. On a machine where
that hasn't run, the files in `~` are **copies**: an edit must go to both the
live file and `Configs/...`, or the next commit loses it. Check first:

```powershell
(Get-Item ~\.config\whkdrc).LinkType   # SymbolicLink = linked, empty = a copy
```

Some files are **never linked**, because their app saves by replacing the file
(a symlink would turn back into a plain file). They are merged by a script
instead; edit the `default/` data and the script, then run it:

| App file | Script | Data |
|---|---|---|
| Windows Terminal `settings.json` | `windots-install-windows-terminal` | `default/windows-terminal/` + the fragment in `Configs/windows-terminal` |
| Flow Launcher `Settings.json` | `windots-install-flow-launcher` | `default/flow-launcher/settings.json` |
| Startup shortcuts (`shell:startup`) | `windots-refresh-autostart` | the list inside the script |

## Commands (`bin/`)

Naming follows omarchy: `windots-install-*` (install/apply, idempotent),
`windots-launch-*`, `windots-menu-*` (fzf menus), `windots-toggle-*`,
`windots-refresh-*`, `windots-update-*` (steps of `windots-update`, like
`omarchy-update`: git pull, winget, re-apply via `windots-install`, mise). Every script starts with a usage comment block.

`windots` is the command center, like `omarchy`: `windots update -y` runs
`windots-update -y` (longest file-name match on the words), `windots <group>`
lists a group, `windots commands` lists everything. Both read the
`# windots:summary=` / `args=` / `examples=` lines at the top of each script,
and every script answers `--help` / `-h` through `windots.ps1 --help-for` (recipe
in the `windots` skill). A new script without them is missing from the help.

- `windots-launch-or-focus [--float] <regex> [cmd]`: focus by anchored regex on
  exe or title (like omarchy's `focus = "^(app)$"`), else launch.
- `windots-launch-tui` / `windots-launch-or-focus-tui [--float] [--title=t] cmd`:
  TUIs in a borderless Windows Terminal (`windots-tui` profile), fixed title.
- `windots-launch-float <cmd>`: open floating, centered, 875x600 (omarchy's size).
- Menus that are fzf TUIs (`windots-menu-keybindings`, `windots-install-font`)
  launch themselves floating when run with no args; `--pick` runs the list in
  the current terminal.

## Rules learned the hard way

**PowerShell**
- `windots-install*` and anything they call must parse and run on **Windows
  PowerShell 5.1** (a fresh machine has no pwsh 7). Check both:
  `[System.Management.Automation.Language.Parser]::ParseFile(...)` in `pwsh` and `powershell.exe`.
- Scripts that pass flags through to another program (`wt -w new ...`) use plain
  `$args`, **no `param()` block**: with one, PowerShell binds `-w` as `-WarningAction`.
- Keep one-item results arrays: `$x = @(if (...) { ... })`, or `@x` splats the
  characters of a single string.
- Never name a helper `Where` (alias of `Where-Object`).
- `sed` in Git Bash eats backslashes in Windows paths: use the Edit tool (or
  Python) for lines with `\`.
- Back up files the script rewrites (`<file>.bak.<unix time>`); be idempotent.

**tuckr**
- When a folder is missing in `~`, tuckr links the **whole folder** into the repo
  ("folding"). Apps then write their state (sockets, caches, sessions) into
  `Configs/`, and deleting `~\<folder>\<file>` deletes the repo's file. So
  `bin\lib\dotfiles.ps1` treats only **git-tracked** files as dotfiles, creates
  every folder before tuckr runs, and turns folder links back into real folders
  (`Repair-FoldedLinks`). Never enumerate `Configs/` from the filesystem.
- Anything a script removes from `~` goes through `Remove-Dotfile`: files only,
  never folders, never through a link, real files to the Recycle Bin. A bad run
  once deleted the person's `~\Pictures` (folded into the repo); never again.

**whkd** (`Configs/komorebi/.config/whkdrc`)
- `.shell pwsh`; the trailing `# ...` on a line is its description in the
  Alt+K menu (`windots-menu-keybindings`). Keep it, in Portuguese.
- **Never use hex key codes** (`0xc1`): with the full file loaded, whkd keeps
  running but ignores *every* hotkey. Keys whkd can't name go to
  `bin/windots-hotkeys.ahk` (AutoHotkey v2), e.g. the ABNT2 `/` (`vkC1`).
- US/US-Intl `/` is `oem_2`; `-` / `=` are `oem_minus` / `oem_plus`.
- After editing: restart whkd **with a refreshed PATH** (or `windots-*` commands
  aren't found), then verify that `Alt+number` still switches workspaces. The
  first key right after a restart is sometimes dropped: retry before concluding.
- Check conflicts with herdr-app (`Configs/herdr-app/.config/herdr-app/keys.json`)
  and Flow Launcher hotkeys. Alt+number belongs to komorebi workspaces.

**komorebi**
- Float override only has a *toggle*; `windots-launch-float` serializes it with a
  mutex and only turns it off if it turned it on. Don't toggle it elsewhere.
- Workspaces have a Tiling and a Floating *layer*; a workspace left on Floating
  makes every new window float (`komorebic state` -> `layer`).
- `windots-float-ontop` keeps floating windows above tiled ones (named pipe
  subscription); monocle has its own border colour.

**Startup items** are only created by `windots-refresh-autostart`. Agents are
often not allowed to create them: change the script, then ask the person to run
`pwsh -NoProfile -ExecutionPolicy Bypass -File ~/windots/bin/windots-refresh-autostart.ps1`.

**Never version secrets or personal data**: `~\.atuin\data` (key, history),
`~\.config\omapass` (`.history_key`), Flow's `History.json`, herdr-app's
`view.json` / `window.json` / generated `*.d.ts` / `jsconfig.json`.

## Themes

Catppuccin Mocha, official ports only (catppuccin/powershell, windows-terminal,
btop, fzf, atuin): don't hand-write palettes when a port exists. Font:
JetBrainsMonoNL Nerd Font (`windots-install-font`).

## Testing

Verify on the real desktop, not just by reading files:
- simulate hotkeys with `keybd_event` and check the effect (`komorebic state`,
  foreground window, window rect, `GetWindowLong` flags);
- screenshot windows (`System.Drawing` `CopyFromScreen`) and look at them;
- close every window your test opened.

## Commits

Use the `commit-message` skill (kept in the `claude` group). One commit per responsibility, semantic (`feat(scope): subject`), lowercase
subject under 50 chars, body as short bullets, **no Co-Authored-By trailer**.
Before committing, check nothing is already staged (`git diff --cached`), and
after each commit check which files went in. Push to `origin main`. Update the
README (Portuguese) when commands, groups or install steps change.
