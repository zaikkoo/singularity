#!/usr/bin/env bash
#
# LAUNCH.sh — Hyprland rice installer (zaikkoo/singularity)
#
# What this script does:
#   1. Checks that it's running on Arch Linux and that yay is installed
#   2. Installs the required packages (official repos + AUR)
#   3. Backs up any existing config in ~/.config
#   4. Creates symlinks from the repo configs to ~/.config
#   5. Applies the cursor theme via hyprctl (if Hyprland is already running)
#
# Usage:
#   ./LAUNCH.sh

set -euo pipefail

# --------- CONFIGURATION ---------

# Directory this script lives in (assumes it's the root of the cloned repo)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES_DIR/.config"
CONFIG_DEST="$HOME/.config"

# .config folders that will be symlinked (edit if you add/remove something in the repo)
CONFIG_FOLDERS=(
    hypr
    waybar
    kitty
    rofi
    swaync
    fastfetch
    fish
    gtk-3.0
    gtk-4.0
    nvim
)

# Standalone .config files (not folders) that will be symlinked
CONFIG_FILES=(
    starship.toml
)

# Official repo packages (pacman)
PACMAN_PACKAGES=(
    hyprland kitty rofi-wayland swaync fastfetch fish starship nautilus
    nwg-look neovim awww qt6ct papirus-icon-theme wl-clipboard
    modemmanager gpsd pipewire pipewire-pulse pipewire-alsa
    wireplumber dconf ncspot cmatrix cava
)

# AUR packages (via yay)
AUR_PACKAGES=(
    apple_cursor papirus-folders ttf-jetbrains-mono-nerd ttf-rubik-vf           
    libcava waybar-cava-git ttf-iosevka-nerd
)

# --------- FUNCTIONS ---------

log()  { printf '\033[1;36m[LAUNCH]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[WARNING]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }

check_requirements() {
    if [[ $EUID -eq 0 ]]; then
        err "Don't run this script as root/sudo. It asks for your password when needed."
        exit 1
    fi

    if ! command -v pacman &>/dev/null; then
        err "pacman not found. This script is for Arch Linux (or derivatives)."
        exit 1
    fi

    if ! command -v yay &>/dev/null; then
        err "yay not found. Install yay before running this script:"
        err "  sudo pacman -S --needed base-devel"
        err "  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
        exit 1
    fi

    if [[ ! -d "$CONFIG_SRC" ]]; then
        err "Couldn't find the .config folder in $DOTFILES_DIR"
        err "Run this script from inside the cloned repo folder."
        exit 1
    fi
}

install_packages() {
    log "Making sure base-devel is installed (needed to build AUR packages)..."
    sudo pacman -S --needed --noconfirm base-devel

    log "Installing official repo packages..."
    yay -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

    log "Installing AUR packages..."
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

    log "Applying Papirus folder color (white)..."
    papirus-folders -C white --theme Papirus-Dark || warn "Couldn't apply the folder color automatically. Run manually: papirus-folders -C white --theme Papirus-Dark"

    log "Enabling audio services (pipewire)..."
    systemctl --user enable --now pipewire pipewire-pulse wireplumber || warn "Couldn't enable audio services automatically. Run manually: systemctl --user enable --now pipewire pipewire-pulse wireplumber"
}

link_item() {
    local name="$1"
    local src="$CONFIG_SRC/$name"
    local dest="$CONFIG_DEST/$name"

    if [[ ! -e "$src" ]]; then
        warn "$name doesn't exist in the repo, skipping."
        return
    fi

    if [[ -L "$dest" ]]; then
        # already a symlink — remove it to recreate it pointing to the current repo
        log "Updating existing symlink: $name"
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        # exists and isn't a symlink — back it up
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        warn "Existing config found for $name, moving it to $(basename "$backup")"
        mv "$dest" "$backup"
    fi

    ln -s "$src" "$dest"
    log "Linked: $name -> $dest"
}

link_configs() {
    mkdir -p "$CONFIG_DEST"

    for folder in "${CONFIG_FOLDERS[@]}"; do
        link_item "$folder"
    done

    for file in "${CONFIG_FILES[@]}"; do
        link_item "$file"
    done
}

apply_gtk_theme() {
    log "Applying GTK theme via gsettings (needed for GTK4/libadwaita apps, like Nautilus)..."
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface font-name 'Rubik 11.6'
    gsettings set org.gnome.desktop.interface cursor-theme 'macOS'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface font-hinting 'slight'
    gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
    gsettings set org.gnome.desktop.interface font-rgba-order 'rgb' \
        || warn "Couldn't apply the theme via gsettings automatically."
}

apply_cursor() {
    if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
        log "Applying cursor theme..."
        hyprctl setcursor macOS 24 || warn "Couldn't apply the cursor right now (run manually later: hyprctl setcursor macOS 24)"
    else
        warn "Hyprland isn't running right now. The cursor will be applied on next login (it's already in autostart.lua)."
    fi
}

set_default_shell() {
    local fish_path
    fish_path="$(command -v fish)"

    if [[ "$SHELL" == "$fish_path" ]]; then
        log "fish is already the default shell."
        return
    fi

    log "Setting fish as the default shell..."
    if ! grep -qx "$fish_path" /etc/shells; then
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi
    if ! chsh -s "$fish_path"; then
        warn "chsh failed, trying via usermod..."
        sudo usermod -s "$fish_path" "$(whoami)" || warn "Couldn't change the shell automatically. Run manually: chsh -s $fish_path"
    fi
}

main() {
    log "Starting rice installation..."
    check_requirements
    install_packages
    link_configs
    apply_cursor
    apply_gtk_theme
    set_default_shell
    log "Done! The system will reboot to apply everything (shell, rice, etc)."

    read -rp "Reboot now? [Y/n] " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        warn "Reboot cancelled. Log out/in (or reboot manually) whenever you want."
    else
        log "Rebooting in 3 seconds..."
        sleep 3
        sudo reboot
    fi
}


main "$@"
