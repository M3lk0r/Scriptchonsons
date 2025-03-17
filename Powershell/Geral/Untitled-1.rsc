/interface vlan
add interface=bridge name=vlan40-rede-aberta vlan-id=40
add interface=bridge name=vlan50-wifi-corporate vlan-id=50
/ip pool
add name=wifi-corporate ranges=10.1.50.2-10.1.50.200
add name=rede-aberta ranges=192.168.101.2-192.168.101.200
/ip address
add address=10.1.50.1/24 interface=vlan50-wifi-corporate network=10.1.50.0
add address=192.168.101.1/24 interface=vlan40-rede-aberta network=192.168.101.0
/ip dhcp-server
add address-pool=rede-aberta interface=vlan40-rede-aberta name=rede-aberta
/ip dhcp-server network
add address=192.168.101.0/24 dns-server=1.1.1.1,8.8.8.8 gateway=192.168.101.1
/ip firewall address-list
add address=192.168.101.0/24 list=rede-aberta
/ip firewall filter
add action=accept chain=forward comment="Permite rede-aberta para WAN" out-interface-list=WAN src-address-list=rede-aberta
add action=accept chain=forward comment="Permite DHCP Option 43 (AP -> Controladora)" dst-address-list=ip-unificontroller dst-port=8080,8443,3478,10001 protocol=tcp src-address-list=rede-gerencia
add action=accept chain=forward comment="Permite trfego AP -> Controladora UniFi" dst-address-list=ip-unificontroller dst-port=22,8880,8843 protocol=tcp src-address-list=rede-gerencia
add action=accept chain=forward comment="Permite trfego AP -> Controladora UniFi" dst-address-list=ip-unificontroller protocol=icmp src-address-list=rede-gerencia
add action=accept chain=forward comment="Permite STUN para descoberta de APs" dst-address-list=ip-unificontroller dst-port=5514,3478 protocol=udp src-address-list=rede-gerencia
add action=accept chain=forward comment="Permite L2 Discovery APs UniFi" dst-address-list=ip-unificontroller dst-port=10001 protocol=udp src-address-list=rede-gerencia
add action=accept chain=forward comment="Permite trfego AP -> Controladora UniFi" dst-address-list=rede-gerencia protocol=icmp src-address-list=ip-unificontroller
add action=accept chain=forward comment="Permite DHCP Option 43 (AP -> Controladora)" dst-address-list=ip-unificontroller dst-port=80,443,8080,8880,8882,8443 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="Permite DHCP Option 43 (AP -> Controladora)" dst-address-list=ip-unificontroller dst-port=80,443,8080,8880,8882,8443 protocol=tcp src-address-list=rede-aberta
add action=accept chain=forward comment="Permite DNS para clientes do Captive Portal" dst-address-list=ip-domaincontroller dst-port=53 protocol=udp src-address-list=rede-aberta
add action=accept chain=forward comment="Permite ICMP Captive Portal" dst-address-list=ip-unificontroller protocol=icmp src-address-list=rede-aberta
add action=accept chain=forward comment="Permite rede-aberta para consulta DNS ip-domaincontroller" dst-address-list=ip-proxy dst-port=80,443 protocol=tcp src-address-list=rede-aberta






set-inform https://unificontroller.agripecas.net/inform
syswrapper.sh restore-default
mca-cli
info

/ip firewall filter
add action=accept chain=forward comment="Permite DHCP Option 43 (AP -> Controladora)" src-address-list=rede-gerencia dst-address-list=ip-unificontroller dst-port=8080,8443,3478,10001 protocol=tcp
add action=accept chain=forward comment="Permite tráfego AP -> Controladora UniFi" src-address-list=rede-gerencia dst-address-list=ip-unificontroller dst-port=22,8880,8843 protocol=tcp
add action=accept chain=forward comment="Permite STUN para descoberta de APs" src-address-list=rede-gerencia dst-address-list=ip-unificontroller dst-port=3478 protocol=udp
add action=accept chain=forward comment="Permite L2 Discovery APs UniFi" src-address-list=rede-gerencia dst-address-list=ip-unificontroller dst-port=10001 protocol=udp
add action=accept chain=forward comment="Permite Controladora UniFi acessar APs" src-address-list=ip-unificontroller dst-address-list=rede-gerencia dst-port=22,8080,8443,3478,10001 protocol=tcp
add action=accept chain=forward comment="Permite STUN APs -> Controladora UniFi" src-address-list=rede-gerencia dst-address-list=ip-unificontroller dst-port=3478 protocol=udp
