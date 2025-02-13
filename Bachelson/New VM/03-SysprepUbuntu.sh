#!/bin/bash

# Synopsis
#	Prepares Ubuntu VM to be used as VMWare VM Template.
# Description
#	Clears logs, resets hostname, resets network config, resets machine-id, and clears temp files/folders.
# Example
#	SysprepUbuntu.sh
# Notes
#	NAME: SysprepUbuntu
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

LOGFILE="/var/log/sysprep-ubuntu.log"

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

stop_rsyslog() {
    log "INFO" "Stopping rsyslog service..."
    systemctl stop rsyslog
    check_success "Stop rsyslog service"
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

log "INFO" "Starting Ubuntu sysprep..."
stop_rsyslog
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