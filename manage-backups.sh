#!/bin/bash

# Minecraft Backup Management Script

SERVER_IP=$(terraform output -raw minecraft_server_ip 2>/dev/null)
ZONE=$(terraform output -raw minecraft_server_zone 2>/dev/null)
PROJECT=$(terraform output -json 2>/dev/null | jq -r '.project_id.value // empty')

if [ -z "$SERVER_IP" ] || [ -z "$ZONE" ]; then
    echo "Error: Could not get server details. Make sure Terraform has been applied."
    exit 1
fi

if [ -z "$PROJECT" ]; then
    PROJECT=$(gcloud config get-value project)
fi

case "$1" in
    create)
        echo "Creating manual backup..."
        DESCRIPTION="${2:-Manual backup created from local machine}"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft /opt/minecraft/backup.sh create '$DESCRIPTION'"
        ;;
    
    list)
        echo "Fetching backup list..."
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft /opt/minecraft/backup.sh list"
        ;;
    
    status)
        echo "Backup system status:"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft /opt/minecraft/backup.sh status"
        ;;
    
    restore)
        if [ -z "$2" ]; then
            echo "Usage: $0 restore <backup-name>"
            echo ""
            echo "Available backups:"
            gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft /opt/minecraft/backup.sh list"
            exit 1
        fi
        
        echo "WARNING: This will restore backup '$2' and restart the server."
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft /opt/minecraft/backup.sh restore '$2'"
        else
            echo "Restore cancelled."
        fi
        ;;
    
    download)
        if [ -z "$2" ]; then
            echo "Usage: $0 download <backup-name> [local-path]"
            echo ""
            echo "Available backups:"
            gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "ls -1 /opt/minecraft/backups/*.tar.gz | xargs -n1 basename"
            exit 1
        fi
        
        BACKUP_NAME="$2"
        LOCAL_PATH="${3:-.}"
        
        echo "Downloading backup: $BACKUP_NAME"
        gcloud compute scp minecraft-server:/opt/minecraft/backups/"$BACKUP_NAME" "$LOCAL_PATH/" --zone "$ZONE" --project "$PROJECT"
        echo "Backup downloaded to: $LOCAL_PATH/$BACKUP_NAME"
        ;;
    
    upload)
        if [ -z "$2" ]; then
            echo "Usage: $0 upload <local-backup-file>"
            exit 1
        fi
        
        if [ ! -f "$2" ]; then
            echo "Error: File not found: $2"
            exit 1
        fi
        
        echo "Uploading backup: $2"
        FILENAME=$(basename "$2")
        gcloud compute scp "$2" minecraft-server:/tmp/ --zone "$ZONE" --project "$PROJECT"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo mv /tmp/$FILENAME /opt/minecraft/backups/ && sudo chown minecraft:minecraft /opt/minecraft/backups/$FILENAME"
        echo "Backup uploaded. Use 'restore $FILENAME' to restore it."
        ;;
    
    schedule)
        echo "Current backup schedule:"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "cat /etc/cron.d/minecraft-backup"
        ;;
    
    logs)
        echo "Recent backup logs:"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo tail -50 /var/log/minecraft-backup.log"
        ;;
    
    test)
        echo "Testing backup system..."
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft /opt/minecraft/backup.sh create 'Test backup'"
        ;;
    
    *)
        echo "Minecraft Backup Manager"
        echo ""
        echo "Usage: $0 {create|list|status|restore|download|upload|schedule|logs|test}"
        echo ""
        echo "Commands:"
        echo "  create [desc]     - Create a manual backup with optional description"
        echo "  list              - List all available backups"
        echo "  status            - Show backup system status"
        echo "  restore <backup>  - Restore a specific backup"
        echo "  download <backup> - Download a backup to local machine"
        echo "  upload <file>     - Upload a local backup to server"
        echo "  schedule          - Show backup schedule"
        echo "  logs              - Show recent backup logs"
        echo "  test              - Test the backup system"
        echo ""
        echo "Examples:"
        echo "  $0 create 'Before major update'"
        echo "  $0 restore minecraft_manual_20240113_120000.tar.gz"
        echo "  $0 download minecraft_auto_20240113_060000.tar.gz ~/backups/"
        ;;
esac