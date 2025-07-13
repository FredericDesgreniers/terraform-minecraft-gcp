#!/bin/bash

echo "Checking DNS configuration for minecraft.frde.me..."
echo ""

# Get the server IP from Terraform
SERVER_IP=$(terraform output -raw minecraft_server_ip 2>/dev/null)

if [ -z "$SERVER_IP" ]; then
    echo "Error: Could not get server IP. Make sure Terraform has been applied."
    exit 1
fi

echo "Your Minecraft server IP: $SERVER_IP"
echo ""

# Check current DNS resolution
echo "Current DNS resolution for minecraft.frde.me:"
RESOLVED_IP=$(dig +short minecraft.frde.me @8.8.8.8)

if [ -z "$RESOLVED_IP" ]; then
    echo "  No A record found for minecraft.frde.me"
    echo ""
    echo "Action required:"
    echo "  Add an A record in Squarespace pointing minecraft.frde.me to $SERVER_IP"
else
    echo "  minecraft.frde.me resolves to: $RESOLVED_IP"
    echo ""
    if [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
        echo "✓ DNS is correctly configured!"
        echo ""
        echo "Players can now connect using: minecraft.frde.me"
    else
        echo "⚠ DNS mismatch detected!"
        echo ""
        echo "Action required:"
        echo "  Update the A record in Squarespace to point to $SERVER_IP"
        echo "  (Currently pointing to $RESOLVED_IP)"
    fi
fi

echo ""
echo "Note: DNS changes can take up to 48 hours to propagate globally."