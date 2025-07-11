#!/bin/bash

# Add Nginx Reverse Proxy Script
# Usage: ./add-proxy.sh -h example.com -p 8080 [-i target_ip] [-s] [-r]
# Author: Auto-generated
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET_IP="127.0.0.1"
SSL_ENABLED=false
REMOVE_MODE=false
HOST=""
PORT=""

# Logging functions
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Show usage information
show_usage() {
    cat << EOF
${BLUE}Nginx Reverse Proxy Management Script${NC}

${YELLOW}USAGE:${NC}
  $0 -h <hostname> -p <port> [OPTIONS]

${YELLOW}REQUIRED PARAMETERS:${NC}
  -h <hostname>     Domain name or hostname (e.g., app.example.com)
  -p <port>         Target port number (e.g., 3000, 8080)

${YELLOW}OPTIONAL PARAMETERS:${NC}
  -i <target_ip>    Target IP address (default: 127.0.0.1 for localhost)
  -s                Enable SSL template (creates HTTPS configuration)
  -r                Remove mode (removes the specified proxy configuration)
  --help            Show this help message

${YELLOW}EXAMPLES:${NC}
  Add new proxy:     $0 -h app.example.com -p 3000
  Add with custom IP: $0 -h api.example.com -p 8080 -i 192.168.1.100
  Add with SSL:      $0 -h secure.example.com -p 3000 -s
  Remove proxy:      $0 -h old.example.com -p 8080 -r

${YELLOW}NOTES:${NC}
  - Ports are assumed to be on localhost (0.0.0.0) unless -i is specified
  - SSL configuration requires manual certificate setup with Certbot
  - All configurations are tested before applying
  - Nginx is automatically reloaded after successful configuration

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -i|--ip)
                TARGET_IP="$2"
                shift 2
                ;;
            -s|--ssl)
                SSL_ENABLED=true
                shift
                ;;
            -r|--remove)
                REMOVE_MODE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$HOST" ]]; then
        error "Hostname (-h) is required. Use --help for usage information."
    fi

    if [[ -z "$PORT" ]]; then
        error "Port (-p) is required. Use --help for usage information."
    fi

    # Validate port number
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        error "Invalid port number: $PORT. Must be between 1 and 65535."
    fi

    # Validate IP address format (basic check)
    if ! [[ "$TARGET_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error "Invalid IP address format: $TARGET_IP"
    fi
}

# Check if running with appropriate privileges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a user with sudo privileges."
    fi

    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo privileges. Please run with a user that has sudo access."
    fi
}

# Check if Nginx is installed and running
check_nginx() {
    if ! command -v nginx &> /dev/null; then
        error "Nginx is not installed. Please run the nginx-setup.sh script first."
    fi

    if ! sudo systemctl is-active --quiet nginx; then
        error "Nginx is not running. Please start Nginx: sudo systemctl start nginx"
    fi
}

# Remove reverse proxy configuration
remove_proxy() {
    local config_file="/etc/nginx/sites-available/$HOST"
    local enabled_file="/etc/nginx/sites-enabled/$HOST"

    log "Removing reverse proxy configuration for $HOST"

    # Check if configuration exists
    if [[ ! -f "$config_file" ]]; then
        warn "Configuration file for $HOST does not exist"
        return 0
    fi

    # Remove enabled symlink
    if [[ -L "$enabled_file" ]]; then
        sudo rm "$enabled_file"
        log "Removed enabled configuration for $HOST"
    fi

    # Backup and remove configuration file
    local backup_file="${config_file}.removed.$(date +%Y%m%d_%H%M%S)"
    sudo mv "$config_file" "$backup_file"
    log "Configuration file backed up to $backup_file"

    # Test and reload Nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx
        log "Nginx configuration reloaded successfully"
        info "Reverse proxy for $HOST has been removed"
    else
        error "Nginx configuration test failed. Please check the configuration."
    fi
}

# Create HTTP reverse proxy configuration
create_http_config() {
    local config_file="/etc/nginx/sites-available/$HOST"

    log "Creating HTTP reverse proxy configuration for $HOST"

    sudo tee "$config_file" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $HOST;

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
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    location / {
        proxy_pass http://$TARGET_IP:$PORT;
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
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Health check endpoint (optional)
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Error pages
    error_page 500 502 503 504 /500.html;
    location /500.html {
        root /var/www/html;
        internal;
    }

    # Logging
    access_log /var/log/nginx/$HOST.access.log;
    error_log /var/log/nginx/$HOST.error.log;
}
EOF

    log "HTTP configuration created for $HOST"
}

# Create HTTPS reverse proxy configuration
create_https_config() {
    local config_file="/etc/nginx/sites-available/$HOST"

    log "Creating HTTPS reverse proxy configuration for $HOST"

    sudo tee "$config_file" > /dev/null <<EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name $HOST;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $HOST;

    # SSL Configuration (update paths after running certbot)
    # ssl_certificate /etc/letsencrypt/live/$HOST/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$HOST/privkey.pem;
    
    # Include SSL parameters
    include /etc/nginx/snippets/ssl-params.conf;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    location / {
        proxy_pass http://$TARGET_IP:$PORT;
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
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Health check endpoint (optional)
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Error pages
    error_page 500 502 503 504 /500.html;
    location /500.html {
        root /var/www/html;
        internal;
    }

    # Logging
    access_log /var/log/nginx/$HOST.access.log;
    error_log /var/log/nginx/$HOST.error.log;
}
EOF

    warn "SSL configuration created but certificates are commented out."
    warn "Run 'sudo certbot --nginx -d $HOST' to obtain and configure SSL certificates."
    log "HTTPS configuration created for $HOST"
}

# Enable the site configuration
enable_site() {
    local config_file="/etc/nginx/sites-available/$HOST"
    local enabled_file="/etc/nginx/sites-enabled/$HOST"

    if [[ -f "$config_file" ]]; then
        sudo ln -sf "$config_file" "$enabled_file"
        log "Site configuration enabled for $HOST"
    else
        error "Configuration file does not exist: $config_file"
    fi
}

# Test and reload Nginx
apply_configuration() {
    log "Testing Nginx configuration..."
    
    if sudo nginx -t; then
        log "Configuration test passed"
        sudo systemctl reload nginx
        log "Nginx reloaded successfully"
    else
        error "Nginx configuration test failed. Please check the configuration."
    fi
}

# Show success message
show_success_message() {
    echo
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}  Reverse Proxy Added Successfully!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo
    echo -e "${BLUE}Configuration Details:${NC}"
    echo -e "  ${YELLOW}Domain:${NC} $HOST"
    echo -e "  ${YELLOW}Target:${NC} $TARGET_IP:$PORT"
    echo -e "  ${YELLOW}Protocol:${NC} $([ "$SSL_ENABLED" = true ] && echo "HTTPS (with HTTP redirect)" || echo "HTTP")"
    echo
    echo -e "${BLUE}Configuration Files:${NC}"
    echo -e "  ${YELLOW}Available:${NC} /etc/nginx/sites-available/$HOST"
    echo -e "  ${YELLOW}Enabled:${NC} /etc/nginx/sites-enabled/$HOST"
    echo
    echo -e "${BLUE}Log Files:${NC}"
    echo -e "  ${YELLOW}Access:${NC} /var/log/nginx/$HOST.access.log"
    echo -e "  ${YELLOW}Error:${NC} /var/log/nginx/$HOST.error.log"
    echo
    if [ "$SSL_ENABLED" = true ]; then
        echo -e "${BLUE}Next Steps for SSL:${NC}"
        echo -e "  1. Install Certbot: ${YELLOW}sudo apt install certbot python3-certbot-nginx${NC}"
        echo -e "  2. Obtain certificate: ${YELLOW}sudo certbot --nginx -d $HOST${NC}"
        echo -e "  3. Test auto-renewal: ${YELLOW}sudo certbot renew --dry-run${NC}"
        echo
    fi
    echo -e "${BLUE}Test the configuration:${NC}"
    echo -e "  ${YELLOW}curl -H 'Host: $HOST' http://$(curl -s ifconfig.me)/${NC}"
    echo
}

# Main execution function
main() {
    parse_arguments "$@"
    
    if [ "$REMOVE_MODE" = true ]; then
        log "Starting removal of reverse proxy for $HOST"
        check_privileges
        check_nginx
        remove_proxy
        return 0
    fi

    log "Starting reverse proxy setup for $HOST -> $TARGET_IP:$PORT"
    
    check_privileges
    check_nginx
    
    # Check if configuration already exists
    if [[ -f "/etc/nginx/sites-available/$HOST" ]]; then
        warn "Configuration for $HOST already exists. Creating backup..."
        local backup_file="/etc/nginx/sites-available/$HOST.backup.$(date +%Y%m%d_%H%M%S)"
        sudo cp "/etc/nginx/sites-available/$HOST" "$backup_file"
        log "Existing configuration backed up to $backup_file"
    fi

    # Create appropriate configuration
    if [ "$SSL_ENABLED" = true ]; then
        create_https_config
    else
        create_http_config
    fi

    enable_site
    apply_configuration
    show_success_message
}

# Handle script interruption
trap 'error "Script interrupted by user"' INT TERM

# Execute main function with all arguments
main "$@"