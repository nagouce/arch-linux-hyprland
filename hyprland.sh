#!/bin/bash

# Script para configurar e ativar o Hyprland automaticamente

# Verifica se está sendo executado como root
if [[ $EUID -ne 0 ]]; then
   echo "Execute este script com sudo."
   exit 1
fi

# Instala pacotes necessários (Hyprland, libinput, sddm, kitty)
echo "Instalando pacotes necessários..."
pacman -S --noconfirm hyprland libinput sddm kitty

# Cria o diretório de configuração do Hyprland
echo "Criando configuração do Hyprland..."
mkdir -p /home/$SUDO_USER/.config/hypr
cat << EOF > /home/$SUDO_USER/.config/hypr/hyprland.conf
# Configurações de entrada (mouse e teclado)
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

# Iniciar o kitty como terminal
exec-once = kitty

# Atalhos básicos
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive
bind = SUPER, M, exit
bind = SUPER, F, fullscreen
EOF

# Corrige permissões do arquivo de configuração
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.config/hypr /home/$SUDO_USER/.config/hypr/hyprland.conf

# Cria a sessão do Hyprland para o sddm
echo "Configurando sessão do Hyprland..."
mkdir -p /usr/share/wayland-sessions
cat << EOF > /usr/share/wayland-sessions/hyprland.desktop
[Desktop Entry]
Name=Hyprland
Comment=A dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF

# Habilita o sddm para iniciar automaticamente
echo "Habilitando o sddm..."
systemctl enable sddm

# Mensagem final
echo "Configuração concluída! Reiniciando em 5 segundos..."
sleep 5
reboot