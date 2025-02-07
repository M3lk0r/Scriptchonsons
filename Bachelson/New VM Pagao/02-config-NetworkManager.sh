#!/bin/bash

# Synopsis
#	Changes Ubuntu 22.04 default netplan configuration to NetworkManager
# Description
#	Changes Ubuntu 22.04 default netplan configuration to NetworkManager
# Example
#	Config-NetworkManager.sh
# Notes
#	NAME: Config-NetworkManager
#	AUTHOR: giovanipaganini@outlook.com
#	CREATION DATE: 11 August 2023
#	MODIFIED DATE: 11 August 2023
#	VERSION: 1.0
#	CHANGE LOG:
#	V1.0, 11 August 2023 - Initial Version.

# Check if being run as sudo
if [ `id -u` -ne 0 ]; then
	echo "Access denied! Run as SUDO"
	exit 1
fi

set -v

# Install NetworkManager
apt install -y network-manager

# Backup current config
mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak

cat << 'EOL' | tee /etc/netplan/00-installer-config.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: NetworkManager
  
EOL

netplan generate
netplan apply

cat << 'EOL' | tee /etc/NetworkManager/conf.d/manage-all.conf
[keyfile]
unmanaged-devices=none
EOL

systemctl enable NetworkManager
systemctl restart NetworkManager

systemctl mask networkd-dispatcher.service
systemctl mask systemd-networkd-wait-online.service
systemctl mask systemd-networkd.service
systemctl mask systemd-networkd.socket

reboot