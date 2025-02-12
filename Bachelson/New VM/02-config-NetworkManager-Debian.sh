#!/bin/bash

# Synopsis
#	Changes Ubuntu 24.04 default netplan configuration to NetworkManager
# Description
#	Changes Ubuntu 24.04 default netplan configuration to NetworkManager
# Example
#	Config-NetworkManager.sh
# Notes
# NAME: Config-NetworkManager
#	AUTHOR: eduardo.agms@outlook.com.br
#	CREATION DATE: 10 August 2023
#	MODIFIED DATE: 29 January 2025
#	VERSION: 2.0
#	CHANGE LOG:
#	V1.0, 10 August 2023 - Initial Version.
#	V2.0, 29 January 2025 - Improved error handling, logging, modularity and compatibility with Ubuntu 24.04.

if [ "$(id -u)" -ne 0 ]; then
    echo "Access denied! Run as SUDO"
    exit 1
fi

LOGFILE="/var/log/config-networkmanager.log"

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

check_ubuntu_version() {
    if [ "$(lsb_release -rs)" != "24.04" ]; then
        log "ERROR" "This script is only compatible with Ubuntu 24.04."
        exit 1
    fi
}

install_network_manager() {
    log "INFO" "Installing NetworkManager..."
    if ! command -v NetworkManager &> /dev/null; then
        apt update -y
        apt install -y network-manager
        check_success "NetworkManager installation"
    else
        log "INFO" "NetworkManager is already installed."
    fi
}

configure_netplan() {
    log "INFO" "Configuring netplan..."
    NETPLAN_FILE="/etc/netplan/00-installer-config.yaml"
    BACKUP_FILE="$NETPLAN_FILE.bak"

    if [ -f "$NETPLAN_FILE" ]; then
        mv "$NETPLAN_FILE" "$BACKUP_FILE"
        check_success "Backup netplan configuration"
    fi

    cat << 'EOL' | tee "$NETPLAN_FILE" > /dev/null
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: NetworkManager
EOL

    netplan generate
    netplan apply
    check_success "Netplan configuration"
}

configure_network_manager() {
    log "INFO" "Configuring NetworkManager..."
    NM_CONF_FILE="/etc/NetworkManager/conf.d/manage-all.conf"

    cat << 'EOL' | tee "$NM_CONF_FILE" > /dev/null
[keyfile]
unmanaged-devices=none
EOL

    systemctl enable NetworkManager
    systemctl restart NetworkManager
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
        if systemctl is-active --quiet "$service"; then
            systemctl mask "$service"
            check_success "Disable $service"
        else
            log "INFO" "$service is already disabled."
        fi
    done
}

log "INFO" "Starting NetworkManager configuration..."
check_ubuntu_version
install_network_manager
configure_netplan
configure_network_manager
disable_network_services

log "INFO" "NetworkManager configuration completed successfully. Rebooting..."
reboot