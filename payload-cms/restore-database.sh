#!/bin/bash

# MongoDB Restore Script for Payload CMS Lattice-CMS
# Usage: ./restore-database.sh <backup_file.tar.gz>

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
TEMP_DIR="/tmp/restore-$(date +%s)"

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

# Check if backup file is provided
if [[ $# -eq 0 ]]; then
    error "Usage: $0 <backup_file.tar.gz>"
fi

BACKUP_FILE="$1"

# Check if backup file exists
check_backup_file() {
    if [[ ! -f "$BACKUP_FILE" ]]; then
        # Try to find file in backup directory
        if [[ -f "$BACKUP_DIR/$BACKUP_FILE" ]]; then
            BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
        else
            error "Backup file not found: $BACKUP_FILE"
        fi
    fi
    
    log "Using backup file: $BACKUP_FILE"
}

# Check if MongoDB container is running
check_mongo_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "MongoDB container '$CONTAINER_NAME' is not running"
    fi
    log "MongoDB container is running"
}

# Confirm restore operation
confirm_restore() {
    warn "⚠️  WARNING: This will REPLACE all data in the '$DATABASE_NAME' database!"
    warn "⚠️  Current data will be permanently lost!"
    
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        info "Restore operation cancelled."
        exit 0
    fi
    
    echo ""
    read -p "Type 'DELETE_ALL_DATA' to confirm: " -r
    if [[ $REPLY != "DELETE_ALL_DATA" ]]; then
        info "Restore operation cancelled."
        exit 0
    fi
}

# Extract backup file
extract_backup() {
    log "Extracting backup file..."
    
    mkdir -p "$TEMP_DIR"
    tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
    
    # Find the database directory
    DB_DIR=$(find "$TEMP_DIR" -name "$DATABASE_NAME" -type d | head -1)
    
    if [[ -z "$DB_DIR" ]]; then
        error "Database directory '$DATABASE_NAME' not found in backup"
    fi
    
    log "Backup extracted to: $TEMP_DIR"
}

# Create a backup of current database before restore
backup_current_db() {
    log "Creating backup of current database before restore..."
    
    CURRENT_BACKUP_NAME="pre-restore-backup-$(date +%Y%m%d_%H%M%S)"
    
    # Create backup
    docker exec "$CONTAINER_NAME" mongodump \
        --db "$DATABASE_NAME" \
        --out "/tmp/$CURRENT_BACKUP_NAME" \
        --quiet
    
    # Copy to host
    docker cp "$CONTAINER_NAME:/tmp/$CURRENT_BACKUP_NAME" "$BACKUP_DIR/"
    
    # Compress
    cd "$BACKUP_DIR"
    tar -czf "${CURRENT_BACKUP_NAME}.tar.gz" "$CURRENT_BACKUP_NAME"
    rm -rf "$CURRENT_BACKUP_NAME"
    
    # Clean up from container
    docker exec "$CONTAINER_NAME" rm -rf "/tmp/$CURRENT_BACKUP_NAME"
    
    log "Current database backed up as: $BACKUP_DIR/${CURRENT_BACKUP_NAME}.tar.gz"
}

# Drop existing database
drop_database() {
    log "Dropping existing database: $DATABASE_NAME"
    
    docker exec "$CONTAINER_NAME" mongosh --eval "db.getSiblingDB('$DATABASE_NAME').dropDatabase()" --quiet
    
    log "Database dropped successfully"
}

# Restore database
restore_database() {
    log "Restoring database from backup..."
    
    # Copy backup to container
    docker cp "$DB_DIR" "$CONTAINER_NAME:/tmp/restore-db"
    
    # Restore using mongorestore
    docker exec "$CONTAINER_NAME" mongorestore \
        --db "$DATABASE_NAME" \
        "/tmp/restore-db" \
        --quiet
    
    # Clean up
    docker exec "$CONTAINER_NAME" rm -rf "/tmp/restore-db"
    
    log "Database restored successfully"
}

# Verify restore
verify_restore() {
    log "Verifying restore..."
    
    # Check if database exists and has collections
    collections=$(docker exec "$CONTAINER_NAME" mongosh --eval "
        db.getSiblingDB('$DATABASE_NAME').getCollectionNames().length
    " --quiet)
    
    if [[ "$collections" -gt 0 ]]; then
        log "✅ Restore verified: Database has $collections collections"
    else
        error "❌ Restore verification failed: Database appears to be empty"
    fi
}

# Clean up temporary files
cleanup() {
    log "Cleaning up temporary files..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    log "Cleanup completed"
}

# Show restore info
show_restore_info() {
    info "✅ Database restore completed successfully!"
    info "📁 Restored from: $BACKUP_FILE"
    info "🗄️  Database: $DATABASE_NAME"
    info "🕒 Restored: $(date)"
    
    echo ""
    info "🔄 You may need to restart your Payload CMS application:"
    info "docker-compose restart payload"
    
    echo ""
    warn "⚠️  Remember to:"
    warn "- Test your application thoroughly"
    warn "- Check all collections and data"
    warn "- Verify user accounts and permissions"
}

# Main restore function
main() {
    log "Starting MongoDB restore for Lattice-CMS..."
    
    check_backup_file
    check_mongo_container
    confirm_restore
    extract_backup
    backup_current_db
    drop_database
    restore_database
    verify_restore
    cleanup
    show_restore_info
    
    log "Restore process completed successfully!"
}

# Handle script interruption
trap 'cleanup; error "Restore interrupted by user"' INT TERM

# Execute main function
main "$@"
