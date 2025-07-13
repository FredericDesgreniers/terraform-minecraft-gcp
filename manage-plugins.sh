#!/bin/bash

# Script to help manage Minecraft plugins

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
    list)
        echo "Listing installed plugins:"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "ls -la /opt/minecraft/plugins/*.jar 2>/dev/null || echo 'No plugins installed yet'"
        ;;
    
    upload)
        if [ -z "$2" ]; then
            echo "Usage: $0 upload <plugin-file.jar>"
            exit 1
        fi
        
        if [ ! -f "$2" ]; then
            echo "Error: File $2 not found"
            exit 1
        fi
        
        echo "Uploading plugin: $2"
        gcloud compute scp "$2" minecraft-server:/tmp/ --zone "$ZONE" --project "$PROJECT"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo mv /tmp/$(basename $2) /opt/minecraft/plugins/ && sudo chown minecraft:minecraft /opt/minecraft/plugins/$(basename $2)"
        echo "Plugin uploaded. Restart the server to load it."
        ;;
    
    download)
        if [ -z "$2" ]; then
            echo "Usage: $0 download <plugin-url>"
            echo "Example: $0 download https://example.com/plugin.jar"
            exit 1
        fi
        
        FILENAME=$(basename "$2")
        echo "Downloading plugin: $FILENAME"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "cd /opt/minecraft/plugins && sudo wget -O '$FILENAME' '$2' && sudo chown minecraft:minecraft '$FILENAME'"
        echo "Plugin downloaded. Restart the server to load it."
        ;;
    
    remove)
        if [ -z "$2" ]; then
            echo "Usage: $0 remove <plugin-name>"
            exit 1
        fi
        
        echo "Removing plugin: $2"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo rm -f /opt/minecraft/plugins/$2"
        echo "Plugin removed. Restart the server to unload it."
        ;;
    
    restart)
        echo "Restarting Minecraft server..."
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo systemctl restart minecraft"
        echo "Server restarted."
        ;;
    
    logs)
        echo "Showing recent server logs (Ctrl+C to exit):"
        gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo journalctl -u minecraft -f"
        ;;
    
    *)
        echo "Minecraft Plugin Manager"
        echo ""
        echo "Usage: $0 {list|upload|download|remove|restart|logs}"
        echo ""
        echo "Commands:"
        echo "  list                    - List installed plugins"
        echo "  upload <file.jar>       - Upload a plugin from your local machine"
        echo "  download <url>          - Download a plugin from a URL"
        echo "  remove <plugin.jar>     - Remove an installed plugin"
        echo "  restart                 - Restart the Minecraft server"
        echo "  logs                    - Show server logs (live)"
        echo ""
        echo "Examples:"
        echo "  $0 upload ~/Downloads/EssentialsX.jar"
        echo "  $0 download https://ci.ender.zone/job/EssentialsX/lastSuccessfulBuild/artifact/jars/EssentialsX-2.20.1.jar"
        echo "  $0 remove EssentialsX-2.20.1.jar"
        ;;
esac