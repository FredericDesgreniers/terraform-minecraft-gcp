output "minecraft_server_ip" {
  description = "The public IP address of the Minecraft server"
  value       = var.use_static_ip ? google_compute_address.minecraft_ip[0].address : google_compute_instance.minecraft_server.network_interface[0].access_config[0].nat_ip
}

output "minecraft_server_name" {
  description = "The name of the Minecraft server instance"
  value       = google_compute_instance.minecraft_server.name
}

output "minecraft_server_zone" {
  description = "The zone where the Minecraft server is deployed"
  value       = google_compute_instance.minecraft_server.zone
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "gcloud compute ssh ${var.instance_name} --zone ${var.zone} --project ${var.project_id}"
}

output "minecraft_connection_string" {
  description = "Connection string for Minecraft clients"
  value       = "${var.use_static_ip ? google_compute_address.minecraft_ip[0].address : google_compute_instance.minecraft_server.network_interface[0].access_config[0].nat_ip}:25565"
}

output "dns_instructions" {
  description = "Instructions for updating DNS in Squarespace"
  value       = <<-EOT
    
    To point minecraft.frde.me to your server:
    
    1. Log in to Squarespace
    2. Go to Settings → Domains → frde.me
    3. Click "DNS Settings"
    4. Add or update an A record:
       - Host: minecraft
       - Points to: ${var.use_static_ip ? google_compute_address.minecraft_ip[0].address : google_compute_instance.minecraft_server.network_interface[0].access_config[0].nat_ip}
       - TTL: 3600 (or your preference)
    
    After updating, players can connect using: minecraft.frde.me
  EOT
}