/ip firewall address-list
add address=10.12.1.0/24 list=rede-local
add address=10.12.200.0/24 list=rede-local
add address=10.12.254.0/24 list=rede-local
add address=storage.agripecas.net list=ip-fileserver
add address=177.125.164.133 list=gerenciamento-remoto
add address=179.84.107.68 list=gerenciamento-remoto
add address=45.70.147.216 list=gerenciamento-remoto
add address=hd8082qmwfe.sn.mynetname.net list=gerenciamento-remoto
add address=192.168.70.68 list=ip-publico
add address=het091ne5v8.sn.mynetname.net list=ip-publico
add address=143.202.225.26 list=ip-publico
add address=192.168.70.0/24 list=rede-local
add address=10.3.60.12 list=rede-local
add address=10.3.1.23 list=rede-monitor-cftv
add address=10.3.1.26 list=rede-monitor-cftv
add address=10.12.1.248 list=ip-cftv
add address=zabbix.agripecas.net list=ip-monitor-servers
add address=observium.agripecas.net list=ip-monitor-servers
add address=172.16.1.1 list=ip-domaincontroller
add address=172.16.1.10 list=ip-domaincontroller
add address=wazuh-server.agripecas.net list=ip-wazuh
add address=10.3.13.2 list=ip-ti
add address=10.3.13.5 list=ip-ti
add address=172.16.1.12 list=ip-proxy
/ip firewall filter
add action=accept chain=input comment="(ICMP)Aceitar ping para ip-publico com limite de 100/segundo" dst-address-list=ip-publico limit=100,10:packet protocol=icmp src-address-list=gerenciamento-remoto
add action=accept chain=forward comment="(ICMP)Aceitar ping para rede-local a partir da rede-servidores com limite de 1000/segundo" dst-address-list=rede-local limit=1k,10:packet protocol=icmp src-address-list=rede-servidores
add action=accept chain=input comment="(ICMP)Aceitar ping para as intefaces da rede-local a partir da rede-suporte com limite de 1000/segundo" dst-address-list=rede-local limit=1k,5:packet protocol=icmp src-address-list=ip-ti
add action=accept chain=input comment="(ICMP)Aceitar ping para as intefaces da rede-local a partir da rede-suporte com limite de 1000/segundo" dst-address-list=rede-local limit=1k,5:packet protocol=icmp src-address-list=rede-servidores
add action=accept chain=forward comment="(ICMP)Aceitar ping para rede-local a partir da rede-suporte com limite de 1000/segundo" dst-address-list=rede-local limit=1k,10:packet protocol=icmp src-address-list=ip-ti
add action=accept chain=output comment="(Wireguard) Libera a comunica\E7\E3o do ip-publico para gerenciamento-remoto na porta UDP 13231" dst-address-list=gerenciamento-remoto dst-port=13231 protocol=udp src-address-list=ip-publico
add action=accept chain=input comment="(Wireguard) Libera a comunica\E7\E3o do gerenciamento-remoto para ip-publico na porta UDP 13231" dst-address-list=ip-publico dst-port=13231 protocol=udp src-address-list=gerenciamento-remoto
add action=accept chain=forward comment="(SNMP)Aceitar conexes UDP 161 e 16161 de rede-servidores para rede-local" dst-address-list=rede-local dst-port=161,16161 protocol=udp src-address-list=ip-monitor-servers
add action=accept chain=input comment="(SNMP)Aceitar conexes UDP 161 e 16161 de gerenciamento-remoto para rede-local" dst-address-list=rede-local dst-port=161,16161 protocol=udp src-address-list=gerenciamento-remoto
add action=accept chain=input comment="(SNMP)Aceitar conexes UDP 161 e 16161 de gerenciamento-remoto para ip-publico" dst-address-list=ip-publico dst-port=161,16161 protocol=udp src-address-list=gerenciamento-remoto
add action=accept chain=forward comment="(VNC)Aceitar conexes UDP 5900 de rede-suporte para rede-local" dst-address-list=rede-local dst-port=5900 protocol=udp src-address-list=ip-ti
add action=accept chain=forward comment="(VNC)Aceitar conexes TCP 5900 de rede-suporte para rede-local" dst-address-list=rede-local dst-port=5900 protocol=tcp src-address-list=ip-ti
add action=accept chain=forward comment="(CFTV)Aceitar conexes TCP HTTP, HTTPS e porta 37777 de rede-monitor-cftv para ip-cftv" dst-address-list=ip-cftv dst-port=37777,443,80 protocol=tcp src-address-list=rede-monitor-cftv
add action=accept chain=forward comment="(SMB)Aceitar conexes SMB de rede-suporte para rede-local" dst-address-list=rede-local dst-port=445 protocol=tcp src-address-list=ip-ti
add action=accept chain=input comment="(Winbox)Aceitar conexes TCP 9900 de gerenciamento-remoto para ip-publico" dst-address-list=ip-publico dst-port=9900 protocol=tcp src-address-list=gerenciamento-remoto
add action=accept chain=forward comment="(SMB) Aceitar conexes TCP 445 da rede-local para ip-fileserver" dst-address-list=ip-fileserver dst-port=445 protocol=tcp src-address-list=rede-local
add action=accept chain=input comment="(Winbox)Permitir conex\E3o via winbox na porta TCP 9900 nos endere\E7os da rede local" dst-address-list=rede-local dst-port=9900 protocol=tcp src-address-list=ip-ti
add action=accept chain=forward comment="(Wazuh) Aceitar conexes TCP 1514,1515 da rede-local para ip-wazuh" dst-address-list=ip-wazuh dst-port=1514,1515 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(Web) Permite conex\E3o HTTPS e HTTP para o ip-proxy" dst-address-list=ip-proxy dst-port=80,443 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(Web) Permite conex\E3o HTTPS e HTTP para o ip-proxy" dst-address-list=ip-proxy dst-port=80,443 protocol=udp src-address-list=rede-local
add action=accept chain=output comment="(DNS) Aceitar conexes TCP 53 das instefaces da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=53 protocol=tcp src-address-list=rede-local
add action=accept chain=output comment="(DNS) Aceitar conexes UDP 53 das instefaces da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=53 protocol=udp src-address-list=rede-local
add action=accept chain=forward comment="(DNS) Aceitar conexes TCP 53 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=53 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(DNS) Aceitar conexes UDP 53 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=53 protocol=udp src-address-list=rede-local
add action=accept chain=forward comment="(LDAP) Aceitar conexes TCP 389 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=389 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(LDAPs) Aceitar conexes TCP 636 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=636 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(Kerberos) Aceitar conexes TCP 88 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=88 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(Kerberos) Aceitar conexes UDP 88 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=88 protocol=udp src-address-list=rede-local
add action=accept chain=forward comment="(SMB) Aceitar conexes TCP 445 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=445 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(RPC) Aceitar conexes TCP 135 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=135 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(NetBIOS) Aceitar conexes UDP 137-138 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=137,138 protocol=udp src-address-list=rede-local
add action=accept chain=forward comment="(NetBIOS) Aceitar conexes TCP 139 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=139 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(NTP) Aceitar conexes UDP 123 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=123 protocol=udp src-address-list=rede-local
add action=accept chain=forward comment="(Global Catalog LDAP) Aceitar conexes TCP 3268 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=3268 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(Global Catalog LDAPS) Aceitar conexes TCP 3269 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=3269 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(WSUS) Aceitar conexes TCP 8530 e 8531 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=8530,8531 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(WinRM) Aceitar conexes TCP 5985 da rede-local para ip-domaincontroller" dst-address-list=ip-domaincontroller dst-port=5985 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="(Fresco) Regra para o fresco do alison dar acessar os dados do PC dele" dst-address-list=ip-ti dst-port=445,3389 protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="Aceitar forward da rede-local portas TCP para WAN" dst-port=53,80,443 out-interface-list=WAN protocol=tcp src-address-list=rede-local
add action=accept chain=forward comment="Aceitar forward da rede-local portas UDP para WAN" dst-port=53,3478-3481,50000-60000 out-interface-list=WAN protocol=udp src-address-list=rede-local
add action=accept chain=output comment="Aceitar saida da rede-local portas TCP para WAN" dst-port=53,80,443 out-interface-list=WAN protocol=tcp src-address-list=rede-local
add action=accept chain=output comment="Aceitar saida da rede-local portas UDP para WAN" dst-port=53,3478-3481,50000-60000 out-interface-list=WAN protocol=udp src-address-list=rede-local
add action=accept chain=output comment="Permitir tr\E1fego de sa\EDda para conex\F5es estabelecidas e relacionadas" connection-state=established,related src-address-list=rede-local
add action=accept chain=input comment="Permitir tr\E1fego de sa\EDda para conex\F5es estabelecidas e relacionadas" connection-state=established,related dst-address-list=rede-local
add action=accept chain=forward comment="Permitir tr\E1fego de forward para conex\F5es estabelecidas e relacionadas" connection-state=established,related dst-address-list=rede-local
add action=accept chain=forward comment="Permitir tr\E1fego de forward para conex\F5es estabelecidas e relacionadas" connection-state=established,related src-address-list=rede-local
add action=drop chain=input comment="Dropar todo acesso de entrada"
add action=drop chain=output comment="Dropar todo trafego de sada"
add action=drop chain=forward comment="Dropa todo trafego de forward"