variable "pm_api_url" {
  type = string
}
variable "pm_api_token_id" { type = string }
variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" { type = string }
variable "proxmox_node" {
  type        = string
  description = "Имя узла"
}

variable "ciuser" { type = string }


variable "vm_params" {
  type = map(object({
    vmid      = number
    cores     = number
    memory    = number
    disk_size = number,
    ip        = string
  }))


  default = {
    "k3s-control-plane" = { vmid = 410, cores = 2, memory = 2048, disk_size = 30, ip = "10.0.0.10" }
    "k3s-worker-1"      = { vmid = 411, cores = 2, memory = 4096, disk_size = 40, ip = "10.0.0.11" }
    "k3s-worker-2"      = { vmid = 412, cores = 2, memory = 4096, disk_size = 40, ip = "10.0.0.12" }
    "ci-runner"         = { vmid = 413, cores = 1, memory = 1024, disk_size = 20, ip = "10.0.0.13" }
  }
}
