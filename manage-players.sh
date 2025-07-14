#!/bin/bash

# Minecraft Player Management Script

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
    online)
        echo "Currently online players:"
        echo "========================"
        # Get recent activity to determine who's likely online
        ssh_command "sudo journalctl -u minecraft --since '10 minutes ago' | grep -E 'joined the game|lost connection' | tail -20"
        echo ""
        echo "Players currently online are those who joined but haven't disconnected."
        ;;
    
    history)
        echo "Players who have joined recently:"
        echo "================================="
        ssh_command "sudo journalctl -u minecraft --since '24 hours ago' | grep 'joined the game' | grep -oP '[a-zA-Z0-9_]+(?= joined)' | sort -u"
        ;;
    
    all)
        echo "All players who have ever joined:"
        echo "================================="
        ssh_command "ls -1 /opt/minecraft/world/playerdata/*.dat 2>/dev/null | wc -l | xargs -I {} echo 'Total unique players: {}'"
        echo ""
        echo "Recent players from logs:"
        ssh_command "sudo zgrep -h 'joined the game' /opt/minecraft/logs/*.gz /opt/minecraft/logs/latest.log 2>/dev/null | grep -oP '[a-zA-Z0-9_]+(?=\[)' | sort -u | head -20"
        ;;
    
    info)
        if [ -z "$2" ]; then
            echo "Usage: $0 info <playername>"
            exit 1
        fi
        
        echo "Information for player: $2"
        echo "========================="
        
        # Check if whitelisted
        echo -n "Whitelisted: "
        ssh_command "grep -q '\"$2\"' /opt/minecraft/whitelist.json 2>/dev/null && echo 'Yes' || echo 'No'"
        
        # Check if operator
        echo -n "Operator: "
        ssh_command "grep -q '\"$2\"' /opt/minecraft/ops.json 2>/dev/null && echo 'Yes' || echo 'No'"
        
        # Check if banned
        echo -n "Banned: "
        ssh_command "grep -q '\"$2\"' /opt/minecraft/banned-players.json 2>/dev/null && echo 'Yes' || echo 'No'"
        
        # Last seen
        echo ""
        echo "Activity from logs:"
        ssh_command "sudo grep '$2' /opt/minecraft/logs/latest.log | tail -5"
        ;;
    
    search)
        if [ -z "$2" ]; then
            echo "Usage: $0 search <partial-name>"
            exit 1
        fi
        
        echo "Searching for players matching '$2':"
        echo "===================================="
        ssh_command "sudo zgrep -h 'joined the game' /opt/minecraft/logs/*.gz /opt/minecraft/logs/latest.log 2>/dev/null | grep -oP '[a-zA-Z0-9_]+(?=\[)' | sort -u | grep -i '$2'"
        ;;
    
    uuid)
        if [ -z "$2" ]; then
            echo "Usage: $0 uuid <playername>"
            exit 1
        fi
        
        echo "Looking up UUID for $2..."
        # Check local server files first
        UUID=$(ssh_command "grep -A1 -B1 '\"$2\"' /opt/minecraft/whitelist.json /opt/minecraft/ops.json 2>/dev/null | grep -oP '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1")
        
        if [ ! -z "$UUID" ]; then
            echo "UUID: $UUID"
        else
            echo "Player not found in server files"
            echo "You can look up UUIDs at: https://namemc.com/search?q=$2"
        fi
        ;;
    
    monitor)
        echo "Monitoring player joins/leaves (Ctrl+C to stop):"
        echo "==============================================="
        ssh_command "sudo journalctl -u minecraft -f | grep -E 'UUID of player|joined the game|lost connection|logged in with'"
        ;;
    
    *)
        echo "Minecraft Player Manager"
        echo ""
        echo "Usage: $0 {online|history|all|info|search|uuid|monitor}"
        echo ""
        echo "Commands:"
        echo "  online              - Show currently online players"
        echo "  history             - Show players who joined recently"
        echo "  all                 - List all players who ever joined"
        echo "  info <player>       - Show player information"
        echo "  search <text>       - Search for players by partial name"
        echo "  uuid <player>       - Get player's UUID"
        echo "  monitor             - Live monitor joins/leaves"
        echo ""
        echo "Examples:"
        echo "  $0 online"
        echo "  $0 info Steve"
        echo "  $0 search ste"
        echo ""
        echo "Tips:"
        echo "- Player names are case-sensitive"
        echo "- Players must join at least once to appear"
        echo "- Check https://namemc.com for name history"
        ;;
esac