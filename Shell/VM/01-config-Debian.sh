#!/bin/bash

# Synopsis
#   Configures and hardens Debian 12 VM
# Description
#   Hardens Debian, configures sources list, secures SSH, and applies security directives.
# Example
#   sudo ./Configure-Debian.sh
# Notes
#   NAME: ConfigureDebian
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 2.2
#   CHANGE LOG:
#   V1.0, 10 August 2023 - Initial Version.
#   V2.0, 29 January 2025 - Improved error handling, logging, modularity, and compatibility with Debian 12.
#   V2.1, 12 March 2025 - Added rollback, improved checks, and added trap for interruptions.
#   V2.2, 13 March 2025 - Added dependency checks, improved backups, and better error handling.

set -e

LOGFILE="/var/log/configure-debian.log"
BACKUP_DIR="/opt/backup"
mkdir -p "$BACKUP_DIR"

log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOGFILE"
}

check_success() {
    if [ $? -ne 0 ]; then
        log "ERROR" "Command failed: $1"
        exit 1
    fi
}

rollback() {
    log "ERROR" "An error occurred. Rolling back changes..."
    if [ -f "$BACKUP_DIR/sources.list.bak" ]; then
        mv "$BACKUP_DIR/sources.list.bak" /etc/apt/sources.list
    fi
    if [ -f "$BACKUP_DIR/sshd_config.bak" ]; then
        mv "$BACKUP_DIR/sshd_config.bak" /etc/ssh/sshd_config
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    fi
    if [ -f "$BACKUP_DIR/sysctl.conf.bak" ]; then
        mv "$BACKUP_DIR/sysctl.conf.bak" /etc/sysctl.conf
        sysctl -p
    fi
    if [ -f "$BACKUP_DIR/jail.local.bak" ]; then
        mv "$BACKUP_DIR/jail.local.bak" /etc/fail2ban/jail.local
        systemctl restart fail2ban
    fi
    log "INFO" "Rollback completed."
    exit 1
}

trap rollback ERR

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Access denied! Run as SUDO"
    exit 1
fi

configure_firewall() {
    log "INFO" "Configuring firewall..."
    apt update && apt install ufw -y
    check_success "Install UFW"
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 65222/tcp
    ufw enable
    ufw reload
    
    ufw status | grep -q "Status: active"
    check_success "Firewall configuration"
}

configure_sources() {
    log "INFO" "Configuring sources.list..."
    cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.bak"
    check_success "Backup sources.list"
    
    cat << 'EOL' | tee /etc/apt/sources.list > /dev/null
# Debian 12 Bookworm
deb http://deb.debian.org/debian bookworm main contrib non-free
deb-src http://deb.debian.org/debian bookworm main contrib non-free

deb http://security.debian.org/debian-security bookworm-security main contrib non-free
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free

deb http://deb.debian.org/debian bookworm-updates main contrib non-free
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free
EOL
    
    apt update
    check_success "Configure sources.list"
}

update_system() {
    log "INFO" "Updating system..."
    apt update && apt upgrade -y && apt autoremove -y
    check_success "System update"
}

install_packages() {
    log "INFO" "Installing essential packages..."
    apt install -y curl wget unzip ufw fail2ban htop ntp net-tools ncdu open-vm-tools git ntpdate
    check_success "Install packages"
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
    
    systemctl restart ssh
    check_success "SSH configuration"
}

configure_motd() {
    log "INFO" "Configuring MOTD..."
    cat << 'EOL' | tee /etc/motd > /dev/null
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
    check_success "Configure MOTD"
}

configure_sysctl() {
    log "INFO" "Configuring sysctl..."
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak"
    check_success "Backup sysctl.conf"
    
    cat << 'EOL' | tee /etc/sysctl.conf > /dev/null
# Security settings
kernel.core_uses_pid = 1
kernel.randomize_va_space = 2
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
    
    sysctl -p
    check_success "Configure sysctl"
}

configure_fail2ban() {
    log "INFO" "Configuring Fail2Ban..."
    apt install -y fail2ban
    check_success "Install Fail2Ban"
    
    cat << 'EOL' | tee /etc/fail2ban/jail.local > /dev/null
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
    check_success "Configure Fail2Ban"
}

log "INFO" "Starting Debian configuration and hardening..."
configure_firewall
configure_sources
update_system
install_packages
configure_ssh
configure_motd
configure_sysctl
configure_fail2ban

log "INFO" "Configuration completed successfully. Rebooting..."
reboot