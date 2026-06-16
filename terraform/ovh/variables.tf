variable "ovh_application_key" {
  type      = string
  sensitive = true
}

variable "ovh_application_secret" {
  type      = string
  sensitive = true
}

variable "ovh_consumer_key" {
  type      = string
  sensitive = true
}

variable "ovh_service_name" {
  type        = string
  description = "ID du projet Public Cloud OVH (UUID)."
}

variable "ovh_openstack_user_id" {
  type        = string
  description = "ID de l'utilisateur OpenStack créé dans le projet (voir manager OVH)."
}

variable "ovh_openstack_password" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "GRA11"
}

variable "hostname" {
  type    = string
  default = "vps-prod"
}

# Flavors : voir `openstack flavor list` ou doc OVH (b3-8, s1-2, d2-2, ...)
variable "flavor" {
  type    = string
  default = "d2-2"
}

variable "image_name" {
  type    = string
  default = "Debian 12"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for the initial root login (Ansible will swap to deploy user)."
}
