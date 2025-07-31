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

# Função para detectar modo de boot (UEFI ou BIOS)
detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS"
    fi
}

# Função para verificar tipo de conexão de rede
check_network_type() {
    if ip link | grep -q "wlan"; then
        NETWORK_TYPE="Wi-Fi"
        echo "Conexão Wi-Fi detectada. Certifique-se de que está conectado via 'nmtui'."
    elif ip link | grep -q "eth"; then
        NETWORK_TYPE="Ethernet"
        echo "Conexão Ethernet detectada. Ativando DHCP..."
        dhcpcd 2>/dev/null || true
    else
        NETWORK_TYPE="Unknown"
        echo "Nenhuma conexão de rede detectada. Configure com 'nmtui' ou 'dhcpcd'."
        exit 1
    fi
}

# Função para verificar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo "Erro: $1"
        exit 1
    fi
}

# Instalar dialog e git no ambiente live
pacman -S --noconfirm dialog git
check_error "Falha ao instalar dialog e git no ambiente live"

# Aviso inicial sobre formatação
echo "Bem-vindo à instalação do Arch Linux com Hyprland!"
read -p "Deseja formatar completamente o disco e prosseguir? (s/n): " initial_confirm
if [ "$initial_confirm" != "s" ]; then
    echo "Instalação cancelada."
    exit 1
fi

# Solicitar disco
echo "Lista de discos disponíveis:"
lsblk
read -p "Digite o disco para particionamento (ex.: /dev/sda): " disk
if [ ! -b "$disk" ]; then
    echo "Erro: Disco inválido."
    exit 1
fi
if lsblk -dno RM "$disk" | grep -q 1; then
    echo "Erro: Disco selecionado é removível. Escolha um disco interno."
    exit 1
fi
if [ $(lsblk -dno SIZE "$disk" | grep -o '[0-9.]\+') -lt 20 ]; then
    echo "Erro: Disco muito pequeno (<20GB)."
    exit 1
fi
read -p "AVISO: Todos os dados em $disk serão apagados. Continuar? (s/n): " confirm
if [ "$confirm" != "s" ]; then
    echo "Instalação cancelada."
    exit 1
fi

# Solicitar usuário e senha
read -p "Digite o nome do usuário: " user
read -s -p "Digite a senha do usuário: " pass
echo
read -s -p "Confirme a senha do usuário: " pass_confirm
echo
if [ "$pass" != "$pass_confirm" ]; then
    echo "Erro: As senhas não coincidem."
    exit 1
fi

# Solicitar hostname
read -p "Digite o hostname do sistema: " hostname

# Selecionar fuso horário com dialog
region=$(dialog --stdout --menu "Selecione a região do fuso horário:" 20 60 10 \
    "America" "Américas" \
    "Europe" "Europa" \
    "Asia" "Ásia" \
    "Africa" "África" \
    "Australia" "Austrália" \
    "Pacific" "Pacífico" \
    "Other" "Outro")
if [ -z "$region" ]; then
    echo "Erro: Região não selecionada."
    exit 1
fi

if [ "$region" = "Other" ]; then
    read -p "Digite o fuso horário completo (ex.: America/Sao_Paulo): " timezone
else
    subregions=$(find /usr/share/zoneinfo/$region -type f | sed "s|/usr/share/zoneinfo/$region/||" | sort)
    timezone=$(dialog --stdout --menu "Selecione o fuso horário em $region:" 20 60 10 \
        "Sao_Paulo" "Brasil - São Paulo" \
        $(echo "$subregions" | awk '{print $1, $1}'))
    timezone="$region/$timezone"
fi
if [ ! -f "/usr/share/zoneinfo/$timezone" ]; then
    echo "Erro: Fuso horário inválido."
    exit 1
fi

# Selecionar língua com dialog
language=$(dialog --stdout --menu "Selecione a língua:" 20 60 10 \
    "pt_BR.UTF-8" "Português (Brasil)" \
    "en_US.UTF-8" "Inglês (EUA)" \
    $(grep -v '^#' /etc/locale.gen | grep UTF-8 | awk '{print $1, $1}'))
if [ -z "$language" ]; then
    echo "Erro: Língua não selecionada."
    exit 1
fi

# Selecionar layout do teclado
keymap=$(dialog --stdout --menu "Selecione o layout do teclado:" 20 60 10 \
    "br" "Português (Brasil)" \
    "us" "Inglês (EUA)" \
    $(localectl list-keymaps | sort | awk '{print $1, $1}'))
if [ -z "$keymap" ]; then
    echo "Erro: Layout do teclado não selecionado."
    exit 1
fi

# Detectar modo de boot
detect_boot_mode
echo "Modo de boot detectado: $BOOT_MODE"

# Verificar tipo de conexão de rede
check_network_type

# Iniciar log
exec 1> >(tee -a /tmp/install.log)
exec 2>&1
echo "Iniciando instalação em $(date)"

echo "[1/9] → Verificando pré-requisitos..."
check_internet

# Atualizar lista de espelhos com base na região
echo "Atualizando lista de espelhos..."
pacman -Syy reflector
if [ "$region" = "America" ]; then
    for i in {1..3}; do
        reflector --country Brazil,United_States,Canada,Chile,Argentina --latest 20 --sort rate --save /etc/pacman.d/mirrorlist && break
        echo "Tentativa $i: Falha ao atualizar espelhos. Tentando novamente em 5 segundos..."
        sleep 5
    done
else
    for i in {1..3}; do
        reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist && break
        echo "Tentativa $i: Falha ao atualizar espelhos. Tentando novamente em 5 segundos..."
        sleep 5
    done
fi
pacman -Syy
check_error "Falha ao atualizar repositórios"

echo "[2/9] → Particionando $disk..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
sgdisk --zap-all "$disk"
partprobe "$disk"
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart EFI fat32 1MiB 513MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart linux-swap 513MiB 4609MiB
parted -s "$disk" mkpart primary ext4 4609MiB 56337MiB
parted -s "$disk" mkpart primary ext4 56337MiB 100%
partprobe "$disk"
check_error "Falha ao particionar o disco"

echo "[3/9] → Formatando partições..."
mkfs.fat -F32 "${disk}1"
mkswap "${disk}2"
swapon "${disk}2"
mkfs.ext4 "${disk}3"
mkfs.ext4 "${disk}4"
check_error "Falha ao formatar partições"

echo "[4/9] → Montando partições..."
mount "${disk}3" /mnt
mkdir -p /mnt/{boot,home}
mount "${disk}1" /mnt/boot
mount "${disk}4" /mnt/home
check_error "Falha ao montar partições"

echo "[5/9] → Instalando base..."
pacstrap /mnt base base-devel linux-zen linux-firmware networkmanager sudo git nano \
    grub efibootmgr hyprland xdg-desktop-portal-hyprland kitty waybar rofi swww \
    sddm polkit-gnome pipewire-audio wireplumber pavucontrol brightnessctl bluez bluez-utils \
    blueman network-manager-applet thunar thunar-archive-plugin ttf-jetbrains-mono-nerd \
    noto-fonts bash-completion btop clang curl dbeaver docker docker-compose dunst feh \
    fwupd gcc go htop jupyterlab kdeconnect libinput lm_sensors make mariadb mesa \
    neovim nginx nodejs npm openssh poetry postgresql python python-pip redis ripgrep \
    rust sof-firmware starship tlp unzip zip
check_error "Falha ao instalar pacotes base"

echo "[6/9] → Gerando /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
check_error "Falha ao gerar fstab"

echo "[7/9] → Configurando sistema..."
arch-chroot /mnt /bin/bash <<EOF
set -e

# Configurar fuso horário
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Configurar locale
sed -i "s/^#$language/$language/" /etc/locale.gen
locale-gen
echo "LANG=$language" > /etc/locale.conf

# Configurar hostname
echo "$hostname" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
HOSTS

# Configurar root e usuário
echo "root:$pass" | chpasswd
useradd -m -G wheel,docker,video,audio,input "$user"
echo "$user:$pass" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel_install
chmod 440 /etc/sudoers.d/wheel_install

# Configurar layout do teclado
echo "KEYMAP=$keymap" > /etc/vconsole.conf
mkdir -p /home/$user/.config/hypr
echo "input { kb_layout = $keymap }" > /home/$user/.config/hypr/hyprland.conf
chown -R $user:$user /home/$user/.config

# Instalar GRUB
if [ "$BOOT_MODE" = "UEFI" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    grub-install --target=i386-pc $disk
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Habilitar serviços
systemctl enable systemd-timesyncd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable tlp
systemctl enable docker
systemctl enable sddm
systemctl enable fstrim.timer

# Instalar yay para pacotes do AUR
pacman -S base-devel git --noconfirm
su - "$user" -c "
  git clone https://aur.archlinux.org/yay.git /tmp/yay &&
  cd /tmp/yay &&
  makepkg -s --noconfirm
"
pacman -U /tmp/yay/yay-*.pkg.tar.zst --noconfirm

# Instalar pacotes do AUR
su - "$user" -c "yay -S code postman swaylock-effects mongodb-bin python-virtualenv --noconfirm --needed"

# Copiar configurações do repositório
su - "$user" -c "
  git clone https://github.com/nagouce/arch-linux-hyprland.git ~/setup &&
  mkdir -p ~/.config &&
  cp -r ~/setup/configs/* ~/.config/ || true
"

# Remover privilégios de sudo sem senha
rm /etc/sudoers.d/wheel_install
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
EOF
check_error "Falha ao configurar o sistema"

echo "[8/9] → Verificando configurações de hardware..."
if lscpu | grep -i intel; then
    echo "CPU Intel detectada. Instalando intel-ucode..."
    pacstrap /mnt intel-ucode
elif lscpu | grep -i amd; then
    echo "CPU AMD detectada. Instalando amd-ucode..."
    pacstrap /mnt amd-ucode
fi
if lspci | grep -i nvidia; then
    echo "GPU NVIDIA detectada. Instalando drivers..."
    pacstrap /mnt nvidia-dkms nvidia-utils libva-nvidia-driver
    echo 'env = WLR_NO_HARDWARE_CURSORS,1' >> /mnt/home/$user/.config/hypr/hyprland.conf
    echo 'env = WLR_DRM_DEVICES,/dev/dri/card0' >> /mnt/home/$user/.config/hypr/hyprland.conf
elif lspci | grep -i intel; then
    echo "GPU Intel detectada. Instalando drivers..."
    pacstrap /mnt intel-media-driver vulkan-intel
elif lspci | grep -i amd; then
    echo "GPU AMD detectada. Instalando drivers..."
    pacstrap /mnt xf86-video-amdgpu vulkan-radeon
fi
check_error "Falha ao instalar drivers gráficos"

echo "[9/9] → Instalação concluída."
echo "Reiniciando em 10 segundos..."
sleep 10
reboot