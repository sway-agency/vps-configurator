output "vps_public_ip" {
  value = scaleway_instance_server.vps.public_ip
}

output "vps_ipv6" {
  value = scaleway_instance_server.vps.ipv6_address
}

output "domain_full" {
  value = local.domain_full
}

output "db_host" {
  value     = local.db_host
  sensitive = false
}

output "db_port" {
  value = local.db_port_effective
}

output "db_password" {
  value     = local.db_password
  sensitive = true
}

output "database_url" {
  value     = local.database_url
  sensitive = true
}

output "r2_bucket" {
  value = var.r2_enabled ? local.r2_bucket : null
}

output "r2_endpoint" {
  value = var.r2_enabled ? local.r2_endpoint : null
}

output "ansible_inventory_path" {
  value       = local_sensitive_file.ansible_inventory.filename
  description = "Chemin du fichier d'inventory Ansible généré."
}

output "next_steps" {
  value = <<-EOT

    ✓ Env ${var.env_name} provisionnée.
    ✓ Inventory Ansible écrit : ${local_sensitive_file.ansible_inventory.filename}

    Prochaines étapes :
      cd ../../../../ansible
      ansible-galaxy collection install -r requirements.yml   # (1 fois)
      cp group_vars/all.example.yml group_vars/all.yml        # (1 fois) puis édite ssh_public_key

      # 1er run (bootstrap) — override user/port en CLI :
      ansible-playbook -i inventories/${var.env_name}.yml playbook.yml \
        -e ansible_user=root -e ansible_port=22

      # Runs suivants : l'inventory pointe déjà sur deploy@4242, aucun override
      ansible-playbook -i inventories/${var.env_name}.yml playbook.yml
  EOT
}
