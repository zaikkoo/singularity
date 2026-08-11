#!/usr/bin/env bash
#
# UNINSTALL.sh — Hyprland rice uninstaller (zaikkoo/singularity)
#
# What this script does:
#   1. Removes the symlinks created by LAUNCH.sh in ~/.config
#   2. Restores the most recent backup of each config (if it exists)
#   3. Reverts the GTK/gsettings theme to the default values
#   4. Restores the default shell to bash
#   5. (optional, with --purge) also removes the packages installed by LAUNCH.sh
#
# Usage:
#   ./UNINSTALL.sh            # only removes configs/symlinks
#   ./UNINSTALL.sh --purge    # removes configs/symlinks AND the pacman/AUR packages

set -euo pipefail

# --------- CONFIGURATION ---------

PURGE=false
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=true ;;
    esac
done

# Directory this script lives in (assumes it's the root of the cloned repo)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES_DIR/.config"
CONFIG_DEST="$HOME/.config"

# Must match the LAUNCH.sh lists EXACTLY
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

CONFIG_FILES=(
    starship.toml
)

# Must match the LAUNCH.sh lists EXACTLY (only used with --purge)
PACMAN_PACKAGES=(
    hyprland kitty rofi-wayland swaync fastfetch fish starship nautilus
    nwg-look neovim awww qt6ct papirus-icon-theme wl-clipboard
    modemmanager gpsd pipewire pipewire-pulse pipewire-alsa
    wireplumber dconf ncspot cmatrix cava
)

AUR_PACKAGES=(
    apple_cursor papirus-folders ttf-jetbrains-mono-nerd ttf-rubik-vf
    libcava waybar-cava-git ttf-iosevka-nerd
)

# --------- FUNCTIONS ---------

log()  { printf '\033[1;36m[UNINSTALL]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[WARNING]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; }

check_requirements() {
    if [[ $EUID -eq 0 ]]; then
        err "Don't run this script as root/sudo. It asks for your password when needed."
        exit 1
    fi
}

# Finds the most recent backup of an item (e.g. hypr.bak.20260811143012)
# Returns empty if none is found.
find_latest_backup() {
    local name="$1"
    find "$CONFIG_DEST" -maxdepth 1 -name "${name}.bak.*" 2>/dev/null | sort -r | head -n1
}

unlink_item() {
    local name="$1"
    local src="$CONFIG_SRC/$name"
    local dest="$CONFIG_DEST/$name"

    # Only remove it if it's a symlink pointing to the repo (don't touch configs that aren't ours)
    if [[ -L "$dest" ]]; then
        local target
        target="$(readlink -f "$dest" 2>/dev/null || true)"
        if [[ "$target" == "$(cd "$src" 2>/dev/null && pwd || echo "$src")" ]]; then
            rm "$dest"
            log "Symlink removed: $name"
        else
            warn "$name is a symlink, but it doesn't point to the repo. Skipping (leaving it alone)."
            return
        fi
    elif [[ -e "$dest" ]]; then
        warn "$name exists but isn't a symlink (maybe it was already restored). Skipping."
        return
    else
        log "$name no longer exists in $CONFIG_DEST, nothing to remove."
    fi

    local backup
    backup="$(find_latest_backup "$name")"
    if [[ -n "$backup" ]]; then
        if [[ -e "$dest" ]]; then
            warn "Something already exists at $dest; won't overwrite it with backup $backup."
        else
            mv "$backup" "$dest"
            log "Backup restored: $(basename "$backup") -> $name"
        fi
    else
        log "No backup found for $name."
    fi
}

unlink_configs() {
    for folder in "${CONFIG_FOLDERS[@]}"; do
        unlink_item "$folder"
    done

    for file in "${CONFIG_FILES[@]}"; do
        unlink_item "$file"
    done
}

reset_gtk_theme() {
    log "Reverting GTK/gsettings theme to the defaults..."
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' || true
    gsettings set org.gnome.desktop.interface font-name 'Cantarell 11' || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' || true
    gsettings set org.gnome.desktop.interface color-scheme 'default' || true
    gsettings set org.gnome.desktop.interface font-hinting 'slight' || true
    gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale' || true
    gsettings reset org.gnome.desktop.interface font-rgba-order \
        || warn "Couldn't reset font-rgba-order automatically."
}

purge_packages() {
    log "Removing packages installed by LAUNCH.sh (--purge enabled)..."
    warn "This may remove packages you also use for other reasons. Double-check first if needed."
    yay -Rns --noconfirm "${AUR_PACKAGES[@]}" "${PACMAN_PACKAGES[@]}" \
        || warn "Some packages couldn't be removed (they might be a dependency of something else, or already not installed)."
}

restore_default_shell() {
    local bash_path
    bash_path="$(command -v bash)"

    if [[ "$SHELL" == "$bash_path" ]]; then
        log "bash is already the default shell."
        return
    fi

    log "Restoring bash as the default shell..."
    if ! chsh -s "$bash_path"; then
        warn "chsh failed, trying via usermod..."
        sudo usermod -s "$bash_path" "$(whoami)" || warn "Couldn't change the shell automatically. Run manually: chsh -s $bash_path"
    fi
}

main() {
    log "Starting rice uninstallation..."
    check_requirements
    unlink_configs
    reset_gtk_theme
    restore_default_shell

    if [[ "$PURGE" == true ]]; then
        purge_packages
        log "Done! Symlinks removed, backups restored, and packages uninstalled."
    else
        log "Done! The symlinks were removed and backups (if any) were restored."
        warn "Packages installed via pacman/yay (hyprland, waybar-cava-git, etc.) were NOT removed."
        warn "Run with --purge to remove them too, or manually: yay -Rns <package>"
    fi

    read -rp "Reboot now to apply everything? [Y/n] " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        warn "Reboot cancelled. Log out/in (or reboot manually) whenever you want."
    else
        log "Rebooting in 3 seconds..."
        sleep 3
        sudo reboot
    fi
}

main "$@"
