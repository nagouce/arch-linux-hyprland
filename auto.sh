#!/bin/bash

# Script para instalar pacotes no Arch Linux usando pacman
# Execute com sudo ou como root após clonar do GitHub

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root. Use sudo."
   exit 1
fi

# Atualiza o sistema e o cache do pacman
echo "Atualizando o sistema..."
pacman -Syu --noconfirm

# Lista de pacotes a serem instalados (extraída do pacotes.txt)
PACOTES=(
    bash-completion
    bluez
    bluez-utils
    blueman
    btop
    clang
    code
    curl
    dbeaver
    docker
    docker-compose
    dunst
    efibootmgr
    feh
    fwupd
    gcc
    git
    go
    htop
    hyprland
    intel-media-driver
    intel-ucode
    jupyterlab
    kdeconnect
    kitty
    libinput
    linux-zen
    lm_sensors
    make
    mariadb
    mesa
    mongodb
    nano
    neovim
    network-manager-applet
    networkmanager
    nginx
    nodejs
    npm
    noto-fonts
    openssh
    pavucontrol
    pipewire
    pipewire-alsa
    pipewire-audio
    pipewire-pulse
    poetry
    postman
    postgresql
    python
    python-pip
    redis
    ripgrep
    rofi
    rust
    sof-firmware
    starship
    thunar
    thunar-archive-plugin
    tlp
    unzip
    virtualenv
    vulkan-intel
    waybar
    wget
    wireplumber
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    zip
)

# Instala os pacotes listados
echo "Instalando pacotes..."
pacman -S --noconfirm "${PACOTES[@]}"

# Habilita serviços essenciais
echo "Habilitando serviços..."
systemctl enable bluetooth
systemctl enable docker
systemctl enable mariadb
systemctl enable postgresql
systemctl enable nginx
systemctl enable NetworkManager
systemctl enable tlp

# Inicia serviços imediatamente (opcional, remova se não quiser iniciar agora)
echo "Iniciando serviços..."
systemctl start bluetooth
systemctl start docker
systemctl start mariadb
systemctl start postgresql
systemctl start nginx
systemctl start NetworkManager
systemctl start tlp

# Configurações adicionais para Hyprland
echo "Configurando variáveis de ambiente para Hyprland..."
echo "XDG_SESSION_TYPE=wayland" >> /etc/environment
echo "XDG_SESSION_DESKTOP=Hyprland" >> /etc/environment
echo "XDG_CURRENT_DESKTOP=Hyprland" >> /etc/environment

# Mensagem de conclusão
echo "Instalação concluída! Reinicie o sistema para garantir que todas as configurações sejam aplicadas."

exit 0