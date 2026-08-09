#!/usr/bin/env bash
#
# LAUNCH.sh — instalador do rice Hyprland (zaikkoo/dotfileszk)
#
# O que este script faz:
#   1. Verifica se está rodando em Arch Linux e se o yay está instalado
#   2. Instala os pacotes necessários (repositórios oficiais + AUR)
#   3. Faz backup de qualquer config existente em ~/.config
#   4. Cria symlinks dos configs do repositório para ~/.config
#   5. Aplica o tema de cursor via hyprctl (se o Hyprland já estiver rodando)
#
# Uso:
#   ./LAUNCH.sh

set -euo pipefail

# --------- CONFIGURAÇÃO ---------

# Diretório onde este script está (assume que é a raiz do repo clonado)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES_DIR/.config"
CONFIG_DEST="$HOME/.config"

# Pastas do .config que serão linkadas (edite se adicionar/remover algo no repo)
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
)

# Pacotes dos repositórios oficiais (pacman)
PACMAN_PACKAGES=(
    hyprland
    kitty
    rofi-wayland
    swaync
    fastfetch
    fish
    awww          # daemon de wallpaper (sucessor do swww), fornece o comando awww-daemon
    qt6ct
    papirus-icon-theme
    wl-clipboard
    modemmanager   # dependência de build do waybar-cava-git (mm-glib)
    ncspot         # spotify via terminal
)

# Pacotes do AUR (via yay)
AUR_PACKAGES=(
    apple_cursor          # tema de cursor "macOS"
    ttf-jetbrains-mono-nerd
    ttf-rubik-vf           # Rubik (variable font)
    libcava                # necessário pro módulo cava do waybar
    waybar-cava-git        # substitui o pacote "waybar" padrão (não instale os dois)
)

# --------- FUNÇÕES ---------

log()  { printf '\033[1;36m[LAUNCH]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[AVISO]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[ERRO]\033[0m %s\n' "$1" >&2; }

check_requirements() {
    if [[ $EUID -eq 0 ]]; then
        err "Não rode este script como root/sudo. Ele pede senha quando precisa."
        exit 1
    fi

    if ! command -v pacman &>/dev/null; then
        err "pacman não encontrado. Este script é para Arch Linux (ou derivadas)."
        exit 1
    fi

    if ! command -v yay &>/dev/null; then
        err "yay não encontrado. Instale o yay antes de rodar este script:"
        err "  sudo pacman -S --needed base-devel git"
        err "  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
        exit 1
    fi

    if [[ ! -d "$CONFIG_SRC" ]]; then
        err "Não encontrei a pasta .config em $DOTFILES_DIR"
        err "Rode este script de dentro da pasta do repositório clonado."
        exit 1
    fi
}

install_packages() {
    log "Instalando pacotes dos repositórios oficiais..."
    yay -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

    log "Instalando pacotes do AUR..."
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

link_configs() {
    mkdir -p "$CONFIG_DEST"

    for folder in "${CONFIG_FOLDERS[@]}"; do
        local src="$CONFIG_SRC/$folder"
        local dest="$CONFIG_DEST/$folder"

        if [[ ! -d "$src" ]]; then
            warn "Pasta $folder não existe no repo, pulando."
            continue
        fi

        if [[ -L "$dest" ]]; then
            # já é um symlink — remove pra recriar apontando pro repo atual
            log "Atualizando symlink existente: $folder"
            rm "$dest"
        elif [[ -e "$dest" ]]; then
            # existe e não é symlink — faz backup
            local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
            warn "Config existente encontrada em $folder, movendo para $(basename "$backup")"
            mv "$dest" "$backup"
        fi

        ln -s "$src" "$dest"
        log "Linkado: $folder -> $dest"
    done
}

apply_cursor() {
    if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
        log "Aplicando tema de cursor..."
        hyprctl setcursor macOS 24 || warn "Não consegui aplicar o cursor agora (rode manualmente depois: hyprctl setcursor macOS 24)"
    else
        warn "Hyprland não está rodando agora. O cursor será aplicado no próximo login (já está no autostart.lua)."
    fi
}

main() {
    log "Iniciando instalação do rice..."
    check_requirements
    install_packages
    link_configs
    apply_cursor
    log "Concluído! Faça logout/login (ou reinicie) para entrar no Hyprland com o rice aplicado."
}

main "$@"
