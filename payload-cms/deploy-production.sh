#!/bin/bash

# Production Deployment Script for Payload CMS Lattice-CMS
# Usage: ./deploy-production.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Consider using a non-root user with Docker permissions."
    fi
}

# Check if Docker and Docker Compose are installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi

    if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
    fi

    log "Docker and Docker Compose are available"
}

# Check if .env file exists
check_env_file() {
    if [[ ! -f .env ]]; then
        warn ".env file not found. Creating from .env.production template..."
        if [[ -f .env.production ]]; then
            cp .env.production .env
            warn "Please edit .env file with your production values before proceeding."
            read -p "Press Enter to continue after editing .env file..."
        else
            error ".env.production template not found. Please create a .env file with your configuration."
        fi
    fi
    log ".env file found"
}

# Validate required environment variables
validate_env() {
    log "Validating environment variables..."
    
    # Source the .env file
    source .env
    
    # Check required variables
    required_vars=("MONGO_ROOT_PASSWORD" "PAYLOAD_SECRET" "JWT_SECRET")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            error "Required environment variable $var is not set in .env file"
        fi
    done
    
    # Check password strength
    if [[ ${#MONGO_ROOT_PASSWORD} -lt 12 ]]; then
        error "MONGO_ROOT_PASSWORD must be at least 12 characters long"
    fi
    
    if [[ ${#JWT_SECRET} -lt 32 ]]; then
        error "JWT_SECRET must be at least 32 characters long"
    fi
    
    log "Environment variables validated successfully"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p uploads
    chmod 755 logs uploads
    
    log "Directories created successfully"
}

# Pull latest images
pull_images() {
    log "Pulling latest Docker images..."
    docker compose pull
    log "Images pulled successfully"
}

# Build application
build_application() {
    log "Building Payload CMS application..."
    docker compose build --no-cache payload
    log "Application built successfully"
}

# Deploy services
deploy_services() {
    log "Deploying services..."
    
    # Stop existing services
    docker compose down
    
    # Start services in production mode
    docker compose -f docker compose.yaml -f docker compose.prod.yaml up -d
    
    log "Services deployed successfully"
}

# Wait for services to be healthy
wait_for_services() {
    log "Waiting for services to be healthy..."
    
    # Wait for MongoDB
    timeout=60
    while ! docker compose exec -T mongo mongosh --eval "db.adminCommand('ping')" &> /dev/null; do
        if [[ $timeout -eq 0 ]]; then
            error "MongoDB failed to start within 60 seconds"
        fi
        sleep 1
        ((timeout--))
    done
    log "MongoDB is healthy"
    
    # Wait for Payload CMS
    timeout=60
    while ! curl -f http://localhost:3001/api/health &> /dev/null; do
        if [[ $timeout -eq 0 ]]; then
            error "Payload CMS failed to start within 60 seconds"
        fi
        sleep 1
        ((timeout--))
    done
    log "Payload CMS is healthy"
}

# Show deployment status
show_status() {
    log "Deployment Status:"
    docker compose ps
    
    echo ""
    info "🚀 Payload CMS (Lattice-CMS) deployed successfully!"
    info "📍 Application: http://localhost:3001"
    info "🔧 Admin Panel: http://localhost:3001/admin"
    info "💾 Database: MongoDB (lattice-cms)"
    info "🔄 Redis Cache: Available"
    
    echo ""
    info "Next steps:"
    info "1. Configure your reverse proxy (Nginx) to point to localhost:3001"
    info "2. Set up SSL certificates"
    info "3. Create your first admin user through the admin panel"
    info "4. Configure your domain and CORS settings"
    
    echo ""
    warn "Security reminders:"
    warn "- Change default passwords immediately"
    warn "- Configure proper firewall rules"
    warn "- Set up regular backups"
    warn "- Monitor application logs"
}

# Main deployment function
main() {
    log "Starting Payload CMS Lattice-CMS production deployment..."
    
    check_root
    check_docker
    check_env_file
    validate_env
    create_directories
    pull_images
    build_application
    deploy_services
    wait_for_services
    show_status
    
    log "Deployment completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted by user"' INT TERM

# Execute main function
main "$@"
