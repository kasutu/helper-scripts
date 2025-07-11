# Nginx Reverse Proxy Setup Guide

## Overview

This guide provides two bash scripts for setting up and managing Nginx reverse proxies on Ubuntu LTS:

1. **`nginx-setup.sh`** - Initial installation and configuration
2. **`add-proxy.sh`** - Add/remove additional reverse proxy configurations

## Quick Start

### 1. Initial Setup

```bash
# Make the script executable
chmod +x nginx-setup.sh

# Run the initial setup (installs Nginx and configures crm.splitscale.ph)
./nginx-setup.sh
```

This script will:
- Install and configure Nginx on Ubuntu LTS
- Set up UFW firewall rules
- Create your first reverse proxy: `crm.splitscale.ph` → `128.199.126.68:3000`
- Generate SSL configuration templates
- Set up log rotation and maintenance scripts

### 2. Adding More Reverse Proxies

```bash
# Make the script executable
chmod +x add-proxy.sh

# Add a new reverse proxy
./add-proxy.sh -h app.example.com -p 5000
```

## Script Usage Examples

### Basic Examples

```bash
# Add proxy for localhost application
./add-proxy.sh -h api.mysite.com -p 3000

# Add proxy with custom target IP
./add-proxy.sh -h external.mysite.com -p 8080 -i 192.168.1.100

# Add proxy with SSL template (requires manual certificate setup)
./add-proxy.sh -h secure.mysite.com -p 3000 -s

# Remove a proxy configuration
./add-proxy.sh -h old.mysite.com -p 8080 -r
```

### Advanced Examples

```bash
# Frontend application
./add-proxy.sh -h myapp.com -p 3000

# API service
./add-proxy.sh -h api.myapp.com -p 8000

# Admin panel with SSL
./add-proxy.sh -h admin.myapp.com -p 4000 -s

# WebSocket service
./add-proxy.sh -h ws.myapp.com -p 3001

# Remove old service
./add-proxy.sh -h legacy.myapp.com -p 9000 -r
```

## Command Reference

### nginx-setup.sh

```bash
./nginx-setup.sh
```

**What it does:**
- Updates system packages
- Installs Nginx
- Configures UFW firewall
- Creates initial reverse proxy for crm.splitscale.ph
- Sets up SSL templates and security configurations
- Creates maintenance and log rotation scripts

### add-proxy.sh

```bash
./add-proxy.sh -h <hostname> -p <port> [OPTIONS]
```

**Required Parameters:**
- `-h <hostname>` - Domain name (e.g., app.example.com)
- `-p <port>` - Target port number (e.g., 3000, 8080)

**Optional Parameters:**
- `-i <target_ip>` - Target IP (default: 127.0.0.1)
- `-s` - Enable SSL template
- `-r` - Remove mode
- `--help` - Show help message

## File Locations

### Configuration Files
- **Available configs:** `/etc/nginx/sites-available/`
- **Enabled configs:** `/etc/nginx/sites-enabled/`
- **SSL parameters:** `/etc/nginx/snippets/ssl-params.conf`
- **Main Nginx config:** `/etc/nginx/nginx.conf`

### Log Files
- **Access logs:** `/var/log/nginx/<domain>.access.log`
- **Error logs:** `/var/log/nginx/<domain>.error.log`
- **Main error log:** `/var/log/nginx/error.log`

### Maintenance
- **Maintenance script:** `/usr/local/bin/nginx-maintenance`
- **DH parameters:** `/etc/nginx/dhparam.pem`

## SSL Certificate Setup

For SSL-enabled configurations, follow these steps:

### 1. Install Certbot

```bash
sudo apt install certbot python3-certbot-nginx
```

### 2. Obtain SSL Certificate

```bash
sudo certbot --nginx -d yourdomain.com
```

### 3. Test Auto-renewal

```bash
sudo certbot renew --dry-run
```

## Maintenance Commands

### Using the maintenance script:

```bash
# Check Nginx status
nginx-maintenance status

# Test configuration
nginx-maintenance test

# Reload configuration
nginx-maintenance reload

# Restart Nginx
nginx-maintenance restart

# View error logs
nginx-maintenance logs

# View access logs
nginx-maintenance access-logs
```

### Manual commands:

```bash
# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# Check Nginx status
sudo systemctl status nginx

# View enabled sites
ls -la /etc/nginx/sites-enabled/

# View available sites
ls -la /etc/nginx/sites-available/
```

## Troubleshooting

### Common Issues

1. **Configuration test fails:**
   ```bash
   sudo nginx -t
   # Check for syntax errors and fix them
   ```

2. **Service not accessible:**
   ```bash
   # Check if the target service is running
   curl http://127.0.0.1:3000
   
   # Check Nginx error logs
   sudo tail -f /var/log/nginx/error.log
   ```

3. **SSL certificate issues:**
   ```bash
   # Check certificate status
   sudo certbot certificates
   
   # Renew certificates manually
   sudo certbot renew
   ```

4. **Firewall blocking connections:**
   ```bash
   # Check UFW status
   sudo ufw status
   
   # Allow specific ports if needed
   sudo ufw allow 80
   sudo ufw allow 443
   ```

### Log Analysis

```bash
# View recent access logs
sudo tail -f /var/log/nginx/yourdomain.com.access.log

# View recent error logs
sudo tail -f /var/log/nginx/yourdomain.com.error.log

# Search for specific errors
sudo grep "error" /var/log/nginx/error.log

# Check connection attempts
sudo grep "failed" /var/log/nginx/access.log
```

## Security Best Practices

1. **Keep Nginx updated:**
   ```bash
   sudo apt update && sudo apt upgrade nginx
   ```

2. **Monitor logs regularly:**
   ```bash
   # Set up log monitoring with fail2ban
   sudo apt install fail2ban
   ```

3. **Use SSL for all domains:**
   ```bash
   # Always use the -s flag for production domains
   ./add-proxy.sh -h production.com -p 3000 -s
   ```

4. **Regular backups:**
   ```bash
   # Backup configurations
   sudo tar -czf nginx-backup-$(date +%Y%m%d).tar.gz /etc/nginx/
   ```

## Directory Structure After Setup

```
/etc/nginx/
├── nginx.conf                 # Main configuration
├── sites-available/           # Available site configurations
│   ├── crm.splitscale.ph     # Initial setup
│   ├── app.example.com       # Added via script
│   └── default.backup.*      # Backup of original default
├── sites-enabled/            # Enabled site configurations (symlinks)
├── snippets/
│   └── ssl-params.conf       # SSL security parameters
└── dhparam.pem              # DH parameters for SSL

/var/log/nginx/
├── access.log                # Main access log
├── error.log                 # Main error log
├── crm.splitscale.ph.access.log
├── crm.splitscale.ph.error.log
└── [domain].access.log       # Per-domain logs
```

## Performance Tuning

For high-traffic applications, consider these optimizations:

### 1. Worker Process Configuration

Edit `/etc/nginx/nginx.conf`:

```nginx
worker_processes auto;
worker_connections 1024;
```

### 2. Enable Caching

Add to your server block:

```nginx
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 3. Rate Limiting

Add to `/etc/nginx/nginx.conf` in the `http` block:

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
```

Then in your location block:

```nginx
limit_req zone=api burst=20 nodelay;
```

This setup provides a robust, secure, and maintainable Nginx reverse proxy solution for your Ubuntu LTS server.