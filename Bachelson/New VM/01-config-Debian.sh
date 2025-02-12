#!/bin/bash

# Synopsis
#	Configures and hardens Debian 12 VM
# Description
#	Hardens Debian, Configures sources list, secure ssh and sets other security directives.
# Example
#	Configure-Debian.sh
# Notes
#	NAME: ConfigureDebian
#	AUTHOR: eduardo.agms@outlook.com.br
#	CREATION DATE: 10 August 2023
#	MODIFIED DATE: 29 January 2025
#	VERSION: 2.0
#	CHANGE LOG:
#	V1.0, 10 August 2023 - Initial Version.
#	V2.0, 29 January 2025 - Improved error handling, logging, modularity and compatibility with Debian 12.

if [ "$(id -u)" -ne 0 ]; then
    echo "Access denied! Run as SUDO"
    exit 1
fi

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

configure_firewall() {
    log "INFO" "Configuring firewall..."
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 65222/tcp
    ufw enable
    ufw reload
    check_success "Firewall configuration"
}

configure_sources() {
    log "INFO" "Configuring sources.list..."
    mkdir -p "$BACKUP_DIR"
    mv /etc/apt/sources.list "$BACKUP_DIR/sources.list.bak"
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
    check_success "Create new sources.list"
}

update_system() {
    log "INFO" "Updating and upgrading system..."
    apt update -y && apt upgrade -y && apt full-upgrade -y && apt autoremove -y
    check_success "System update and upgrade"
}

install_packages() {
    log "INFO" "Installing packages..."
    apt install -y ncdu gparted parted open-vm-tools git htop ntp ntpdate ufw
    check_success "Package installation"
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
#     _____            _						   #
#    / ____|          | |						   #
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
    check_success "MOTD configuration"
}

configure_sysctl() {
    log "INFO" "Configuring sysctl..."
    mv /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak"
    check_success "Backup sysctl.conf"

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

    sysctl -p
    check_success "Sysctl configuration"
}

configure_ntp() {
    log "INFO" "Configuring NTP..."
    sed -i 's/pool 0.debian.pool.ntp.org iburst/#pool 0.debian.pool.ntp.org iburst/g' /etc/ntp.conf
    sed -i 's/pool 1.debian.pool.ntp.org iburst/#pool 1.debian.pool.ntp.org iburst/g' /etc/ntp.conf
    sed -i 's/pool 2.debian.pool.ntp.org iburst/#pool 2.debian.pool.ntp.org iburst/g' /etc/ntp.conf
    sed -i 's/pool 3.debian.pool.ntp.org iburst/#pool 3.debian.pool.ntp.org iburst/g' /etc/ntp.conf
    sed -i 's/restrict -4 default kod notrap nomodify nopeer noquery limited/#restrict -4 default kod notrap nomodify nopeer noquery limited/g' /etc/ntp.conf
    sed -i 's/restrict -6 default kod notrap nomodify nopeer noquery limited/#restrict -6 default kod notrap nomodify nopeer noquery limited/g' /etc/ntp.conf

    cat << 'EOL' | tee -a /etc/ntp.conf > /dev/null
# NTP security settings
restrict -4 ignore
restrict -6 ignore
server 200.160.7.186
server 201.49.148.135
server 200.186.125.195
server 200.20.186.76
server 200.160.0.8
server 200.189.40.8
server 200.192.232.8
server 200.160.7.193
EOL

    ntpdate -u 200.160.7.186
    systemctl restart ntp
    check_success "NTP configuration"
}

log "INFO" "Starting Debian configuration and hardening..."
configure_firewall
configure_sources
update_system
install_packages
configure_ssh
configure_motd
configure_sysctl
configure_ntp

log "INFO" "Configuration completed successfully. Rebooting..."
reboot