#!/bin/bash

# Script de automação para instalação do Arch Linux usando archinstall
# Executar como root no ambiente live do Arch Linux

# Verifica se está rodando como root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script deve ser executado como root!"
    exit 1
fi

# Verifica se pacotes.txt existe
if [ ! -f pacotes.txt ]; then
    echo "Erro: Arquivo pacotes.txt não encontrado no diretório atual!"
    exit 1
fi

# Função para verificar conexão com a Internet
check_internet() {
    echo "Verificando conexão com a Internet..."
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo "Conexão com a Internet OK!"
    else
        echo "Sem conexão com a Internet. Configurando rede..."
        configure_network
    fi
}

# Função para configurar rede (Wi-Fi ou cabo)
configure_network() {
    read -p "Você está usando Wi-Fi? (s/n): " use_wifi
    if [[ "$use_wifi" =~ ^[Ss]$ ]]; then
        echo "Listando dispositivos Wi-Fi disponíveis..."
        iwctl device list
        read -p "Digite o nome do dispositivo Wi-Fi (ex: wlan0): " wifi_device
        read -p "Digite o SSID da rede Wi-Fi: " wifi_ssid
        read -s -p "Digite a senha do Wi-Fi: " wifi_pass
        echo
        iwctl --passphrase "$wifi_pass" station "$wifi_device" connect "$wifi_ssid"
        sleep 5
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo "Conectado à rede Wi-Fi $wifi_ssid!"
        else
            echo "Falha ao conectar à rede Wi-Fi. Verifique os dados e tente novamente."
            exit 1
        fi
    else
        echo "Configurando rede cabeada..."
        systemctl start dhcpcd
        sleep 5
        if ping -c 1 8.8.8.8 &>/dev/null; then
            echo "Rede cabeada configurada com sucesso!"
        else
            echo "Falha ao configurar rede cabeada. Verifique o cabo e tente novamente."
            exit 1
        fi
    fi
}

# Função para coletar informações do usuário
collect_user_info() {
    read -p "Digite o hostname para o sistema: " hostname
    read -p "Digite o nome do usuário: " username
    read -s -p "Digite a senha do usuário: " user_password
    echo
    read -s -p "Digite a senha do root: " root_password
    echo
}

# Função para gerar arquivo de configuração JSON para archinstall
generate_archinstall_config() {
    # Lê pacotes do pacotes.txt e formata como array JSON
    packages=$(cat pacotes.txt | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')

    # Cria arquivo JSON com configurações
    cat <<EOF > /tmp/archinstall-config.json
{
    "audio": "pipewire",
    "bootloader": "grub-install",
    "config_version": "2.8.2",
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
    "root_password": "$root_password",
    "disk_config": {
        "layout": {
            "type": "manual",
            "partitions": []
        }
    }
}
EOF
}

# Função principal
main() {
    echo "Iniciando instalação automatizada do Arch Linux com archinstall..."
    check_internet
    collect_user_info
    generate_archinstall_config
    echo "Iniciando archinstall com configuração pré-definida..."
    echo "Você será solicitado a configurar o particionamento interativamente."
    archinstall --config /tmp/archinstall-config.json
    if [ $? -eq 0 ]; then
        echo "Instalação concluída com sucesso! Reiniciando em 10 segundos..."
        sleep 10
        reboot
    else
        echo "Erro durante a instalação. Verifique os logs em /var/log/archinstall."
        exit 1
    fi
}

main