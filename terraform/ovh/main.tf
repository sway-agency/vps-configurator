terraform {
  required_version = ">= 1.5"
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.45"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# OVH Public Cloud = OpenStack sous le capot. On utilise le provider ovh pour
# créer les credentials, et openstack pour créer l'instance.
provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

data "ovh_cloud_project_user" "user" {
  service_name = var.ovh_service_name
  user_id      = var.ovh_openstack_user_id
}

provider "openstack" {
  auth_url    = "https://auth.cloud.ovh.net/v3/"
  domain_name = "default"
  user_name   = data.ovh_cloud_project_user.user.username
  password    = var.ovh_openstack_password
  tenant_id   = var.ovh_service_name
  region      = var.region
}

resource "openstack_compute_keypair_v2" "bootstrap" {
  name       = "${var.hostname}-bootstrap"
  public_key = var.ssh_public_key
}

data "openstack_images_image_v2" "debian" {
  name        = var.image_name
  most_recent = true
}

resource "openstack_compute_instance_v2" "vps" {
  name        = var.hostname
  image_id    = data.openstack_images_image_v2.debian.id
  flavor_name = var.flavor
  key_pair    = openstack_compute_keypair_v2.bootstrap.name

  network {
    name = "Ext-Net"
  }

  metadata = {
    managed-by = "terraform"
    role       = "vps-configurator"
  }
}
