@echo off
setlocal

REM Configuração de Redes Privadas
REM Desativa a descoberta de rede
netsh advfirewall firewall set rule group="Network Discovery" new enable=No profile=private
REM Ativa o compartilhamento de arquivos e impressoras
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes profile=private

REM Configuração de Redes Públicas
REM Desativa a descoberta de rede
netsh advfirewall firewall set rule group="Network Discovery" new enable=No profile=public
REM Desativa o compartilhamento de arquivos e impressoras
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=No profile=public

REM Configuração de Redes do Domínio
REM Desativa a descoberta de rede
netsh advfirewall firewall set rule group="Network Discovery" new enable=No profile=domain
REM Ativa o compartilhamento de arquivos e impressoras
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes profile=domain

echo Configurações de compartilhamento avançadas foram aplicadas com sucesso.

endlocal
pause
