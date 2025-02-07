#!/bin/bash
# Synopsis

#	Configures and hardens Ubuntu 22.04 VM
# Description
#	Hardens Ubuntu, Configures sources list, secure ssh and sets other security directives.
# Example
#	Configure-UbuntuAviva.sh
# Notes
#	NAME: Configure-UbuntuAviva
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

# Configure firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 65222/tcp
ufw enable
ufw reload

# Creates sources.list backup and creates new sources.list file
mkdir /opt/backup
mv /etc/apt/sources.list /opt/backup

cat << 'EOL' | tee /etc/apt/sources.list
# Mirror C3SL/UFPR
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ jammy main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ jammy-security main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ jammy-updates main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ jammy-proposed main restricted universe multiverse
deb http://ubuntu.c3sl.ufpr.br/ubuntu/ jammy-backports main restricted universe multiverse

# Mirror UEPG
deb https://mirror.uepg.br/ubuntu/ jammy main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ jammy-security main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ jammy-proposed main restricted universe multiverse
deb https://mirror.uepg.br/ubuntu/ jammy-backports main restricted universe multiverse
EOL

# Updates and Upgrades
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y

# Install packages
apt install -y ncdu gparted parted open-vm-tools git htop ntp ntpdate

# Configure SSH

cp /etc/ssh/sshd_config /opt/backup
sed -i 's/#Port 22/Port 65222/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/g' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/g' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
sed -i 's/#PrintLastLog/PrintLastLog/g' /etc/ssh/sshd_config
sed -i '/Port 65222/ i\Protocol 2' /etc/ssh/sshd_config
sed -i '/PermitRootLogin no/ a\AllowUsers infra' /etc/ssh/sshd_config

cat << 'EOL' | tee /etc/motd
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

systemctl restart sshd

# Configure /etc/sysctl.conf
mv /etc/sysctl.conf /opt/backup

cat <<'EOL' | tee -a /etc/sysctl.conf
##-------------------------------------------
# Ajustes de Seguranca
##-------------------------------------------
# BOOLEAN Values:
# a) 0 (zero) - disabled / no / false
# b) Non zero - enabled / yes / true
##-------------------------------------------
 
# Controls whether core dumps will append the PID to the core filename
# Useful for debugging multi-threaded applications
kernel.core_uses_pid = 1
 
#Enable ExecShield protection
kernel.exec-shield = 1
kernel.randomize_va_space = 1
 
# increase system file descriptor limit
fs.file-max = 65535
 
#Allow for more PIDs
kernel.pid_max = 65536
 
########## IPv4 networking start ##############
 
# TCP and memory optimization
# increase TCP max buffer size setable using setsockopt()
#net.ipv4.tcp_rmem = 4096 87380 8388608
#net.ipv4.tcp_wmem = 4096 87380 8388608
 
# increase Linux auto tuning TCP buffer limits
#net.core.rmem_max = 8388608
#net.core.wmem_max = 8388608
#net.core.netdev_max_backlog = 5000
#net.ipv4.tcp_window_scaling = 1
 
#Increase system IP port limits
net.ipv4.ip_local_port_range = 2000 65000
 
# Controls IP packet forwarding
net.ipv4.ip_forward = 0
 
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
 
# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
 
# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
 
# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
 
# Accept Redirects? No, this is not router
net.ipv4.conf.all.secure_redirects = 0
# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
 
# Send redirects, if router, but this is just server
# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
 
# Log Martians (http://en.wikipedia.org/wiki/Martian_packet)
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
 
# Log packets with impossible addresses to kernel log? yes
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
 
# Ignore all ICMP ECHO and TIMESTAMP requests sent to it via broadcast/multicast
net.ipv4.icmp_echo_ignore_broadcasts = 1
 
# Prevent against the common 'syn flood attack'
net.ipv4.tcp_syncookies = 1
 
# Enable source validation by reversed path, as specified in RFC1812
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
 
########## IPv6 networking start ##############
 
# Disable IPv6 support
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
 
# Number of Router Solicitations to send until assuming no routers are present.
# This is host and not router
net.ipv6.conf.default.router_solicitations = 0
 
# Accept Router Preference in RA?
net.ipv6.conf.default.accept_ra_rtr_pref = 0
 
# Learn Prefix Information in Router Advertisement
net.ipv6.conf.default.accept_ra_pinfo = 0
 
# Setting controls whether the system will accept Hop Limit settings from a router advertisement
net.ipv6.conf.default.accept_ra_defrtr = 0
 
#router advertisements can cause the system to assign a global unicast address to an interface
net.ipv6.conf.default.autoconf = 0
 
#how many neighbor solicitations to send out per address?
net.ipv6.conf.default.dad_transmits = 0
 
# How many global unicast IPv6 addresses can be assigned to each interface?
net.ipv6.conf.default.max_addresses = 1
EOL

sysctl -p

# Configure Timezone
timedatectl set-timezone America/Sao_Paulo

# Configure NTP
sed -i 's/pool 0.ubuntu.pool.ntp.org iburst/#pool 0.ubuntu.pool.ntp.org iburst/g' /etc/ntp.conf
sed -i 's/pool 1.ubuntu.pool.ntp.org iburst/#pool 1.ubuntu.pool.ntp.org iburst/g' /etc/ntp.conf
sed -i 's/pool 2.ubuntu.pool.ntp.org iburst/#pool 2.ubuntu.pool.ntp.org iburst/g' /etc/ntp.conf
sed -i 's/pool 3.ubuntu.pool.ntp.org iburst/#pool 3.ubuntu.pool.ntp.org iburst/g' /etc/ntp.conf
sed -i 's/pool ntp.ubuntu.com/#pool ntp.ubuntu.com/g' /etc/ntp.conf
sed -i 's/restrict -4 default kod notrap nomodify nopeer noquery limited/#restrict -4 default kod notrap nomodify nopeer noquery limited/g' /etc/ntp.conf
sed -i 's/restrict -6 default kod notrap nomodify nopeer noquery limited/#restrict -6 default kod notrap nomodify nopeer noquery limited/g' /etc/ntp.conf

cat << 'EOL' | tee -a /etc/ntp.conf
##------------------------------------------------
# Ajuste de seguranca
##------------------------------------------------
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

reboot