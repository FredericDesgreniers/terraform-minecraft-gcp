#!/bin/bash

# Minecraft Whitelist Management Script

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

# Function to run minecraft commands
run_command() {
    gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "sudo -u minecraft screen -p 0 -S minecraft -X eval 'stuff \"$1\015\"'"
}

# Function to run server commands via SSH
ssh_command() {
    gcloud compute ssh minecraft-server --zone "$ZONE" --project "$PROJECT" --command "$1"
}

case "$1" in
    enable)
        echo "Enabling whitelist..."
        run_command "whitelist on"
        ssh_command "sudo sed -i 's/white-list=false/white-list=true/g' /opt/minecraft/server.properties"
        echo "Whitelist enabled! Only whitelisted players can join."
        ;;
    
    disable)
        echo "Disabling whitelist..."
        run_command "whitelist off"
        ssh_command "sudo sed -i 's/white-list=true/white-list=false/g' /opt/minecraft/server.properties"
        echo "Whitelist disabled. Anyone can join."
        ;;
    
    add)
        if [ -z "$2" ]; then
            echo "Usage: $0 add <username>"
            exit 1
        fi
        echo "Adding $2 to whitelist..."
        run_command "whitelist add $2"
        echo "Player $2 added to whitelist."
        ;;
    
    remove)
        if [ -z "$2" ]; then
            echo "Usage: $0 remove <username>"
            exit 1
        fi
        echo "Removing $2 from whitelist..."
        run_command "whitelist remove $2"
        echo "Player $2 removed from whitelist."
        ;;
    
    list)
        echo "Current whitelisted players:"
        ssh_command "cat /opt/minecraft/whitelist.json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo 'No players whitelisted yet'"
        ;;
    
    status)
        echo "Whitelist status:"
        ssh_command "grep 'white-list=' /opt/minecraft/server.properties"
        echo ""
        echo "Whitelisted players:"
        ssh_command "cat /opt/minecraft/whitelist.json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo 'No players whitelisted yet'"
        ;;
    
    reload)
        echo "Reloading whitelist..."
        run_command "whitelist reload"
        echo "Whitelist reloaded."
        ;;
    
    import)
        if [ -z "$2" ]; then
            echo "Usage: $0 import <file>"
            echo "File should contain one username per line"
            exit 1
        fi
        
        if [ ! -f "$2" ]; then
            echo "Error: File $2 not found"
            exit 1
        fi
        
        echo "Importing players from $2..."
        while IFS= read -r player; do
            if [ ! -z "$player" ]; then
                echo "Adding $player..."
                run_command "whitelist add $player"
                sleep 1
            fi
        done < "$2"
        echo "Import complete!"
        ;;
    
    *)
        echo "Minecraft Whitelist Manager"
        echo ""
        echo "Usage: $0 {enable|disable|add|remove|list|status|reload|import}"
        echo ""
        echo "Commands:"
        echo "  enable              - Enable whitelist (private server)"
        echo "  disable             - Disable whitelist (public server)"
        echo "  add <player>        - Add a player to whitelist"
        echo "  remove <player>     - Remove a player from whitelist"
        echo "  list                - List all whitelisted players"
        echo "  status              - Show whitelist status"
        echo "  reload              - Reload whitelist from file"
        echo "  import <file>       - Import players from file (one per line)"
        echo ""
        echo "Examples:"
        echo "  $0 enable"
        echo "  $0 add Steve"
        echo "  $0 add Alex"
        echo "  $0 import players.txt"
        ;;
esac