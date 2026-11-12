# windots

Dotfiles do Windows, gerenciados com [tuckr](https://github.com/RaphGL/Tuckr).

## Grupos (`Configs/`)

| Grupo | Arquivos (relativos a `~`) |
|---|---|
| `pwsh` | `Documents/PowerShell/Microsoft.PowerShell_profile.ps1`, `catppuccin-fzf-mocha.ps1` (cores do fzf) |
| `atuin` | `.atuin/config.toml`, `.atuin/themes/catppuccin-mocha-blue.toml` |
| `btop` | `btop.conf` e `themes/catppuccin_mocha.theme` na pasta do btop4win (`AppData/Local/Microsoft/WinGet/Packages/aristocratos.btop4win_…/btop4win/`) |
| `windows-terminal` | fragment `AppData/Local/Microsoft/Windows Terminal/Fragments/windots/windots.json`: esquema Catppuccin Mocha e o perfil oculto `windots-tui` |
| `mise` | `.config/mise/config.toml` (atuin, starship, fzf, neovim, lazygit, lazydocker, claude) |
| `starship` | `.config/starship.toml` (config do omarchy) |
| `komorebi` | `komorebi.json`, `applications.json`, `.config/whkdrc`, `.config/komorebi-switcher.toml` |
| `backgrounds` | `Pictures/Wallpapers/catppuccin/` (12 imagens do dot-omarchy) |
| `herdr-app` | `.config/herdr-app/keys.json` (omarchy + retropet), `settings.json`, `themes/` (catppuccin, retropet), layout `retropet` (`layouts/`, `mods/retropet-*`) |

## Comandos (`bin/`)

Como o `bin` do omarchy: o `windots-install` põe `~\windots\bin` no PATH e os scripts viram comandos.

| Comando | O que faz |
|---|---|
| `windots-launch-or-focus [--float] <regex> [comando]` | como o `focus = "^(app)$"` do omarchy: foca a janela cujo exe ou título casa com a regex, indo até o workspace dela; se não estiver aberta, abre (`--float`: flutuante) |
| `windots-launch-tui [--float] [--title=<t>] <comando>` | como o `omarchy-launch-tui`: abre um TUI numa janela de terminal própria (perfil `windots-tui`, Catppuccin Mocha sem margem), sem barra de título nem abas, com título fixo (padrão: o nome do comando) |
| `windots-launch-or-focus-tui [--float] [--title=<t>] <comando>` | como o `omarchy-launch-or-focus-tui`: foca a janela do TUI pelo título; se não estiver aberta, chama o `windots-launch-tui` |
| `windots-launch-float <comando>` | abre o comando flutuante, centralizado, sempre em 875×600 (o tamanho do omarchy) |
| `windots-float-ontop` | roda em segundo plano: janelas flutuantes ficam sempre acima das em tile |
| `windots-hotkeys.ahk` | atalhos que o whkd não faz (AutoHotkey v2): Win não abre o Iniciar, Alt+arrastar move/redimensiona janelas, Alt+Shift+/ no teclado ABNT2 |
| `windots-install-backgrounds` | lista os backgrounds em Configurações → Personalização: um tema `windots <pasta>` (slideshow com todas as imagens, mantendo modo escuro e cor de destaque) e 5 imagens em "Imagens recentes" |
| `windots-install-font [--pick | nome]` | como o `omarchy-install-font`: sem nome, abre a lista de fontes no fzf como TUI flutuante (Alt+Ctrl+Shift+F); instala uma Nerd Font do release mais recente do [nerd-fonts](https://github.com/ryanoasis/nerd-fonts) só para o usuário, sem admin (padrão: JetBrainsMono; o Windows Terminal e o herdr-app usam a variação `JetBrainsMonoNL Nerd Font`) |
| `windots-install-flow-launcher` | aplica no `Settings.json` do Flow Launcher os atalhos de `default/flow-launcher` (Alt+Esc menu do sistema, Win+Alt+Space apps, Ctrl+Alt+Space plugins) e as palavras-chave `sys`/`app`, com backup; não é link do tuckr porque o Flow substitui o arquivo ao salvar |
| `windots-install-windows-terminal` | aplica o Catppuccin Mocha no Windows Terminal: o tema da interface (`default/windows-terminal`) e o esquema de cores em todos os perfis, editando o `settings.json` (com backup) no que um fragment não alcança |
| `windots-toggle-fullscreen` | como o Super+F do omarchy (aqui Alt+F): a janela em foco ocupa o monitor inteiro, cobrindo a barra do Windows; de novo, volta ao tamanho, posição e tile de antes |
| `windots-toggle-dark-mode [light\|dark]` | alterna o Windows entre modo escuro e claro (ou define um); mexe direto no registro, então funciona com o Windows não ativado |
| `windots-menu-keybindings [--list]` | como o Super+K do omarchy (aqui Alt+K): lista com busca de todos os atalhos (whkd + AutoHotkey) no fzf, num terminal flutuante; Enter executa o atalho escolhido |
| `windots-refresh-autostart` | recria os atalhos da pasta Inicializar (komorebi + masir, komorebi-switcher, Flow Launcher, float-ontop, hotkeys) |

## Instalação

1. Ative o **Modo de Desenvolvedor** (Configurações → Sistema → Avançado), necessário para symlinks.
2. Libere a execução de scripts para o seu usuário (o Windows vem bloqueando por padrão):

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

   Confira com `Get-ExecutionPolicy -List` (a linha `CurrentUser` deve mostrar `RemoteSigned`).
   Se o repositório foi baixado como `.zip` em vez de clonado, desbloqueie os arquivos antes:

   ```powershell
   Get-ChildItem ~\windots -Recurse | Unblock-File
   ```

3. Clone em `~\windots` e rode:

   ```powershell
   cd ~\windots
   .\bin\windots-install.ps1
   ```

   Depois da primeira vez, o `bin` já está no PATH: basta `windots-install` (ex.: `windots-install -SkipPackages`).

O script:
- ativa o Modo de Desenvolvedor e o sudo no modo embutido (pede UAC uma vez) e deixa a barra de tarefas no topo, pequena, alinhada à esquerda e sem Visão de Tarefas/Widgets/Copilot (`-SkipSystem` pula essa parte);
- instala os pacotes do winget, o komorebi-switcher (release do GitHub) e o herdr-app (instalador oficial, que também instala o herdr-core);
- cria a junction `%APPDATA%\dotfiles` → este repositório (onde o tuckr procura);
- faz backup (`*.pre-windots`) dos arquivos que vai substituir e roda `tuckr add`;
- lista os backgrounds em Personalização (`windots-install-backgrounds`), aplica o Catppuccin no Windows Terminal (`windots-install-windows-terminal`), roda `mise install` e recria os atalhos de inicialização (`windots-refresh-autostart`).

## Uso diário

```powershell
tuckr status              # o que está linkado
tuckr add <grupo>         # linka um grupo
tuckr rm <grupo>          # remove os links de um grupo
tuckr push <grupo> <arq>  # adiciona um arquivo novo a um grupo
```

## Temas

Tudo em Catppuccin Mocha, com os temas oficiais: [PowerShell](https://github.com/catppuccin/powershell), [Windows Terminal](https://github.com/catppuccin/windows-terminal), [btop](https://github.com/catppuccin/btop), [fzf](https://github.com/catppuccin/fzf) e [atuin](https://github.com/catppuccin/atuin) (acento blue). O tema de interface do Windows Terminal fica em `default/windows-terminal/`, porque não vai num fragment.
