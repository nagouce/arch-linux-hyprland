#!/bin/bash

# Verifica se está no ambiente live
if [ ! -d /sys/firmware/efi ]; then
  echo "Ambiente live não detectado ou não é EFI. Verifique a inicialização."
  exit 1
fi

# Configura teclado
loadkeys br-abnt2

# Verifica conexão com a internet
if ping -c 4 archlinux.org &> /dev/null; then
  echo "Conexão com a internet confirmada."
else
  echo "Sem conexão com a internet. Configurando Wi-Fi..."
  iwctl << EOF
  device list
  station wlan0 scan
  station wlan0 get-networks
  station wlan0 connect "SUA_REDE_WIFI"
  exit
EOF
  read -p "Digite a senha do Wi-Fi: " wifi_password
  iwctl --passphrase "$wifi_password" station wlan0 connect "SUA_REDE_WIFI"
  if ! ping -c 4 archlinux.org &> /dev/null; then
    echo "Falha na conexão com a internet. Verifique e tente novamente."
    exit 1
  fi
fi

# Otimiza mirrors
pacman -Syy
reflector --country Brazil --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

# Verifica o disco
echo "Discos disponíveis:"
lsblk
read -p "Digite o dispositivo do disco para instalação (ex.: /dev/sda): " disk
if [ ! -b "$disk" ]; then
  echo "Disco $disk não encontrado. Verifique com 'lsblk' e tente novamente."
  exit 1
fi

# Limpa partições existentes (opcional, com confirmação)
read -p "Deseja limpar todas as partições do disco $disk? (s/n): " wipe_disk
if [ "$wipe_disk" = "s" ]; then
  echo "Limpando partições do disco $disk..."
  wipefs -a "$disk"
fi

# Cria arquivo de configuração para o archinstall
cat > config.json << EOL
{
  "audio": "pipewire",
  "bootloader": "grub",
  "custom-commands": [
    "systemctl enable bluetooth",
    "systemctl enable NetworkManager",
    "systemctl enable tlp",
    "systemctl enable sshd",
    "systemctl enable sddm",
    "gpasswd -a \$USER wheel",
    "echo 'pt_BR.UTF-8 UTF-8' > /etc/locale.gen",
    "locale-gen",
    "echo 'LANG=pt_BR.UTF-8' > /etc/locale.conf",
    "echo 'KEYMAP=br-abnt2' > /etc/vconsole.conf",
    "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
  ],
  "disk-config": {
    "device": "$disk",
    "partitions": [
      {
        "mountpoint": "/",
        "filesystem": "btrfs",
        "size": "50%"
      },
      {
        "mountpoint": "/home",
        "filesystem": "btrfs",
        "size": "45%"
      },
      {
        "type": "swap",
        "size": "8GB"
      }
    ]
  },
  "hostname": "arch-notebook",
  "kernels": ["linux-zen"],
  "locale": {
    "kb_layout": "br",
    "language": "pt_BR",
    "timezone": "America/Sao_Paulo"
  },
  "mirror-regions": ["Brazil"],
  "network": "nm",
  "ntp": true,
  "packages": [
    "bash-completion",
    "bluez",
    "bluez-utils",
    "blueman",
    "btop",
    "clang",
    "code",
    "curl",
    "dbeaver",
    "docker",
    "docker-compose",
    "dunst",
    "efibootmgr",
    "feh",
    "fwupd",
    "gcc",
    "git",
    "go",
    "htop",
    "hyprland",
    "intel-media-driver",
    "intel-ucode",
    "jupyterlab",
    "kdeconnect",
    "kitty",
    "libinput",
    "lm_sensors",
    "make",
    "mariadb",
    "mesa",
    "mongodb",
    "nano",
    "neovim",
    "network-manager-applet",
    "networkmanager",
    "nginx",
    "nodejs",
    "npm",
    "noto-fonts",
    "openssh",
    "pavucontrol",
    "pipewire",
    "pipewire-alsa",
    "pipewire-audio",
    "pipewire-pulse",
    "poetry",
    "postgresql",
    "python",
    "python-pip",
    "redis",
    "ripgrep",
    "rofi",
    "rust",
    "sof-firmware",
    "starship",
    "thunar",
    "thunar-archive-plugin",
    "tlp",
    "unzip",
    "virtualenv",
    "vulkan-intel",
    "waybar",
    "wget",
    "wireplumber",
    "xdg-desktop-portal",
    "xdg-desktop-portal-hyprland",
    "zip",
    "sddm",
    "perl-io-socket-ssl",
    "perl-authen-sasl",
    "perl-mediawiki-api",
    "perl-datetime-format-iso8601",
    "perl-lwp-protocol-https",
    "perl-cgi",
    "subversion",
    "libsecret",
    "less"
  ],
  "profile": "minimal",
  "root-password": "sua_senha_root",
  "user": {
    "name": "seu_usuario",
    "password": "sua_senha_usuario",
    "sudo": true
  }
}
EOL

# Executa o archinstall com a configuração
archinstall --config config.json

# Verifica se a instalação foi bem-sucedida
if [ $? -eq 0 ]; then
  echo "Instalação concluída com sucesso! Reiniciando em 10 segundos..."
  sleep 10
  reboot
else
  echo "Erro durante a instalação. Verifique os logs em /var/log/archinstall."
  exit 1
fi