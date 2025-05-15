#!/bin/bash

# Synopsis
#   Prepares Debian VM to be used as VMWare VM Template.
# Description
#   Clears logs, resets hostname, resets network config, resets machine-id, and clears temp files/folders.
# Example
#   sudo ./SysprepDebian.sh
# Notes
#   NAME: SysprepDebian
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 2.2
#   CHANGE LOG:
#   V1.0, 10 August 2023 - Initial Version.
#   V2.0, 29 January 2025 - Improved error handling, logging, modularity, and compatibility with Debian 12.
#   V2.1, 12 March 2025 - Added dependency checks, improved backups, and better error handling.
#   V2.2, 13 March 2025 - Improved service handling, added rollback, and ensured compatibility with Debian 12.

set -e

LOGFILE="/var/log/sysprep-debian.log"
BACKUP_DIR="/opt/backup/sysprep"
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
    if [ -f "$BACKUP_DIR/hostname.bak" ]; then
        cp "$BACKUP_DIR/hostname.bak" /etc/hostname
    fi
    if [ -f "$BACKUP_DIR/machine-id.bak" ]; then
        cp "$BACKUP_DIR/machine-id.bak" /etc/machine-id
    fi
    log "INFO" "Rollback completed."
    exit 1
}

trap rollback ERR

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Access denied! Run as SUDO"
    exit 1
fi

stop_services() {
    log "INFO" "Stopping unnecessary services..."
    SERVICES=("rsyslog" "systemd-networkd" "systemd-networkd-wait-online" "networkd-dispatcher")
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            check_success "Stop $service"
        else
            log "INFO" "$service is already stopped."
        fi
    done
}

clear_audit_logs() {
    log "INFO" "Clearing audit logs..."
    LOG_FILES=("/var/log/wtmp" "/var/log/lastlog")
    for log_file in "${LOG_FILES[@]}"; do
        if [ -f "$log_file" ]; then
            truncate -s0 "$log_file"
            check_success "Truncate $log_file"
        else
            log "WARNING" "$log_file does not exist."
        fi
    done
}

clean_temp_files() {
    log "INFO" "Cleaning temporary files..."
    rm -rf /tmp/* /var/tmp/*
    check_success "Clean temporary files"
}

clear_ssh_keys() {
    log "INFO" "Clearing SSH keys..."
    rm -rf /etc/ssh/ssh_host_*
    check_success "Clear SSH keys"
}

configure_sysprep_service() {
    log "INFO" "Configuring sysprep service..."
    cat << 'EOL' | tee /etc/systemd/system/sysprep.service > /dev/null
[Unit]
Description=One time boot script
[Service]
Type=simple
ExecStart=/runOnce.sh
[Install]
WantedBy=multi-user.target
EOL
    check_success "Create sysprep.service"
    
    cat << 'EOL' | tee /runOnce.sh > /dev/null
#!/bin/bash
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
systemctl disable sysprep.service
rm -f /home/infra/*.sh
rm -f /etc/systemd/system/sysprep.service
rm -f /runOnce.sh
EOL
    check_success "Create /runOnce.sh"
    
    chmod +x /runOnce.sh
    systemctl enable sysprep.service
    check_success "Enable sysprep.service"
}

reset_hostname() {
    log "INFO" "Resetting hostname..."
    cp /etc/hostname "$BACKUP_DIR/hostname.bak"
    sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
    truncate -s0 /etc/hostname
    hostnamectl set-hostname localhost
    check_success "Reset hostname"
}

clear_apt_cache() {
    log "INFO" "Clearing APT cache..."
    apt clean
    check_success "Clear APT cache"
}

reset_machine_id() {
    log "INFO" "Resetting machine-id..."
    cp /etc/machine-id "$BACKUP_DIR/machine-id.bak"
    truncate -s0 /etc/machine-id
    rm -f /var/lib/dbus/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
    check_success "Reset machine-id"
}

clear_cloud_init_logs() {
    log "INFO" "Clearing cloud-init logs..."
    cloud-init clean --logs
    check_success "Clear cloud-init logs"
}

clear_shell_history() {
    log "INFO" "Clearing shell history..."
    cat /dev/null > ~/.bash_history && history -c
    history -w
    cat /dev/null > /home/infra/.bash_history
    check_success "Clear shell history"
}

log "INFO" "Starting Debian sysprep..."
stop_services
clear_audit_logs
clean_temp_files
clear_ssh_keys
configure_sysprep_service
reset_hostname
clear_apt_cache
reset_machine_id
clear_cloud_init_logs
clear_shell_history

log "INFO" "Sysprep completed successfully. Shutting down..."
shutdown -h now