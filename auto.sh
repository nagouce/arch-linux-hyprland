#!/bin/bash

# Instala o git, se necessário
pacman -Sy git --noconfirm

# Clona o repositório
git clone https://github.com/nagouce/arch-linux-hyprland.git
cd arch-linux-hyprland

# Cria o arquivo user_configuration.json
cat << EOF > user_configuration.json
{
  "audio": {
    "audio": "pipewire"
  },
  "bootloader": "systemd-boot",
  "config_version": "2.8.2",
  "debug": false,
  "disk_config": {
    "disk_layouts": [
      {
        "device_path": "/dev/sda",
        "partitions": [
          {
            "boot": true,
            "encrypted": false,
            "filesystem": {
              "format": "fat32"
            },
            "mountpoint": "/boot",
            "size": "512MiB",
            "type": "primary"
          },
          {
            "encrypted": false,
            "filesystem": {
              "format": "swap"
            },
            "mountpoint": "swap",
            "size": "4GiB",
            "type": "primary"
          },
          {
            "encrypted": false,
            "filesystem": {
              "format": "ext4"
            },
            "mountpoint": "/",
            "size": "50GiB",
            "type": "primary"
          },
          {
            "encrypted": false,
            "filesystem": {
              "format": "ext4"
            },
            "mountpoint": "/home",
            "size": "100%FREE",
            "type": "primary"
          }
        ],
        "wipe": true
      }
    ]
  },
  "hostname": "Sociedade Secreta",
  "kernels": ["linux-zen"],
  "locale_config": {
    "kb_layout": "br",
    "sys_enc": "UTF-8",
    "sys_lang": "pt_BR"
  },
  "network_config": {
    "type": "nm"
  },
  "no_pkg_lookups": false,
  "ntp": true,
  "offline": false,
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
    "postman",
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
    "zip"
  ],
  "parallel_downloads": 0,
  "profile_config": {
    "profile": "hyprland"
  },
  "services": [
    "bluetooth",
    "docker",
    "NetworkManager",
    "sshd",
    "tlp"
  ],
  "swap": true,
  "timezone": "America/Sao_Paulo",
  "users": [
    {
      "username": "nagouce",
      "password": "$6$exemplo_hash",
      "sudo": true
    }
  ]
}
EOF

# Gera o hash da senha
echo "0247" | openssl passwd -6 -stdin > password_hash
sed -i "s|\$6\$exemplo_hash|$(cat password_hash)|" user_configuration.json
rm password_hash

# Executa o archinstall
archinstall --config user_configuration.json

# Verifica o resultado
if [ $? -eq 0 ]; then
  echo "Instalação concluída! Reinicie o sistema com 'reboot'."
else
  echo "Erro durante a instalação. Verifique os logs em /var/log/archinstall."
  exit 1
fi