#!/bin/bash

# MongoDB Backup Script for Payload CMS Lattice-CMS
# Usage: ./backup-database.sh [backup_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./backups"
DATABASE_NAME="lattice-cms"
CONTAINER_NAME="payload-cms-mongo-1"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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

# Get backup name from argument or use timestamp
BACKUP_NAME=${1:-"lattice-cms-backup-${TIMESTAMP}"}

# Create backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log "Created backup directory: $BACKUP_DIR"
    fi
}

# Check if MongoDB container is running
check_mongo_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "MongoDB container '$CONTAINER_NAME' is not running"
    fi
    log "MongoDB container is running"
}

# Create database backup
create_backup() {
    log "Creating backup of database: $DATABASE_NAME"
    log "Backup name: $BACKUP_NAME"
    
    # Create backup using mongodump
    docker exec "$CONTAINER_NAME" mongodump \
        --db "$DATABASE_NAME" \
        --out "/tmp/backup-${TIMESTAMP}" \
        --quiet
    
    # Copy backup from container to host
    docker cp "$CONTAINER_NAME:/tmp/backup-${TIMESTAMP}" "$BACKUP_DIR/"
    
    # Rename backup directory
    mv "$BACKUP_DIR/backup-${TIMESTAMP}" "$BACKUP_DIR/$BACKUP_NAME"
    
    # Clean up temporary backup in container
    docker exec "$CONTAINER_NAME" rm -rf "/tmp/backup-${TIMESTAMP}"
    
    log "Backup created successfully: $BACKUP_DIR/$BACKUP_NAME"
}

# Compress backup
compress_backup() {
    log "Compressing backup..."
    
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"
    
    log "Backup compressed: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
}

# Show backup info
show_backup_info() {
    backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    backup_size=$(du -h "$backup_file" | cut -f1)
    
    info "✅ Backup completed successfully!"
    info "📁 Backup file: $backup_file"
    info "📏 Backup size: $backup_size"
    info "🗄️  Database: $DATABASE_NAME"
    info "🕒 Created: $(date)"
    
    echo ""
    info "To restore this backup, use:"
    info "./restore-database.sh ${BACKUP_NAME}.tar.gz"
}

# Clean old backups (keep last 7 days)
clean_old_backups() {
    log "Cleaning old backups (keeping last 7 days)..."
    
    find "$BACKUP_DIR" -name "lattice-cms-backup-*.tar.gz" -type f -mtime +7 -delete
    
    log "Old backups cleaned"
}

# Main backup function
main() {
    log "Starting MongoDB backup for Lattice-CMS..."
    
    create_backup_dir
    check_mongo_container
    create_backup
    compress_backup
    show_backup_info
    clean_old_backups
    
    log "Backup process completed successfully!"
}

# Handle script interruption
trap 'error "Backup interrupted by user"' INT TERM

# Execute main function
main "$@"
