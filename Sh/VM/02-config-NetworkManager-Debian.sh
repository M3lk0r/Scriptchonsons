#!/bin/bash

# Synopsis
#   Changes Debian 12 default network configuration to NetworkManager
# Description
#   Changes Debian 12 default network configuration to NetworkManager
# Example
#   sudo ./Config-NetworkManager.sh
# Notes
#   NAME: Config-NetworkManager
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 2.1
#   CHANGE LOG:
#   V1.0, 10 August 2023 - Initial Version.
#   V2.0, 29 January 2025 - Improved error handling, logging, modularity, and compatibility with Debian 12.
#   V2.1, 13 March 2025 - Added dependency checks, improved backups, and better error handling.

set -e

LOGFILE="/var/log/config-networkmanager.log"
BACKUP_DIR="/opt/backup/network-config"
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
    if [ -f "$BACKUP_DIR/01-netcfg.yaml.bak" ]; then
        cp "$BACKUP_DIR/01-netcfg.yaml.bak" /etc/netplan/01-netcfg.yaml
        netplan apply
    fi
    if [ -f "$BACKUP_DIR/manage-all.conf.bak" ]; then
        cp "$BACKUP_DIR/manage-all.conf.bak" /etc/NetworkManager/conf.d/manage-all.conf
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

install_network_manager() {
    log "INFO" "Installing NetworkManager..."
    apt update && apt install -y network-manager
    check_success "Install NetworkManager"
}

configure_netplan() {
    log "INFO" "Configuring netplan..."
    NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
    cp "$NETPLAN_FILE" "$BACKUP_DIR/01-netcfg.yaml.bak"
    check_success "Backup netplan configuration"
    
    cat << 'EOL' | tee "$NETPLAN_FILE" > /dev/null
network:
  version: 2
  renderer: NetworkManager
EOL
    
    netplan apply
    check_success "Configure netplan"
}

configure_network_manager() {
    log "INFO" "Configuring NetworkManager..."
    NM_CONF_FILE="/etc/NetworkManager/conf.d/manage-all.conf"
    mkdir -p "$(dirname "$NM_CONF_FILE")"
    cp "$NM_CONF_FILE" "$BACKUP_DIR/manage-all.conf.bak" 2>/dev/null || true
    
    cat << 'EOL' | tee "$NM_CONF_FILE" > /dev/null
[keyfile]
unmanaged-devices=none
EOL
    
    systemctl enable NetworkManager
    systemctl restart NetworkManager
    check_success "Configure NetworkManager"
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
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            systemctl mask "$service"
            check_success "Disable $service"
        else
            log "INFO" "$service is already disabled."
        fi
    done
}

log "INFO" "Starting NetworkManager configuration..."
install_network_manager
configure_netplan
configure_network_manager
disable_network_services

log "INFO" "NetworkManager configuration completed successfully. Rebooting..."
reboot