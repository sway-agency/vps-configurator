# ============ Identité de l'env ============
variable "env_name" {
  type        = string
  description = "Nom court de l'env (prod, staging, dev, preprod, ...). Sert de prefix aux ressources et de groupe Ansible."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.env_name))
    error_message = "env_name doit faire 2-16 chars, lowercase, [a-z0-9-]."
  }
}

variable "project_slug" {
  type        = string
  description = "Slug du projet (ex: 'myapp'). Préfixe pour les noms de ressources globalement uniques (bucket R2, etc.)."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project_slug))
    error_message = "project_slug doit faire 2-31 chars, lowercase, [a-z0-9-]."
  }
}

# ============ Scaleway: VPS ============
variable "scaleway_zone" {
  type    = string
  default = "fr-par-1"
}

variable "scaleway_region" {
  type    = string
  default = "fr-par"
}

variable "scaleway_project_id" {
  type = string
}

variable "vps_type" {
  type        = string
  default     = "DEV1-S"
  description = "Type d'instance Scaleway. Voir scaleway.com/en/pricing/virtual-instances/"
}

variable "vps_image" {
  type    = string
  default = "debian_bookworm"
}

variable "vps_root_volume_size_gb" {
  type    = number
  default = 20
}

variable "ssh_public_key" {
  type        = string
  description = "Clé publique SSH bootstrap (Ansible swap ensuite vers le user `deploy`)."
}

# ============ Database ============
variable "db_provider" {
  type        = string
  default     = "scaleway"
  description = "'scaleway' (Managed DB) ou 'vps' (DB en docker sur le VPS — pas de ressource TF créée)."
  validation {
    condition     = contains(["scaleway", "vps"], var.db_provider)
    error_message = "db_provider doit être 'scaleway' ou 'vps'."
  }
}

variable "db_engine" {
  type        = string
  default     = "postgresql"
  description = "'postgresql' ou 'mariadb' (alias mysql)."
  validation {
    condition     = contains(["postgresql", "mariadb", "mysql"], var.db_engine)
    error_message = "db_engine doit être 'postgresql', 'mariadb' ou 'mysql'."
  }
}

variable "db_engine_version" {
  type        = string
  default     = ""
  description = "Version explicite (ex: '16' pour PG, '11' pour MariaDB). Vide = défaut Scaleway."
}

variable "db_node_type" {
  type        = string
  default     = "db-dev-s"
  description = "Type de nœud RDB Scaleway. db-dev-s = ~10€/mois. Voir scaleway.com/en/pricing/database/"
}

variable "db_volume_size_gb" {
  type    = number
  default = 10
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_user" {
  type    = string
  default = "appuser"
}

# ============ Cloudflare ============
variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID de la zone Cloudflare (visible dans le dashboard CF, à droite de la page Overview)."
}

variable "domain" {
  type        = string
  description = "Domaine apex (ex: 'example.com')."
}

variable "subdomain" {
  type        = string
  default     = ""
  description = "Sous-domaine de l'env (ex: 'staging' → staging.example.com). Vide = apex (uniquement pour prod)."
}

variable "extra_dns_records" {
  type = list(object({
    name = string
    type = string
    value = string
    proxied = optional(bool, true)
  }))
  default     = []
  description = "Records DNS additionnels à créer (ex: [{name='mail', type='MX', value='10 mx.example.com'}])."
}

# ============ Cloudflare R2 ============
variable "r2_enabled" {
  type    = bool
  default = true
}

variable "r2_access_key_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "S3-style access key id. À générer dans le dashboard CF (R2 → Manage R2 API Tokens). Cloudflare ne permet pas (encore) de la créer via TF."
}

variable "r2_secret_access_key" {
  type      = string
  default   = ""
  sensitive = true
}

# ============ Output Ansible ============
variable "ansible_dir" {
  type        = string
  description = "Chemin absolu vers le dossier `ansible/` (où écrire inventories/<env>.yml). Ex: ../../../../ansible"
  default     = "../../../../ansible"
}
