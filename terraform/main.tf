terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
  required_version = ">=0.14"
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "k3s_nodes" {
  for_each = var.vm_params

  name        = each.key
  target_node = var.proxmox_node
  vmid        = each.value.vmid

  clone      = "init"
  full_clone = true

  os_type = "cloud-init"
  agent   = 1

  cpu {
    cores   = each.value.cores
    sockets = 1
  }

  memory = each.value.memory

  bootdisk = "scsi0"
  scsihw   = "virtio-scsi-pci"
  boot     = "order=scsi0"

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  serial {
    id   = 0
    type = "socket"
  }

  disks {
    scsi {
      scsi0 {
        disk {
          size    = "${each.value.disk_size}G"
          storage = "local"
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = "local"
        }
      }
    }
  }

  ipconfig0 = "ip=${each.value.ip}/24,gw=10.0.0.1"

  ciuser = var.ciuser

  sshkeys = var.ssh_public_key

  lifecycle {
    ignore_changes = [network]
  }
}
