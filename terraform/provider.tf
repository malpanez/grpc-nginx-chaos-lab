terraform {
  required_version = ">= 1.3.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.87.0"
    }
  }
}

locals {
  # Ensure the provider endpoint is in the format expected by bpg/proxmox (no /api2/json, trailing slash)
  proxmox_endpoint = format(
    "%s/",
    trimsuffix(replace(var.pm_api_url, "/api2/json", ""), "/")
  )
}

provider "proxmox" {
  endpoint  = local.proxmox_endpoint
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = true
}
