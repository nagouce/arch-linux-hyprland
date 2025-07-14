#!/bin/bash
set -e

disk="/dev/sda"
user="nagouce"
pass="0247"
hostname="Sociedade Secreta"

echo "[1/9] → Particionando $disk..."
sgdisk --zap-all $disk
parted -s $disk mklabel gpt
parted -s $disk mkpart EFI fat32 1MiB 513MiB
parted -s $disk set 1 esp on
parted -s $disk mkpart linux-swap 513MiB 4609MiB
parted -s $disk mkpart primary ext4 4609MiB 56337MiB
parted -s $disk mkpart primary ext4 56337MiB 100%
mkfs.fat -F32 "${disk}1"
mkswap "${disk}2"
swapon "${disk}2"
mkfs.ext4 "${disk}3"
mkfs.ext4 "${disk}4"

echo "[2/9] → Montando partições..."
mount "${disk}3" /mnt
mkdir -p /mnt/{boot,home}
mount "${disk}1" /mnt/boot
mount "${disk}4" /mnt/home

echo "[3/9] → Instalando base..."
pacstrap /mnt base base-devel linux-zen linux-firmware networkmanager sudo git nano

echo "[4/9] → Gerando /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[5/9] → Chroot e configuração..."
arch-chroot /mnt /bin/bash <<EOF
set -e

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

echo "$hostname" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
HOSTS

echo "root:$pass" | chpasswd

useradd -m -G wheel,docker,video,audio,input $user
echo "$user:$pass" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

su - $user -c "
  git clone https://github.com/nagouce/arch-setup-auto.git ~/setup &&
  xargs -a ~/setup/pacotes.txt sudo pacman -S --noconfirm --needed &&
  mkdir -p ~/.config &&
  cp -r ~/setup/configs/* ~/.config/ || true &&
  systemctl enable NetworkManager bluetooth tlp docker
"

EOF

echo "[8/9] → Instalação concluída."
echo "[9/9] → Reiniciando…"
reboot
