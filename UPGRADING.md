# Upgrading Your Minecraft Server

## Upgrading RAM (No Data Loss)

You can safely increase RAM allocation without losing your world data.

### Method 1: Update Terraform Variables (Recommended)

1. Edit your `terraform.tfvars`:
   ```hcl
   memory_allocation = "6G"  # Increase from 3G to 6G
   ```

2. Apply the change:
   ```bash
   terraform apply
   ```

3. The server will restart with new memory settings.

### Method 2: Manual Update (Immediate)

1. SSH to server and edit the service:
   ```bash
   gcloud compute ssh minecraft-server --zone us-central1-a
   sudo systemctl stop minecraft
   sudo sed -i 's/-Xmx3G/-Xmx6G/g; s/-Xms3G/-Xms6G/g' /etc/systemd/system/minecraft.service
   sudo systemctl daemon-reload
   sudo systemctl start minecraft
   ```

## Upgrading Instance Type (More CPU/RAM)

You may need a larger instance type if you want more than 4GB RAM.

### Safe Upgrade Process

1. Update `terraform.tfvars`:
   ```hcl
   machine_type = "e2-standard-4"  # 4 vCPUs, 16GB RAM
   memory_allocation = "12G"       # Allocate 12GB to Minecraft
   ```

2. Apply changes (server will restart):
   ```bash
   terraform apply
   ```

### Instance Type Options

| Type | vCPUs | RAM | Max MC RAM | Players |
|------|-------|-----|------------|---------|
| e2-medium | 1-2 | 4GB | 3G | 10-20 |
| e2-standard-2 | 2 | 8GB | 6G | 20-30 |
| e2-standard-4 | 4 | 16GB | 12G | 30-50 |
| e2-standard-8 | 8 | 32GB | 28G | 50-100 |

### What Happens During Upgrade

1. **Instance Stop**: Server stops (players disconnected)
2. **Resize**: GCP changes the machine type
3. **Instance Start**: Server starts with new resources
4. **World Loads**: All data intact, more resources available

### Downtime

- Typical downtime: 2-5 minutes
- Plan upgrades during low-activity periods
- Announce to players beforehand

## Memory Allocation Guidelines

- **OS Overhead**: Reserve 1-2GB for system
- **Minecraft**: Allocate 75-85% of total RAM
- **Example**: 16GB instance → 12-14GB for Minecraft

### Checking Current Usage

```bash
# Check RAM usage
./manage-plugins.sh ssh "free -h"

# Check Minecraft memory
./manage-plugins.sh ssh "sudo systemctl status minecraft | grep Memory"
```

## Best Practices

1. **Before Upgrading**:
   - Create a backup: `./manage-backups.sh create "Before RAM upgrade"`
   - Check current performance metrics
   - Notify players of maintenance

2. **After Upgrading**:
   - Monitor server performance
   - Check logs for any issues
   - Adjust if needed

3. **Performance Tuning**:
   - More RAM helps with:
     - Larger view distances
     - More simultaneous players
     - Complex redstone/farms
     - Extensive exploration
   
## Troubleshooting

### Server Won't Start After RAM Increase

1. Check available RAM:
   ```bash
   gcloud compute ssh minecraft-server --command "free -h"
   ```

2. Ensure you're not over-allocating:
   - Leave 1-2GB for system
   - Check instance type limits

3. Review logs:
   ```bash
   ./manage-plugins.sh logs
   ```

### Performance Issues After Upgrade

- Clear memory: Restart server
- Check for memory leaks in plugins
- Consider SSD disk upgrade for better I/O

## Zero-Downtime Options

For truly zero downtime (advanced):

1. Create new instance with desired specs
2. Restore latest backup to new instance  
3. Update DNS to point to new instance
4. Decommission old instance

This requires more setup but ensures no player disruption.