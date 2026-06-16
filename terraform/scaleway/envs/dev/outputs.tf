output "vps_public_ip" {
  value = module.env.vps_public_ip
}

output "domain_full" {
  value = module.env.domain_full
}

output "ansible_inventory_path" {
  value = module.env.ansible_inventory_path
}

output "next_steps" {
  value = module.env.next_steps
}

output "db_password" {
  value     = module.env.db_password
  sensitive = true
}

output "database_url" {
  value     = module.env.database_url
  sensitive = true
}

output "r2_bucket" {
  value = module.env.r2_bucket
}

output "r2_endpoint" {
  value = module.env.r2_endpoint
}
