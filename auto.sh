#!/bin/bash

# Script simplificado para instalação do Arch Linux com archinstall
# Executar como root no ambiente live do Arch Linux

# Verifica se está rodando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script deve ser executado como root!"
    exit 1
fi

# Verifica se pacotes.txt existe
if [ ! -f pacotes.txt ]; then
    echo "Erro: Arquivo pacotes.txt não encontrado!"
    exit 1
fi

# Função para configurar rede (Wi-Fi ou cabo)
configure_network() {
    echo "Verificando conexão com a Internet..."
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo "Conexão OK!"
        return
    fi
    read -p "Usar Wi-Fi? (s/n): " use_wifi
    if [[ "$use_wifi" =~ ^[Ss]$ ]]; then
        echo "Dispositivos Wi-Fi:"
        iwctl device list
        read -p "Nome do dispositivo Wi-Fi (ex: wlan0): " wifi_device
        read -p "SSID da rede Wi-Fi: " wifi_ssid
        read -s -p "Senha do Wi-Fi: " wifi_pass
        echo
        iwctl --passphrase "$wifi_pass" station "$wifi_device" connect "$wifi_ssid"
        sleep 5
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo "Wi-Fi conectado!"
        else
            echo "Falha ao conectar Wi-Fi. Verifique os dados."
            exit 1
        fi
    else
        echo "Configurando rede cabeada..."
        systemctl start dhcpcd
        sleep 5
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo "Rede cabeada OK!"
        else
            echo "Falha na rede cabeada. Verifique o cabo."
            exit 1
        fi
    fi
}

# Função para coletar dados do usuário
collect_user_info() {
    read -p "Hostname do sistema: " hostname
    read -p "Nome do usuário: " username
    read -s -p "Senha do usuário: " user_password
    echo
    read -s -p "Senha do root: " root_password
    echo
}

# Função para gerar arquivo JSON para archinstall
generate_archinstall_config() {
    packages=$(cat pacotes.txt | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')
    cat <<EOF > /tmp/archinstall-config.json
{
    "audio": "pipewire",
    "bootloader": "grub-install",
    "hostname": "$hostname",
    "kernels": ["linux-zen"],
    "locale_config": {
        "kb_layout": "br",
        "sys_enc": "UTF-8",
        "sys_lang": "pt_BR"
    },
    "mirror_config": {
        "mirror_regions": {
            "Brazil": []
        }
    },
    "network_config": {
        "type": "nm"
    },
    "ntp": true,
    "packages": ["base", "base-devel", "linux-firmware", "intel-ucode", $packages],
    "profile": {
        "profile": "hyprland"
    },
    "timezone": "America/Sao_Paulo",
    "users": {
        "$username": {
            "password": "$user_password",
            "sudo": true
        }
    },
    "root_password": "$root_password"
}
EOF
}

# Função principal
main() {
    echo "Iniciando instalação do Arch Linux com archinstall..."
    configure_network
    collect_user_info
    generate_archinstall_config
    echo "Abrindo archinstall. Configure o particionamento quando solicitado."
    archinstall --config /tmp/archinstall-config.json 2> /tmp/install-error.log
    if [ $? -eq 0 ]; then
        echo "Instalação concluída! Reiniciando em 5 segundos..."
        sleep 5
        reboot
    else
        echo "Erro na instalação. Veja /tmp/install-error.log."
        exit 1
    fi
}

main