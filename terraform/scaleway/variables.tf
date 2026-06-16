variable "scaleway_access_key" {
  type      = string
  sensitive = true
}

variable "scaleway_secret_key" {
  type      = string
  sensitive = true
}

variable "scaleway_project_id" {
  type = string
}

variable "scaleway_organization_id" {
  type = string
}

variable "region" {
  type    = string
  default = "fr-par"
}

variable "zone" {
  type    = string
  default = "fr-par-1"
}

variable "hostname" {
  type    = string
  default = "vps-prod"
}

# https://www.scaleway.com/en/pricing/virtual-instances/
# DEV1-S est minimal ; pour du sérieux, vise PLAY2-NANO ou PRO2-XXS.
variable "instance_type" {
  type    = string
  default = "DEV1-S"
}

variable "image" {
  type    = string
  default = "debian_bookworm"
}

variable "root_volume_size_gb" {
  type    = number
  default = 20
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for the initial root login (Ansible will swap to deploy user)."
}
