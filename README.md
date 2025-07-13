# Minecraft Server on GCP with Terraform

This Terraform configuration deploys a Minecraft Java Edition server on Google Cloud Platform.

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) installed
2. [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and authenticated
3. A GCP project with billing enabled
4. Enable required APIs:
   ```bash
   gcloud services enable compute.googleapis.com
   ```

## Quick Start

1. Clone this repository and navigate to the directory:
   ```bash
   cd minecraft-terraform-gcp
   ```

2. Copy the example variables file and update with your values:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` with your GCP project ID and desired configuration.

4. Initialize Terraform:
   ```bash
   terraform init
   ```

5. Plan the deployment:
   ```bash
   terraform plan
   ```

6. Deploy the server:
   ```bash
   terraform apply
   ```

7. Get the server IP:
   ```bash
   terraform output minecraft_server_ip
   ```

## Connecting to Your Server

After deployment, you can connect using:
- **Minecraft Client**: Use the IP shown in `terraform output minecraft_connection_string`
- **SSH**: `terraform output ssh_command`

## Server Management

### Check Server Status
```bash
gcloud compute ssh minecraft-server --zone us-central1-a --command "sudo systemctl status minecraft"
```

### View Server Logs
```bash
gcloud compute ssh minecraft-server --zone us-central1-a --command "sudo journalctl -u minecraft -f"
```

### Restart Server
```bash
gcloud compute ssh minecraft-server --zone us-central1-a --command "sudo systemctl restart minecraft"
```

### Manual Backup
```bash
./manage-backups.sh create "Description of backup"
```

## Backup Management

The server includes an enhanced backup system with automated backups every 6 hours.

### Backup Commands
```bash
# Create manual backup
./manage-backups.sh create "Before plugin installation"

# List all backups
./manage-backups.sh list

# Check backup system status
./manage-backups.sh status

# Restore a backup
./manage-backups.sh restore minecraft_manual_20240113_120000.tar.gz

# Download backup to local machine
./manage-backups.sh download minecraft_auto_20240113_060000.tar.gz ~/backups/

# View backup logs
./manage-backups.sh logs
```

### Backup Schedule
- **Automatic backups**: Every 6 hours (midnight, 6am, noon, 6pm)
- **Retention**: Keeps recent backups, automatically cleans old ones
- **Backup includes**: All worlds, plugins, and configuration files

### Backup Features
- Announces to players before backup
- Saves world data safely without stopping server
- Stores metadata about each backup
- Automatic cleanup of old backups
- Backup logs in `/var/log/minecraft-backup.log`

## Plugin Management

The server runs Paper, which supports Bukkit/Spigot plugins. Use the included `manage-plugins.sh` script:

### List Installed Plugins
```bash
./manage-plugins.sh list
```

### Upload a Plugin
```bash
./manage-plugins.sh upload ~/Downloads/EssentialsX.jar
```

### Download a Plugin from URL
```bash
./manage-plugins.sh download https://example.com/plugin.jar
```

### Remove a Plugin
```bash
./manage-plugins.sh remove PluginName.jar
```

### Restart Server (to load/unload plugins)
```bash
./manage-plugins.sh restart
```

### Popular Plugins
- **EssentialsX**: Basic commands and economy
- **LuckPerms**: Advanced permissions system
- **WorldEdit**: World manipulation tools
- **WorldGuard**: Region protection
- **Vault**: Economy/permissions API

Find more plugins at:
- [SpigotMC](https://www.spigotmc.org/resources/)
- [Bukkit](https://dev.bukkit.org/projects)
- [PaperMC](https://papermc.io/downloads/plugins)

## Configuration Options

### Instance Types
- `e2-micro`: 0.25-2 vCPUs, 1GB RAM (free tier eligible, very small servers)
- `e2-small`: 0.5-2 vCPUs, 2GB RAM (small servers, 5-10 players)
- `e2-medium`: 1-2 vCPUs, 4GB RAM (default, 10-20 players)
- `e2-standard-4`: 4 vCPUs, 16GB RAM (larger servers, 20-50 players)

### Minecraft Versions
Update the `minecraft_version` variable with the server JAR hash from:
https://www.minecraft.net/en-us/download/server

### Memory Allocation
Adjust `memory_allocation` based on your instance type:
- e2-small: "1G"
- e2-medium: "3G"
- e2-standard-4: "12G"

## Features

- Paper server (supports plugins) with configurable server type
- Automatic server installation and setup
- Plugin management script included
- Systemd service for automatic restarts
- Daily automated backups (3 AM server time)
- Firewall rules for Minecraft (25565) and SSH (22)
- Optional static IP address
- Configurable instance type and disk size

## Cost Estimation

Monthly costs (approximate):
- e2-medium instance: ~$35
- 20GB persistent disk: ~$1
- Static IP: ~$7 (if unused)
- Network egress: Variable based on usage

Use `e2-micro` for free tier eligibility (limited performance).

## Destroy Resources

To remove all resources and avoid charges:
```bash
terraform destroy
```

## Troubleshooting

### Server not starting
Check logs: `sudo journalctl -u minecraft -n 100`

### Can't connect to server
1. Verify firewall rules are created
2. Check server is running: `sudo systemctl status minecraft`
3. Ensure you're using the correct IP from `terraform output`

### Performance issues
- Upgrade instance type in `terraform.tfvars`
- Increase memory allocation
- Check disk space: `df -h`