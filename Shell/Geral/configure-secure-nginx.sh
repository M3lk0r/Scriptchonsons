#!/bin/bash

# Synopsis
#   Configura o NGINX como proxy reverso com melhores práticas de segurança.
# Description
#   Este script configura NGINX, define as melhores práticas para proxy reverso.
#   Inclui instalação de ModSecurity, bloqueio de bots, configuração de GeoIP e aplicação de regras de segurança.
# Example
#   sudo ./configure-secure-nginx.sh
# Notes
#   AUTHOR: eduardo.agms@outlook.com.br
#   VERSION: 0.1
#   LAST MODIFIED: 18 March 2025

readonly LOGFILE="/var/log/configure-secure-nginx.log"
readonly BACKUP_DIR="/opt/backup/nginx_$(date +%F_%T)"
mkdir -p "$BACKUP_DIR"

if [ -t 1 ]; then
    readonly RED='\033[0;31m'
    readonly YELLOW='\033[0;33m'
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly YELLOW=''
    readonly GREEN=''
    readonly BLUE=''
    readonly NC=''
fi

log() {
    local level="$1"
    local message="$2"
    local color
    case "$level" in
        INFO)    color="$BLUE" ;;
        WARN)    color="$YELLOW" ;;
        ERROR)   color="$RED" ;;
        SUCCESS) color="$GREEN" ;;
        *)       color="$NC" ;;
    esac
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[$timestamp] [$level] $message"
    echo -e "${color}${log_line}${NC}" | tee -a "$LOGFILE"
}

check_success() {
    local action="$1"
    if [ $? -ne 0 ]; then
        log "ERROR" "Falha ao executar: $action"
        exit 1
    else
        log "SUCCESS" "Sucesso: $action"
    fi
}

check_os() {
    if [ "$(lsb_release -rs)" != "24.04" ]; then
        log "ERROR" "Este script só pode ser executado no Ubuntu 24.04!"
        exit 1
    fi
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "Acesso negado! Execute como root (sudo)."
        exit 1
    fi
}

install_dependencies() {
    log "INFO" "Instalando dependências..."
    apt-get update
    apt-get install -y --no-install-recommends \
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
    check_success "Backup do nginx.conf"
    
    if ! grep -q "geoip_country" "$nginx_conf"; then
        sed -i '/http {/a \
    geoip_country /usr/share/GeoIP/GeoIP.dat;\
    map $geoip_country_code $allowed_country {\
        default no;\
        BR yes;\
        }' "$nginx_conf"
        check_success "Adição da configuração GeoIP"
    else
        log "INFO" "GeoIP já configurado no nginx.conf."
    fi
}

install_bot_blocker() {
    log "INFO" "Instalando NGINX Ultimate Bad Bot Blocker..."
    local installer="/usr/local/sbin/install-ngxblocker"
    wget -q https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O "$installer"
    check_success "Download do instalador do Bad Bot Blocker"
    chmod +x "$installer"
    "$installer" -x
    check_success "Instalação do Bad Bot Blocker"
}

install_modsecurity() {
    log "INFO" "Compilando e instalando ModSecurity..."
    local modsec_dir="/usr/local/src/ModSecurity"
    mkdir -p "$modsec_dir"
    cd "$modsec_dir"
    
    if [ -d .git ]; then
        log "INFO" "Repositório ModSecurity já existe. Verificando versão e integridade..."
        
        local current_version
        current_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "N/A")
        
        git fetch --tags
        local latest_version
        latest_version=$(git describe --tags --abbrev=0)
        
        log "INFO" "Versão atual do ModSecurity: $current_version"
        log "INFO" "Versão mais recente do ModSecurity: $latest_version"
        
        if [ "$current_version" != "$latest_version" ]; then
            log "INFO" "Atualizando repositório ModSecurity para a versão $latest_version..."
            git reset --hard
            git clean -fd
            git checkout "$latest_version"
            check_success "Atualização do repositório ModSecurity"
        else
            log "INFO" "Versão mais recente já está instalada."
        fi
    else
        log "INFO" "Clonando repositório ModSecurity..."
        git clone --depth 1 -b v3/master https://github.com/SpiderLabs/ModSecurity .
        check_success "Clone do repositório ModSecurity"
    fi
    
    log "INFO" "Atualizando submodules do ModSecurity..."
    for attempt in {1..3}; do
        log "INFO" "Tentativa $attempt de inicializar submodules..."
        if git submodule update --init --recursive; then
            log "SUCCESS" "Submodules clonados com sucesso."
            break
        else
            log "WARN" "Falha na tentativa $attempt para clonar submodules."
            if [ "$attempt" -eq 3 ]; then
                log "ERROR" "Falha ao clonar submodules após 3 tentativas. Tentando continuar sem alguns submódulos..."
                git submodule update --init --recursive --force
                break
            fi
            sleep 10
        fi
    done
    
    log "INFO" "Compilando ModSecurity..."
    ./build.sh
    ./configure
    make -j"$(nproc)"
    make install
    check_success "Compilação e instalação do ModSecurity"
    
    log "INFO" "Compilando módulo NGINX para ModSecurity..."
    local nginx_modsec_dir="/usr/local/src/ModSecurity-nginx"
    mkdir -p "$nginx_modsec_dir"
    cd "$nginx_modsec_dir"
    
    if [ -d .git ]; then
        log "INFO" "Repositório ModSecurity-nginx já existe. Atualizando..."
        git reset --hard
        git clean -fd
        git pull origin master
        check_success "Atualização do repositório ModSecurity-nginx"
    else
        log "INFO" "Clonando repositório ModSecurity-nginx..."
        git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git .
        check_success "Clone do repositório ModSecurity-nginx"
    fi
    
    local nginx_version
    nginx_version=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
    log "INFO" "Versão do NGINX detectada: $nginx_version"
    
    wget -q "http://nginx.org/download/nginx-${nginx_version}.tar.gz"
    tar zxvf "nginx-${nginx_version}.tar.gz"
    cd "nginx-${nginx_version}"
    
    ./configure --with-compat --add-dynamic-module="$nginx_modsec_dir"
    make modules
    mkdir -p /etc/nginx/modules /usr/share/nginx/modules
    cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/
    cp objs/ngx_http_modsecurity_module.so /usr/share/nginx/modules/
    check_success "Compilação do módulo NGINX para ModSecurity"
}

remove_duplicate_ips() {
    log "INFO" "Removendo IPs duplicados de globalblacklist.conf..."
    
    local blacklist_file="/etc/nginx/conf.d/globalblacklist.conf"
    
    if [ ! -f "$blacklist_file" ]; then
        log "WARN" "Arquivo $blacklist_file não encontrado."
        return 1
    fi
    
    cp "$blacklist_file" "$blacklist_file.bak"
    check_success "Backup de globalblacklist.conf"
    
    awk '{
    # Se for comentário ou não parecer iniciar com IP, imprime a linha normalmente
    if ($1 ~ /^#/ || $1 !~ /^[0-9]+\./) {
      print;
    } else {
      ip = $1;
      if (!(ip in seen)) {
        seen[ip] = 1;
        print;
      } else {
        # Podemos opcionalmente enviar para stderr ou logar que o IP foi removido.
        # Exemplo: print "REMOVIDO: " $0 > "/dev/stderr"
      }
    }
    }' "$blacklist_file" > "${blacklist_file}.tmp"
    
    mv "${blacklist_file}.tmp" "$blacklist_file"
    check_success "Remoção de IPs duplicados"
    
    log "INFO" "O arquivo $blacklist_file foi atualizado e duplicatas removidas."
}

load_modsecurity_module() {
    log "INFO" "Carregando módulo ModSecurity no NGINX..."
    local module_line="load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;"
    if ! grep -qE "$module_line" /etc/nginx/nginx.conf; then
        sed -i "1i$module_line" /etc/nginx/nginx.conf
        check_success "Inserção do load_module no nginx.conf"
    else
        log "INFO" "Módulo ModSecurity já carregado no nginx.conf."
    fi
}

configure_modsecurity() {
    log "INFO" "Configurando ModSecurity e OWASP CRS..."
    
    mkdir -p /etc/nginx/modsec
    wget -q -P /etc/nginx/modsec/ https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended
    mv /etc/nginx/modsec/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
    check_success "Configuração do modsecurity.conf"
    
    wget -q -O /etc/nginx/modsec/unicode.mapping https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping
    chmod 644 /etc/nginx/modsec/unicode.mapping
    chown root:root /etc/nginx/modsec/unicode.mapping
    
    git clone https://github.com/coreruleset/coreruleset.git /etc/nginx/modsec/coreruleset
    cp /etc/nginx/modsec/coreruleset/crs-setup.conf.example /etc/nginx/modsec/coreruleset/crs-setup.conf
    
    cat << 'EOL' > /etc/nginx/modsec/modsec-base-cfg.conf
Include /etc/nginx/modsec/modsecurity.conf
Include /etc/nginx/modsec/coreruleset/crs-setup.conf
Include /etc/nginx/modsec/coreruleset/rules/*.conf
EOL
    
    touch /var/log/modsec_audit.log
    chown www-data:www-data /var/log/modsec_audit.log
    chmod 644 /var/log/modsec_audit.log
    
    check_success "Configuração do ModSecurity e OWASP CRS"
    
    configure_crs_setup
}

configure_crs_setup() {
    local setup_file="/etc/nginx/modsec/coreruleset/crs-setup.conf"
    log "INFO" "Configurando CRS setup com Paranoia Level 2..."
    sed -i '/^[#]*\s*SecAction.*setvar:tx.paranoia_level=/s/^#\+//' "$setup_file"
    sed -i 's/setvar:tx.paranoia_level=1/setvar:tx.paranoia_level=2/' "$setup_file"
    
    if ! grep -q "id:900000" "$setup_file"; then
        cat << 'EOF' >> "$setup_file"
SecAction "id:900000,phase:1,nolog,pass,t:none,setvar:tx.paranoia_level=2"
EOF
    fi
    check_success "Configuração do CRS setup (paranoia level 2)"
}

apply_security_config() {
    log "INFO" "Aplicando regras de segurança nos virtual hosts..."

    mkdir -p /etc/nginx/bots.d
    touch /etc/nginx/bots.d/ddos.conf /etc/nginx/bots.d/blockbots.conf

    for vhost in /etc/nginx/sites-available/*; do
        if ! grep -q "modsecurity on" "$vhost"; then
            cp "$vhost" "$BACKUP_DIR/$(basename "$vhost").bak"

            sed -i '/server {/a \
    # Bloqueio de bots e GeoIP\
    include /etc/nginx/bots.d/ddos.conf;\
    include /etc/nginx/bots.d/blockbots.conf;\
    \
    # ModSecurity\
    modsecurity on;\
    modsecurity_rules_file /etc/nginx/modsec/modsec-base-cfg.conf;\
    \
    location / {\
        # Verificação de país permitido\
        if ($allowed_country = no) {\
            return 444;\
        }\
    }' "$vhost"

            if grep -q "listen 443 ssl" "$vhost"; then
                sed -i '/listen 443 ssl;/a \
    # Bloqueio de bots e GeoIP\
    include /etc/nginx/bots.d/ddos.conf;\
    include /etc/nginx/bots.d/blockbots.conf;\
    \
    # ModSecurity\
    modsecurity on;\
    modsecurity_rules_file /etc/nginx/modsec/modsec-base-cfg.conf;\
    \
    location / {\
        # Verificação de país permitido\
        if ($allowed_country = no) {\
            return 444;\
        }\
    }' "$vhost"
            fi

            check_success "Aplicação das regras de segurança no vhost $(basename "$vhost")"
        else
            log "INFO" "Vhost $(basename "$vhost") já está configurado."
        fi
    done
}


test_and_restart_nginx() {
    log "INFO" "Testando configuração do NGINX..."
    nginx -t
    check_success "Teste de configuração do NGINX"
    
    log "INFO" "Reiniciando NGINX..."
    systemctl restart nginx
    check_success "Reinício do NGINX"
}

main() {
    install_dependencies
    install_bot_blocker
    install_modsecurity
    remove_duplicate_ips
    configure_geoip
    
    load_modsecurity_module
    configure_modsecurity
    apply_security_config
    
    test_and_restart_nginx
    log "SUCCESS" "Configuração do NGINX concluída com sucesso."
}

if [ "$#" -gt 0 ]; then
    case "$1" in
        install_dependencies) install_dependencies ;;
        install_bot_blocker) install_bot_blocker ;;
        install_modsecurity) install_modsecurity ;;
        configure_geoip) configure_geoip ;;
        remove_duplicate_ips) remove_duplicate_ips ;;
        
        configure_modsecurity) configure_modsecurity ;;
        load_modsecurity_module) load_modsecurity_module ;;
        apply_security_config) apply_security_config ;;
        
        test_and_restart_nginx) test_and_restart_nginx ;;
        main) main ;;
        *) echo "Função desconhecida: $1" && exit 1 ;;
    esac
else
    main
fi