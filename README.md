# ⚙️ Arch Linux Instalador Automatizado — por @nagouce

Este repositório instala o Arch Linux com **particionamento automático**, configurações completas e pacotes úteis, tudo com um script só.

## ✅ Configurações aplicadas:

- **Usuário**: `nagouce`  
- **Senha**: `0247`  
- **Hostname**: `Sociedade Secreta`  
- **Partições**:  
  - `/boot` → 512 MiB (FAT32)  
  - `swap` → 4 GiB  
  - `/` → 50 GiB (ext4)  
  - `/home` → resto do disco (ext4)

- **Kernel**: `linux-zen`  
- **Interface**: `Hyprland` + `Wayland`  
- **Pacotes**: dev tools, áudio, Bluetooth, Docker, Samsung tweaks

## 🚀 Como usar:

1. Dê o **boot do Arch Live ISO**
2. Conecte à internet (cabo ou Wi‑Fi via `nmtui`)
3. Execute:

```bash
git clone https://github.com/nagouce/arch-setup-auto.git
cd arch-setup-auto
chmod +x auto.sh
./auto.sh
```

Depois do reboot, é só logar como `nagouce` (senha `0247`) e usar o sistema pronto.
