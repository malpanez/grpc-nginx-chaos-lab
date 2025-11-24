variable "pm_api_url" {
  description = "Proxmox API endpoint (no /api2/json suffix), e.g. https://pve:8006/"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API token ID, e.g. terraform@pve!token-name"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_node" {
  description = "Proxmox node name (e.g. pve)"
  type        = string
}

variable "lxc_ostemplate" {
  description = "LXC OS template, e.g. local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  type        = string
}

variable "lxc_storage" {
  description = "Storage name for rootfs (e.g. local-lvm)"
  type        = string
}

variable "lxc_bridge" {
  description = "Network bridge (e.g. vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "lxc_gateway" {
  description = "Gateway IP address (e.g. 192.168.100.1)"
  type        = string
  default     = "192.168.100.1"
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file to inject into LXCs"
  type        = string
}

variable "lxc_network_cidr" {
  description = "CIDR suffix for IPs (e.g. /24)"
  type        = string
  default     = "/24"
}

variable "nginx_ip" {
  description = "IP for nginx-gateway LXC"
  type        = string
  default     = "192.168.100.10"
}

variable "grpc_app_1_ip" {
  description = "IP for grpc-app-1 LXC"
  type        = string
  default     = "192.168.100.11"
}

variable "grpc_app_2_ip" {
  description = "IP for grpc-app-2 LXC"
  type        = string
  default     = "192.168.100.12"
}
