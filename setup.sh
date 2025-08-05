#!/bin/bash

# Script para configurar Arch Linux com Hyprland usando yay

# Verifica se está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    echo "Execute este script com sudo."
    exit 1
fi

# Cria um arquivo de log
LOGFILE="/home/$SUDO_USER/setup-arch-hyprland.log"
echo "Iniciando configuração: $(date)" > $LOGFILE

# Verifica conexão com a internet
echo "Verificando conexão com a internet..." | tee -a $LOGFILE
if ! ping -c 1 google.com &> /dev/null; then
    echo "Sem conexão com a internet. Ativando NetworkManager..." | tee -a $LOGFILE
    systemctl start NetworkManager >> $LOGFILE 2>&1
    systemctl enable NetworkManager >> $LOGFILE 2>&1
    sleep 5
    if ! ping -c 1 google.com &> /dev/null; then
        echo "Erro: Sem conexão com a internet. Verifique sua rede e tente novamente." | tee -a $LOGFILE
        exit 1
    fi
fi

# Atualiza o sistema
echo "Atualizando o sistema..." | tee -a $LOGFILE
pacman -Syu --noconfirm >> $LOGFILE 2>&1 || { echo "Erro ao atualizar o sistema" | tee -a $LOGFILE; exit 1; }

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
echo "Instalando pacotes oficiais..." | tee -a $LOGFILE
pacman -S --noconfirm --needed "${PACOTES_OFICIAIS[@]}" >> $LOGFILE 2>&1 || { echo "Erro ao instalar pacotes oficiais" | tee -a $LOGFILE; exit 1; }

# Instala pacotes do AUR
echo "Instalando pacotes do AUR..." | tee -a $LOGFILE
su - $SUDO_USER -c "yay -S --noconfirm ${PACOTES_AUR[*]}" >> $LOGFILE 2>&1 || echo "Aviso: Alguns pacotes do AUR podem ter falhado" | tee -a $LOGFILE

# Configura o Hyprland
echo "Configurando o Hyprland..." | tee -a $LOGFILE
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
echo "Configurando a waybar..." | tee -a $LOGFILE
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
echo "Configurando o sddm..." | tee -a $LOGFILE
pacman -S --noconfirm sddm >> $LOGFILE 2>&1 || { echo "Erro ao instalar sddm" | tee -a $LOGFILE; exit 1; }
mkdir -p /usr/share/wayland-sessions
cat << EOF > /usr/share/wayland-sessions/hyprland.desktop
[Desktop Entry]
Name=Hyprland
Comment=A dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
systemctl enable sddm >> $LOGFILE 2>&1 || { echo "Erro ao habilitar sddm" | tee -a $LOGFILE; exit 1; }

# Habilita serviços
echo "Habilitando serviços..." | tee -a $LOGFILE
systemctl enable NetworkManager >> $LOGFILE 2>&1
systemctl start NetworkManager >> $LOGFILE 2>&1
systemctl enable bluetooth >> $LOGFILE 2>&1
systemctl start bluetooth >> $LOGFILE 2>&1
systemctl enable docker >> $LOGFILE 2>&1
systemctl enable mariadb >> $LOGFILE 2>&1
systemctl enable postgresql >> $LOGFILE 2>&1
systemctl enable nginx >> $LOGFILE 2>&1
systemctl enable tlp >> $LOGFILE 2>&1

# Configura variáveis de ambiente
echo "Configurando variáveis de ambiente..." | tee -a $LOGFILE
echo "export XDG_SESSION_TYPE=wayland" >> /home/$SUDO_USER/.bash_profile
echo "export XDG_SESSION_DESKTOP=Hyprland" >> /home/$SUDO_USER/.bash_profile
echo "export XDG_CURRENT_DESKTOP=Hyprland" >> /home/$SUDO_USER/.bash_profile
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bash_profile

# Mensagem final
echo "Configuração concluída! Log salvo em $LOGFILE. Reiniciando em 5 segundos..." | tee -a $LOGFILE
sleep 5
reboot