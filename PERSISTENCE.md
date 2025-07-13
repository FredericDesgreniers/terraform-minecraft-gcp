# Minecraft Server Data Persistence

Your Minecraft world data is protected by multiple layers of persistence and backup:

## 1. Persistent Boot Disk ✅
- World data is stored on the VM's boot disk at `/opt/minecraft/`
- The disk is **persistent** - it survives server restarts, stops, and reboots
- Set to `auto_delete = false` - disk is retained even if instance is deleted

## 2. Protection Layers

### Server Restarts ✅
- **Safe**: World data persists through:
  - `sudo systemctl restart minecraft`
  - Server crashes and automatic restarts
  - OS reboots
  - Instance stop/start cycles

### Instance Operations ✅
- **Safe**: Data survives these GCP operations:
  - Stopping instance: `gcloud compute instances stop`
  - Starting instance: `gcloud compute instances start`
  - Resizing instance (changing machine type)
  - Moving instance to different zone (with disk)

### Deletion Protection 🛡️
- Enable with: `enable_deletion_protection = true` in terraform.tfvars
- Prevents accidental instance deletion via console or API

## 3. Backup Systems

### Application-Level Backups (Every 6 hours) ✅
- Location: `/opt/minecraft/backups/`
- Includes: All worlds, plugins, configs
- Schedule: 00:00, 06:00, 12:00, 18:00
- Retention: Smart cleanup of old backups

### Disk Snapshots (Daily) ✅
- GCP disk snapshots at 3 AM
- 7-day retention
- Survives even if disk is deleted
- Can restore entire disk state

## 4. Data Loss Scenarios

### ✅ SAFE Scenarios (No Data Loss)
1. Server process crashes
2. OS crashes or kernel panics  
3. Instance stops/starts
4. Terraform apply (updates)
5. Hardware failures (GCP migrates disk)
6. Zone outages (disk persists)

### ⚠️ RISKY Scenarios (Need Backups)
1. Accidental file deletion in game
2. World corruption from mods/plugins
3. Griefing or unwanted changes
4. Command mistakes (e.g., `/fill` accidents)

### ❌ DATA LOSS Scenarios (Without Protection)
1. `terraform destroy` (if deletion protection disabled)
2. Manual disk deletion in GCP Console
3. Project deletion
4. Account suspension/closure

## 5. Recovery Options

### From Application Backup
```bash
# List backups
./manage-backups.sh list

# Restore specific backup
./manage-backups.sh restore minecraft_auto_20240113_120000.tar.gz
```

### From Disk Snapshot
```bash
# List snapshots
gcloud compute snapshots list --filter="name:minecraft*"

# Create new disk from snapshot
gcloud compute disks create minecraft-recovered \
  --source-snapshot=<snapshot-name> \
  --zone=us-central1-a
```

## 6. Best Practices

1. **Enable Deletion Protection** for production
   ```hcl
   enable_deletion_protection = true
   ```

2. **Test Backups Regularly**
   ```bash
   ./manage-backups.sh create "Weekly test"
   ```

3. **Download Important Backups**
   ```bash
   ./manage-backups.sh download <backup-name> ~/minecraft-backups/
   ```

4. **Monitor Disk Space**
   ```bash
   gcloud compute ssh minecraft-server --command "df -h /opt/minecraft"
   ```

5. **Before Major Changes**
   - Create manual backup
   - Consider downloading backup locally
   - Document what you're changing

## Summary

Your world is safe from infrastructure failures. The main risks are:
- Accidental deletion (mitigated by deletion protection)
- In-game accidents (mitigated by backups)
- Disk space issues (monitor regularly)

The combination of persistent disks, regular backups, and disk snapshots provides excellent data protection.