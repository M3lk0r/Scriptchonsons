#!/bin/bash
# Synopsis:
#   Configura e endurece o NGINX com GeoIP, bloqueio de bots e ModSecurity.
# Description:
#   Realiza o hardening do NGINX ativando filtragem por GeoIP, bloqueando bots/referrers maliciosos e integrando o ModSecurity com OWASP CRS.
# Exemplo:
#   sudo ./configure-secure-nginx.sh
# Notas:
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 1.4
#   LAST MODIFIED: 14 March 2025
# Script para configurar e proteger NGINX no Ubuntu 24.04 com GeoIP, ModSecurity e bloqueio de bots

set -euxo pipefail

LOGFILE="/var/log/configure-secure-nginx.log"
BACKUP_DIR="/opt/backup/nginx_$(date +%F_%T)"
mkdir -p "$BACKUP_DIR"

log() {
    local level="$1"
    local message="$2"
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

# Verifica se o sistema é Ubuntu 24.04 e se o script está sendo executado como root
if [ "$(lsb_release -rs)" != "24.04" ]; then
    log "ERROR" "Este script só pode ser executado no Ubuntu 24.04!"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Acesso negado! Execute como root (sudo)."
    exit 1
fi

install_dependencies() {
    log "INFO" "Instalando dependências..."
    apt-get update && apt-get install -y --no-install-recommends \
        geoip-database libgeoip1 libnginx-mod-http-geoip \
        apt-utils autoconf automake build-essential git \
        libcurl4-openssl-dev libgeoip-dev liblmdb-dev \
        libpcre3-dev libtool libxml2-dev libyajl-dev pkgconf \
        wget zlib1g-dev libpcre2-dev
    check_success "Instalação das dependências"
}

configure_geoip() {
    log "INFO" "Configurando GeoIP no NGINX..."
    local nginx_conf="/etc/nginx/nginx.conf"
    cp "$nginx_conf" "$BACKUP_DIR/nginx.conf.bak"
    
    if ! grep -q "geoip_country" "$nginx_conf"; then
        sed -i '/http {/a \    geoip_country /usr/share/GeoIP/GeoIP.dat;\n    map \$geoip_country_code \$allowed_country {\n        default no;\n        BR yes;\n    }' "$nginx_conf"
        check_success "Configuração do GeoIP"
    else
        log "INFO" "GeoIP já configurado."
    fi
}

install_bot_blocker() {
    log "INFO" "Instalando NGINX Ultimate Bad Bot Blocker..."
    wget -q https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker
    chmod +x /usr/local/sbin/install-ngxblocker
    /usr/local/sbin/install-ngxblocker -x
    check_success "Instalação do NGINX Ultimate Bad Bot Blocker"
}

install_modsecurity() {
    log "INFO" "Compilando ModSecurity..."
    local modsec_dir="/usr/local/src/ModSecurity"
    mkdir -p "$modsec_dir"
    cd "$modsec_dir"
    
    # Clona o repositório principal do ModSecurity
    git clone --depth 1 -b v3/master https://github.com/SpiderLabs/ModSecurity .
    check_success "Clone do repositório ModSecurity"

    # Tenta clonar os submodules com até 3 tentativas
    log "INFO" "Clonando submodules do ModSecurity..."
    for attempt in {1..3}; do
        log "INFO" "Tentativa $attempt de clonar submodules..."
        if git submodule update --init --recursive; then
            log "INFO" "Submodules clonados com sucesso."
            break
        else
            log "WARN" "Falha ao clonar submodules na tentativa $attempt."
            if [ "$attempt" -eq 3 ]; then
                log "ERROR" "Falha ao clonar submodules após 3 tentativas. Abortando."
                exit 1
            fi
            sleep 10  # Espera 10 segundos antes de tentar novamente
        fi
    done

    # Compila o ModSecurity
    log "INFO" "Compilando ModSecurity..."
    ./build.sh
    ./configure
    make -j$(nproc)
    make install
    check_success "Compilação do ModSecurity"
    
    log "INFO" "Compilando módulo NGINX para ModSecurity..."
    local nginx_modsec_dir="/usr/local/src/ModSecurity-nginx"
    mkdir -p "$nginx_modsec_dir"
    cd "$nginx_modsec_dir"
    
    # Clona o repositório do módulo NGINX para ModSecurity
    git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git .
    check_success "Clone do repositório ModSecurity-nginx"
    
    # Baixa e extrai o código-fonte do NGINX (utilizando a versão instalada)
    nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
    wget -q http://nginx.org/download/nginx-$nginx_version.tar.gz
    tar zxvf nginx-$nginx_version.tar.gz
    cd nginx-$nginx_version
    
    # Configura e compila o módulo dinâmico
    ./configure --with-compat --add-dynamic-module="$nginx_modsec_dir"
    make modules
    mkdir -p /etc/nginx/modules  # Garante que o diretório exista
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/
    mkdir -p /usr/share/nginx/modules
    cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/
    check_success "Compilação do módulo NGINX para ModSecurity"
}

configure_modsecurity() {
    log "INFO" "Configurando ModSecurity e OWASP CRS..."
    mkdir -p /etc/nginx/modsec
    wget -q -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended
    mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
    
    # Baixa o arquivo unicode.mapping
    wget -q -O /etc/nginx/modsec/unicode.mapping https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping
    chmod 644 /etc/nginx/modsec/unicode.mapping
    chown root:root /etc/nginx/modsec/unicode.mapping
    
    # Configura o OWASP CRS
    git clone https://github.com/coreruleset/coreruleset.git /etc/nginx/modsec/coreruleset
    cp /etc/nginx/modsec/coreruleset/crs-setup.conf.example /etc/nginx/modsec/coreruleset/crs-setup.conf
    
    cat << 'EOL' > /etc/nginx/modsec/modsec-base-cfg.conf
Include /etc/nginx/modsec/modsecurity.conf
Include /etc/nginx/modsec/coreruleset/crs-setup.conf
Include /etc/nginx/modsec/coreruleset/rules/*.conf
EOL
    
    # Configura o arquivo de log do ModSecurity
    touch /var/log/modsec_audit.log
    chown www-data:www-data /var/log/modsec_audit.log
    chmod 644 /var/log/modsec_audit.log
    
    check_success "Configuração do ModSecurity e OWASP CRS"
}

remove_duplicate_ips() {
    log "INFO" "Removendo IPs duplicados do globalblacklist.conf..."
    local blacklist_file="/etc/nginx/conf.d/globalblacklist.conf"
    if [ -f "$blacklist_file" ]; then
        sort -u "$blacklist_file" -o "$blacklist_file"
        check_success "Remoção de IPs duplicados"
    else
        log "WARN" "Arquivo globalblacklist.conf não encontrado."
    fi
}

apply_security_config() {
    log "INFO" "Aplicando regras de segurança nos vhosts..."
    
    # Garante que os diretórios e arquivos de bloqueio de bots existam, evitando erros de include
    mkdir -p /etc/nginx/bots.d
    [ -f /etc/nginx/bots.d/ddos.conf ] || touch /etc/nginx/bots.d/ddos.conf
    [ -f /etc/nginx/bots.d/blockbots.conf ] || touch /etc/nginx/bots.d/blockbots.conf

    for vhost in /etc/nginx/sites-enabled/*; do
        if ! grep -q "modsecurity on" "$vhost"; then
            cp "$vhost" "$BACKUP_DIR/$(basename "$vhost").bak"
            sed -i '/server {/a \    listen 80 default_server;\n    listen [::]:80 default_server;\n\n    # Bloqueio de bots e GeoIP\n    include /etc/nginx/bots.d/ddos.conf;\n    include /etc/nginx/bots.d/blockbots.conf;\n\n    # ModSecurity\n    modsecurity on;\n    modsecurity_rules_file /etc/nginx/modsec/modsec-base-cfg.conf;\n\n    location / {\n        # Verificação de país permitido\n        if ($allowed_country = no) {\n            return 444;\n        }\n\n        # First attempt to serve request as file, then\n        # as directory, then fall back to displaying a 404.\n        try_files $uri $uri/ =404;\n    }' "$vhost"
            check_success "Aplicação das regras de segurança no vhost $vhost"
        else
            log "INFO" "Vhost $(basename "$vhost") já está configurado."
        fi
    done
}

log "INFO" "Iniciando configuração do NGINX..."
install_dependencies
install_modsecurity
configure_geoip
install_bot_blocker
configure_modsecurity
remove_duplicate_ips
apply_security_config

# Insere a diretiva load_module no início do arquivo de configuração do NGINX, se ainda não estiver presente.
log "INFO" "Carregando módulo ModSecurity no NGINX..."
if ! grep -qE 'load_module\s+/etc/nginx/modules/ngx_http_modsecurity_module.so;' /etc/nginx/nginx.conf; then
    sed -i '1iload_module /etc/nginx/modules/ngx_http_modsecurity_module.so;' /etc/nginx/nginx.conf
fi

# Testa a configuração do NGINX
nginx -t
check_success "Teste de configuração do NGINX"

log "INFO" "Reiniciando NGINX..."
systemctl restart nginx
check_success "Reinício do NGINX"

log "INFO" "Configuração do NGINX concluída com sucesso."