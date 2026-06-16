terraform {
  required_version = ">= 1.5"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
  }
}

provider "scaleway" {
  access_key      = var.scaleway_access_key
  secret_key      = var.scaleway_secret_key
  project_id      = var.scaleway_project_id
  organization_id = var.scaleway_organization_id
  zone            = var.zone
  region          = var.region
}

resource "scaleway_iam_ssh_key" "bootstrap" {
  name       = "${var.hostname}-bootstrap"
  public_key = var.ssh_public_key
}

resource "scaleway_instance_server" "vps" {
  name              = var.hostname
  type              = var.instance_type
  image             = var.image
  enable_ipv6       = true
  routed_ip_enabled = true

  root_volume {
    size_in_gb = var.root_volume_size_gb
    volume_type = "b_ssd"
  }

  tags = ["managed-by-terraform", "vps-configurator"]

  depends_on = [scaleway_iam_ssh_key.bootstrap]
}
