# Arch Linux Instalador Automatizado

Script interativo para instalar o Arch Linux com Hyprland, otimizado para programação, desenvolvimento, IA e acesso a bancos de dados.

## ✨ Funcionalidades
- **Particionamento automático**:
  - `/boot`: 512 MiB (FAT32, EFI)
  - `swap`: 4 GiB
  - `/`: 50 GiB (ext4)
  - `/home`: Resto do disco (ext4)
- **Kernel**: `linux-zen`
- **Interface**: Hyprland (Wayland) com SDDM
- **Pacotes**: Ferramentas de desenvolvimento, bancos de dados, IA, Bluetooth (veja `pacotes.txt`)
- **Configurações interativas**:
  - Seleção de disco com confirmação de formatação.
  - Escolha de usuário, senha, hostname, fuso horário, língua e teclado via menus.
- **Detecção de hardware**: Drivers gráficos (NVIDIA, Intel, AMD) instalados automaticamente.
- **Suporte UEFI/BIOS**: GRUB configurado conforme o modo de boot.
- **Integração com celular**: Bluetooth e KDE Connect para áudio e transferência de arquivos.

## ⚠️ Aviso
- **Apaga todos os dados no disco selecionado. Faça backup!**
- Requer internet.

## 🚀 Como usar
1. Inicie o Arch Linux Live ISO.
2. Conecte-se à internet (`nmtui` para Wi-Fi).
3. Execute:
   ```bash
   git clone https://github.com/nagouce/arch-linux-hyprland.git
   cd arch-linux-hyprland
   chmod +x auto.sh
   ./auto.sh
