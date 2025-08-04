#!/bin/bash
set -e

# Função para verificar conexão com a internet
check_internet() {
    for i in {1..3}; do
        if ping -c 1 archlinux.org > /dev/null 2>&1; then
            return 0
        fi
        echo "Tentativa $i: Sem conexão com a internet. Tentando novamente em 5 segundos..."
        sleep 5
    done
    echo "Erro: Sem conexão com a internet. Use 'nmtui' para Wi-Fi ou 'dhcpcd' para Ethernet."
    exit 1
}

# Função para verificar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo "Erro: $1"
        echo "Detalhes em /tmp/install.log"
        exit 1
    fi
}

# Instalar ferramentas necessárias no ambiente live
pacman -S --noconfirm lsof dosfstools smartmontools
check_error "Falha ao instalar lsof, dosfstools ou smartmontools no ambiente live"

# Aviso inicial
echo "Bem-vindo à instalação automatizada do Arch Linux com Hyprland!"
read -p "Deseja formatar completamente o disco /dev/sda e prosseguir? (s/n): " initial_confirm
if [ "$initial_confirm" != "s" ]; then
    echo "Instalação cancelada."
    exit 1
fi

# Verificar saúde do disco
echo "Verificando saúde do disco /dev/sda..."
smartctl -a /dev/sda | tee -a /tmp/install.log
if smartctl -a /dev/sda | grep -q "SMART overall-health self-assessment test result: FAILED"; then
    echo "Erro: Disco /dev/sda apresenta falhas no teste SMART. Considere substituir o disco."
    exit 1
fi

# Verificar se o disco está em modo somente leitura
if blockdev --getro /dev/sda | grep -q 1; then
    echo "Erro: Disco /dev/sda está em modo somente leitura. Verifique com 'dmesg | grep sda'."
    dmesg | grep sda | tail -n 20 >> /tmp/install.log
    exit 1
fi

# Liberar disco e partições
echo "Liberando disco /dev/sda..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
umount /dev/sda1 2>/dev/null || true
lsof /dev/sda /dev/sda1 2>> /tmp/install.log || true
fuser -m /dev/sda /dev/sda1 2>> /tmp/install.log || true
fuser -k -m /dev/sda /dev/sda1 2>/dev/null || true
dd if=/dev/zero of=/dev/sda bs=1M count=10 status=progress 2>> /tmp/install.log
wipefs -a /dev/sda 2>> /tmp/install.log
sgdisk --zap-all /dev/sda 2>> /tmp/install.log
echo 1 > /proc/sys/kernel/sysrq
echo u > /proc/sysrq-trigger
sync
sleep 2
partprobe /dev/sda
blockdev --rereadpt /dev/sda

# Solicitar usuário, senha e hostname
read -p "Digite o nome do usuário: " user
read -s -p "Digite a senha do usuário: " pass
echo
read -s -p "Confirme a senha do usuário: " pass_confirm
echo
if [ "$pass" != "$pass_confirm" ]; then
    echo "Erro: As senhas não coincidem."
    exit 1
fi
read -p "Digite o hostname do sistema: " hostname

# Criar arquivo de configuração para archinstall
cat <<EOF > /tmp/archinstall-config.json
{
    "audio": "pipewire",
    "bootloader": "grub",
    "custom-commands": [
        "pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland kitty waybar rofi swww sddm polkit-gnome wireplumber pavucontrol brightnessctl bluez bluez-utils blueman network-manager-applet thunar thunar-archive-plugin ttf-jetbrains-mono-nerd noto-fonts bash-completion btop clang curl dbeaver docker docker-compose dunst feh fwupd gcc go htop jupyterlab kdeconnect libinput lm_sensors make mariadb mesa neovim nginx nodejs npm openssh poetry postgresql python python-pip redis ripgrep rust sof-firmware starship tlp unzip zip",
        "systemctl enable NetworkManager bluetooth tlp docker sddm fstrim.timer",
        "git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -s --noconfirm && pacman -U --noconfirm yay-*.pkg.tar.zst",
        "su - $user -c 'yay -S --noconfirm --needed code postman swaylock-effects mongodb-bin python-virtualenv'",
        "su - $user -c 'git clone https://github.com/nagouce/arch-linux-hyprland.git ~/setup && mkdir -p ~/.config && cp -r ~/setup/configs/* ~/.config/ || true'"
    ],
    "disk_config": {
        "config_type": "manual_partitioning",
        "device_modifications": [
            {
                "device": "/dev/sda",
                "wipe": true,
                "partitions": [
                    {
                        "type": "primary",
                        "start": "1MiB",
                        "size": "512MiB",
                        "mountpoint": "/boot/efi",
                        "filesystem": "fat32",
                        "flags": ["Boot", "ESP"]
                    },
                    {
                        "type": "primary",
                        "start": "513MiB",
                        "size": "8192MiB",
                        "mountpoint": null,
                        "filesystem": "linux-swap"
                    },
                    {
                        "type": "primary",
                        "start": "8705MiB",
                        "size": "50000MiB",
                        "mountpoint": "/",
                        "filesystem": "ext4"
                    },
                    {
                        "type": "primary",
                        "start": "58705MiB",
                        "size": "-1",
                        "mountpoint": "/home",
                        "filesystem": "ext4"
                    }
                ]
            }
        ]
    },
    "hostname": "$hostname",
    "kernels": ["linux-zen"],
    "locale_config": {
        "kb_layout": "br",
        "sys_enc": "UTF-8",
        "sys_lang": "pt_BR.UTF-8",
        "timezone": "America/Sao_Paulo"
    },
    "mirror_config": {
        "mirror_regions": {
            "Brazil": []
        }
    },
    "network_config": {
        "type": "nm"
    },
    "profile_config": {
        "profile": "minimal"
    },
    "users": [
        {
            "username": "$user",
            "password": "$pass",
            "sudo": true
        }
    ],
    "root-password": "$pass",
    "sys-encoding": "utf-8",
    "sys-language": "pt_BR"
}
EOF

# Verificar modo UEFI
if [ ! -d /sys/firmware/efi ]; then
    echo "Erro: Este script requer modo UEFI. Seu sistema está em modo BIOS legado."
    exit 1
fi

# Verificar conexão de rede
check_internet
check_network_type() {
    if ip link | grep -q "wlan"; then
        echo "Conexão Wi-Fi detectada. Certifique-se de que está conectado via 'nmtui'."
    elif ip link | grep -q "eth"; then
        echo "Conexão Ethernet detectada. Ativando DHCP..."
        dhcpcd 2>/dev/null || true
    else
        echo "Nenhuma conexão de rede detectada. Configure com 'nmtui' ou 'dhcpcd'."
        exit 1
    fi
}
check_network_type

# Atualizar espelhos
echo "Atualizando lista de espelhos com os melhores pings do Brasil..."
pacman -Syy reflector
for i in {1..3}; do
    reflector --country Brazil --fastest 5 --sort rate --save /etc/pacman.d/mirrorlist && break
    echo "Tentativa $i: Falha ao atualizar espelhos. Tentando novamente em 5 segundos..."
    sleep 5
done
if [ ! -s /etc/pacman.d/mirrorlist ]; then
    echo "Erro: Lista de espelhos vazia. Usando espelho padrão..."
    echo "Server = https://mirror.ufscar.br/archlinux/$repo/os/$arch" > /etc/pacman.d/mirrorlist
fi
pacman -Syy
check_error "Falha ao atualizar repositórios"

# Executar archinstall com configuração
echo "Iniciando instalação com archinstall..."
archinstall --config /tmp/archinstall-config.json --silent --skip-ntp
check_error "Falha ao executar archinstall"

# Configurações adicionais de hardware no chroot
echo "Configurando hardware adicional..."
arch-chroot /mnt /bin/bash <<EOF
set -e
if lscpu | grep -i intel; then
    echo "CPU Intel detectada. Instalando intel-ucode..."
    pacman -S --noconfirm intel-ucode
elif lscpu | grep -i amd; then
    echo "CPU AMD detectada. Instalando amd-ucode..."
    pacman -S --noconfirm amd-ucode
fi
if lspci | grep -i nvidia; then
    echo "GPU NVIDIA detectada. Instalando drivers..."
    pacman -S --noconfirm nvidia-dkms nvidia-utils libva-nvidia-driver
    echo 'env = WLR_NO_HARDWARE_CURSORS,1' >> /home/$user/.config/hypr/hyprland.conf
    echo 'env = WLR_DRM_DEVICES,/dev/dri/card0' >> /home/$user/.config/hypr/hyprland.conf
elif lspci | grep -i intel; then
    echo "GPU Intel detectada. Instalando drivers..."
    pacman -S --noconfirm intel-media-driver vulkan-intel
elif lspci | grep -i amd; then
    echo "GPU AMD detectada. Instalando drivers..."
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon
fi
EOF
check_error "Falha ao configurar hardware"

echo "Instalação concluída."
echo "IMPORTANTE: Remova TODOS os pendrives e dispositivos externos antes de reiniciar."
echo "Entre na BIOS/UEFI (tecla F2) e configure:"
echo "1. Confirme que Secure Boot está DESATIVADO."
echo "2. Confirme que Fast BIOS Mode está DESATIVADO."
echo "3. Em Boot Device Options, selecione 'Arch Linux' ou o disco interno (/dev/sda)."
echo "4. Se 'Arch Linux' não aparecer, reinstale o GRUB manualmente (veja /tmp/install.log)."
echo "5. Envie o /tmp/install.log com 'cat /tmp/install.log | nc termbin.com 9999'."
echo "Reiniciando em 15 segundos... Pressione Ctrl+C para cancelar."
sleep 15
reboot