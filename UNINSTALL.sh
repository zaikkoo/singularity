#!/usr/bin/env bash
#
# UNINSTALL.sh — desinstalador do rice Hyprland (zaikkoo/singularity)
#
# O que este script faz:
#   1. Remove os symlinks criados pelo LAUNCH.sh em ~/.config
#   2. Restaura o backup mais recente de cada config (se existir)
#   3. Reverte o tema GTK/gsettings pros valores padrão
#   4. Restaura o shell padrão para bash
#   5. (opcional, com --purge) remove também os pacotes instalados pelo LAUNCH.sh
#
# Uso:
#   ./UNINSTALL.sh            # só remove configs/symlinks
#   ./UNINSTALL.sh --purge    # remove configs/symlinks E os pacotes pacman/AUR

set -euo pipefail

# --------- CONFIGURAÇÃO ---------

PURGE=false
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=true ;;
    esac
done

# Diretório onde este script está (assume que é a raiz do repo clonado)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES_DIR/.config"
CONFIG_DEST="$HOME/.config"

# Precisa ser EXATAMENTE igual às listas do LAUNCH.sh
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

# Precisa ser EXATAMENTE igual às listas do LAUNCH.sh (usadas só com --purge)
PACMAN_PACKAGES=(
    hyprland kitty rofi-wayland swaync fastfetch fish starship nautilus
    nwg-look neovim awww qt6ct papirus-icon-theme wl-clipboard
    modemmanager gpsd pipewire pipewire-pulse pipewire-alsa
    wireplumber dconf ncspot cmatrix cava
)

AUR_PACKAGES=(
    apple_cursor papirus-folders ttf-jetbrains-mono-nerd ttf-rubik-vf
    libcava waybar-cava-git
)

# --------- FUNÇÕES ---------

log()  { printf '\033[1;36m[UNINSTALL]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[ERRO]\033[0m %s\n' "$1" >&2; }

check_requirements() {
    if [[ $EUID -eq 0 ]]; then
        err "Não rode este script como root/sudo. Ele pede senha quando precisa."
        exit 1
    fi
}

# Acha o backup mais recente de um item (ex: hypr.bak.20260811143012)
# Retorna vazio se não encontrar nenhum.
find_latest_backup() {
    local name="$1"
    find "$CONFIG_DEST" -maxdepth 1 -name "${name}.bak.*" 2>/dev/null | sort -r | head -n1
}

unlink_item() {
    local name="$1"
    local src="$CONFIG_SRC/$name"
    local dest="$CONFIG_DEST/$name"

    # Só remove se for symlink apontando pro repo (não mexe em configs que não são nossas)
    if [[ -L "$dest" ]]; then
        local target
        target="$(readlink -f "$dest" 2>/dev/null || true)"
        if [[ "$target" == "$(cd "$src" 2>/dev/null && pwd || echo "$src")" ]]; then
            rm "$dest"
            log "Symlink removido: $name"
        else
            warn "$name é um symlink, mas não aponta pro repo. Pulando (não mexo nisso)."
            return
        fi
    elif [[ -e "$dest" ]]; then
        warn "$name existe mas não é symlink (talvez já tenha sido restaurado antes). Pulando."
        return
    else
        log "$name já não existe em $CONFIG_DEST, nada a remover."
    fi

    local backup
    backup="$(find_latest_backup "$name")"
    if [[ -n "$backup" ]]; then
        if [[ -e "$dest" ]]; then
            warn "Já existe algo em $dest; não vou sobrescrever o backup $backup."
        else
            mv "$backup" "$dest"
            log "Backup restaurado: $(basename "$backup") -> $name"
        fi
    else
        log "Nenhum backup encontrado pra $name."
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
    log "Revertendo tema GTK/gsettings pros padrões..."
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' || true
    gsettings set org.gnome.desktop.interface font-name 'Cantarell 11' || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' || true
    gsettings set org.gnome.desktop.interface color-scheme 'default' || true
    gsettings set org.gnome.desktop.interface font-hinting 'slight' || true
    gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale' || true
    gsettings reset org.gnome.desktop.interface font-rgba-order \
        || warn "Não consegui resetar font-rgba-order automaticamente."
}

purge_packages() {
    log "Removendo pacotes instalados pelo LAUNCH.sh (--purge ativado)..."
    warn "Isso pode remover pacotes que você também usa por outros motivos. Confira antes se necessário."
    yay -Rns --noconfirm "${AUR_PACKAGES[@]}" "${PACMAN_PACKAGES[@]}" \
        || warn "Alguns pacotes não puderam ser removidos (podem ser dependência de outra coisa, ou já não estarem instalados)."
}

restore_default_shell() {
    local bash_path
    bash_path="$(command -v bash)"

    if [[ "$SHELL" == "$bash_path" ]]; then
        log "bash já é o shell padrão."
        return
    fi

    log "Restaurando bash como shell padrão..."
    if ! chsh -s "$bash_path"; then
        warn "chsh falhou, tentando via usermod..."
        sudo usermod -s "$bash_path" "$(whoami)" || warn "Não consegui trocar o shell automaticamente. Rode manualmente: chsh -s $bash_path"
    fi
}

main() {
    log "Iniciando desinstalação do rice..."
    check_requirements
    unlink_configs
    reset_gtk_theme
    restore_default_shell

    if [[ "$PURGE" == true ]]; then
        purge_packages
        log "Concluído! Symlinks removidos, backups restaurados e pacotes desinstalados."
    else
        log "Concluído! Os symlinks foram removidos e os backups (se havia) foram restaurados."
        warn "Os pacotes instalados via pacman/yay (hyprland, waybar-cava-git, etc.) NÃO foram removidos."
        warn "Rode com --purge pra removê-los também, ou manualmente: yay -Rns <pacote>"
    fi

    read -rp "Reiniciar agora pra aplicar tudo? [S/n] " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        warn "Reinício cancelado. Faça logout/login (ou reinicie manualmente) quando quiser."
    else
        log "Reiniciando em 3 segundos..."
        sleep 3
        sudo reboot
    fi
}

main "$@"
