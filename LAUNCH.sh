#!/usr/bin/env bash
#
# LAUNCH.sh — instalador do rice Hyprland (zaikkoo/singularity)
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

# Arquivos soltos do .config (não pastas) que serão linkados
CONFIG_FILES=(
    starship.toml
)

# Pacotes dos repositórios oficiais (pacman)
PACMAN_PACKAGES=(
    hyprland
    kitty
    rofi-wayland
    swaync
    fastfetch
    fish
    starship
    nautilus
    neovim
    awww          # daemon de wallpaper (sucessor do swww), fornece o comando awww-daemon
    qt6ct
    papirus-icon-theme
    wl-clipboard
    modemmanager   # dependência de build do waybar-cava-git (mm-glib)
    gpsd           # dependência de build do waybar-cava-git (libgps)
    ncspot         # spotify via terminal
    cmatrix
    cava
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
        err "  sudo pacman -S --needed base-devel"
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
    log "Garantindo que base-devel está instalado (necessário pra compilar pacotes do AUR)..."
    sudo pacman -S --needed --noconfirm base-devel

    log "Instalando pacotes dos repositórios oficiais..."
    yay -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

    log "Instalando pacotes do AUR..."
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

link_item() {
    local name="$1"
    local src="$CONFIG_SRC/$name"
    local dest="$CONFIG_DEST/$name"

    if [[ ! -e "$src" ]]; then
        warn "$name não existe no repo, pulando."
        return
    fi

    if [[ -L "$dest" ]]; then
        # já é um symlink — remove pra recriar apontando pro repo atual
        log "Atualizando symlink existente: $name"
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        # existe e não é symlink — faz backup
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        warn "Config existente encontrada em $name, movendo para $(basename "$backup")"
        mv "$dest" "$backup"
    fi

    ln -s "$src" "$dest"
    log "Linkado: $name -> $dest"
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

apply_cursor() {
    if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
        log "Aplicando tema de cursor..."
        hyprctl setcursor macOS 24 || warn "Não consegui aplicar o cursor agora (rode manualmente depois: hyprctl setcursor macOS 24)"
    else
        warn "Hyprland não está rodando agora. O cursor será aplicado no próximo login (já está no autostart.lua)."
    fi
}

set_default_shell() {
    local fish_path
    fish_path="$(command -v fish)"

    if [[ "$SHELL" == "$fish_path" ]]; then
        log "fish já é o shell padrão."
        return
    fi

    log "Definindo fish como shell padrão..."
    if ! grep -qx "$fish_path" /etc/shells; then
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi
    if ! chsh -s "$fish_path"; then
        warn "chsh falhou, tentando via usermod..."
        sudo usermod -s "$fish_path" "$(whoami)" || warn "Não consegui trocar o shell automaticamente. Rode manualmente: chsh -s $fish_path"
    fi
}

main() {
    log "Iniciando instalação do rice..."
    check_requirements
    install_packages
    link_configs
    apply_cursor
    set_default_shell
    log "Concluído! O sistema vai reiniciar pra aplicar tudo (shell, rice, etc)."

    read -rp "Reiniciar agora? [S/n] " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        warn "Reinício cancelado. Faça logout/login (ou reinicie manualmente) quando quiser."
    else
        log "Reiniciando em 3 segundos..."
        sleep 3
        sudo reboot
    fi
}


main "$@"
