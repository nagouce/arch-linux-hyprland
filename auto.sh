#!/bin/bash

# Script para configurar e executar o archinstall com pacotes pré-definidos

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root. Use sudo."
   exit 1
fi

# Lista de pacotes do pacotes.txt
PACOTES=(
    "bash-completion"
    "bluez"
    "bluez-utils"
    "blueman"
    "btop"
    "clang"
    "code"
    "curl"
    "dbeaver"
    "docker"
    "docker-compose"
    "dunst"
    "efibootmgr"
    "feh"
    "fwupd"
    "gcc"
    "git"
    "go"
    "htop"
    "hyprland"
    "intel-media-driver"
    "intel-ucode"
    "jupyterlab"
    "kdeconnect"
    "kitty"
    "libinput"
    "linux-zen"
    "lm_sensors"
    "make"
    "mariadb"
    "mesa"
    "mongodb"
    "nano"
    "neovim"
    "network-manager-applet"
    "networkmanager"
    "nginx"
    "nodejs"
    "npm"
    "noto-fonts"
    "openssh"
    "pavucontrol"
    "pipewire"
    "pipewire-alsa"
    "pipewire-audio"
    "pipewire-pulse"
    "poetry"
    "postman"
    "postgresql"
    "python"
    "python-pip"
    "redis"
    "ripgrep"
    "rofi"
    "rust"
    "sof-firmware"
    "starship"
    "thunar"
    "thunar-archive-plugin"
    "tlp"
    "unzip"
    "virtualenv"
    "vulkan-intel"
    "waybar"
    "wget"
    "wireplumber"
    "xdg-desktop-portal"
    "xdg-desktop-portal-hyprland"
    "zip"
)

# Cria um arquivo de configuração JSON para o archinstall
CONFIG_FILE="/tmp/archinstall-config.json"

# Inicia o arquivo JSON
echo "{" > $CONFIG_FILE
echo "  \"packages\": [" >> $CONFIG_FILE

# Adiciona os pacotes ao JSON, com vírgulas entre eles, exceto no último
for ((i=0; i<${#PACOTES[@]}; i++)); do
    if [ $i -eq $((${#PACOTES[@]}-1)) ]; then
        echo "    \"${PACOTES[$i]}\"" >> $CONFIG_FILE
    else
        echo "    \"${PACOTES[$i]}\"," >> $CONFIG_FILE
    fi
done

# Fecha o arquivo JSON
echo "  ]" >> $CONFIG_FILE
echo "}" >> $CONFIG_FILE

# Exibe o conteúdo do JSON para depuração
echo "Conteúdo do arquivo de configuração gerado:"
cat $CONFIG_FILE

# Executa o archinstall com o arquivo de configuração
echo "Executando archinstall com os pacotes pré-configurados..."
archinstall --config $CONFIG_FILE

# Remove o arquivo de configuração temporário
rm -f $CONFIG_FILE

echo "Configuração concluída! Verifique na interface do archinstall se os pacotes estão pré-selecionados e siga as instruções para finalizar a instalação."
exit 0