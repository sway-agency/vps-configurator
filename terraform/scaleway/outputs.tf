output "public_ipv4" {
  value       = scaleway_instance_server.vps.public_ip
  description = "IP publique IPv4 du VPS — à mettre dans ansible/inventory.yml"
}

output "public_ipv6" {
  value = scaleway_instance_server.vps.ipv6_address
}

output "ansible_inventory_snippet" {
  value = <<-EOT
    # Copie ce bloc dans ansible/inventory.yml
    all:
      hosts:
        vps:
          ansible_host: ${scaleway_instance_server.vps.public_ip}
          ansible_user: root
          ansible_port: 22
  EOT
}
