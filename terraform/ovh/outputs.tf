output "public_ipv4" {
  value       = openstack_compute_instance_v2.vps.access_ip_v4
  description = "IP publique IPv4 du VPS — à mettre dans ansible/inventory.yml"
}

output "ansible_inventory_snippet" {
  value = <<-EOT
    # Copie ce bloc dans ansible/inventory.yml
    all:
      hosts:
        vps:
          ansible_host: ${openstack_compute_instance_v2.vps.access_ip_v4}
          ansible_user: debian
          ansible_port: 22
  EOT
}
