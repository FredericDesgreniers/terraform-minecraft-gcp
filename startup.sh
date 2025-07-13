#!/bin/bash

# Update system
apt-get update
apt-get install -y wget screen

# Install Java 21 (Amazon Corretto)
wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" > /etc/apt/sources.list.d/corretto.list
apt-get update
apt-get install -y java-21-amazon-corretto-jdk

# Create minecraft user
useradd -m -r -s /bin/bash minecraft

# Create minecraft directory
mkdir -p /opt/minecraft
cd /opt/minecraft

# Download server based on type
if [ "${server_type}" = "paper" ]; then
    # Get Paper build info
    BUILD_JSON=$(wget -qO- "https://api.papermc.io/v2/projects/paper/versions/${minecraft_version}/builds")
    LATEST_BUILD=$(echo "$BUILD_JSON" | grep -oP '"build":\s*\K\d+' | tail -1)
    
    # Download Paper
    wget -O server.jar "https://api.papermc.io/v2/projects/paper/versions/${minecraft_version}/builds/$LATEST_BUILD/downloads/paper-${minecraft_version}-$LATEST_BUILD.jar"
    
    # Create plugins directory
    mkdir -p plugins
elif [ "${server_type}" = "spigot" ]; then
    # Download BuildTools and build Spigot
    wget -O BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
    java -jar BuildTools.jar --rev ${minecraft_version}
    mv spigot-*.jar server.jar
    rm -rf BuildTools.jar BuildData Bukkit CraftBukkit Spigot work
    
    # Create plugins directory
    mkdir -p plugins
else
    # Download vanilla server
    VERSION_MANIFEST=$(wget -qO- https://launchermeta.mojang.com/mc/game/version_manifest.json)
    VERSION_URL=$(echo "$VERSION_MANIFEST" | grep -oP "\"id\":\s*\"${minecraft_version}\".*?\"url\":\s*\"\K[^\"]+")
    VERSION_JSON=$(wget -qO- "$VERSION_URL")
    SERVER_URL=$(echo "$VERSION_JSON" | grep -oP "\"server\":\s*{.*?\"url\":\s*\"\K[^\"]+")
    wget -O server.jar "$SERVER_URL"
fi

# Accept EULA
echo "eula=true" > eula.txt

# Create server properties
cat > server.properties <<EOF
spawn-protection=16
max-tick-time=60000
query.port=25565
generator-settings=
sync-chunk-writes=true
force-gamemode=false
allow-nether=true
enforce-whitelist=false
gamemode=survival
broadcast-console-to-ops=true
enable-query=false
player-idle-timeout=0
difficulty=easy
spawn-monsters=true
broadcast-rcon-to-ops=true
op-permission-level=4
pvp=true
entity-broadcast-range-percentage=100
snooper-enabled=true
level-type=default
hardcore=false
enable-status=true
enable-command-block=false
max-players=20
network-compression-threshold=256
resource-pack-sha1=
max-world-size=29999984
function-permission-level=2
rcon.port=25575
server-port=25565
server-ip=
spawn-npcs=true
allow-flight=false
level-name=world
view-distance=10
resource-pack=
spawn-animals=true
white-list=false
rcon.password=
generate-structures=true
online-mode=true
max-build-height=256
level-seed=
prevent-proxy-connections=false
use-native-transport=true
enable-jmx-monitoring=false
motd=A Minecraft Server on GCP
rate-limit=0
enable-rcon=false
EOF

# Set ownership
chown -R minecraft:minecraft /opt/minecraft

# Create systemd service
cat > /etc/systemd/system/minecraft.service <<EOF
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=/opt/minecraft
Type=simple
ExecStart=/usr/bin/java -Xms${memory_allocation} -Xmx${memory_allocation} -jar server.jar nogui
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start Minecraft server
systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft

# Create enhanced backup script
cat > /opt/minecraft/backup.sh <<'EOF'
${backup_script_content}
EOF

chmod +x /opt/minecraft/backup.sh
chown minecraft:minecraft /opt/minecraft/backup.sh

# Create log file with proper permissions
touch /var/log/minecraft-backup.log
chown minecraft:minecraft /var/log/minecraft-backup.log

# Setup backup schedule (multiple times per day)
cat > /etc/cron.d/minecraft-backup <<'CRON'
# Minecraft backup schedule
# Backup every 6 hours (midnight, 6am, noon, 6pm)
0 0,6,12,18 * * * minecraft /opt/minecraft/backup.sh auto >> /var/log/minecraft-backup.log 2>&1

# Weekly cleanup of old backups (Sundays at 4 AM)
0 4 * * 0 minecraft /opt/minecraft/backup.sh cleanup >> /var/log/minecraft-backup.log 2>&1
CRON

# Setup log rotation for backup logs
cat > /etc/logrotate.d/minecraft-backup <<'EOF'
/var/log/minecraft-backup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0644 minecraft minecraft
}
EOF

echo "Minecraft server setup complete!"