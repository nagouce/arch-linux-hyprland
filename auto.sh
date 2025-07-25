#!/bin/bash
set -e

# Função para verificar conexão com a internet
check_internet() {
    if ! ping -c 1 archlinux.org > /dev/null 2>&1; then
        echo "Erro: Sem conexão com a internet. Use 'nmtui' para configurar."
        exit 1
    fi
}

# Função para detectar modo de boot (UEFI ou BIOS)
detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS"
    fi
}

# Instalar dialog e git para menus interativos e clonagem
pacman -S --noconfirm dialog git

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
# Primeiro, selecionar região principal
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

# Selecionar sub-região (se aplicável)
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

# Iniciar log
exec 1> >(tee -a /tmp/install.log)
exec 2>&1
echo "Iniciando instalação em $(date)"

echo "[1/9] → Verificando pré-requisitos..."
check_internet

echo "[2/9] → Particionando $disk..."
sgdisk --zap-all "$disk"
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart EFI fat32 1MiB 513MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart linux-swap 513MiB 4609MiB
parted -s "$disk" mkpart primary ext4 4609MiB 56337MiB
parted -s "$disk" mkpart primary ext4 56337MiB 100%
mkfs.fat -F32 "${disk}1"
mkswap "${disk}2"
swapon "${disk}2"
mkfs.ext4 "${disk}3"
mkfs.ext4 "${disk}4"

echo "[3/9] → Montando partições..."
mount "${disk}3" /mnt
mkdir -p /mnt/{boot,home}
mount "${disk}1" /mnt/boot
mount "${disk}4" /mnt/home

echo "[4/9] → Instalando base..."
pacstrap /mnt base base-devel linux-zen linux-firmware networkmanager sudo git nano grub efibootmgr systemd-timesyncd

echo "[5/9] → Gerando /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[6/9] → Configurando sistema..."
arch-chroot /mnt /bin/bash <<EOF
set -e

ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd

sed -i "s/^#$language/$language/" /etc/locale.gen
locale-gen
echo "LANG=$language" > /etc/locale.conf

echo "$hostname" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
HOSTS

echo "root:$pass" | chpasswd
useradd -m -G wheel,docker,video,audio,input "$user"
echo "$user:$pass" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Instalar GRUB conforme modo de boot
if [ "$BOOT_MODE" = "UEFI" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    grub-install --target=i386-pc $disk
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Configurar layout do teclado
echo "KEYMAP=$keymap" > /etc/vconsole.conf

su - "$user" -c "
  git clone https://github.com/nagouce/arch-linux-hyprland.git ~/setup &&
  xargs -a ~/setup/pacotes.txt sudo pacman -S --noconfirm --needed &&
  mkdir -p ~/.config &&
  cp -r ~/setup/configs/* ~/.config/ || true
"

systemctl enable NetworkManager bluetooth tlp docker sddm
EOF

echo "[7/9] → Verificando configurações de hardware..."
if lspci | grep -i nvidia; then
    echo "GPU NVIDIA detectada. Instalando drivers..."
    pacstrap /mnt nvidia-dkms nvidia-utils libva-nvidia-driver
elif lspci | grep -i intel; then
    echo "GPU Intel detectada. Instalando drivers..."
    pacstrap /mnt intel-media-driver vulkan-intel
elif lspci | grep -i amd; then
    echo "GPU AMD detectada. Instalando drivers..."
    pacstrap /mnt xf86-video-amdgpu vulkan-radeon
fi

echo "[8/9] → Instalação concluída."
echo "[9/9] → Reiniciando em 10 segundos..."
sleep 10
reboot
