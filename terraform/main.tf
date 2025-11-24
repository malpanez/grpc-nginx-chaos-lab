locals {
  lxc_containers = {
    nginx_gateway = {
      hostname = "nginx-gateway"
      vmid     = 201
      ip       = var.nginx_ip
    }
    grpc_app_1 = {
      hostname = "grpc-app-1"
      vmid     = 202
      ip       = var.grpc_app_1_ip
    }
    grpc_app_2 = {
      hostname = "grpc-app-2"
      vmid     = 203
      ip       = var.grpc_app_2_ip
    }
  }
}

resource "proxmox_virtual_environment_container" "containers" {
  for_each     = local.lxc_containers
  node_name    = var.pm_node
  vm_id        = each.value.vmid
  unprivileged = true

  features {
    nesting = true
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  disk {
    datastore_id = var.lxc_storage
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = var.lxc_bridge
  }

  initialization {
    hostname = each.value.hostname

    ip_config {
      ipv4 {
        address = "${each.value.ip}${var.lxc_network_cidr}"
        gateway = var.lxc_gateway
      }
    }

    user_account {
      keys = [trimspace(file(var.ssh_public_key_file))]
    }
  }

  operating_system {
    template_file_id = var.lxc_ostemplate
    type             = "debian"
  }

  started = true
}
