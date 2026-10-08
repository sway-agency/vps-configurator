terraform {
  required_version = ">= 1.5"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }

  # Backend local par défaut (tfstate dans le dir). Pour du sérieux, passer sur
  # un backend distant (S3, Terraform Cloud, etc.) — voir README.
  # backend "s3" { ... }
}

provider "scaleway" {
  access_key      = var.scaleway_access_key
  secret_key      = var.scaleway_secret_key
  project_id      = var.scaleway_project_id
  organization_id = var.scaleway_organization_id
  zone            = var.scaleway_zone
  region          = var.scaleway_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

module "env" {
  source = "../../modules/env"

  env_name     = var.env_name
  project_slug = var.project_slug

  # Scaleway
  scaleway_project_id     = var.scaleway_project_id
  scaleway_region         = var.scaleway_region
  scaleway_zone           = var.scaleway_zone
  vps_type                = var.vps_type
  vps_root_volume_size_gb = var.vps_root_volume_size_gb
  ssh_public_key          = var.ssh_public_key

  # DB
  db_provider       = var.db_provider
  db_engine         = var.db_engine
  db_engine_version = var.db_engine_version
  db_node_type      = var.db_node_type
  db_volume_size_gb = var.db_volume_size_gb
  db_name           = var.db_name
  db_user           = var.db_user

  # Cloudflare
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  domain                = var.domain
  subdomain             = var.subdomain
  extra_dns_records     = var.extra_dns_records

  # R2
  r2_enabled           = var.r2_enabled
  r2_access_key_id     = var.r2_access_key_id
  r2_secret_access_key = var.r2_secret_access_key

  ansible_dir = "${path.module}/../../../../ansible"
}
