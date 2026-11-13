# windots

Dotfiles do Windows, gerenciados com [tuckr](https://github.com/RaphGL/Tuckr), imitando o [omarchy](https://github.com/basecamp/omarchy) (Super vira Alt).

Para agentes de código: [`AGENTS.md`](AGENTS.md) (estrutura, convenções e armadilhas) e a skill `windots` (grupo `claude`), com o passo a passo das tarefas comuns.

## Grupos (`Configs/`)

| Grupo | Arquivos (relativos a `~`) |
|---|---|
| `pwsh` | `.config/powershell/profile.ps1` (mise, starship, atuin e zoxide no `cd`), `catppuccin-fzf-mocha.ps1` (cores do fzf); o `windots-install` põe no `$PROFILE` (em Documentos) só uma linha que carrega esse arquivo; o módulo [Catppuccin](https://github.com/catppuccin/powershell) é clonado pelo `windots-reinstall-pkgs` em `~\.local\share\powershell\Modules` |
| `atuin` | `.atuin/config.toml`, `.atuin/themes/catppuccin-mocha-blue.toml` |
| `btop` | `btop.conf` e `themes/catppuccin_mocha.theme` na pasta do btop4win (`AppData/Local/Microsoft/WinGet/Packages/aristocratos.btop4win_…/btop4win/`) |
| `claude` | skills do Claude Code em `.claude/skills/`: `windots` (mexer neste setup: atalhos, apps, grupos, comandos, temas) e `commit-message` (mensagens de commit semânticas) |
| `windows-terminal` | fragment `AppData/Local/Microsoft/Windows Terminal/Fragments/windots/windots.json`: esquema Catppuccin Mocha e o perfil oculto `windots-tui` |
| `mise` | `.config/mise/config.toml` (atuin, starship, fzf, fd, ripgrep, zoxide, neovim, lazygit, lazydocker, claude, go, node, npm, rust) |
| `starship` | `.config/starship.toml` (config do omarchy) |
| `komorebi` | `komorebi.json`, `applications.json`, `.config/whkdrc`, `.config/komorebi-switcher.toml` |
| `backgrounds` | `.config/windots/backgrounds/catppuccin/` (12 imagens do dot-omarchy), como o `~/.config/omarchy/backgrounds` |

Nada fica em Documentos, Imagens ou Área de Trabalho: o OneDrive faz backup (e às vezes redireciona) essas pastas, o que dá conflito com links. Tudo vai em `~\.config`, como no omarchy.

## Comandos (`bin/`)

Como o `bin` do omarchy: o `windots-install` põe `~\windots\bin` no PATH e os scripts viram comandos. Como no `omarchy`, há um comando central: `windots update -y` é o mesmo que `windots-update -y`, `windots` sozinho mostra a ajuda, `windots <grupo>` lista os comandos do grupo (ex.: `windots install`) e todo comando aceita `--help` / `-h`.

| Comando | O que faz |
|---|---|
| `windots [comando] [args]` | como o `omarchy`: chama o `windots-*` pelas palavras (`windots install font` → `windots-install-font`); sem argumentos, mostra a ajuda com os grupos |
| `windots-commands [--json]` | como o `omarchy commands`: lista todos os comandos com uso e descrição, lidos das linhas `# windots:` no topo de cada script |
| `windots-launch-or-focus [--float] <regex> [comando]` | como o `focus = "^(app)$"` do omarchy: foca a janela cujo exe ou título casa com a regex, indo até o workspace dela; se não estiver aberta, abre (`--float`: flutuante) |
| `windots-launch-tui [--float] [--title=<t>] <comando>` | como o `omarchy-launch-tui`: abre um TUI numa janela de terminal própria (perfil `windots-tui`, Catppuccin Mocha sem margem), sem barra de título nem abas, com título fixo (padrão: o nome do comando) |
| `windots-launch-or-focus-tui [--float] [--title=<t>] <comando>` | como o `omarchy-launch-or-focus-tui`: foca a janela do TUI pelo título; se não estiver aberta, chama o `windots-launch-tui` |
| `windots-launch-float <comando>` | abre o comando flutuante, centralizado, sempre em 875×600 (o tamanho do omarchy) |
| `windots-float-ontop` | roda em segundo plano: janelas flutuantes ficam sempre acima das em tile |
| `windots-hotkeys.ahk` | atalhos que o whkd não faz (AutoHotkey v2): Win não abre o Iniciar, Alt+arrastar move/redimensiona janelas, Alt+Shift+/ no teclado ABNT2 |
| `windots-install-backgrounds` | lista os backgrounds em Configurações → Personalização: um tema `windots <pasta>` (slideshow com todas as imagens, mantendo modo escuro e cor de destaque) e 5 imagens em "Imagens recentes" |
| `windots-install-font [--pick | nome]` | como o `omarchy-install-font`: sem nome, abre a lista de fontes no fzf como TUI flutuante (Alt+Ctrl+Shift+F); instala uma Nerd Font do release mais recente do [nerd-fonts](https://github.com/ryanoasis/nerd-fonts) só para o usuário, sem admin (padrão: JetBrainsMono; o Windows Terminal e o herdr-app usam a variação `JetBrainsMonoNL Nerd Font`) |
| `windots-install-flow-launcher` | aplica no `Settings.json` do Flow Launcher os atalhos de `default/flow-launcher` (Alt+Esc menu do sistema, Win+Alt+Space apps, Ctrl+Alt+Space plugins) e as palavras-chave `sys`/`app`, com backup; não é link do tuckr porque o Flow substitui o arquivo ao salvar |
| `windots-install-herdr-app` | o herdr-app regrava `keys.json` e `settings.json` enquanto roda, então eles não são links: o script mescla `default/herdr-app` (binds do omarchy, fonte) com os binds do retropet e grava os dois (com backup). O [retropet](https://github.com/higorhgon/retropet) é o submódulo `default/retropet`: layout, mods e tema são **copiados** arquivo por arquivo para `~\.config\herdr-app` (o herdr-app recusa um mod cujos arquivos resolvem para fora da pasta dele, o que um link para o submódulo faz), sem mexer nos mods e temas que o próprio herdr-app instala. Reinicie o herdr-app para carregar |
| `windots-install-windows-terminal` | aplica o Catppuccin Mocha no Windows Terminal: o tema da interface (`default/windows-terminal`) e o esquema de cores em todos os perfis, editando o `settings.json` (com backup) no que um fragment não alcança |
| `windots-toggle-fullscreen` | como o Super+F do omarchy (aqui Alt+F): a janela em foco ocupa o monitor inteiro, cobrindo a barra do Windows; de novo, volta ao tamanho, posição e tile de antes |
| `windots-toggle-dark-mode [light\|dark]` | alterna o Windows entre modo escuro e claro (ou define um); mexe direto no registro, então funciona com o Windows não ativado |
| `windots-menu-keybindings [--list]` | como o Super+K do omarchy (aqui Alt+K): lista com busca de todos os atalhos (whkd + AutoHotkey) no fzf, num terminal flutuante; Enter executa o atalho escolhido |
| `windots-center-switcher` | centraliza o komorebi-switcher na barra de tarefas de cada monitor desta máquina; o `komorebi-switcher.toml` guarda uma seção por monitor, então o mesmo arquivo serve para o PC e o notebook |
| `windots-setup-security-sudo [--enable-sudo \| --disable-sudo \| --status]` | liga o sudo do Windows (modo inline, igual a Configurações > Sistema > Avançado > Habilitar sudo > Em linha). É a base dos comandos que precisam de admin (`windots-setup-security-ssh`, winget): um UAC por comando e a saída fica no mesmo terminal. Este é o único script que pede UAC direto, porque o sudo não liga o próprio sudo; sem nada para mudar, não pergunta nada. O `windots-install` chama |
| `windots-setup-security-ssh [--enable-ssh \| --disabled-ssh \| --status \| --allow-user-links \| --block-user-links] [--shell=pwsh\|powershell\|cmd]` | como `omarchy-setup-security-sshd` / `omarchy-remove-security-sshd`: confere se o cliente e o servidor OpenSSH (recursos opcionais do Windows) estão instalados e instala o que faltar, liga o `sshd` (inicia com o Windows) e abre a porta 22. `--disabled-ssh` (ou `--disable-ssh`) para o serviço, desativa e fecha a porta (o cliente fica); `--status` mostra instalação, serviço, firewall, rede, usuário, IP e chaves. Precisa de admin: usa o sudo (e liga o sudo antes, se estiver desligado). A regra de firewall do Windows vale só para redes **Privadas**: numa rede Pública o ssh fica bloqueado de propósito `--shell` define o shell de um login ssh (padrão `pwsh`; o do Windows é o `cmd`; a escolha é testada antes de gravar, e `--shell=cmd` volta ao padrão). `--allow-user-links` desliga o RedirectionGuard só para o `sshd.exe` e reinicia o `sshd`, para sessões ssh seguirem links e junctions (o `mise.exe` do winget, as junctions `latest` do mise); é uma troca de segurança consciente, nunca feita sozinha, e o `--block-user-links` desfaz. Uma atualização do OpenSSH pode religar a proteção |
| `windots-setup-security-network-trust [--trust \| --untrust \| --status]` | marca a rede atual (a da rota padrão) como Privada, ou volta para Pública com `--untrust`; `--status` lista as redes conectadas e a categoria de cada uma. O firewall do `sshd` só vale em rede Privada, então numa rede Pública o ssh fica bloqueado. O Windows guarda a categoria por rede (faça uma vez em cada rede em que confia). Precisa de admin (usa o sudo). Cuidado: Privada deixa todos os dispositivos da rede alcançarem o computador, visitantes de um Wi-Fi compartilhado inclusive; prefira chave SSH à senha |
| `windots-refresh-autostart` | recria os atalhos da pasta Inicializar (komorebi + masir, komorebi-switcher, Flow Launcher, float-ontop, center-switcher, hotkeys) |
| `windots-update [-y] [--prune]` | como o `omarchy-update`: atualiza o repositório (`git pull`), os pacotes do winget, reaplica o windots (`windots-install -SkipPackages -SkipSystem`), atualiza as ferramentas do mise (com `--prune`, também apaga as versões antigas delas com `mise prune`, liberando espaço) e oferece reiniciar se o Windows pedir; `-y` não pergunta nada; log em `%TEMP%\windots-update.log` |
| `windots-reinstall-pkgs` | como o `omarchy-reinstall-pkgs`: instala o que faltar dos apps padrão (winget de `default/packages.txt` com um único UAC, komorebi-switcher, herdr-app, módulo Catppuccin do PowerShell, ferramentas do mise) sem mexer em configurações; o que já está instalado fica como está |
| `windots-reinstall-configs [-y]` | como o `omarchy-reinstall-configs`: apaga o que estiver em `~` no lugar de cada dotfile (cópias, links antigos, links para arquivos que saíram do repositório), guarda backup (`.bak.<tempo>`) do que for diferente do repositório e linka tudo de novo com o `windots-install -SkipPackages -SkipSystem`; use quando algo ficou em conflito |
| `windots-update-herdr-app [--app] [--retropet]` | `--app` (padrão) atualiza o herdr-app com o instalador oficial (pula se ele estiver aberto); `--retropet` leva o submódulo `default/retropet` ao último commit do GitHub e copia de novo, mostrando o comando para registrar o novo commit no windots (nunca commita sozinho). O `windots-update` roda a parte `--app` |
| `windots-update-winget` | `winget upgrade --all` sem nenhuma pergunta (como `pacman -Syu --noconfirm`), com um único UAC via sudo |

## Instalação numa máquina nova

Tudo no **Windows PowerShell** que vem com o Windows (o PowerShell 7 é instalado pelo script).

1. **Libere a execução de scripts** para o seu usuário (o Windows vem bloqueando por padrão):

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

   Confira com `Get-ExecutionPolicy -List` (a linha `CurrentUser` deve mostrar `RemoteSigned`).

2. **Instale o git e clone** o repositório em `~\windots`:

   ```powershell
   winget install --id Git.Git -e
   # feche e abra o PowerShell para o git entrar no PATH
   git clone --recurse-submodules https://github.com/higorhgon/windots.git $HOME\windots
   ```

   Se baixar como `.zip` em vez de clonar, desbloqueie os arquivos antes: `Get-ChildItem ~\windots -Recurse | Unblock-File`.

3. **Rode o instalador:**

   ```powershell
   cd ~\windots
   .\bin\windots-install.ps1
   ```

   - Aparece **um aviso do UAC**: aceite (Modo de Desenvolvedor e sudo).
   - A barra de tarefas pisca: o Explorer reinicia para ela ir para o topo, pequena.

4. **Reinicie** (ou saia e entre de novo). Sobem sozinhos: komorebi + whkd + masir, komorebi-switcher, Flow Launcher, AutoHotkey (`windots-hotkeys`) e `windots-float-ontop`.

5. **Ajustes depois do primeiro login:**
   - Se a instalação avisou *settings.json not found*, o Windows Terminal e/ou o Flow Launcher ainda não tinham sido abertos: abra cada um uma vez e rode `windots-install-windows-terminal` e `windots-install-flow-launcher`.
   - **Centralize o komorebi-switcher** neste monitor: `windots-center-switcher`. Ele mede a barra de tarefas e o switcher (já considerando a escala da tela), grava a posição no `komorebi-switcher.toml` mantendo a seção de outras máquinas, e reinicia o switcher. Isso já acontece sozinho: o `windots-install` roda o script e um atalho de inicialização (`windots-center-switcher --wait`) roda no login, esperando o komorebi subir; numa máquina nova o switcher fica centralizado após a primeira reinicialização, e depois nada muda (sem reiniciar o switcher à toa).

Depois da primeira vez, o `bin` já está no PATH e dá para rodar de novo só o que faltou: `windots-install -SkipPackages` (sem downloads) ou `windots-install -SkipSystem` (sem UAC nem barra de tarefas).

### O que o `windots-install` faz, em ordem

1. Ativa o Modo de Desenvolvedor e o sudo embutido (um UAC) e deixa a barra de tarefas no topo, pequena, alinhada à esquerda e sem Visão de Tarefas/Widgets/Copilot (`-SkipSystem` pula).
2. `windots-reinstall-pkgs`: instala os apps do winget listados em `default/packages.txt`, o komorebi-switcher (release do GitHub) e o herdr-app (instalador oficial, que também instala o herdr-core) (`-SkipPackages` pula).
3. Põe `~\windots\bin` no PATH.
4. Cria a junction `%APPDATA%\dotfiles` → este repositório (onde o tuckr procura).
5. Faz backup (`*.pre-windots`) dos arquivos que vai substituir e roda `tuckr add` em todos os grupos. Depois aponta cada link direto para o arquivo do repo, sem passar pela junction: sessões SSH não atravessam links nem junctions criados por usuário comum (erro "untrusted mount point").
6. `windots-install-backgrounds`, `windots-install-font JetBrainsMono` (só se ainda não estiver instalada), `windots-install-windows-terminal`, `windots-install-herdr-app` (keys/settings mesclados e retropet copiado) e `windots-install-flow-launcher`.
7. `mise install` e `windots-refresh-autostart`.

## Uso diário

```powershell
windots                   # ajuda: grupos e comandos
windots update            # atualiza tudo (windots, winget, mise); --prune libera espaço
tuckr status              # o que está linkado
tuckr add <grupo>         # linka um grupo
tuckr rm <grupo>          # remove os links de um grupo
tuckr push <grupo> <arq>  # adiciona um arquivo novo a um grupo
```

## Temas

Tudo em Catppuccin Mocha, com os temas oficiais: [PowerShell](https://github.com/catppuccin/powershell), [Windows Terminal](https://github.com/catppuccin/windows-terminal), [btop](https://github.com/catppuccin/btop), [fzf](https://github.com/catppuccin/fzf) e [atuin](https://github.com/catppuccin/atuin) (acento blue). O tema de interface do Windows Terminal fica em `default/windows-terminal/`, porque não vai num fragment.
