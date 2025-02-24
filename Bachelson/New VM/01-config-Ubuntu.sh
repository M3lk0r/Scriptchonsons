#!/bin/bash

# Synopsis
#   Configures and hardens Ubuntu 24.04 VM
# Description
#   Hardens Ubuntu, configures sources list, secures SSH, and applies security directives.
# Example
#   sudo ./configure-ubuntu.sh
# Notes
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 2.1
#   LAST MODIFIED: 21 February 2025

set -e

LOGFILE="/var/log/configure-ubuntu.log"
BACKUP_DIR="/opt/backup"
mkdir -p "$BACKUP_DIR"

log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOGFILE"
}

check_success() {
    local status=$?
    local action="$1"
    if [ $status -ne 0 ]; then
        log "ERROR" "Falha ao executar: $action"
        exit 1
    fi
}

trap 'log "ERROR" "Erro inesperado! Saindo..."' ERR

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Acesso negado! Execute como root (sudo)."
    exit 1
fi

configure_firewall() {
    log "INFO" "Configurando firewall..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 65222/tcp
    ufw allow 65222/udp
    ufw enable
    ufw reload
    check_success "Configuração do firewall"
}

configure_sources() {
    log "INFO" "Configurando repositórios (sources.list)..."
    cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.bak"

    cat << 'EOL' > /etc/apt/sources.list
# Mirror C3SL/UFPR (Ubuntu 24.04 - Noble Numbat)
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ noble main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ noble-security main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ noble-updates main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ noble-backports main restricted universe multiverse

# Mirror UEPG
deb https://mirror.uepg.br/ubuntu/ noble main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ noble-updates main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ noble-security main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ noble-backports main restricted universe multiverse
EOL

    check_success "Repositórios configurados"
}

update_system() {
    log "INFO" "Atualizando sistema..."
    apt update && apt upgrade -y && apt autoremove -y
    check_success "Atualização do sistema"
}

install_packages() {
    log "INFO" "Instalando pacotes essenciais..."
    apt install -y curl wget unzip ufw fail2ban htop ntp net-tools ncdu open-vm-tools git ntpdate
    check_success "Instalação de pacotes"
}

restart_ssh() {
    if systemctl list-units --full -all | grep -q sshd.service; then
        systemctl restart sshd
    elif systemctl list-units --full -all | grep -q ssh.service; then
        systemctl restart ssh
    else
        log "ERROR" "Neither sshd nor ssh service found!"
        exit 1
    fi
    check_success "SSH service restart"
}

configure_ssh() {
    log "INFO" "Configuring SSH..."
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak"
    check_success "Backup SSH config"

    sed -i 's/#Port 22/Port 65222/g' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/g' /etc/ssh/sshd_config
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/g' /etc/ssh/sshd_config
    sed -i 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
    sed -i 's/#PrintLastLog/PrintLastLog/g' /etc/ssh/sshd_config
    sed -i '/Port 65222/ i\Protocol 2' /etc/ssh/sshd_config
    sed -i '/PermitRootLogin no/ a\AllowUsers infra' /etc/ssh/sshd_config

    restart_ssh
}

configure_motd() {
    log "INFO" "Configurando mensagem de login (MOTD)..."
    cat << 'EOL' > /etc/motd

####################################################
#     _____            _                           #
#    / ____|          | |                          #
#   | |     ___  _ __ | |_ ___  ___  ___           #
#   | |    / _ \| '_ \| __/ _ \/ __|/ _ \          #
#   | |___| (_) | | | | || (_) \__ \ (_) |         #
#    \_____\___/|_| |_|\__\___/|___/\___/          #
#                                                  #
# Tecnologia da Informação - Infraestrutura        #
# Acesso Restrito e Monitorado!                    #
#                                                  #
####################################################
EOL
    check_success "Configuração do MOTD"
}

configure_sysctl() {
    log "INFO" "Configurando parâmetros de segurança (sysctl)..."
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak"

    cat << 'EOL' | tee /etc/sysctl.conf > /dev/null
    
# Security settings
kernel.core_uses_pid = 1
kernel.exec-shield = 1
kernel.randomize_va_space = 1
fs.file-max = 65535
kernel.pid_max = 65536
net.ipv4.ip_forward = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOL

    sysctl --system
    check_success "Configuração do sysctl"
}

configure_ntp() {
    log "INFO" "Configurando NTP..."
    cp /etc/ntp.conf "$BACKUP_DIR/ntp.conf.bak"

    cat << 'EOL' > /etc/ntp.conf
# Configuração de servidores NTP confiáveis
server 200.160.7.186 iburst
server 201.49.148.135 iburst
server 200.186.125.195 iburst
server 200.20.186.76 iburst
server 200.160.0.8 iburst
EOL

    systemctl restart ntp
    check_success "Configuração do NTP"
}

configure_fail2ban() {
    log "INFO" "Configurando Fail2Ban..."
    cp /etc/fail2ban/jail.local "$BACKUP_DIR/jail.local.bak" || touch /etc/fail2ban/jail.local

    cat << 'EOL' > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = 65222
EOL

    systemctl restart fail2ban
    check_success "Configuração do Fail2Ban"
}

log "INFO" "Iniciando configuração do servidor Ubuntu 24.04..."
configure_firewall
configure_sources
update_system
install_packages
configure_ssh
configure_motd
configure_sysctl
configure_ntp
configure_fail2ban

log "INFO" "Configuração concluída com sucesso. Reiniciando..."
reboot