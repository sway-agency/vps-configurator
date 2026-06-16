# Terraform — Scaleway

Provisionne une `scaleway_instance_server` (Debian 12) prête pour Ansible.

## Setup

```bash
cp terraform.tfvars.example terraform.tfvars
# édite terraform.tfvars (API keys, project, ssh key)

terraform init
terraform plan
terraform apply
```

## Output

`terraform output public_ipv4` → l'IP à mettre dans `ansible/inventory.yml`.

## Notes

- Le serveur sort avec la clé SSH bootstrap → premier run Ansible en `root@<ip>:22`.
- Après le 1er run Ansible : SSH passe sur `4242`, root est désactivé.
- L'IP publique est facturée (`routed_ip_enabled = true`). Pour la libérer en `destroy`, le state suffit.
