#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Bootstrap a fresh Arch Linux + niri/Hyprland machine from these dotfiles.
#
# This repo IS ~/.config, so the config files themselves are deployed simply by
# checking the repo out into ~/.config. This script installs everything that
# lives *outside* the config files: packages, the AUR helper, system services,
# the cursor theme, and GTK/cursor state.
#
# Usage (on a fresh machine):
#   mkdir -p ~/.config && cd ~/.config
#   git init && git remote add origin <YOUR_REMOTE_URL>
#   git fetch origin && git checkout -f main
#   ./setup.sh
#
# Idempotent: safe to re-run at any time (e.g. after adding packages).
# ---------------------------------------------------------------------------
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

[ "${EUID:-$(id -u)}" -eq 0 ] && { echo "Run as your normal user, not root."; exit 1; }

# --- 1. base tooling + AUR helper (yay) ------------------------------------
say "Installing base-devel & git"
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v yay >/dev/null 2>&1; then
    say "Bootstrapping yay (AUR helper)"
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
    rm -rf "$tmp"
fi

# --- 2. packages -----------------------------------------------------------
say "Installing native (repo) packages"
sudo pacman -S --needed --noconfirm - < "$CONFIG_DIR/pkglist-native.txt"

say "Installing AUR packages (this can take a while to build)"
yay -S --needed --noconfirm --answerdiff=None --answerclean=None --removemake \
    - < "$CONFIG_DIR/pkglist-aur.txt"

# --- 3. services -----------------------------------------------------------
say "Enabling system services"
sudo timedatectl set-ntp true
sudo systemctl enable --now systemd-timesyncd.service NetworkManager.service
sudo systemctl enable sddm.service   # greeter; not --now, that would kill a live session

if [ -d "$CONFIG_DIR/systemd/user" ]; then
    say "Enabling user timers/services from the repo"
    systemctl --user daemon-reload 2>/dev/null || true
    for unit in "$CONFIG_DIR"/systemd/user/*.timer "$CONFIG_DIR"/systemd/user/*.service; do
        [ -e "$unit" ] && systemctl --user enable --now "$(basename "$unit")" 2>/dev/null \
            || warn "could not enable $(basename "$unit") (ok if it has no [Install])"
    done
fi

# --- 4. cursor theme (Bibata-Modern-Ice) -----------------------------------
say "Applying cursor theme (Bibata-Modern-Ice)"
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 20 2>/dev/null || true
mkdir -p "$HOME/.local/share/icons/default"
cat > "$HOME/.local/share/icons/default/index.theme" <<'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF
for v in 3.0 4.0; do
    f="$HOME/.config/gtk-$v/settings.ini"
    mkdir -p "$(dirname "$f")"
    [ -f "$f" ] || printf '[Settings]\n' > "$f"
    grep -q gtk-cursor-theme-name "$f" \
        || printf 'gtk-cursor-theme-name=Bibata-Modern-Ice\ngtk-cursor-theme-size=20\n' >> "$f"
done

# --- 5. permissions + caches ----------------------------------------------
say "Marking scripts executable and refreshing caches"
chmod +x "$CONFIG_DIR"/waybar/scripts/*.sh "$CONFIG_DIR"/setup.sh 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f "$HOME/.local/share/icons" 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true

say "Done. Log out and back into niri (or Hyprland) to apply everything."
say "Then run 'waypaper' to set a wallpaper (default folder ~/Pictures/wallpapers)."
