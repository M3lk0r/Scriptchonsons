#!/bin/bash

# Synopsis
#   Instala e configura o NGINX como proxy reverso com melhores práticas.
# Description
#   Este script instala o NGINX, configura suporte a HTTP/HTTPS, e define as melhores práticas para proxy reverso.
#   Permite personalizar o server_name, endereço de destino (backend) e nome do arquivo de configuração.
# Example
#   sudo ./configure-nginx-proxy.sh
# Notes
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 1.0
#   LAST MODIFIED: 13 March 2025

set -e

LOGFILE="/var/log/configure-nginx-proxy.log"
BACKUP_DIR="/opt/backup"
mkdir -p "$BACKUP_DIR"

log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOGFILE"
}

check_success() {
    local status=$?
    local action="$1"
    if [ $status -ne 0 ]; then
        log "ERROR" "Falha ao executar: $action"
        exit 1
    fi
}

trap 'log "ERROR" "Erro inesperado! Saindo..."' ERR

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Acesso negado! Execute como root (sudo)."
    exit 1
fi

install_nginx() {
    log "INFO" "Instalando NGINX..."
    apt-get update
    apt-get install -y nginx
    check_success "Instalação do NGINX"
}

configure_firewall() {
    log "INFO" "Configurando o firewall..."
    
    if ! ufw status | grep -q "Status: active"; then
        log "ERROR" "O UFW não está ativo. Ative o UFW antes de continuar."
        exit 1
    fi
    
    if ! ufw status | grep -q "80/tcp"; then
        log "INFO" "Adicionando regra para a porta 80/tcp..."
        ufw allow 80/tcp
    else
        log "INFO" "A regra para a porta 80/tcp já existe."
    fi
    
    if ! ufw status | grep -q "443/tcp"; then
        log "INFO" "Adicionando regra para a porta 443/tcp..."
        ufw allow 443/tcp
    else
        log "INFO" "A regra para a porta 443/tcp já existe."
    fi
    
    ufw reload
    check_success "Recarregamento do UFW"
    
    log "INFO" "Configuração do firewall concluída com sucesso!"
}

convert_pfx_to_crt_key() {
    local pfx_file="$1"
    local pfx_password="$2"
    local crt_file="$3"
    local key_file="$4"
    
    log "INFO" "Convertendo o arquivo .pfx para .crt e .key..."
    openssl pkcs12 -in "$pfx_file" -out "$crt_file" -clcerts -nokeys -password "pass:$pfx_password"
    check_success "Extraindo o certificado (.crt) do .pfx"
    
    openssl pkcs12 -in "$pfx_file" -out "$key_file" -nocerts -nodes -password "pass:$pfx_password"
    check_success "Extraindo a chave privada (.key) do .pfx"
    
    log "INFO" "Conversão concluída com sucesso!"
}

create_fullchain() {
    local server_cert="$1"
    local chain_cert="$2"
    local fullchain_file="$3"
    
    log "INFO" "Criando arquivo fullchain.pem..."
    cat "$server_cert" "$chain_cert" > "$fullchain_file"
    check_success "Criação do fullchain.pem"
    
    log "INFO" "Fullchain.pem criado com sucesso em: $fullchain_file"
}

configure_http_https() {
    log "INFO" "Configurando suporte a HTTP/HTTPS..."
    
    read -p "Deseja configurar HTTPS? (s/n): " USE_HTTPS
    if [[ "$USE_HTTPS" == "s" || "$USE_HTTPS" == "S" ]]; then
        read -p "Usar Let's Encrypt para gerar certificados? (s/n): " USE_LETSENCRYPT
        if [[ "$USE_LETSENCRYPT" == "s" || "$USE_LETSENCRYPT" == "S" ]]; then
            log "INFO" "Instalando Certbot para Let's Encrypt..."
            apt-get install -y certbot python3-certbot-nginx
            check_success "Instalação do Certbot"
            
            read -p "Digite o server_name (ex: exemplo.com): " SERVER_NAME
            log "INFO" "Configurando NGINX para o desafio do Let's Encrypt..."
            
            TEMP_CONFIG="/etc/nginx/sites-available/letsencrypt-challenge"
            cat << EOL > "$TEMP_CONFIG"
server {
    listen 80;
    server_name $SERVER_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOL
            
            ln -sf "$TEMP_CONFIG" "/etc/nginx/sites-enabled/letsencrypt-challenge"
            systemctl reload nginx
            check_success "Recarregamento do NGINX para o desafio do Let's Encrypt"
            
            log "INFO" "Gerando certificado Let's Encrypt para $SERVER_NAME..."
            certbot --nginx -d "$SERVER_NAME" --non-interactive --agree-tos --email admin@$SERVER_NAME
            check_success "Geração do certificado Let's Encrypt"
            
            rm -f "$TEMP_CONFIG" "/etc/nginx/sites-enabled/letsencrypt-challenge"
            systemctl reload nginx
            log "INFO" "Configuração temporária do desafio removida."
        else
            read -p "Você possui um certificado .pfx? (s/n): " USE_PFX
            if [[ "$USE_PFX" == "s" || "$USE_PFX" == "S" ]]; then
                read -p "Digite o caminho completo para o arquivo .pfx: " PFX_FILE
                read -s -p "Digite a senha do arquivo .pfx: " PFX_PASSWORD
                echo
                
                if [[ ! -f "$PFX_FILE" ]]; then
                    log "ERROR" "Arquivo .pfx não encontrado!"
                    exit 1
                fi
                
                CERT_DIR="/etc/nginx/ssl"
                mkdir -p "$CERT_DIR"
                CRT_FILE="$CERT_DIR/$SERVER_NAME.crt"
                KEY_FILE="$CERT_DIR/$SERVER_NAME.key"
                
                convert_pfx_to_crt_key "$PFX_FILE" "$PFX_PASSWORD" "$CRT_FILE" "$KEY_FILE"
                
                read -p "Digite o caminho completo para o arquivo chain.pem (certificado intermediário): " CHAIN_FILE
                if [[ ! -f "$CHAIN_FILE" ]]; then
                    log "ERROR" "Arquivo chain.pem não encontrado!"
                    exit 1
                fi
                
                FULLCHAIN_FILE="$CERT_DIR/$SERVER_NAME-fullchain.pem"
                create_fullchain "$CRT_FILE" "$CHAIN_FILE" "$FULLCHAIN_FILE"
                
                SSL_CERT="$FULLCHAIN_FILE"
                SSL_KEY="$KEY_FILE"
            else
                read -p "Digite o caminho completo para o certificado do servidor (.crt): " SERVER_CERT
                read -p "Digite o caminho completo para o certificado chain.pem (intermediário): " CHAIN_CERT
                read -p "Digite o caminho completo para a chave privada SSL existente (.key): " SSL_KEY
                
                if [[ ! -f "$SERVER_CERT" || ! -f "$CHAIN_CERT" || ! -f "$SSL_KEY" ]]; then
                    log "ERROR" "Certificado ou chave privada não encontrados!"
                    exit 1
                fi
                
                CERT_DIR="/etc/nginx/ssl"
                mkdir -p "$CERT_DIR"
                FULLCHAIN_FILE="$CERT_DIR/$SERVER_NAME-fullchain.pem"
                create_fullchain "$SERVER_CERT" "$CHAIN_CERT" "$FULLCHAIN_FILE"
                
                SSL_CERT="$FULLCHAIN_FILE"
            fi
        fi
    fi
}

create_nginx_proxy_config() {
    log "INFO" "Criando arquivo de configuração do proxy reverso..."
    
    read -p "Digite o nome do arquivo de configuração (ex: meu-proxy): " CONFIG_NAME
    read -p "Digite o server_name (ex: exemplo.com): " SERVER_NAME
    read -p "Digite o endereço de destino (backend) (ex: http://192.168.1.100:8080): " BACKEND_ADDRESS
    
    CONFIG_FILE="/etc/nginx/sites-available/$CONFIG_NAME"
    CONFIG_LINK="/etc/nginx/sites-enabled/$CONFIG_NAME"
    
    log "INFO" "Criando arquivo de configuração: $CONFIG_FILE..."
    cat << EOL > "$CONFIG_FILE"
# Configuração de proxy reverso para $SERVER_NAME
server {
    listen 80;
    server_name $SERVER_NAME;

    # Redirecionamento para HTTPS (se configurado)
    $(if [[ "$USE_HTTPS" == "s" || "$USE_HTTPS" == "S" ]]; then
        echo "return 301 https://\$host\$request_uri;"
    fi)
}

$(if [[ "$USE_HTTPS" == "s" || "$USE_HTTPS" == "S" ]]; then
    echo "server {"
    echo "    listen 443 ssl;"
    echo "    server_name $SERVER_NAME;"
    if [[ "$USE_LETSENCRYPT" == "s" || "$USE_LETSENCRYPT" == "S" ]]; then
        echo "    ssl_certificate /etc/letsencrypt/live/$SERVER_NAME/fullchain.pem;"
        echo "    ssl_certificate_key /etc/letsencrypt/live/$SERVER_NAME/privkey.pem;"
    else
        echo "    ssl_certificate $SSL_CERT;"
        echo "    ssl_certificate_key $SSL_KEY;"
    fi
    echo ""
    echo "    # Melhores práticas para SSL"
    echo "    ssl_protocols TLSv1.2 TLSv1.3;"
    echo "    ssl_ciphers HIGH:!aNULL:!MD5;"
    echo "    ssl_prefer_server_ciphers on;"
    echo "    ssl_session_cache shared:SSL:10m;"
    echo "    ssl_session_timeout 10m;"
    echo ""
    echo "    # Configurações de proxy reverso"
    echo "    location / {"
    echo "        proxy_pass $BACKEND_ADDRESS;"
    echo "        proxy_set_header Host \$host;"
    echo "        proxy_set_header X-Real-IP \$remote_addr;"
    echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
    echo "        proxy_set_header X-Forwarded-Proto \$scheme;"
    echo "        proxy_set_header X-Forwarded-Host \$host;"
    echo "        proxy_set_header X-Forwarded-Server \$host;"
    echo "        proxy_connect_timeout 60s;"
    echo "        proxy_read_timeout 60s;"
    echo "        proxy_send_timeout 60s;"
    echo "        proxy_buffer_size 128k;"
    echo "        proxy_buffers 4 256k;"
    echo "        proxy_busy_buffers_size 256k;"
    echo ""
    echo "        # Suporte a WebSockets"
    echo "        proxy_http_version 1.1;"
    echo "        proxy_set_header Upgrade \$http_upgrade;"
    echo "        proxy_set_header Connection "upgrade";"
    echo "    }"
    echo "}"
fi)
EOL
    
    ln -sf "$CONFIG_FILE" "$CONFIG_LINK"
    check_success "Criação do arquivo de configuração"
}

test_and_restart_nginx() {
    log "INFO" "Testando configuração do NGINX..."
    nginx -t
    check_success "Teste de configuração do NGINX"
    
    log "INFO" "Reiniciando NGINX..."
    systemctl restart nginx
    check_success "Reinicialização do NGINX"
}

configure_auto_renewal() {
    log "INFO" "Configurando renovação automática do certificado Let's Encrypt..."
    
    if ! command -v certbot &> /dev/null; then
        log "ERROR" "Certbot não está instalado. Instale o Certbot antes de configurar a renovação automática."
        exit 1
    fi
    
    CRON_JOB="0 0 * * * /usr/bin/certbot renew --quiet --post-hook \"systemctl reload nginx\""
    
    if ! crontab -l | grep -q "$CRON_JOB"; then
        log "INFO" "Adicionando cron job para renovação automática..."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        check_success "Configuração do cron job"
    else
        log "INFO" "O cron job para renovação automática já está configurado."
    fi
    
    log "INFO" "Renovação automática configurada com sucesso!"
}

main() {
    log "INFO" "Iniciando instalação e configuração do NGINX como proxy reverso..."
    
    if ! command -v nginx &> /dev/null; then
        install_nginx
    else
        log "INFO" "NGINX já está instalado."
    fi
    
    configure_firewall
    configure_http_https
    create_nginx_proxy_config
    test_and_restart_nginx
    
    log "INFO" "Configuração do NGINX como proxy reverso concluída com sucesso!"
    log "INFO" "Acesse o proxy em: http://$SERVER_NAME"
    if [[ "$USE_HTTPS" == "s" || "$USE_HTTPS" == "S" ]]; then
        log "INFO" "Acesse o proxy seguro em: https://$SERVER_NAME"
    fi
    
    if [[ "$USE_HTTPS" == "s" || "$USE_HTTPS" == "S" ]]; then
        if [[ "$USE_LETSENCRYPT" == "s" || "$USE_LETSENCRYPT" == "S" ]]; then
            configure_auto_renewal
        fi
    fi
}

main