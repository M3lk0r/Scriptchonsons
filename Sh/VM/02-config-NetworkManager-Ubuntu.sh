#!/bin/bash

# Synopsis
#   Changes Ubuntu 24.04 default netplan configuration to NetworkManager
# Description
#   Changes Ubuntu 24.04 default netplan configuration to NetworkManager
# Example
#   sudo ./Config-NetworkManager.sh
# Notes
#   NAME: Config-NetworkManager
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 2.4
#   CHANGE LOG:
#   V1.0, 10 August 2023 - Initial Version.
#   V2.0, 29 January 2025 - Improved error handling, logging, modularity and compatibility with Ubuntu 24.04.
#   V2.1, 21 February 2025 - Optimized service checks, improved error handling, and added optional reboot.
#   V2.2, 12 March 2025 - Added dependency checks, improved backups, and better error handling.
#   V2.3, 13 March 2025 - Fixed netplan security permissions issue,ensured complete deactivation of systemd-networkd services and sockets.

set -e

LOGFILE="/var/log/config-networkmanager.log"
NETPLAN_FILE="/etc/netplan/00-installer-config.yaml"
NM_CONF_FILE="/etc/NetworkManager/conf.d/manage-all.conf"
BACKUP_DIR="/opt/backup/network-config"
AUTO_REBOOT=false

log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOGFILE"
}

check_success() {
    local last_command=$1
    if [ $? -ne 0 ]; then
        log "ERROR" "Command failed: $last_command"
        exit 1
    fi
}

rollback() {
    log "ERROR" "An error occurred. Rolling back changes..."
    if [ -f "$BACKUP_DIR/00-installer-config.yaml.bak" ]; then
        cp "$BACKUP_DIR/00-installer-config.yaml.bak" "$NETPLAN_FILE"
        netplan apply
    fi
    if [ -f "$BACKUP_DIR/manage-all.conf.bak" ]; then
        cp "$BACKUP_DIR/manage-all.conf.bak" "$NM_CONF_FILE"
        systemctl restart NetworkManager
    fi
    log "INFO" "Rollback completed."
    exit 1
}

trap rollback ERR

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Access denied! Run as SUDO"
    exit 1
fi

check_ubuntu_version() {
    if [ "$(lsb_release -rs)" != "24.04" ]; then
        log "ERROR" "This script is only compatible with Ubuntu 24.04."
        exit 1
    fi
}

install_network_manager() {
    log "INFO" "Checking if NetworkManager is installed..."
    if ! dpkg -l | grep -qw network-manager; then
        log "INFO" "Installing NetworkManager..."
        apt update -y && apt install -y network-manager
        check_success "NetworkManager installation"
    else
        log "INFO" "NetworkManager is already installed."
    fi
}

configure_netplan() {
    log "INFO" "Configuring netplan..."
    mkdir -p "$BACKUP_DIR"
    if [ -f "$NETPLAN_FILE" ]; then
        cp "$NETPLAN_FILE" "$BACKUP_DIR/00-installer-config.yaml.bak"
        check_success "Backup netplan configuration"
    fi
    
    cat << 'EOL' | tee "$NETPLAN_FILE" > /dev/null
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: NetworkManager
EOL
    
    chmod 600 "$NETPLAN_FILE"
    check_success "Netplan permissions secured"
    
    netplan generate && netplan apply
    check_success "Netplan configuration"
}

configure_network_manager() {
    log "INFO" "Configuring NetworkManager..."
    mkdir -p "$(dirname "$NM_CONF_FILE")"
    if [ -f "$NM_CONF_FILE" ]; then
        cp "$NM_CONF_FILE" "$BACKUP_DIR/manage-all.conf.bak"
        check_success "Backup NetworkManager configuration"
    fi
    
    cat << 'EOL' | tee "$NM_CONF_FILE" > /dev/null
[keyfile]
unmanaged-devices=none
EOL
    
    systemctl enable --now NetworkManager
    check_success "NetworkManager configuration"
}

disable_network_services() {
    log "INFO" "Disabling unnecessary network services..."
    SERVICES=(
        "networkd-dispatcher.service"
        "systemd-networkd-wait-online.service"
        "systemd-networkd.service"
        "systemd-networkd.socket"
    )
    
    for service in "${SERVICES[@]}"; do
        if systemctl list-units --full -all | grep -q "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            systemctl mask "$service"
            check_success "Disabled and masked $service"
        else
            log "INFO" "$service is already masked or inactive."
        fi
    done
    
    systemctl daemon-reexec
    check_success "Systemd daemon re-executed"
}

verify_services() {
    log "INFO" "Verifying that all networkd services are disabled..."
    if systemctl list-units --type=service --all | grep -q "systemd-networkd.service"; then
        status=$(systemctl is-active systemd-networkd)
        if [ "$status" = "inactive" ] || [ "$status" = "failed" ] || [ "$status" = "masked" ]; then
            log "INFO" "All networkd services are correctly disabled."
        else
            log "ERROR" "Some networkd services are still active."
            exit 1
        fi
    else
        log "INFO" "All networkd services are disabled."
    fi
}

log "INFO" "Starting NetworkManager configuration..."
check_ubuntu_version
install_network_manager
configure_netplan
configure_network_manager
disable_network_services
verify_services

log "INFO" "NetworkManager configuration completed successfully."
if [ "$AUTO_REBOOT" = true ]; then
    log "INFO" "Rebooting system..."
    reboot
else
    log "INFO" "Reboot required. Please restart manually."
fi