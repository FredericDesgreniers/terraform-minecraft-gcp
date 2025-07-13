terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Minecraft server instance
resource "google_compute_instance" "minecraft_server" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    auto_delete = false  # IMPORTANT: Disk survives instance deletion
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = var.disk_size
      type  = "pd-standard"  # or "pd-ssd" for better performance
    }
  }
  
  # Prevent accidental instance deletion
  deletion_protection = var.enable_deletion_protection

  network_interface {
    network = "default"
    access_config {
      nat_ip = var.use_static_ip ? google_compute_address.minecraft_ip[0].address : null
    }
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    server_type          = var.server_type
    minecraft_version    = var.minecraft_version
    memory_allocation    = var.memory_allocation
    backup_script_content = file("${path.module}/backup-system.sh")
  })

  tags = ["minecraft-server"]

  service_account {
    scopes = ["cloud-platform"]
  }
}

# Firewall rule for Minecraft
resource "google_compute_firewall" "minecraft" {
  name    = "minecraft-server-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["25565"]
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["minecraft-server"]
}

# Static IP (optional but recommended)
resource "google_compute_address" "minecraft_ip" {
  count  = var.use_static_ip ? 1 : 0
  name   = "minecraft-server-ip"
  region = var.region
}

# Snapshot schedule for disk backups
resource "google_compute_resource_policy" "minecraft_snapshot" {
  name   = "minecraft-disk-snapshot-schedule"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "03:00"  # 3 AM
      }
    }
    
    retention_policy {
      max_retention_days    = 7
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
    
    snapshot_properties {
      storage_locations = [var.region]
      labels = {
        environment = "minecraft"
        auto_backup = "true"
      }
    }
  }
}

# Attach snapshot schedule to disk after instance creation
resource "google_compute_disk_resource_policy_attachment" "minecraft_disk_attachment" {
  name = google_compute_resource_policy.minecraft_snapshot.name
  disk = google_compute_instance.minecraft_server.name
  zone = var.zone
}