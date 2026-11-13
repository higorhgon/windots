#!/bin/bash
# windots setup wsl, the part that runs INSIDE the Arch Linux distro, as root.
# Called by bin/windots-setup-wsl.ps1, which pipes the password in on stdin:
#
#   bash setup.sh --user=<name> --password-stdin --repo=<windots on the Windows side, as /mnt/c/...> [--skip-tools]
#
# What it does, in order (every step can run again):
#   1. pacman keyring + full system update, then the base packages: sudo, base-devel, git, curl,
#      mise, bash-completion (Arch's WSL image has no sudo), and the en_US / pt_BR locales (WSL hands
#      bash LANG=en_US.UTF-8 but the image only generates C.UTF-8, so every shell would warn)
#   2. the user: created (home, bash, group wheel) or updated, with the password it was given
#   3. sudo for that user: the wheel group, with a password (/etc/sudoers.d, checked with visudo)
#   4. /etc/wsl.conf: that user becomes the default one (WSL then opens as them, not as root)
#   5. as that user: the windots mise config and starship config linked from the Windows repo, the
#      Claude Code commit-message skill, a ~/.bashrc block (mise, starship, zoxide, atuin), and
#      `mise install` for the tools of the windots config (--skip-tools leaves that one out)
set -euo pipefail

user_name=""; repo=""; skip_tools=0; password_stdin=0
for a in "$@"; do
  case "$a" in
    --user=*) user_name="${a#--user=}" ;;
    --repo=*) repo="${a#--repo=}" ;;
    --password-stdin) password_stdin=1 ;;
    --skip-tools) skip_tools=1 ;;
    *) echo "setup.sh: unknown option $a" >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "setup.sh: must run as root" >&2; exit 1; }
[[ $user_name =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo "setup.sh: '$user_name' is not a valid Linux user name (lowercase letters, digits, - and _)" >&2; exit 2; }
[[ $user_name != root ]] || { echo "setup.sh: the user must not be root" >&2; exit 2; }
[[ -d $repo/Configs ]] || { echo "setup.sh: --repo must be the windots folder seen from Linux (no Configs/ in '$repo')" >&2; exit 2; }
(( password_stdin )) || { echo "setup.sh: the password comes on stdin (--password-stdin)" >&2; exit 2; }

# The password: one line from stdin (the Windows side sends CRLF).
IFS= read -r password || true
password="${password%$'\r'}"
[[ -n $password ]] || { echo "setup.sh: empty password" >&2; exit 2; }

step() { printf '\n\e[36m==> %s\e[0m\n' "$*"; }

# A pacman killed half-way (an interrupted run) leaves its lock behind and would block this one.
if [[ -e /var/lib/pacman/db.lck ]] && ! pgrep -x pacman >/dev/null; then
  echo "  - removing a stale pacman lock left by an interrupted run"
  rm -f /var/lib/pacman/db.lck
fi

step "pacman keyring and system update"
[[ -s /etc/pacman.d/gnupg/pubring.gpg ]] || pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm

step "base packages (sudo, base-devel, git, curl, mise, bash-completion)"
pacman -S --needed --noconfirm sudo base-devel git curl mise bash-completion

step "locales (en_US.UTF-8, pt_BR.UTF-8)"
# WSL hands bash LANG=en_US.UTF-8, but Arch's image generates only C.UTF-8: every new shell would
# print "setlocale: cannot change locale". Generating the locales (a no-op when they exist) ends that.
sed -i -E 's/^#[[:space:]]*(en_US\.UTF-8 UTF-8)/\1/; s/^#[[:space:]]*(pt_BR\.UTF-8 UTF-8)/\1/' /etc/locale.gen
locale-gen
step "user $user_name"
if id "$user_name" >/dev/null 2>&1; then
  echo "  - $user_name exists: making sure it is in wheel, with bash"
  usermod -aG wheel -s /bin/bash "$user_name"
else
  useradd -m -G wheel -s /bin/bash "$user_name"
  echo "  - created $user_name"
fi
# chpasswd splits at the first ':' only, so a password with ':' is fine.
printf '%s:%s\n' "$user_name" "$password" | chpasswd
unset password
echo "  - password set"

step "sudo for the wheel group"
sudoers=/etc/sudoers.d/10-windots-wheel
printf '%%wheel ALL=(ALL:ALL) ALL\n' > "$sudoers.tmp"
chmod 0440 "$sudoers.tmp"
if visudo -cf "$sudoers.tmp" >/dev/null; then
  mv "$sudoers.tmp" "$sudoers"
  echo "  - $sudoers: wheel can sudo (with its password)"
else
  rm -f "$sudoers.tmp"
  echo "setup.sh: sudoers check failed; sudo was not changed" >&2
  exit 1
fi

step "/etc/wsl.conf: $user_name is the default user"
touch /etc/wsl.conf
if grep -q '^\[user\]' /etc/wsl.conf; then
  # An existing [user] section: set or add the default line inside it, leave the rest alone.
  if sed -n '/^\[user\]/,/^\[/p' /etc/wsl.conf | grep -q '^default='; then
    sed -i "/^\[user\]/,/^\[/ s/^default=.*/default=$user_name/" /etc/wsl.conf
  else
    sed -i "/^\[user\]/a default=$user_name" /etc/wsl.conf
  fi
else
  printf '\n[user]\ndefault=%s\n' "$user_name" >> /etc/wsl.conf
fi
cat /etc/wsl.conf | sed 's/^/    /'

step "dotfiles, shell and tools for $user_name"
user_script=/tmp/windots-user-setup.sh
cat > "$user_script" <<'USER_SCRIPT'
set -euo pipefail
skip_tools="$1"
mkdir -p "$HOME/.config/mise" "$HOME/.claude/skills"

# The windots config files stay in the Windows repo: one place to edit, WSL follows it.
link() { ln -sfn "$1" "$2"; echo "  - $2 -> $1"; }
link "$REPO/Configs/mise/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
link "$REPO/Configs/starship/.config/starship.toml" "$HOME/.config/starship.toml"
# Only the commit skill: the windots one is about this Windows desktop, and the Claude settings
# there have defaultShell=powershell, which Linux must not get.
link "$REPO/Configs/claude/.claude/skills/commit-message" "$HOME/.claude/skills/commit-message"

# A block of its own in ~/.bashrc, replaced on every run.
begin='# >>> windots (windots setup wsl) >>>'; end='# <<< windots <<<'
touch "$HOME/.bashrc"
sed -i "/^$begin\$/,/^$end\$/d" "$HOME/.bashrc"
cat >> "$HOME/.bashrc" <<BASHRC
$begin
command -v mise >/dev/null && eval "\$(mise activate bash)"
command -v starship >/dev/null && eval "\$(starship init bash)"
command -v zoxide >/dev/null && eval "\$(zoxide init --cmd cd bash)"
command -v atuin >/dev/null && eval "\$(atuin init bash --disable-up-arrow)"
$end
BASHRC
echo "  - ~/.bashrc: windots block (mise, starship, zoxide, atuin)"

if [[ $skip_tools == 1 ]]; then
  echo "  - mise install skipped (--skip-tools): run 'mise install' later"
else
  echo "  - mise install (the tools of the windots config; the first run takes a while)"
  mise install --yes
fi
USER_SCRIPT
chmod 0755 "$user_script"
sudo -u "$user_name" -H env "REPO=$repo" bash "$user_script" "$skip_tools"
rm -f "$user_script"

printf '\n\e[32mDone. Restart the distro (wsl --terminate) and open it: you land as %s.\e[0m\n' "$user_name"
