# windots

Dotfiles do Windows, gerenciados com [tuckr](https://github.com/RaphGL/Tuckr).

## Grupos (`Configs/`)

| Grupo | Arquivos (relativos a `~`) |
|---|---|
| `pwsh` | `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` |
| `mise` | `.config/mise/config.toml` (atuin, starship, neovim, lazygit, lazydocker, claude) |
| `starship` | `.config/starship.toml` (config do omarchy) |
| `komorebi` | `komorebi.json`, `applications.json`, `.config/whkdrc`, `.config/komorebi-switcher.toml` |
| `herdr-app` | `.config/herdr-app/keys.json` (omarchy), `settings.json`, `themes/` (catppuccin) |

## Comandos (`bin/`)

Como o `bin` do omarchy: o `windots-install` põe `~\windots\bin` no PATH e os scripts viram comandos.

| Comando | O que faz |
|---|---|
| `windots-launch-or-focus [--float] <regex> [comando]` | como o `focus = "^(app)$"` do omarchy: foca a janela cujo exe ou título casa com a regex, indo até o workspace dela; se não estiver aberta, abre (`--float`: flutuante) |
| `windots-launch-float <comando>` | abre o comando flutuante, centralizado, sempre em 875×600 (o tamanho do omarchy) |
| `windots-float-ontop` | roda em segundo plano: janelas flutuantes ficam sempre acima das em tile |
| `windots-block-start-menu.ahk` | impede a tecla Win de abrir o menu Iniciar (AutoHotkey v2) |
| `windots-refresh-autostart` | recria os atalhos da pasta Inicializar (komorebi + masir, komorebi-switcher, Flow Launcher, float-ontop, block-start-menu) |

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
- roda `mise install` e recria os atalhos de inicialização (`windots-refresh-autostart`).

## Uso diário

```powershell
tuckr status              # o que está linkado
tuckr add <grupo>         # linka um grupo
tuckr rm <grupo>          # remove os links de um grupo
tuckr push <grupo> <arq>  # adiciona um arquivo novo a um grupo
```
