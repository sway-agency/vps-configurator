# Mappées 1:1 vers le module. Voir terraform/scaleway/modules/env/variables.tf pour la doc.

variable "env_name" {
  type    = string
  default = "dev" # renomme librement : "staging", "preprod", etc. (variable, donc override via tfvars)
}

variable "project_slug" {
  type = string
}

# ---- Scaleway ----
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

variable "scaleway_region" {
  type    = string
  default = "fr-par"
}

variable "scaleway_zone" {
  type    = string
  default = "fr-par-1"
}

variable "vps_type" {
  type    = string
  default = "DEV1-S"
}

variable "vps_root_volume_size_gb" {
  type    = number
  default = 40
}

variable "ssh_public_key" {
  type = string
}

# ---- DB ----
variable "db_provider" {
  type    = string
  default = "scaleway"
}

variable "db_engine" {
  type    = string
  default = "postgresql"
}

variable "db_engine_version" {
  type    = string
  default = ""
}

variable "db_node_type" {
  type    = string
  default = "db-dev-s"
}

variable "db_volume_size_gb" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_user" {
  type    = string
  default = "appuser"
}

# ---- Cloudflare ----
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "subdomain" {
  type    = string
  default = ""
}

variable "extra_dns_records" {
  type = list(object({
    name    = string
    type    = string
    value   = string
    proxied = optional(bool, true)
  }))
  default = []
}

# ---- R2 ----
variable "r2_enabled" {
  type    = bool
  default = true
}

variable "r2_access_key_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "r2_secret_access_key" {
  type      = string
  sensitive = true
  default   = ""
}
