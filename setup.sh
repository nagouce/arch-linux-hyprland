#!/bin/bash

# Script para configurar Arch Linux com Hyprland

# Verifica se está sendo executado como root
if [[ $EUID -ne 0 ]]; then
   echo "Execute este script com sudo."
   exit 1
fi

# Verifica conexão com a internet
echo "Verificando conexão com a internet..."
if ! ping -c 1 google.com &> /dev/null; then
    echo "Sem conexão com a internet. Ativando NetworkManager..."
    systemctl start NetworkManager
    systemctl enable NetworkManager
    sleep 5
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Erro: Sem conexão com a internet. Verifique sua rede e tente novamente."
        exit 1
    fi
fi

# Atualiza o sistema
echo "Atualizando o sistema..."
pacman -Syu --noconfirm || { echo "Erro ao atualizar o sistema"; exit 1; }

# Pacotes dos repositórios oficiais
PACOTES_OFICIAIS=(
    bash-completion bluez bluez-utils blueman btop clang code curl dbeaver docker
    docker-compose dunst efibootmgr feh fwupd gcc git go htop hyprland
    intel-media-driver intel-ucode jupyterlab kdeconnect kitty libinput linux-zen
    lm_sensors make mariadb mesa nano neovim network-manager-applet networkmanager
    nginx nodejs npm noto-fonts openssh pavucontrol pipewire pipewire-alsa
    pipewire-audio pipewire-pulse python python-pip redis ripgrep rofi rust
    sof-firmware starship thunar thunar-archive-plugin tlp unzip vulkan-intel
    waybar wget wireplumber xdg-desktop-portal xdg-desktop-portal-hyprland zip
)

# Pacotes do AUR
PACOTES_AUR=(
    mongodb postman poetry virtualenv
)

# Instala pacotes oficiais
echo "Instalando pacotes oficiais..."
pacman -S --noconfirm --needed "${PACOTES_OFICIAIS[@]}" || { echo "Erro ao instalar pacotes oficiais"; exit 1; }

# Instala yay para pacotes do AUR
echo "Instalando yay..."
su - $SUDO_USER -c "git clone https://aur.archlinux.org/yay.git /tmp/yay" || { echo "Erro ao clonar yay"; exit 1; }
cd /tmp/yay
su - $SUDO_USER -c "makepkg -si" || { echo "Erro ao instalar yay"; exit 1; }
cd -
rm -rf /tmp/yay

# Instala pacotes do AUR
echo "Instalando pacotes do AUR..."
su - $SUDO_USER -c "yay -S --noconfirm ${PACOTES_AUR[*]}" || echo "Aviso: Alguns pacotes do AUR podem ter falhado"

# Configura o Hyprland
echo "Configurando o Hyprland..."
mkdir -p /home/$SUDO_USER/.config/hypr
cat << EOF > /home/$SUDO_USER/.config/hypr/hyprland.conf
# Configurações de entrada
input {
    kb_layout = br
    follow_mouse = 1
    sensitivity = 0
}
input:touchpad {
    natural_scroll = yes
    tap-to-click = yes
}

# Configurações gerais
monitor=,preferred,auto,1
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Iniciar aplicativos
exec-once = kitty
exec-once = waybar
exec-once = nm-applet

# Atalhos
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive
bind = SUPER, M, exit
bind = SUPER, F, fullscreen
bind = SUPER, R, exec, rofi -show drun
bind = SUPER, E, exec, thunar
EOF
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/hypr /home/$SUDO_USER/.config/hypr/hyprland.conf

# Configura a waybar
echo "Configurando a waybar..."
mkdir -p /home/$SUDO_USER/.config/waybar
cat << EOF > /home/$SUDO_USER/.config/waybar/config
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "tray"],
    "clock": {
        "format": "{:%H:%M %d/%m/%Y}"
    }
}
EOF
cat << EOF > /home/$SUDO_USER/.config/waybar/style.css
* {
    font-family: monospace;
    font-size: 14px;
}
window#waybar {
    background: #1e1e2e;
    color: #cdd6f4;
}
EOF
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/waybar /home/$SUDO_USER/.config/waybar/*

# Configura o sddm
echo "Configurando o sddm..."
pacman -S --noconfirm sddm || { echo "Erro ao instalar sddm"; exit 1; }
mkdir -p /usr/share/wayland-sessions
cat << EOF > /usr/share/wayland-sessions/hyprland.desktop
[Desktop Entry]
Name=Hyprland
Comment=A dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
systemctl enable sddm || { echo "Erro ao habilitar sddm"; exit 1; }

# Habilita serviços
echo "Habilitando serviços..."
systemctl enable NetworkManager
systemctl start NetworkManager
systemctl enable bluetooth
systemctl start bluetooth
systemctl enable docker
systemctl enable mariadb
systemctl enable postgresql
systemctl enable nginx
systemctl enable tlp

# Configura variáveis de ambiente
echo "Configurando variáveis de ambiente..."
echo "export XDG_SESSION_TYPE=wayland" >> /home/$SUDO_USER/.bash_profile
echo "export XDG_SESSION_DESKTOP=Hyprland" >> /home/$SUDO_USER/.bash_profile
echo "export XDG_CURRENT_DESKTOP=Hyprland" >> /home/$SUDO_USER/.bash_profile
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bash_profile

# Mensagem final
echo "Configuração concluída! Reiniciando em 5 segundos..."
sleep 5
reboot