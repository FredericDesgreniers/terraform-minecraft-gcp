#!/bin/bash

# Minecraft Operator (Admin) Management Script

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
    add)
        if [ -z "$2" ]; then
            echo "Usage: $0 add <username> [level]"
            echo "Levels: 1-4 (default: 4)"
            echo "  1 - Can bypass spawn protection"
            echo "  2 - Can use /clear, /difficulty, /gamemode, /give, /tp, etc."
            echo "  3 - Can use /ban, /kick, /op, /deop"
            echo "  4 - Can use all commands including /stop"
            exit 1
        fi
        
        LEVEL="${3:-4}"
        echo "Making $2 an operator (level $LEVEL)..."
        run_command "op $2"
        
        # Set op level if not 4
        if [ "$LEVEL" != "4" ]; then
            sleep 2
            ssh_command "sudo -u minecraft jq '.[] |= if .name == \"$2\" then .level = $LEVEL else . end' /opt/minecraft/ops.json > /tmp/ops.json && sudo mv /tmp/ops.json /opt/minecraft/ops.json && sudo chown minecraft:minecraft /opt/minecraft/ops.json"
        fi
        
        echo "Player $2 is now an operator!"
        ;;
    
    remove)
        if [ -z "$2" ]; then
            echo "Usage: $0 remove <username>"
            exit 1
        fi
        echo "Removing operator status from $2..."
        run_command "deop $2"
        echo "Player $2 is no longer an operator."
        ;;
    
    list)
        echo "Current operators:"
        ssh_command "cat /opt/minecraft/ops.json 2>/dev/null | jq -r '.[] | \"\\(.name) (level \\(.level))\"' 2>/dev/null || echo 'No operators set yet'"
        ;;
    
    level)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 level <username> <1-4>"
            echo ""
            echo "Permission levels:"
            echo "  1 - Can bypass spawn protection"
            echo "  2 - Can use basic commands (/gamemode, /give, /tp)"
            echo "  3 - Can use moderation commands (/ban, /kick, /op)"
            echo "  4 - Can use all commands (/stop, /save-all, etc.)"
            exit 1
        fi
        
        echo "Setting $2 to op level $3..."
        ssh_command "sudo -u minecraft jq '.[] |= if .name == \"$2\" then .level = $3 else . end' /opt/minecraft/ops.json > /tmp/ops.json && sudo mv /tmp/ops.json /opt/minecraft/ops.json && sudo chown minecraft:minecraft /opt/minecraft/ops.json"
        run_command "reload"
        echo "Op level updated. Changes applied."
        ;;
    
    permissions)
        echo "Minecraft Operator Permission Levels:"
        echo ""
        echo "Level 1 - Moderator"
        echo "  - Bypass spawn protection"
        echo "  - Use /tp on self"
        echo ""
        echo "Level 2 - Gamemaster"
        echo "  - All Level 1 permissions"
        echo "  - /clear, /difficulty, /effect, /gamemode, /gamerule"
        echo "  - /give, /summon, /setblock, /tp (others)"
        echo ""
        echo "Level 3 - Admin"
        echo "  - All Level 2 permissions"
        echo "  - /ban, /kick, /op, /deop"
        echo "  - /whitelist management"
        echo ""
        echo "Level 4 - Owner"
        echo "  - All permissions"
        echo "  - /stop, /save-all, /save-on, /save-off"
        echo "  - Server management commands"
        ;;
    
    *)
        echo "Minecraft Operator (Admin) Manager"
        echo ""
        echo "Usage: $0 {add|remove|list|level|permissions}"
        echo ""
        echo "Commands:"
        echo "  add <player> [level]  - Make player an operator (default level 4)"
        echo "  remove <player>       - Remove operator status"
        echo "  list                  - List all operators"
        echo "  level <player> <1-4>  - Change operator permission level"
        echo "  permissions           - Show permission level details"
        echo ""
        echo "Examples:"
        echo "  $0 add Steve          - Make Steve full admin (level 4)"
        echo "  $0 add Alex 2         - Make Alex gamemaster (level 2)"
        echo "  $0 level Steve 3      - Change Steve to level 3"
        echo ""
        echo "Quick reference:"
        echo "  Level 1: Bypass spawn protection"
        echo "  Level 2: Creative mode commands"
        echo "  Level 3: Player management"
        echo "  Level 4: Full server control"
        ;;
esac