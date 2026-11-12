# windots

Dotfiles do Windows, gerenciados com [tuckr](https://github.com/RaphGL/Tuckr).

## Grupos (`Configs/`)

| Grupo | Arquivos (relativos a `~`) |
|---|---|
| `pwsh` | `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` |
| `mise` | `.config/mise/config.toml` (atuin, starship, neovim, lazygit, lazydocker, claude) |
| `starship` | `.config/starship.toml` (config do omarchy) |
| `komorebi` | `komorebi.json`, `applications.json`, `.config/whkdrc`, `.config/komorebi-switcher.toml` |
| `autostart` | `.config/sem-menu-iniciar.ahk` |
| `herdr-app` | `.config/herdr-app/keys.json` (omarchy), `settings.json`, `themes/` (catppuccin) |

Os atalhos da pasta Inicializar são gerados pelo `autostart.ps1` (komorebi, komorebi-switcher, Flow Launcher, sem-menu-iniciar.ahk).

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
   .\install.ps1
   ```

O script:
- ativa o Modo de Desenvolvedor e o sudo no modo embutido (pede UAC uma vez) e deixa a barra de tarefas no topo, pequena, alinhada à esquerda e sem Visão de Tarefas/Widgets/Copilot (`-SkipSystem` pula essa parte);
- instala os pacotes do winget, o komorebi-switcher (release do GitHub) e o herdr-app (instalador oficial, que também instala o herdr-core);
- cria a junction `%APPDATA%\dotfiles` → este repositório (onde o tuckr procura);
- faz backup (`*.pre-windots`) dos arquivos que vai substituir e roda `tuckr add`;
- roda `mise install` e recria os atalhos de inicialização.

## Uso diário

```powershell
tuckr status              # o que está linkado
tuckr add <grupo>         # linka um grupo
tuckr rm <grupo>          # remove os links de um grupo
tuckr push <grupo> <arq>  # adiciona um arquivo novo a um grupo
```
