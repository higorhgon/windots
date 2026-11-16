# windots

Dotfiles do Windows, gerenciados com [tuckr](https://github.com/RaphGL/Tuckr), imitando o [omarchy](https://github.com/basecamp/omarchy) (Super vira a tecla Windows; `Win+L` continua do sistema e `Win+R` abre o lançador com `> ` já digitado).

Para agentes de código: [`AGENTS.md`](AGENTS.md) (estrutura, convenções e armadilhas) e a skill `windots` (grupo `claude`), com o passo a passo das tarefas comuns.

## Grupos (`Configs/`)

| Grupo | Arquivos (relativos a `~`) |
|---|---|
| `pwsh` | `.config/powershell/profile.ps1` (mise, starship, atuin e zoxide no `cd`), `catppuccin-fzf-mocha.ps1` (cores do fzf); o `windots-install` põe no `$PROFILE` (em Documentos) só uma linha que carrega esse arquivo; o módulo [Catppuccin](https://github.com/catppuccin/powershell) é clonado pelo `windots-reinstall-pkgs` em `~\.local\share\powershell\Modules` |
| `atuin` | `.atuin/config.toml`, `.atuin/themes/catppuccin-mocha-blue.toml` |
| `btop` | `btop.conf` e `themes/catppuccin_mocha.theme` na pasta do btop4win (`AppData/Local/Microsoft/WinGet/Packages/aristocratos.btop4win_…/btop4win/`) |
| `claude` | skills do Claude Code em `.claude/skills/`: `windots` (mexer neste setup: atalhos, apps, grupos, comandos, temas) e `commit-message` (mensagens de commit semânticas), e o `.claude/settings.json` (com `defaultShell: powershell`: os comandos `!` do Claude Code rodam no PowerShell em vez do Git Bash). Se o Claude Code regravar o arquivo e o link virar um arquivo comum, o próximo `windots install` refaz o link (a versão que ficou fora do repo vai para `.pre-windots`) |
| `windows-terminal` | fragment `AppData/Local/Microsoft/Windows Terminal/Fragments/windots/windots.json`: o esquema Catppuccin Mocha (o esquema `windots`, do tema atual, é gravado no `settings.json` pelo `windots-theme-set`) e o perfil oculto `windots-tui` |
| `mise` | `.config/mise/config.toml` (atuin, starship, fzf, fd, ripgrep, zoxide, neovim, lazygit, lazydocker, claude, go, node, npm, rust) |
| `starship` | `.config/starship.toml` (config do omarchy) |
| `komorebi` | `komorebi.json`, `applications.json`, `.config/whkdrc`. O `~\.config\komorebi-switcher.toml` não é linkado: é um arquivo por máquina (as cores vêm do tema, e o alinhamento e os workspaces fixos de `windots-install-komorebi-switcher`), criado a partir de `default/komorebi/komorebi-switcher.toml` |

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
| `windots-launch-files` | o atalho `Win+Shift+F` (o `Super+Shift+F` do omarchy abre o nautilus): foca o Files se estiver aberto ou o abre; sem o Files instalado abre o Explorer |
| `windots-float-ontop` | roda em segundo plano: janelas flutuantes ficam sempre acima das em tile |
| `windots-hotkeys.ahk` | atalhos que o whkd não faz (AutoHotkey v2): Win não abre o Iniciar, Win+arrastar move/redimensiona janelas, Win+Shift+/ no teclado ABNT2 |
| `windots-install-font [--pick | nome]` | como o `omarchy-install-font`: sem nome, abre a lista de fontes no fzf como TUI flutuante (Win+Ctrl+Shift+F); instala uma Nerd Font do release mais recente do [nerd-fonts](https://github.com/ryanoasis/nerd-fonts) só para o usuário, sem admin (padrão: JetBrainsMono; o Windows Terminal e o herdr-app usam a variação `JetBrainsMonoNL Nerd Font`) |
| `windots-install-herdr-app` | o herdr-app regrava `keys.json` e `settings.json` enquanto roda, então eles não são links: o script mescla `default/herdr-app` (binds do omarchy, fonte) com os binds do retropet e grava os dois (com backup). O [retropet](https://github.com/higorhgon/retropet) é o submódulo `default/retropet`: layout, mods e tema são **copiados** arquivo por arquivo para `~\.config\herdr-app` (o herdr-app recusa um mod cujos arquivos resolvem para fora da pasta dele, o que um link para o submódulo faz), sem mexer nos mods e temas que o próprio herdr-app instala. Reinicie o herdr-app para carregar |
| `windots-install-windows-terminal` | aplica o tema atual (`windots-theme-set`) e a fonte no Windows Terminal: grava o esquema de cores e o tema da interface `windots`, feitos da paleta do tema, e a fonte em todos os perfis, editando o `settings.json` (com backup, só quando algo muda) no que um fragment não alcança |
| `windots-install-windhawk [--color=#rrggbb] [--check] [--allow-user-settings \| --block-user-settings]` | instala o Windhawk (winget) e o mod Windows 11 Taskbar Styler sem abrir a janela dele: baixa de mods.windhawk.net a fonte e a DLL já compilada (os mesmos arquivos que a janela baixa), copia para `C:\ProgramData\Windhawk`, registra o mod em `HKLM\SOFTWARE\Windhawk` e grava as configurações de `default/windhawk/taskbar-styler.json` com a cor da barra de tarefas (padrão `#1e1e2e`, o Catppuccin Mocha). Pede admin (um UAC, via sudo), reinicia o Explorer só na primeira instalação do mod; uma troca de cor aparece em ~0,3 s e não reinicia nada. Idempotente; `--check` só mostra o estado. É o Windhawk porque o TranslucentTB não consegue se ligar à barra desta build do Windows e a paleta de destaque deixa a cor uns 18% mais escura. Por padrão (`--allow-user-settings`, escolha sua) o primeiro `windots install` dá a este usuário permissão de escrita (só `SetValue`) nas chaves do mod, e por isso os `windots theme set` seguintes não pedem UAC: uma troca de tema leva ~3 s. É uma troca de segurança deliberada: qualquer programa deste usuário pode mudar o estilo da barra. `--block-user-settings` tira a permissão e guarda a escolha (`~/.local/state/windots/windhawk-no-user-settings`), e as execuções seguintes não a dão de volta até você rodar `--allow-user-settings`. O `windots-install` roda este comando e o Windhawk também está em `default/packages.txt` |
| `windots-install-lazyvim [--appname <nome>] [--refresh] [--sync] [--skip-sync]` | o Neovim do omarchy, que é o LazyVim (pacote `omarchy-nvim`, em `omacom/omarchy-pkgs`), em `%LOCALAPPDATA%\nvim`. Sem configuração: clona o starter do LazyVim. Com um LazyVim já lá (o seu): mantém tudo e acrescenta os arquivos do omarchy (`default/lazyvim`): os extras dele (neo-tree) entram no `lazyvim.json` junto com os seus, três linhas no `options.lua` (clipboard remoto, `relativenumber` e `autoformat` desligados) e os plugins `all-themes`, `omarchy-theme-hotreload`, `lualine-transparent`, `disable-news-alert`, `snacks-animated-scrolling-off` e `plugin/after/transparency.lua`. Um arquivo que ele troca vira `<arquivo>.bak.<unix time>`. Uma configuração que não é LazyVim fica intocada; `--refresh` guarda a pasta como `nvim.backup.<data>` e começa do starter. Roda `Lazy! install` (só instala o que falta, não atualiza nada seu) quando a configuração mudou, ou com `--sync`, para o tema trocar sem baixar nada. `--appname` instala em outra pasta (`NVIM_APPNAME`), para testar ao lado da sua. O `windots-install` roda este comando |
| `windots-install-files [--default \| --no-default] [--skip-theme] [--no-restart] [--check]` | instala o [Files](https://files.community) (`FilesCommunity.Files`, winget), o gerenciador de arquivos que **recebe as cores do tema em tudo**, inclusive na lista de arquivos, que o Explorer do Windows não deixa estilizar nem com o Windhawk (só moldura, abas e barras). `--default` (o padrão) faz o mesmo que a chave de Configurações > Avançado do Files: copia o `Files.App.Launcher.exe` e os `.reg` do pacote para `%LOCALAPPDATA%\Files` e importa o `SetFilesAsDefault.reg`, que só escreve em HKCU (sem UAC): abrir pasta, `Win+E` e "mostrar na pasta" abrem o Files. O `explorer.exe` continua rodando, porque ele é a barra e a área de trabalho. `--no-default` devolve o Explorer. Aplica o tema atual: com o Files aberto ele é reiniciado; com `--no-restart` aparece uma notificação avisando que **clicar nela reinicia o Files**. `--check` só mostra o estado |
| `windots-toggle-fullscreen` | como o Super+F do omarchy (aqui Win+F): a janela em foco ocupa o monitor inteiro, cobrindo a barra do Windows; de novo, volta ao tamanho, posição e tile de antes |
| `windots-toggle-dark-mode [light\|dark]` | alterna o Windows entre modo escuro e claro (ou define um); mexe direto no registro, então funciona com o Windows não ativado |
| `windots-theme-set [<nome>] [--skip-taskbar] [--skip-wallpaper] [--skip-files] [--no-restart]` | como o `omarchy-theme-set`: aplica um dos 23 temas do omarchy (`default/themes/<nome>/colors.toml`, as paletas dele; `Tokyo Night`, `tokyo_night` e `tokyo-night` valem o mesmo). Aplica: esquema e tema de interface do Windows Terminal; fundo da barra de tarefas (mod do Windhawk); modo claro/escuro do Windows, que acompanha o `mode` do tema para o texto da barra, a bandeja e os números do switcher continuarem legíveis; cores do komorebi-switcher (workspace ativo = `accent`, com janelas = `muted`); e, com o LazyVim do windots, o esquema de cores do Neovim (`lua/plugins/theme.lua`: o `neovim.lua` do tema, 14 dos 23 vêm com um, ou o modelo aether do omarchy com a paleta), que os Neovims abertos trocam sozinhos; as cores do Files (`AppTheme*BackgroundColor` e `AppThemeMode` no `user_settings.json` dele, o mesmo mapeamento do Catppuccin oficial: `background` na barra de endereço, de ferramentas e na área de arquivos, e o `background` escurecido em 20% na sidebar e na janela; o Files só lê isso ao iniciar, por isso ele é reiniciado ou, com `--no-restart`, uma notificação pergunta); e o papel de parede: a primeira imagem do tema (`default/themes/<nome>/backgrounds`, depois `~/.config/windots/backgrounds/<nome>`), a menos que você já tenha escolhido, no lançador, uma imagem desse tema (a escolha é mantida; `--skip-wallpaper` não mexe no fundo). Sem nome, reaplica o tema atual (é o que o `windots-install` faz). O Explorer reinicia só quando o modo claro/escuro muda, o switcher só quando as cores dele mudam; `--no-restart` não reinicia nada. Ainda sem tema: btop, atuin, fzf, starship, herdr-app e bordas do komorebi |
| `windots-theme-list [--names \| --preview <nome>]` | como o `omarchy-theme-list`: lista os temas com o modo e uma faixa de cores (o atual tem `*`); `--preview` desenha a paleta de um tema |
| `windots-theme-current` | como o `omarchy-theme-current`: o nome do tema atual (`~\.local\state\windots\theme.name`; `catppuccin` se nunca escolheu) |
| `windots-menu [toggle \| summon \| close \| refresh \| quit] [rota]` | como o `omarchy-menu`: abre o menu do windots-launcher numa rota (`style.theme`, `keys`, `setup.restart`...) ou o menu raiz, no processo que já está rodando. `Win+Space` abre o menu raiz e `Win+Alt+Space` o lançador, que abre já listando os apps (os mais usados primeiro) e procura apps, contas, `> comando`, `kill`, comandos e temas ao digitar; os dois vêm do `windots-hotkeys.ahk` (o whkd não pega a tecla Windows). Rotas: `root` e `launcher` (apelidos `apps` e `run`). O menu fica em `menus/default.jsonc` do projeto, no formato do `omarchy-menu.jsonc`, e `~\.config\windots\menu.jsonc` o estende nesta máquina |
| `windots-hotkeys.ahk` (AutoHotkey v2, sobe no login) | além dos atalhos que o whkd não pega (`Win+Space`, `Win+Alt+Space`, `Win+K`, tema, `Win`+arrastar), deixa **os cantos de todas as janelas retos**: o Windows 11 arredonda todas e isso briga com a borda reta do komorebi. Não existe opção nem valor de registro para isso (procurei nos arquivos do DWM e nas chaves dele), então o script usa a preferência de canto por janela do próprio DWM (`DWMWCP_DONOTROUND`), que funciona numa janela de outro processo: um gancho do shell pega as janelas novas e, ao iniciar, ele passa por todas as abertas, inclusive as escondidas pelo komorebi nos outros workspaces. Sem Windhawk e sem injetar nada no `dwm.exe`. Janelas já abertas ficam retas mesmo se o script parar; uma nova fica redonda até ele rodar de novo |
| `windots-install-launcher [--src <pasta>]` | compila o windots-launcher (projeto à parte, em github.com/higorhgon/windots-launcher, por padrão em `~\Projetos\windots-launcher`, WPF em .NET 9) com `dotnet publish` para `~\.local\share\windots-launcher`, onde o `windots-menu` e o `Win+Space` o procuram; para o launcher se ele estiver aberto. O `windots-refresh-autostart` o inicia no login (escondido) quando está instalado. Precisa do SDK do .NET 9 |
| `windots-menu-theme [--pick]` | o menu dos temas, com as cores de cada um e Enter para aplicar (`Win+Ctrl+Shift+Space`, o mesmo do omarchy; o `Win+Ctrl+T` continua sendo o modo escuro/claro). Com o windots-launcher instalado abre nele; senão, no fzf flutuante (`--pick` roda o fzf no terminal atual) |
| `windots-menu-keybindings [--list]` | como o Super+K do omarchy (aqui Win+K): lista com busca de todos os atalhos (whkd + AutoHotkey) no fzf, num terminal flutuante; Enter executa o atalho escolhido. Com o windots-launcher instalado abre nele (menu `keybindings`); `--list` e `--pick` continuam no fzf |
| `windots-setup-security-sudo [--enable-sudo \| --disable-sudo \| --status]` | liga o sudo do Windows (modo inline, igual a Configurações > Sistema > Avançado > Habilitar sudo > Em linha). É a base dos comandos que precisam de admin (`windots-setup-security-ssh`, winget): um UAC por comando e a saída fica no mesmo terminal. Este é o único script que pede UAC direto, porque o sudo não liga o próprio sudo; sem nada para mudar, não pergunta nada. O `windots-install` chama |
| `windots-setup-security-ssh [--enable-ssh \| --disabled-ssh \| --status \| --allow-user-links \| --block-user-links] [--shell=pwsh\|powershell\|cmd]` | como `omarchy-setup-security-sshd` / `omarchy-remove-security-sshd`: confere se o cliente e o servidor OpenSSH (recursos opcionais do Windows) estão instalados e instala o que faltar, liga o `sshd` (inicia com o Windows) e abre a porta 22. `--disabled-ssh` (ou `--disable-ssh`) para o serviço, desativa e fecha a porta (o cliente fica); `--status` mostra instalação, serviço, firewall, rede, usuário, IP e chaves. Precisa de admin: usa o sudo (e liga o sudo antes, se estiver desligado). A regra de firewall do Windows vale só para redes **Privadas**: numa rede Pública o ssh fica bloqueado de propósito `--shell` define o shell de um login ssh (padrão `pwsh`; o do Windows é o `cmd`; a escolha é testada antes de gravar, e `--shell=cmd` volta ao padrão). `--allow-user-links` desliga o RedirectionGuard só para o `sshd.exe` e reinicia o `sshd`, para sessões ssh seguirem links e junctions (o `mise.exe` do winget, as junctions `latest` do mise); é uma troca de segurança consciente, nunca feita sozinha, e o `--block-user-links` desfaz. Uma atualização do OpenSSH pode religar a proteção |
| `windots-setup-security-network-trust [--trust \| --untrust \| --status]` | marca a rede atual (a da rota padrão) como Privada, ou volta para Pública com `--untrust`; `--status` lista as redes conectadas e a categoria de cada uma. O firewall do `sshd` só vale em rede Privada, então numa rede Pública o ssh fica bloqueado. O Windows guarda a categoria por rede (faça uma vez em cada rede em que confia). Precisa de admin (usa o sudo). Cuidado: Privada deixa todos os dispositivos da rede alcançarem o computador, visitantes de um Wi-Fi compartilhado inclusive; prefira chave SSH à senha |
| `windots-restart-komorebi-switcher` | como os `omarchy-restart-*`: para e abre de novo o komorebi-switcher (ele só lê o `.toml` ao iniciar). O `windots-theme-set` e o `windots-install-komorebi-switcher` chamam depois de mudar o `.toml` |
| `windots-install-komorebi-switcher [--build] [--alignment left\|center\|right] [--workspaces <n>] [--revert] [--check]` | instala a versão do komorebi-switcher do windots: o upstream (tag `v0.10.4`) com o patch `default/komorebi-switcher/windots.patch`, que acrescenta ao `~\.config\komorebi-switcher.toml` duas chaves. `alignment = "left"\|"center"\|"right"`: o switcher se posiciona sozinho na barra e acompanha as mudanças de largura e da bandeja (esquerda: logo depois do botão Iniciar, ou na borda esquerda quando o Iniciar está no meio da barra; direita: antes da bandeja; é pelo UI Automation, e o `x` do toml deixa de valer). `persistent_workspaces = N`: os workspaces 1..N ficam sempre visíveis e os outros só aparecem enquanto têm janela ou estão em foco, como na barra do omarchy; os vazios ficam apagados. Padrão: `center` e 5. Por padrão baixa a release mais nova do GitHub (feita pelo workflow `.github/workflows/komorebi-switcher.yml`; confere o SHA-256) e troca o exe; `--build` compila aqui (git, Rust e as Build Tools do Visual Studio; perfil mais leve que o do upstream: uns 7 minutos na primeira vez, uns 2 nas outras). O original fica em `komorebi-switcher.exe.orig` e `--revert` devolve. Uma atualização do switcher pelo winget traz o upstream de volta: rode de novo |
| `windots-restart-herdr-app [--force]` | fecha a janela do herdr-app como o botão de fechar (ele salva o estado) e abre de novo, para carregar teclas, settings, layouts e mods; só a janela reinicia, os terminais continuam no herdr-core. `--force` mata a janela se ela não fechar |
| `windots-restart-komorebi [--only]` | para e inicia de novo o komorebi do jeito do atalho de inicialização (`komorebic start --whkd --masir`, então o whkd e o masir reiniciam junto); necessário depois de mudar o `komorebi.json` ou o `applications.json`. Todas as janelas são gerenciadas de novo: os tiles são refeitos e overrides flutuantes e camadas por workspace se perdem. O komorebi-switcher e o `windots-float-ontop` assinam o komorebi ao iniciar, então os que estavam rodando reiniciam depois dele (`--only` não mexe neles) |
| `windots-restart-whkd` | reinicia o whkd (ele só lê o `whkdrc` ao iniciar) com o PATH atualizado, para os `windots-*` dos atalhos serem achados; a primeira tecla depois do restart às vezes se perde |
| `windots-restart-masir` | reinicia o masir (o foco segue o mouse); também inicia se ele não estiver rodando |
| `windots-restart-float-ontop` | reinicia o `windots-float-ontop` do jeito do atalho de inicialização (pwsh sem janela); ele escuta o komorebi por um pipe, então precisa reiniciar junto com ele |
| `windots-restart-hotkeys` | reinicia o AutoHotkey v2 que roda o `windots-hotkeys.ahk`, para uma edição do script valer |
| `windots-restart-explorer` | reinicia o Explorer do Windows (barra de tarefas e área de trabalho), que só lê cor de destaque e outras opções ao iniciar, e depois reinicia o komorebi-switcher, que fica desenhado na barra; janelas do Explorador de Arquivos fecham e a barra pisca por um instante. Não mexe no komorebi |
| `windots-restart-files [--if-running]` | fecha o Files (pede para a janela fechar e depois para o processo, porque ele fica rodando em segundo plano) e abre de novo, porque ele só lê as cores ao iniciar; as abas voltam. Uma cópia em andamento é interrompida. `--if-running` não abre nada se ele não estava aberto |
| `windots-notify <título> <texto> [--launch=<link>]` | mostra uma notificação do Windows (toast; usa o id de app do PowerShell, então aparece como "Windows PowerShell"). `--launch` é o link aberto ao clicar. Roda no `powershell.exe` 5.1, que tem a API de toast |
| `windots-uri <windots:ação>` | o tratador do protocolo `windots:` (registrado em HKCU). Um link pode vir de qualquer lugar, até de uma página, então só roda o que está na lista do script (`windots:restart-files`), sem argumentos tirados do link |
| `windots-install-git` | instala o Git for Windows com o winget se ele faltar (o winget pede o UAC do instalador); não faz nada se já estiver instalado. O próprio `windots-install.ps1`, quando roda fora de um clone (`irm | iex`), faz o mesmo passo antes de poder clonar o repo |
| `windots-setup-git [--name=<nome>] [--email=<email>] [--force]` | pergunta o nome e o e-mail que o git põe nos commits (como o instalador antigo do omarchy) e grava em `user.name` e `user.email`; se os dois já estão configurados, só avisa e para. `--name` e `--email` dão os valores sem perguntar; `--force` pergunta de novo (Enter mantém o atual) |
| `windots-migrate [--pending \| --mark-all]` | como o `omarchy-migrate`: roda as migrations da pasta `migrations/` que esta máquina ainda não rodou, em ordem, uma vez cada (`migrations/<unix time>.ps1`, marcador em `~\.local\state\windots\migrations\`). Uma que falha para tudo e roda de novo na próxima vez, então elas devem poder ser repetidas. `--pending` lista as pendentes (sai com 1 se não há); `--mark-all` marca todas como feitas sem rodar (máquina recém-instalada). O `windots-update` roda depois de reaplicar |
| `windots-dev-add-migration [--no-edit]` | como o `omarchy-dev-add-migration`: cria `migrations/<unix time>.ps1` a partir de um modelo e abre no `$env:EDITOR` (nvim, senão notepad) |
| `windots-launch-workspaces [--config <arquivo>] [--dry-run] [--wait]` | abre os apps de `~\.config\windots\workspaces.json`, cada um no seu workspace do komorebi, com opções de abrir em silêncio, flutuante, com tamanho e posição (veja "Apps nos workspaces"). Um app já aberto é deixado em paz. `--dry-run` mostra o que faria; `--wait` espera o komorebi subir (o atalho de inicialização usa) |
| `windots-setup-wsl [--user=<nome>] [--distro=<nome>] [--skip-tools] [--reinstall] [-y] [--network=mirrored\|nat] [--lan-ports=<portas>] [--check]` | instala o WSL se faltar (um UAC) e prepara o Arch Linux nele. **Reinício:** só é preciso quando nenhum hipervisor está rodando (o WSL 2 precisa de um, e ele sobe no boot); aí o script agenda a continuação para o próximo login (uma chave RunOnce abre um terminal e pede o usuário e a senha de novo) e oferece reiniciar; com um hipervisor já ativo (Docker Desktop, Windows Sandbox) não há reinício nenhum; se a virtualização está desligada na BIOS, avisa e para, sem agendar nada, para não entrar em loop. **A distro:** instala a distro (`archlinux`, da lista oficial do WSL) se faltar, pede o usuário e a senha (a imagem do Arch só tem o root e não tem sudo) e, por dentro (`default/wsl/setup.sh`), atualiza o sistema, instala sudo, base-devel, git e mise, gera os locales en_US e pt_BR (o WSL entrega LANG=en_US.UTF-8 e a imagem só tem C.UTF-8, então o bash avisaria a cada shell), põe o usuário no grupo wheel com sudo e como usuário padrão do WSL, liga as configs do mise e do starship e a skill `commit-message` do Claude a partir deste repositório (o `settings.json` do Claude não vai: é do Windows), cria um bloco no `~/.bashrc` (mise, starship, zoxide, atuin) e roda o `mise install`. `--skip-tools` deixa o `mise install` de fora; `--reinstall` APAGA a distro e tudo nela antes (pede para digitar o nome; `-y` pula); `--check` só mostra o que está instalado, o modo de rede e o que o script faria. Pode rodar de novo: só atualiza o que já existe. Rode num terminal de verdade (a pergunta da senha não funciona dentro do `!` do Claude Code); sem terminal, `WINDOTS_WSL_PASSWORD` e `--user`. O WSL usa memória (a VM chega a uns 2 GB): feche o que puder numa máquina com pouca RAM. **Rede (opcional; o padrão é NAT):** `--network=mirrored` faz o WSL compartilhar a rede do Windows (Windows 11 22H2+): os serviços dele respondem no IP do Windows e o localhost vale nos dois sentidos, mas ele **não** ganha IP próprio; o modo `bridged` (IP próprio na rede) está obsoleto desde o WSL 2.4.5 e exige um switch externo do Hyper-V, que o Windows Home não tem. As portas são as mesmas do Windows: um SSH no WSL não pode usar a 22 enquanto o do Windows a usa. `--network=nat` volta ao padrão. `--lan-ports=2222,8080` abre essas portas TCP do WSL para a rede (uma regra de firewall do Hyper-V por porta, `windots-wsl-<porta>`, um UAC; só no modo espelhado); nada fica aberto sem pedir, `--lan-ports=none` remove todas, e uma porta aberta vale para todos da rede, visitantes inclusive (não verifiquei se o Windows Defender Firewall ou a rede ser Pública também barram). Só com opções de rede o script não mexe na distro nem pede senha; trocar o modo roda `wsl --shutdown` (todas as distros param) |
| `windots-refresh-autostart` | recria os atalhos da pasta Inicializar (komorebi + masir, komorebi-switcher, float-ontop, hotkeys e, quando instalado, o windots-launcher) |
| `windots-update [-y] [--prune] [--skip-packages] [--skip-winget] [--skip-herdr-app] [--skip-mise]` | como o `omarchy-update`: atualiza o repositório (`windots-update-dev`), os pacotes do winget, o herdr-app, reaplica o windots (`windots-install --skip-packages --skip-system`; se falhar, o update para), roda as migrations, abre de novo os apps que o update fechou (`windots-update-restart`), roda o hook `post-update` (`windots-hook`) e atualiza as ferramentas do mise (`windots-update-mise`; com `--prune`, também apaga as versões antigas); oferece reiniciar se o Windows pedir. Só roda um update por vez, mantém o PC acordado e, com pacotes para atualizar, para se o disco do sistema tiver menos de 5 GB livres (`WINDOTS_UPDATE_MIN_FREE_GB` muda o limite). `-y` não pergunta nada; `--skip-winget`, `--skip-herdr-app` e `--skip-mise` pulam cada parte (o winget é o passo lento, com UAC; `--prune` não faz nada sem o mise); `--skip-packages` pula as três de uma vez e atualiza só o próprio windots, com o mesmo sentido do `windots-install --skip-packages`; uma flag desconhecida para o comando em vez de virar um update completo; log em `%TEMP%\windots-update.log` |
| `windots-reinstall-pkgs` | como o `omarchy-reinstall-pkgs`: instala o que faltar dos apps padrão (winget de `default/packages.txt` com um único UAC, komorebi-switcher, herdr-app, módulo Catppuccin do PowerShell, ferramentas do mise) sem mexer em configurações; o que já está instalado fica como está |
| `windots-reinstall-configs [-y]` | como o `omarchy-reinstall-configs`: apaga o que estiver em `~` no lugar de cada dotfile (cópias, links antigos, links para arquivos que saíram do repositório), guarda backup (`.bak.<tempo>`) do que for diferente do repositório e linka tudo de novo com o `windots-install --skip-packages --skip-system`; use quando algo ficou em conflito |
| `windots-update-herdr-app [--app] [--retropet]` | `--app` (padrão) atualiza o herdr-app com o instalador oficial (pula se ele estiver aberto); `--retropet` leva o submódulo `default/retropet` ao último commit do GitHub e copia de novo, mostrando o comando para registrar o novo commit no windots (nunca commita sozinho). O `windots-update` roda a parte `--app` |
| `windots-update-winget` | `winget upgrade --all` sem nenhuma pergunta (como `pacman -Syu --noconfirm`), com um único UAC via sudo |
| `windots-update-dev` | como o `omarchy-update-dev`: `git pull --ff-only` e atualiza os submódulos; para com mensagem se houver mudanças locais no caminho |
| `windots-update-mise [--prune]` | como o `omarchy-update-mise`: `mise up` sem a espera por releases novas; `--prune` também apaga as versões sem uso |
| `windots-update-restart [--snapshot \| <app>...]` | `--snapshot` lista os apps do windots abertos (komorebi, whkd, masir, komorebi-switcher); com nomes, abre de novo os que não estão rodando. O `windots-update` tira o snapshot antes e reabre o que o instalador fechou; o herdr-app fica de fora de propósito |
| `windots-update-available` | como o `omarchy-update-available`: faz `git fetch` e diz se há commits novos (sai com 0 se há, 1 se está em dia, 2 se não deu para saber) |
| `windots-hook <nome> [args...]` | como o `omarchy-hook`: roda `~\.config\windots\hooks\<nome>.ps1` se existir (por máquina, fora do repositório); o `windots-update` roda o `post-update` no fim. Hook que falha só avisa |

## Instalação numa máquina nova

Tudo no **Windows PowerShell** que vem com o Windows (o PowerShell 7 é instalado pelo script).

### Em uma linha (sem git instalado)

```powershell
irm https://raw.githubusercontent.com/higorhgon/windots/main/bin/windots-install.ps1 | iex
```

Como o `curl -fsSL https://omarchy.org/install | bash` do omarchy: instala o git (winget, se faltar), clona o repositório com os submódulos em `~\windots`, pergunta o nome e o e-mail do git (pula se já estiverem configurados), roda o `windots-install` e marca as migrations como feitas (uma máquina nova já tem o que elas mudariam). Não precisa liberar a execução de scripts: o `iex` não passa pela política e os scripts do repo rodam com `-ExecutionPolicy Bypass`. Variáveis opcionais, definidas antes da linha (`$env:WINDOTS_PATH = 'C:\w'`):
- `WINDOTS_PATH`: onde clonar (padrão `~\windots`; mantenha curto, porque alguns arquivos do repo têm caminhos longos e o Windows para em 260 caracteres);
- `WINDOTS_REPO` e `WINDOTS_REF`: outro repositório (um fork) e a branch ou tag (padrão `main`);
- `WINDOTS_GIT_NAME` e `WINDOTS_GIT_EMAIL`: o nome e o e-mail do git, para não perguntar;
- `WINDOTS_INSTALL_ARGS`: flags para o `windots-install`, por exemplo `--skip-packages`;
- `WINDOTS_NO_INSTALL=1`: para depois do git e do clone, sem rodar o `windots-install`.

### Passo a passo (manual)

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

4. **Reinicie** (ou saia e entre de novo). Sobem sozinhos: komorebi + whkd + masir, komorebi-switcher, AutoHotkey (`windots-hotkeys`), `windots-float-ontop` e o windots-launcher (se instalado).

5. **Ajustes depois do primeiro login:**
   - Se a instalação avisou *settings.json not found*, o Windows Terminal ainda não tinha sido aberto: abra-o uma vez e rode `windots-install-windows-terminal`.

Depois da primeira vez, o `bin` já está no PATH e dá para rodar de novo só o que faltou: `windots-install --skip-packages` (sem downloads) ou `windots-install --skip-system` (sem UAC nem barra de tarefas). Como no Linux, as opções são `--palavra-palavra` (e `-y`, `-h`), não `-Palavra` do PowerShell.

### O que o `windots-install` faz, em ordem

1. Ativa o Modo de Desenvolvedor e o sudo embutido (um UAC) e deixa a barra de tarefas no topo, pequena, alinhada à esquerda e sem Visão de Tarefas/Widgets/Copilot (`--skip-system` pula).
2. `windots-reinstall-pkgs`: instala os apps do winget listados em `default/packages.txt`, o komorebi-switcher (release do GitHub) e o herdr-app (instalador oficial, que também instala o herdr-core) (`--skip-packages` pula).
3. Põe `~\windots\bin` no PATH.
4. Cria a junction `%APPDATA%\dotfiles` → este repositório (onde o tuckr procura).
5. Faz backup (`*.pre-windots`) dos arquivos que vai substituir e roda `tuckr add` em todos os grupos. Depois aponta cada link direto para o arquivo do repo, sem passar pela junction: sessões SSH não atravessam links nem junctions criados por usuário comum (erro "untrusted mount point").
6. `windots-install-font JetBrainsMono` (só se ainda não estiver instalada), `windots-install-windows-terminal`, `windots-install-windhawk` (o mod da barra de tarefas; UAC), `windots-theme-set` (o tema atual em tudo que ele cobre), `windots-install-lazyvim` e `windots-install-herdr-app` (keys/settings mesclados e retropet copiado).
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

## Apps nos workspaces

O komorebi decide em que workspace uma janela fica, mas não abre aplicativos. O `windots-launch-workspaces` abre os apps listados em `~\.config\windots\workspaces.json` (só nesta máquina e **fora do repositório**: os apps de uma máquina não devem abrir em outra; sem o arquivo, nada abre) e põe cada janela no seu workspace, como o `exec-once = [workspace 2 silent; float; size 900 600; move 100 100] app` do Hyprland. O repositório só traz um exemplo, em `default/komorebi/workspaces.example.json`. Para começar: `Copy-Item ~\windots\default\komorebi\workspaces.example.json ~\.config\windots\workspaces.json` e edite. O arquivo é uma lista direta, sem chave por fora:

```json
[
  { "workspace": 1, "command": "wt", "match": { "exe": "WindowsTerminal.exe" } },
  { "workspace": 2, "command": "msedge", "match": { "exe": "msedge.exe" } },
  {
    "workspace": 3,
    "command": "%LOCALAPPDATA%\\Programs\\herdr-app\\herdr-app.exe",
    "match": { "exe": "herdr-app.exe" },
    "delay": 2
  },
  {
    "workspace": 5,
    "command": "notepad",
    "match": { "exe": "Notepad.exe" },
    "float": true,
    "size": ["60%", "70%"],
    "position": "center",
    "silent": false
  }
]
```

| Campo | O que faz |
|---|---|
| `workspace` | 1 a 10, o número do Win+número (obrigatório) |
| `monitor` | 1 = o primeiro (padrão) |
| `command`, `args` | o que abrir: um programa no PATH ou um caminho completo (`%VARIÁVEIS%` são expandidas), e uma lista de argumentos opcional |
| `match` | como reconhecer a janela: `{"exe": "msedge.exe"}`, `{"class": "..."}` ou `{"title": "..."}` (texto exato, como o komorebi mostra em `komorebic state`) |
| `silent` | `true` (padrão): o foco volta para onde estava; `false`: você vai para o workspace da janela nova |
| `float` | `true`: a janela abre flutuando (só essa abertura flutua) |
| `size`, `position` | só para flutuantes: `[largura, altura]` e `"center"` ou `[x, y]` a partir do canto da área de trabalho, em pixels (ajustados pela escala da tela) ou em porcentagem (`"60%"`). O tamanho e a posição são os da janela visível |
| `delay`, `wait` | segundos de espera antes de abrir, e para a janela aparecer (padrão 15) |
| `machines` | só nesses computadores (padrão: todos), por exemplo `["HIGOR-WIN"]` |

Como funciona: o app abre, o komorebi pega a janela no workspace em que você está e ela é enviada ao workspace certo com `komorebic send-to-monitor-workspace` (por um instante ela pode aparecer onde você está). O script **não** registra regras de workspace no komorebi: uma regra ficaria valendo e moveria todas as janelas seguintes daquele app, e o komorebi não tem como remover uma regra só. Um app que já está aberto é deixado em paz, então rodar de novo (ou depois de reiniciar o komorebi) só abre o que falta; `windots restart komorebi` não reabre os apps. Só funciona com janelas que o komorebi gerencia: se ele ignora o app, o script avisa. `windots launch workspaces --dry-run` mostra o que faria, e o atalho de inicialização (criado pelo `windots-refresh-autostart`) roda o comando com `--wait`, esperando o komorebi subir.

## Temas

Cada tema pode ter imagens de fundo em `default/themes/<tema>/backgrounds/`, o mesmo layout do omarchy
(`themes/<tema>/backgrounds`). Estão aqui as 98 imagens dos 23 temas do omarchy (69 MB; os 19 vídeos dele ficaram de
fora, um plano de fundo aqui é uma imagem) e, dentro do `catppuccin`, as 12 imagens que antes eram o grupo
`backgrounds`. O windots-launcher mostra as do tema atual, com prévia, em `Style › Background`. Imagens só desta
máquina vão em `~\.config\windots\backgrounds\<tema>`. Os atalhos de Configurações → Personalização do Windows
(um tema `windots <nome>` com slideshow e as "imagens recentes") não existem mais: não funcionavam direito e o
launcher resolve.

Os temas são os do omarchy (`omacom/omarchy`, `themes/<nome>/colors.toml`), copiados em `default/themes/`: `catppuccin` (o padrão), `catppuccin-latte`, `ethereal`, `everforest`, `flexoki-light`, `gruvbox`, `hackerman`, `jade-horse`, `kanagawa`, `last-horizon`, `lumon`, `lupine`, `matte-black`, `miasma`, `nord`, `retro-82`, `ristretto`, `rose-pine`, `solitude`, `starship`, `tokyo-night`, `vantablack` e `white`. `windots theme list` mostra todos, `windots theme set <nome>` aplica e `Win+Ctrl+Shift+Space` abre o menu.

A barra de tarefas do omarchy usa `background` (fundo), `foreground` (texto) e `red` (alertas). No Windows: o fundo vira exatamente a cor `background` do tema (mod Taskbar Styler do Windhawk; a paleta de destaque do Windows deixava a cor uns 18% mais escura e o TranslucentTB não funciona nesta build do Windows); o texto não aceita uma cor qualquer, só claro ou escuro, e por isso o tema liga o modo claro/escuro do Windows conforme o `mode` dele; e o alerta não tem equivalente na barra. As cores do komorebi-switcher seguem o tema (`accent` no workspace ativo, `muted` nos que têm janelas), enquanto o texto e o fundo dele vêm do Windows e da barra.

Fora da lista acima o resto ainda está em Catppuccin Mocha fixo, com os temas oficiais: [PowerShell](https://github.com/catppuccin/powershell), [btop](https://github.com/catppuccin/btop), [fzf](https://github.com/catppuccin/fzf) e [atuin](https://github.com/catppuccin/atuin) (acento blue). O esquema Catppuccin Mocha do Windows Terminal continua no fragment, mas o `windots-theme-set` define o esquema `windots` como padrão.
