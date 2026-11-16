# AGENTS.md

Guide for coding agents working on **windots**: the Windows dotfiles of this
machine, in the spirit of [omarchy](https://github.com/basecamp/omarchy). The
README (Portuguese) is for the person; this file is for you. For step-by-step
recipes (add a hotkey, an app, a group, a command...) use the `windots` skill.

## What this is

A Windows 11 desktop that behaves like omarchy: komorebi (tiling) + whkd
(hotkeys) + masir (focus follows mouse), windots-launcher, herdr-app, Windows
Terminal, all in Catppuccin Mocha. **omarchy is the reference**: when adding or
changing something, look at how omarchy does it (`omacom/omarchy`, branch
`quattro`: `default/hypr/bindings/*.lua`, `bin/omarchy-*`) and mirror it, with
**Super = the Windows key** (Win+L lock stays the system's; Win+R is the launcher's `run` route).

## Layout

| Path | What |
|---|---|
| `Configs/<group>/` | dotfiles linked by [tuckr](https://github.com/RaphGL/Tuckr); each group mirrors `~` (`Configs/starship/.config/starship.toml` -> `~\.config\starship.toml`) |
| `bin/windots-*` | commands, like omarchy's `bin`; `~\windots\bin` is on the user PATH |
| `bin/windots-install.ps1` | also the one-line installer (`irm .../bin/windots-install.ps1 \| iex`): outside a clone it installs Git, clones the repo, sets the git identity and runs its own copy from the clone (self-contained up to there: the repo is not in place yet; child scripts run with `-ExecutionPolicy Bypass`) |
| `default/wsl/setup.sh` | the part of `windots-setup-wsl` that runs inside Arch on WSL, as root (`.gitattributes` keeps `*.sh` at LF: with `core.autocrlf` bash would choke on CRLF) |
| `migrations/` | like omarchy's: `<unix time>.ps1`, run once per machine by `windots-migrate` (created by `windots-dev-add-migration`) |
| `default/<app>/` | data the `windots-install-*` scripts merge into files that can't be linked |
| `default/themes/<name>/colors.toml`, `.../backgrounds/` | the 23 omarchy themes (copied from `omacom/omarchy`, `themes/<name>/colors.toml`, and the 98 images of `themes/<name>/backgrounds`, 69 MB; videos left out; the person's own images are in `catppuccin/backgrounds`); `windots-theme-set` reads them through `bin/lib/themes.ps1`. The current theme is `~\.local\state\windots\theme.name` (state, never versioned) |
| `default/lazyvim/` | omarchy's Neovim (omacom/omarchy-pkgs, `pkgbuilds/omarchy-nvim`): lazyvim.json, `lua/config`, `lua/plugins`, `plugin/after`, and the aether template `neovim.lua.tpl` (omarchy's `default/themed/neovim.lua.tpl`); `windots-install-lazyvim` merges them into the Neovim config |
| `default/retropet/` | git submodule ([higorhgon/retropet](https://github.com/higorhgon/retropet)): herdr-app layout, mods, theme; `windots-install-herdr-app` copies (never links: herdr-app refuses mod files that resolve outside its folder) its files into `~\.config\herdr-app` |
| `default/packages.txt` | default winget apps (like omarchy's base packages), installed by `windots-reinstall-pkgs` |
| `README.md` | the person's docs (Portuguese): groups, commands, install steps |

tuckr looks for `%APPDATA%\dotfiles`; `windots-install` makes it a junction to this
repo. Groups: `pwsh`, `mise`, `starship`, `komorebi` (komorebi.json,
applications.json, whkdrc; the switcher's toml is not linked, see Themes), `atuin`, `btop`,
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
| Windhawk mod settings (`HKLM\SOFTWARE\Windhawk\Engine\Mods\<id>\Settings`) | `windots-install-windhawk` | `default/windhawk/taskbar-styler.json` (`{color}` is replaced) |
| herdr-app `keys.json`, `settings.json` | `windots-install-herdr-app` | `default/herdr-app/` + `default/retropet/keys.json` |
| Windhawk Taskbar Styler settings (`HKLM\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler\Settings`) | `windots-install-windhawk` | `default/windhawk/taskbar-styler.json` |
| `%LOCALAPPDATA%\nvim` (LazyVim) | `windots-install-lazyvim`, `windots-theme-set` (only `lua/plugins/theme.lua`) | `default/lazyvim/`, `default/themes/<name>/neovim.lua` (never linked: lazy.nvim writes `lazy-lock.json` and `lazyvim.json` into it; the person's own extras and plugins live there) |
| `~\.config\komorebi-switcher.toml` (per machine: the theme's `[colors]`, `alignment`, `persistent_workspaces`) | `windots-theme-set`, `windots-install-komorebi-switcher` | seed `default/komorebi/komorebi-switcher.toml` (never linked: a theme switch must not dirty the repo) |
| Windows Terminal `settings.json`: the `windots` scheme / UI theme | `windots-theme-set` (and `windots-install-windows-terminal`) | `default/themes/` |
| Startup shortcuts (`shell:startup`) | `windots-refresh-autostart` | the list inside the script |
| `~\.local\share\windots-launcher` (the published windots-launcher) | `windots-install-launcher` | the project in `~\Projetos\windots-launcher` (own repo; its menu is `menus/default.jsonc`, extended per machine by `~\.config\windots\menu.jsonc`) |

## Commands (`bin/`)

Naming follows omarchy: `windots-install-*` (install/apply, idempotent),
`windots-launch-*`, `windots-menu-*` (fzf menus), `windots-setup-*` (machine
setup: git, and sudo/ssh, which need admin and re-run themselves through sudo, helpers in
`bin/lib/elevation.ps1`), `windots-migrate` / `windots-dev-*` (migrations), `windots-toggle-*`,
`windots-refresh-*`, `windots-restart-*` (like omarchy's `omarchy-restart-*`: an app
reloads its config only when it starts), `windots-update-*` (steps of `windots-update`, like
`omarchy-update`: git pull, winget, re-apply via `windots-install`, mise; each step is a command, and
`windots-update` checks the exit code of every one that must succeed: `& script.ps1` with `exit 1` does not
throw), `windots-hook` (per-machine hooks in `~\.config\windots\hooks`). Every script starts with a usage comment block.

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
- Flags are Linux style (`--skip-packages`, `--prune`, short `-y` / `-h`), read from
  `$args`; never PowerShell-style `-SkipPackages` switches.
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
- **No dotfiles in OneDrive folders** (Documents, Pictures, Desktop): OneDrive
  backs them up or redirects them, which breaks links. Put files under
  `~\.config` (omarchy style). PowerShell's `$PROFILE` must stay in Documents, so
  `windots-install` writes a one-line loader there (a plain file) for
  `~\.config\powershell\profile.ps1`. Places windots used to link are listed in
  `$WindotsOldPlaces` (`bin\lib\dotfiles.ps1`) so their stale links get removed.
- Anything a script removes from `~` goes through `Remove-Dotfile`: files only,
  never folders, never through a link, real files to the Recycle Bin. A bad run
  once deleted the person's `~\Pictures` (folded into the repo); never again.
- ssh sessions run under sshd's RedirectionGuard: a process there cannot follow a link or
  junction made by a normal user (error 448, "untrusted mount point"; Claude Code's own
  shell is not affected, so test with a real ssh login). So `~` links point straight at the
  repo files, not through the `%APPDATA%\dotfiles` junction (`Repoint-DotfileLinks`, run by
  `windots-install`), and the PowerShell profile loader falls back to the repo path. Tools
  installed through links (winget's `mise.exe`, mise's `latest` junctions) still fail there
  unless `windots setup security ssh --allow-user-links` was run: a deliberate security
  trade-off, never done by default (`--block-user-links` undoes it).

**whkd** (`Configs/komorebi/.config/whkdrc`)
- `.shell pwsh`; the trailing `# ...` on a line is its description in the
  Win+K menu (`windots-menu-keybindings`). Keep it, in Portuguese.
- **Never use hex key codes** (`0xc1`): with the full file loaded, whkd keeps
  running but ignores *every* hotkey. Keys whkd can't name go to
  `bin/windots-hotkeys.ahk` (AutoHotkey v2), e.g. the ABNT2 `/` (`vkC1`).
- Super is the Windows key: `win + ...` works in whkd (checked: Win+2 switches workspace) and `windots-hotkeys.ahk` stops the
  Start menu. A key whkd binds is swallowed before the shell sees it (Win+E/Q/W/T/F/M/O/J/K showed nothing of the system's);
  unbound ones stay the system's (Win+A quick settings, Win+N, Win+B, Win+D), so **Win+L (lock) is left unbound on
  purpose**: never bind it. Win+R is in `windots-hotkeys.ahk`: the launcher's `run` route (the launcher with `> ` typed; falls
  back to the real Run dialog when the launcher is not installed). When testing, do not simulate `Win+Q` / `Win+W` on a live desktop: they close windows.
- US/US-Intl `/` is `oem_2`; `-` / `=` are `oem_minus` / `oem_plus`.
- After editing: `windots restart whkd` (it refreshes the PATH first, or `windots-*`
  commands aren't found), then verify that `Win+number` still switches workspaces. The
  first key right after a restart is sometimes dropped: retry before concluding.
- Check conflicts with herdr-app (`default/herdr-app/keys.json`, `default/retropet/keys.json`)
  and the launcher hotkeys in `windots-hotkeys.ahk`. Win+number belongs to komorebi workspaces.
- Hotkeys that open the windots-launcher (`Win+Space` the root menu, `Win+Alt+Space` the launcher: apps first, `Win+K`
  the keybindings, `Win+Ctrl+Shift+Space` the themes) live in `windots-hotkeys.ahk`, not in whkd: whkd starts a `pwsh`
  for every hotkey (~300 ms) and AutoHotkey is resident. They write `verb<TAB>route` to the launcher's named pipe
  `windots-launcher` (a few ms); starting `windots-launcher.exe` costs a whole .NET process (~300 ms) and is only the
  fallback. Never bind the same key in both, or the menu toggles open and shut. A `; description` after a hotkey in the
  .ahk file is what the Win+K menu shows for it. `Alt+Space` is free (Flow Launcher, which used it, is gone).

**Window corners**
- Windows 11 rounds every window, which clashes with komorebi's square borders. There is no setting for it: no registry
  value (none in the DWM keys or in udwm.dll / dwmcore.dll), no policy. What exists is DWM's corner preference per window,
  `DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWCP_DONOTROUND = 1)`, which works on a window of
  another process. `windots-hotkeys.ahk` sets it on every top-level window: a shell hook (`HSHELL_WINDOWCREATED`) for new
  ones and `EnumWindows` at start for the ones open. Not `WinGetList`: komorebi cloaks the windows of the other
  workspaces and it does not list them. Windhawk's "disable rounded corners" mod needs injection into dwm.exe, which is
  why this is not used. Windows already open stay square after the script stops; a new one is round until it runs again.

**komorebi**
- Float override only has a *toggle*; `windots-launch-float` serializes it with a
  mutex and only turns it off if it turned it on. Don't toggle it elsewhere.
- Workspaces have a Tiling and a Floating *layer*; a workspace left on Floating
  makes every new window float (`komorebic state` -> `layer`).
- `windots-float-ontop` keeps floating windows above tiled ones (named pipe
  subscription); monocle has its own border colour.
- `windots-launch-workspaces` opens the apps in `~\.config\windots\workspaces.json` (per machine and never
  versioned: the apps of one machine must not open on another; `default/komorebi/` has an example) and sends each window to its workspace with `komorebic
  send-to-monitor-workspace` (it moves the *focused* window, so the new one is focused and
  checked first). It registers no komorebi workspace rule on purpose: `komorebic state` doesn't
  show rules and `clear-workspace-rules` wipes a workspace's rules, the person's too. After
  `toggle-float-override` it waits until the state says it is on (komorebi reads the toggle
  late; an app that opens fast beats it). Test it with a throwaway `--config` and an app komorebi
  manages (Notepad): it moves focus and opens windows, so close what you open.
- The hidden window of an AutoHotkey v2 script (`AutoHotkey64.exe`) is ignored in `applications.json`; without it, restarting
  the script tiled that invisible window and took half of the workspace.
- `windots restart komorebi` manages every window again (tiles redone, floating overrides
  and workspace layers lost) and restarts what subscribes to it (komorebi-switcher,
  `windots-float-ontop`): don't run it on the person's desktop just to test.

**WSL** (`bin/windots-setup-wsl.ps1`)
- A restart is needed only when WSL is installed and no hypervisor is running yet
  (`Win32_ComputerSystem.HypervisorPresent`). Then the script writes a `RunOnce` entry that
  continues it at the next sign-in (`--resumed`, never `--reinstall`, never a password). When
  WSL is installed, nothing is pending and there is still no hypervisor, virtualization is off
  in the firmware: it says so and stops WITHOUT scheduling a resume, or it would loop forever.
- Network: `--network=mirrored` is the supported way. `bridged` (own IP) is deprecated since WSL
  2.4.5 and needs a Hyper-V external switch, which Windows Home does not have: don't add it.
  Mirrored shares the Windows port space (a WSL sshd cannot take 22 while the Windows sshd has it).
- A bash script piped to `wsl --exec bash` from PowerShell gets a CRLF at the end: strip CR inside
  Linux (`tr -d '\r'`), or the last command is `locale-gen\r: command not found`.
- PowerShell hands `--lan-ports=22,8080` over as a list when typed unquoted: `windots-setup-wsl`
  joins lists back; do the same for any option whose value has a comma.

**Startup items** are only created by `windots-refresh-autostart`. Agents are
often not allowed to create them: change the script, then ask the person to run
`pwsh -NoProfile -ExecutionPolicy Bypass -File ~/windots/bin/windots-refresh-autostart.ps1`.

**Never version secrets or personal data**: `~\.atuin\data` (key, history),
`~\.config\omapass` (`.history_key`), herdr-app's
`view.json` / `window.json` / generated `*.d.ts` / `jsconfig.json`.

## Themes

Themes are omarchy's: `default/themes/<name>/colors.toml`, applied by `windots-theme-set` (no name =
the current one again, which `windots-install` does). Add or update a theme by copying its
`colors.toml` from `omacom/omarchy` (`themes/<name>/`); keys a theme lacks (`orange`, `brown`,
`muted`...) get the fallbacks in `Read-ThemeColors` (`bin/lib/themes.ps1`). A new thing to theme is a new
`Set-*` function there plus a call in `windots-theme-set`: derive its colours from the palette with
the mapping omarchy's template for that app uses (`default/themed/*.tpl` in omarchy), never by hand.
- Taskbar: omarchy's bar uses `background`, `foreground`, `red`. Windows only takes a solid
  background (Windhawk Taskbar Styler, `Fill=<background>`; the accent palette comes out ~18%
  darker and TranslucentTB fails to hook the taskbar on Windows build 26340), so the text is made
  readable by turning `SystemUsesLightTheme` and `AppsUseLightTheme` on for `mode = light` (Explorer
  must restart to show it). A new colour shows within seconds; a mod that was not installed before
  needs an Explorer restart.
- The Windhawk settings are in HKLM. By the person's choice `windots install windhawk` grants this user `SetValue` on
  the mod's keys (`--allow-user-settings` is the default), so a theme switch needs no UAC; any process of this user
  can then restyle the taskbar, a trade-off accepted on purpose. `--block-user-settings` undoes it and is remembered
  (`~\.local\state\windots\windhawk-no-user-settings`). Windhawk's ACLs are not canonical: edit them as SDDL, never
  with `AddAccessRule`; and write the values through .NET `OpenSubKey(.., SetValue)`, not `Set-ItemProperty` (the
  provider asks for more rights than granted). A new colour needs no Windhawk or Explorer restart (measured ~0.3 s).
- The taskbar shows no app buttons: a second Taskbar Styler rule (`Taskbar.TaskListButton`, `Visibility=Collapsed`, in
  `default/windhawk/taskbar-styler.json`) hides pinned and running apps alike, leaving search, tray and the komorebi-switcher
  workspaces; Windows has no setting for it. Remove that entry to bring the buttons back (`windots install windhawk`).
- komorebi-switcher: upstream cannot place itself in the taskbar and shows every workspace, so windots ships its own build:
  the `v0.10.4` tag + `default/komorebi-switcher/windots.patch` (new keys in the toml: `alignment = left|center|right`, which
  finds the Start button and the tray through UI Automation (Windows 11 draws both in XAML, no handles; `src/windows/anchors.rs`)
  and re-places the switcher whenever its width or the taskbar changes, ignoring the monitor's `x`; and `persistent_workspaces = N`:
  1..N always shown, the others only while busy or focused, empty ones dimmed). It also reads the toml again within ~2 s
  of a change on disk (release `-windots.2` on, or a local build): `windots-theme-set` and the installer then do not restart it
  (`Test-SwitcherLiveReload`, from the marker `~\.local\state\windots\komorebi-switcher.release`). There is no centering script any more
  (`windots-center-switcher` is gone: windots is opinionated, one layout). The build comes from a release of this repo made by
  `.github/workflows/komorebi-switcher.yml` when a tag `komorebi-switcher-v<upstream>-windots.<n>` is pushed (a change to the patch
  means a new tag); `windots install komorebi switcher` downloads the newest one (SHA-256 checked), `--build` compiles locally with a
  lighter profile (env `CARGO_PROFILE_RELEASE_LTO=thin`, codegen units 16: same program, a bigger exe). To change the
  patch: edit a clean checkout of the tag (`git clone --branch v0.10.4 https://github.com/amrbashir/komorebi-switcher`), `git add -N`
  new files, `git diff -- src Cargo.toml > default/komorebi-switcher/windots.patch`, and check `git apply --check` on a clean tag. If
  the switcher logs "Found 0 taskbars" (an empty bar), Explorer was the cause: `windots restart explorer`.
- komorebi-switcher colours: only `[colors] active_indicator` / `busy_indicator` exist (text and
  background follow Windows); the file is per machine, so only its `[colors]` table is rewritten.
- Windows Terminal: scheme and UI theme named `windots`, set with `Set-JsonProperty` (plain
  assignment): `Add-Member -Force` moves the property to the end, the file changes every run and a
  backup piles up each time. Compare the JSON before and after and write only on a change.
- Neovim: the theme is `lua/plugins/theme.lua` in the LazyVim config, as in omarchy (a symlink to the current theme's
  neovim.lua there; here a copy, written by `Set-NeovimTheme` in `bin/lib/themes.ps1`: the theme's own `neovim.lua`, or
  the aether template with the palette). Write it with ONE file replace (`Move-Item -Force` of a temp file): lazy.nvim's
  change detection sees it, fires `LazyReload`, and omarchy's `omarchy-theme-hotreload.lua` applies the colorscheme in
  every open Neovim. The installer never replaces the person's config: it merges (`lazyvim.json` extras, three lines in
  `options.lua`) and backs up what it overwrites as `<file>.bak.<unix time>`. Try it beside the real one with
  `windots install lazyvim --appname nvim-test` (`NVIM_APPNAME`), then delete `nvim-test` and `nvim-test-data`.
- Files (files.community) is the file manager that takes the theme everywhere. Explorer cannot: Windhawk's File Explorer Styler
  only reaches the XAML parts (tabs, bars, details pane); the file list and sidebar are Win32 (tested, and the mod's own guide
  says so). So the Explorer mod was dropped and `windots-install-files` makes Files the default file manager (the same HKCU
  `.reg` Files' own Settings > Advanced switch imports: no UAC; Win+E and folders open Files; `explorer.exe` keeps running as
  the shell). The colours are `AppTheme*BackgroundColor` / `AppThemeMode` in `LocalState\settings\user_settings.json`,
  edited as text (`Set-FilesTheme`, `bin\lib\themes.ps1`) with catppuccin's own mapping. A running Files ignores a file edit
  (measured, 40 s) and reads it only at start: `Update-FilesTheme` restarts it, or with `--no-restart` sends a toast
  (`windots-notify`) whose click opens `windots:restart-files` (`windots-uri.ps1`, a whitelist: never run anything else from
  a link). Live theming would mean a fork of Files; not done.
- komorebi borders follow the theme like omarchy's Hyprland ones (`Set-KomorebiBorders`, `windots-theme-borders`): active, stack
  and floating = the theme's `hyprland_active_border` (first colour of the gradient) or its accent, monocle = its orange,
  unfocused = `hyprland_inactive_border` or #595959. `komorebic border-colour` changes them in the running komorebi, so a theme
  switch restarts nothing; komorebi starts with the colours of komorebi.json, so `windots-float-ontop` (it runs while komorebi
  does) applies the current theme's whenever it connects. Animation: 180 ms (`animation.duration` in komorebi.json; live with
  `komorebic animation-duration 180`).
- Not themed yet (still Catppuccin Mocha): btop, atuin, fzf, starship, herdr-app. Official catppuccin ports are used there
  until they are.
- Never write a `\` + letter inside a string you hand to a tool as an escape-processed argument:
  `lib\themes.ps1` once arrived as `lib<TAB>hemes.ps1`. Use the Write/Edit tools for paths.
Font: JetBrainsMonoNL Nerd Font (`windots-install-font`).

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
