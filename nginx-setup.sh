#!/bin/bash

# Nginx Installation and Reverse Proxy Setup Script for Ubuntu LTS
# Author: Auto-generated
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a user with sudo privileges."
    fi
}

# Check Ubuntu version
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        error "This script is designed for Ubuntu systems only."
    fi
    
    local version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    log "Detected Ubuntu version: $version"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    log "System packages updated successfully"
}

# Install Nginx
install_nginx() {
    log "Installing Nginx..."
    sudo apt install nginx -y
    
    # Enable and start Nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
    # Check if Nginx is running
    if sudo systemctl is-active --quiet nginx; then
        log "Nginx installed and started successfully"
    else
        error "Failed to start Nginx"
    fi
}

# Configure firewall
configure_firewall() {
    log "Configuring UFW firewall..."
    
    # Enable UFW if not already enabled
    sudo ufw --force enable
    
    # Allow SSH, HTTP, and HTTPS
    sudo ufw allow OpenSSH
    sudo ufw allow 'Nginx Full'
    
    log "Firewall configured successfully"
}

# Backup default Nginx configuration
backup_config() {
    log "Backing up default Nginx configuration..."
    
    if [[ -f /etc/nginx/sites-available/default ]]; then
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
        log "Default configuration backed up"
    fi
}

# Remove default site
remove_default_site() {
    log "Removing default Nginx site..."
    
    if [[ -L /etc/nginx/sites-enabled/default ]]; then
        sudo unlink /etc/nginx/sites-enabled/default
        log "Default site removed"
    fi
}

# Create reverse proxy configuration for crm.splitscale.ph
create_initial_proxy() {
    local domain="crm.splitscale.ph"
    local target_ip="128.199.126.68"
    local target_port="3000"
    
    log "Creating reverse proxy for $domain -> $target_ip:$target_port"
    
    sudo tee /etc/nginx/sites-available/$domain > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;

    location / {
        proxy_pass http://$target_ip:$target_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
    }

    # Error pages
    error_page 500 502 503 504 /500.html;
    location /500.html {
        root /var/www/html;
        internal;
    }

    # Logging
    access_log /var/log/nginx/$domain.access.log;
    error_log /var/log/nginx/$domain.error.log;
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    log "Reverse proxy configuration created for $domain"
}

# Create SSL configuration template (for manual SSL setup later)
create_ssl_template() {
    log "Creating SSL configuration template..."
    
    sudo tee /etc/nginx/snippets/ssl-params.conf > /dev/null <<EOF
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF

    log "SSL configuration template created at /etc/nginx/snippets/ssl-params.conf"
}

# Generate DH parameters for SSL
generate_dhparam() {
    log "Generating DH parameters for SSL (this may take a while)..."
    
    if [[ ! -f /etc/nginx/dhparam.pem ]]; then
        sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
        log "DH parameters generated"
    else
        log "DH parameters already exist"
    fi
}

# Test Nginx configuration
test_nginx_config() {
    log "Testing Nginx configuration..."
    
    if sudo nginx -t; then
        log "Nginx configuration test passed"
    else
        error "Nginx configuration test failed"
    fi
}

# Reload Nginx
reload_nginx() {
    log "Reloading Nginx..."
    
    sudo systemctl reload nginx
    
    if sudo systemctl is-active --quiet nginx; then
        log "Nginx reloaded successfully"
    else
        error "Failed to reload Nginx"
    fi
}

# Create log rotation configuration
setup_log_rotation() {
    log "Setting up log rotation..."
    
    sudo tee /etc/logrotate.d/nginx-custom > /dev/null <<EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 nginx adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi \
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
EOF

    log "Log rotation configured"
}

# Create maintenance script
create_maintenance_script() {
    log "Creating maintenance script..."
    
    sudo tee /usr/local/bin/nginx-maintenance > /dev/null <<'EOF'
#!/bin/bash

# Nginx maintenance script

case "$1" in
    status)
        systemctl status nginx
        ;;
    test)
        nginx -t
        ;;
    reload)
        nginx -t && systemctl reload nginx
        ;;
    restart)
        nginx -t && systemctl restart nginx
        ;;
    logs)
        tail -f /var/log/nginx/error.log
        ;;
    access-logs)
        tail -f /var/log/nginx/access.log
        ;;
    *)
        echo "Usage: $0 {status|test|reload|restart|logs|access-logs}"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/nginx-maintenance
    log "Maintenance script created at /usr/local/bin/nginx-maintenance"
}

# Display completion message
show_completion_message() {
    echo
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}  Nginx Setup Completed Successfully!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo
    echo -e "${BLUE}Initial reverse proxy configured:${NC}"
    echo -e "  ${YELLOW}crm.splitscale.ph${NC} -> ${YELLOW}128.199.126.68:3000${NC}"
    echo
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  Test configuration: ${YELLOW}sudo nginx -t${NC}"
    echo -e "  Reload Nginx: ${YELLOW}sudo systemctl reload nginx${NC}"
    echo -e "  Check status: ${YELLOW}sudo systemctl status nginx${NC}"
    echo -e "  Maintenance script: ${YELLOW}nginx-maintenance status${NC}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Configure DNS to point your domain to this server"
    echo -e "  2. Use the add-proxy.sh script to add more domains"
    echo -e "  3. Consider setting up SSL certificates with Certbot"
    echo
    echo -e "${BLUE}To add more reverse proxies:${NC}"
    echo -e "  ${YELLOW}./add-proxy.sh -h example.com -p 8080${NC}"
    echo
}

# Main execution
main() {
    log "Starting Nginx installation and configuration..."
    
    check_root
    check_ubuntu
    update_system
    install_nginx
    configure_firewall
    backup_config
    remove_default_site
    create_initial_proxy
    create_ssl_template
    generate_dhparam
    setup_log_rotation
    create_maintenance_script
    test_nginx_config
    reload_nginx
    show_completion_message
}

# Execute main function
main "$@"