#!/bin/bash

# Synopsis
#	Prepares Ubuntu VM to be used as VMWare VM Template.
# Description
#	Clears logs, resets hostname, resets network config, resets machine-id and clear temp files/folders.
# Example
#	SysprepUbuntu.sh
# Notes
#	NAME: SysprepUbuntu
#	AUTHOR: gpaganini@outlook.com
#	CREATION DATE: 10 August 2023
#	MODIFIED DATE: 10 August 2023
#	VERSION: 1.0
#	CHANGE LOG:
#	V1.0, 10 August 2023 - Initial Version.

# Check if being run as sudo
if [ `id -u` -ne 0 ]; then
	echo "Access denied! Run as SUDO"
	exit 1
fi

set -v

# Begin clean-up
systemctl stop rsyslog

# Clear audit logs
if [ -f /var/log/wtmp ]; then
    truncate -s0 /var/log/wtmp
fi

if [ -f /var/log/lastlog ]; then
    truncate -s0 /var/log/lastlog
fi

# Clean /tmp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear SSH Keys
rm -rf /etc/ssh/ssh_host_*

# Configure service to run script at startup to finish cleanup
cat << 'EOL' | tee /etc/systemd/system/sysprep.service
[Unit]
Description=One time boot script
[Service]
Type=simple
ExecStart=/runOnce.sh
[Install]
WantedBy=multi-user.target
EOL

# Create script file, it will recreate ssh-host keys and also delete the scripts used in sysprep, including itself and this one.
cat << 'EOL' | tee /runOnce.sh
#!/bin/bash
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
systemctl disable sysprep.service
rm -f /home/infra/*.sh
rm -f /etc/systemd/system/sysprep.service
rm -f /runOnce.sh
EOL

chmod +x /runOnce.sh
systemctl enable sysprep.service

<<com
# Create script to recreate ssh keys at next boot.
cat << 'EOL' | sudo tee /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# dynamically create hostname (optional) --disabled
#if hostname | grep localhost; then
#    hostnamectl set-hostname "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')"
#fi

test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL

chmod +x /etc/rc.local
com

# Reset hostname
sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
truncate -s0 /etc/hostname
hostnamectl set-hostname localhost

# Clear APT
apt clean

# Reset machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clear cloud-init logs
sudo cloud-init clean --logs

# Clear shell history
cat /dev/null > ~/.bash_history && history -c
history -w
cat /dev/null > /home/infra/.bash_history

# Adios
shutdown -h now