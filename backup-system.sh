#!/bin/bash

# Enhanced Minecraft Backup System
# This script creates, manages, and restores Minecraft world backups

MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/opt/minecraft/backups"
LOG_FILE="/var/log/minecraft-backup.log"
WORLDS=("world" "world_nether" "world_the_end")

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup function
create_backup() {
    local backup_type="${1:-manual}"
    local description="${2:-}"
    
    log "Starting $backup_type backup..."
    
    # Announce backup to players
    if systemctl is-active --quiet minecraft; then
        echo "say [Backup] Server backup starting in 10 seconds. You may experience brief lag." | systemctl --quiet --pipe minecraft
        sleep 10
        echo "save-off" | systemctl --quiet --pipe minecraft
        echo "save-all" | systemctl --quiet --pipe minecraft
        sleep 5
    fi
    
    # Create timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="minecraft_${backup_type}_${timestamp}"
    
    # Create backup
    cd "$MINECRAFT_DIR"
    tar -czf "$BACKUP_DIR/${backup_name}.tar.gz" "${WORLDS[@]}" plugins/ *.properties *.yml 2>/dev/null
    
    # Save metadata
    cat > "$BACKUP_DIR/${backup_name}.info" <<EOF
Backup Type: $backup_type
Date: $(date)
Description: $description
Server Version: $(grep -oP 'Paper \K[^ ]+' logs/latest.log 2>/dev/null || echo "Unknown")
World Size: $(du -sh world 2>/dev/null | cut -f1)
Players Online: $(echo "list" | systemctl --quiet --pipe minecraft | grep -oP '\d+(?= of)' || echo "0")
EOF
    
    # Re-enable saving
    if systemctl is-active --quiet minecraft; then
        echo "save-on" | systemctl --quiet --pipe minecraft
        echo "say [Backup] Backup completed successfully!" | systemctl --quiet --pipe minecraft
    fi
    
    log "Backup created: ${backup_name}.tar.gz"
    
    # Clean old backups based on retention policy
    cleanup_old_backups
}

# Cleanup old backups
cleanup_old_backups() {
    # Keep different numbers of backups based on age
    # Keep all backups from last 24 hours
    # Keep 1 daily backup for last 7 days
    # Keep 1 weekly backup for last 4 weeks
    # Keep 1 monthly backup for last 3 months
    
    log "Cleaning up old backups..."
    
    # Remove backups older than 90 days
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +90 -delete
    
    # Keep only specific backups for different periods
    # This is a simplified version - you might want more sophisticated retention
    local count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$count" -gt 50 ]; then
        # Keep newest 50 backups
        ls -t "$BACKUP_DIR"/*.tar.gz | tail -n +51 | xargs -r rm
        ls -t "$BACKUP_DIR"/*.info | tail -n +51 | xargs -r rm 2>/dev/null
    fi
    
    log "Cleanup completed. Current backup count: $(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)"
}

# List backups
list_backups() {
    echo "Available backups:"
    echo "=================="
    
    for backup in $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null); do
        local name=$(basename "$backup" .tar.gz)
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        local info_file="${backup%.tar.gz}.info"
        
        echo "- $name (Size: $size, Date: $date)"
        if [ -f "$info_file" ]; then
            grep -E "Description:|Players Online:" "$info_file" | sed 's/^/  /'
        fi
        echo ""
    done
}

# Restore backup
restore_backup() {
    local backup_name="$1"
    
    if [ -z "$backup_name" ]; then
        echo "Error: Please specify a backup to restore"
        list_backups
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    
    if [ ! -f "$backup_file" ]; then
        backup_file="$BACKUP_DIR/${backup_name}"
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file not found: $backup_name"
        return 1
    fi
    
    log "Starting restore of backup: $(basename "$backup_file")"
    
    # Stop server
    systemctl stop minecraft
    
    # Backup current world before restore
    log "Creating safety backup of current world..."
    local safety_backup="minecraft_pre_restore_$(date +%Y%m%d_%H%M%S)"
    cd "$MINECRAFT_DIR"
    tar -czf "$BACKUP_DIR/${safety_backup}.tar.gz" "${WORLDS[@]}" 2>/dev/null
    
    # Remove current worlds
    rm -rf "${WORLDS[@]}"
    
    # Restore backup
    tar -xzf "$backup_file" -C "$MINECRAFT_DIR"
    chown -R minecraft:minecraft "$MINECRAFT_DIR"
    
    # Start server
    systemctl start minecraft
    
    log "Restore completed. Server is starting..."
    echo "Restore completed. Safety backup saved as: $safety_backup"
}

# Get backup status
backup_status() {
    echo "Minecraft Backup System Status"
    echo "=============================="
    echo "Backup directory: $BACKUP_DIR"
    echo "Total backups: $(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)"
    echo "Total size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
    echo ""
    echo "Latest backups:"
    ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -5 | while read backup; do
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  - $(basename "$backup") (Size: $size, Date: $date)"
    done
    echo ""
    echo "Scheduled backups:"
    crontab -l -u minecraft 2>/dev/null | grep -v '^#' | grep backup || echo "  No user crontab found"
    cat /etc/cron.d/minecraft-backup 2>/dev/null | grep -v '^#' || echo "  No system cron found"
}

# Main script logic
case "$1" in
    create)
        create_backup "manual" "$2"
        ;;
    auto)
        create_backup "auto" "Automated backup"
        ;;
    list)
        list_backups
        ;;
    restore)
        restore_backup "$2"
        ;;
    status)
        backup_status
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    *)
        echo "Minecraft Backup System"
        echo "Usage: $0 {create|auto|list|restore|status|cleanup}"
        echo ""
        echo "Commands:"
        echo "  create [description]  - Create a manual backup with optional description"
        echo "  auto                  - Create an automated backup (for cron)"
        echo "  list                  - List all available backups"
        echo "  restore <backup>      - Restore a specific backup"
        echo "  status                - Show backup system status"
        echo "  cleanup               - Clean up old backups"
        ;;
esac