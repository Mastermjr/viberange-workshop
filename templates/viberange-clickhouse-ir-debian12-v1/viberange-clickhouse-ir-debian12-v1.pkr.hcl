variable "description" {
  type    = string
  default = "VibeRange Debian 12 analysis VM with pinned ClickHouse, Vector, CH-UI, Jupyter, and workshop bootstrap assets."
}
variable "icon_path" {
  type    = string
  default = "icon.png"
}
variable "iso_checksum" {
  type    = string
  default = "sha512:9da6ae5b63a72161d0fd4480d0f090b250c4f6bf421474e4776e82eea5cb3143bf8936bf43244e438e74d581797fe87c7193bbefff19414e33932fe787b1400f"
}
variable "os" {
  type    = string
  default = "l26"
}
variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/archive/12.1.0/amd64/iso-cd/debian-12.1.0-amd64-netinst.iso"
}
variable "vm_cpu_cores" {
  type    = string
  default = "3"
}
variable "vm_disk_size" {
  type    = string
  default = "150G"
}
variable "vm_memory" {
  type    = string
  default = "10240"
}
variable "vm_name" {
  type    = string
  default = "viberange-clickhouse-ir-debian12-v1-template"
}
variable "ssh_password" {
  type    = string
  default = "debian"
}
variable "ssh_username" {
  type    = string
  default = "debian"
}

# Ludus injects these values at build time. VM-disk and ISO storage are
# selected by the target environment's Ludus/Proxmox configuration.
variable "proxmox_url" { type = string }
variable "proxmox_host" { type = string }
variable "proxmox_storage_pool" { type = string }
variable "proxmox_storage_format" { type = string }
variable "proxmox_skip_tls_verify" { type = bool }
variable "proxmox_pool" { type = string }
variable "iso_storage_pool" { type = string }
variable "ansible_home" { type = string }
variable "ludus_nat_interface" { type = string }

locals {
  template_description = "VibeRange clickhouse-ir v1 built ${legacy_isotime("2006-01-02 03:04:05")}; ClickHouse 25.8.33.6 LTS; Vector 0.58.0; CH-UI 2.32.0; JupyterLab 4.4.10"
}

source "proxmox-iso" "viberange_clickhouse_ir" {
  boot_command = [
    "<down><tab>",
    "<wait>preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian-12-preseed.cfg ",
    "<wait>language=en locale=en_US.UTF-8 ",
    "<wait>country=US keymap=us ",
    "<wait>hostname=clickhouse-ir domain=local ",
    "<enter><wait>",
  ]
  boot_key_interval = "100ms"
  boot_wait         = "15s"
  http_directory    = "./http"

  boot_iso {
    type              = "ide"
    iso_checksum      = var.iso_checksum
    iso_url           = var.iso_url
    iso_storage_pool  = var.iso_storage_pool
    iso_download_pve  = true
    unmount           = true
    keep_cdrom_device = false
  }

  communicator    = "ssh"
  cores           = var.vm_cpu_cores
  cpu_type        = "host"
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size    = var.vm_disk_size
    format       = var.proxmox_storage_format
    storage_pool = var.proxmox_storage_pool
    type         = "virtio"
    discard      = true
    io_thread    = true
  }
  pool                     = var.proxmox_pool
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify
  memory                   = var.vm_memory
  network_adapters {
    bridge = var.ludus_nat_interface
    model  = "virtio"
  }
  node                 = var.proxmox_host
  os                   = var.os
  proxmox_url          = var.proxmox_url
  template_description = local.template_description
  vm_name              = var.vm_name
  ssh_password         = var.ssh_password
  ssh_username         = var.ssh_username
  ssh_wait_timeout     = "30m"
  task_timeout         = "30m"
}

build {
  sources = ["source.proxmox-iso.viberange_clickhouse_ir"]
  provisioner "ansible" {
    playbook_file = "ansible/prepare-clickhouse-ir.yml"
    use_proxy     = false
    user          = var.ssh_username
    extra_arguments = [
      "--extra-vars",
      "{ansible_python_interpreter: /usr/bin/python3, ansible_password: ${var.ssh_password}, ansible_sudo_pass: ${var.ssh_password}}"
    ]
    ansible_env_vars = [
      "ANSIBLE_HOME=${var.ansible_home}",
      "ANSIBLE_LOCAL_TEMP=${var.ansible_home}/tmp",
      "ANSIBLE_PERSISTENT_CONTROL_PATH_DIR=${var.ansible_home}/pc",
      "ANSIBLE_SSH_CONTROL_PATH_DIR=${var.ansible_home}/cp"
    ]
    skip_version_check = true
  }
}
