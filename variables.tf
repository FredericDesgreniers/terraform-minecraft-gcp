variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the Minecraft server instance"
  type        = string
  default     = "minecraft-server"
}

variable "machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "e2-medium"
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "server_type" {
  description = "Type of Minecraft server (vanilla, paper, spigot)"
  type        = string
  default     = "paper"
}

variable "minecraft_version" {
  description = "Minecraft version (e.g., 1.21.7, 1.21.1, 1.20.4)"
  type        = string
  default     = "1.21.7"
}

variable "memory_allocation" {
  description = "Memory allocation for Minecraft server (e.g., 2G, 4G)"
  type        = string
  default     = "2G"
}

variable "use_static_ip" {
  description = "Whether to use a static IP address (recommended for DNS)"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the instance"
  type        = bool
  default     = false  # Set to true in production
}