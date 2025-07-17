# Payload CMS Production Deployment - Lattice-CMS

Production-ready Docker Compose setup for Payload CMS with MongoDB database named "lattice-cms".

## 🚀 Quick Start

1. **Copy environment file:**
   ```bash
   cp .env.production .env
   ```

2. **Edit environment variables:**
   ```bash
   nano .env
   ```
   
3. **Run production deployment:**
   ```bash
   chmod +x deploy-production.sh
   ./deploy-production.sh
   ```

## 📋 Prerequisites

- Docker and Docker Compose
- Ubuntu/Debian server (recommended)
- At least 2GB RAM
- 20GB+ storage space
- Domain name configured

## 🔧 Configuration

### Environment Variables

Edit `.env` file with your production values:

```env
# Database
DATABASE_URI=mongodb://mongo/lattice-cms
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_secure_password

# Security
PAYLOAD_SECRET=your_payload_secret_key
JWT_SECRET=your_jwt_secret_at_least_32_chars

# Application
PORT=3001
NODE_ENV=production
```

### Docker Compose Files

- `docker-compose.yaml` - Main configuration
- `docker-compose.prod.yaml` - Production overrides
- `.env.production` - Production environment template

## 🐳 Services

### Payload CMS Application
- **Image:** Built from Dockerfile
- **Port:** 3001 (internal)
- **Database:** MongoDB (lattice-cms)
- **Cache:** Redis (optional)

### MongoDB Database
- **Image:** mongo:7.0-jammy
- **Database:** lattice-cms
- **Authentication:** Enabled
- **Storage:** Persistent volumes

### Redis Cache
- **Image:** redis:7-alpine
- **Purpose:** Caching and session storage
- **Authentication:** Password protected

## 🛠️ Deployment

### Production Deployment

```bash
# Deploy all services
./deploy-production.sh

# Check status
docker-compose ps

# View logs
docker-compose logs -f payload
```

### Manual Deployment

```bash
# Pull and build images
docker-compose pull
docker-compose build

# Deploy with production overrides
docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml up -d
```

## 🔄 Database Management

### Backup Database

```bash
# Create backup
./backup-database.sh

# Create named backup
./backup-database.sh my-backup-name
```

### Restore Database

```bash
# Restore from backup
./restore-database.sh backup-file.tar.gz

# List available backups
ls -la backups/
```

## 🔒 Security

### MongoDB Security
- Root user authentication enabled
- Database-specific user (recommended)
- Network isolation
- Regular backups

### Application Security
- JWT tokens for authentication
- CORS configuration
- Rate limiting enabled
- Security headers

### Network Security
- Internal Docker network
- No exposed database ports
- Reverse proxy recommended

## 🌐 Reverse Proxy Setup

### Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### SSL Setup

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
0 12 * * * /usr/bin/certbot renew --quiet
```

## 📊 Monitoring

### Health Checks
- Payload CMS: `http://localhost:3001/api/health`
- MongoDB: Built-in Docker health check
- Redis: Built-in Docker health check

### Logs
```bash
# Application logs
docker-compose logs -f payload

# Database logs
docker-compose logs -f mongo

# All services
docker-compose logs -f
```

### Resource Usage
```bash
# Container stats
docker stats

# Disk usage
docker system df

# Volume usage
docker volume ls
```

## 🔧 Maintenance

### Update Application
```bash
# Pull latest code
git pull origin main

# Rebuild and deploy
docker-compose build --no-cache payload
docker-compose up -d payload
```

### Database Maintenance
```bash
# Connect to MongoDB
docker-compose exec mongo mongosh lattice-cms

# Database stats
docker-compose exec mongo mongosh --eval "db.stats()"

# Compact database
docker-compose exec mongo mongosh --eval "db.runCommand({compact: 'users'})"
```

### Clean Up
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune
```

## 🚨 Troubleshooting

### Common Issues

1. **Service won't start:**
   ```bash
   # Check logs
   docker-compose logs service-name
   
   # Restart service
   docker-compose restart service-name
   ```

2. **Database connection issues:**
   ```bash
   # Check MongoDB logs
   docker-compose logs mongo
   
   # Test connection
   docker-compose exec mongo mongosh lattice-cms
   ```

3. **Memory issues:**
   ```bash
   # Check memory usage
   docker stats
   
   # Increase memory limits in docker-compose.prod.yaml
   ```

### Emergency Procedures

1. **Complete system restore:**
   ```bash
   # Stop all services
   docker-compose down
   
   # Restore from backup
   ./restore-database.sh latest-backup.tar.gz
   
   # Restart services
   docker-compose up -d
   ```

2. **Database corruption:**
   ```bash
   # Stop services
   docker-compose down
   
   # Remove corrupted data
   docker volume rm payload-cms_mongo_data
   
   # Restore from backup
   ./restore-database.sh backup-file.tar.gz
   ```

## 📁 File Structure

```
payload-cms/
├── docker-compose.yaml          # Main Docker Compose configuration
├── docker-compose.prod.yaml     # Production overrides
├── dockerfile                   # Payload CMS Dockerfile
├── .env.production             # Environment template
├── .env                        # Your environment variables
├── deploy-production.sh        # Production deployment script
├── backup-database.sh          # Database backup script
├── restore-database.sh         # Database restore script
├── mongodb-init/               # MongoDB initialization scripts
│   └── 01-init-lattice-cms.js
├── backups/                    # Database backups
├── logs/                       # Application logs
└── uploads/                    # File uploads
```

## 🆘 Support

For issues and support:
1. Check the logs: `docker-compose logs -f`
2. Verify configuration: `docker-compose config`
3. Test connectivity: `docker-compose exec mongo mongosh lattice-cms`
4. Check resources: `docker stats`

## 📄 License

This configuration is provided as-is for production deployment of Payload CMS with MongoDB.
