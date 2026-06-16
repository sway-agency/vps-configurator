# Terraform — OVH Public Cloud

OVH Public Cloud expose une API OpenStack — on combine donc deux providers : `ovh` pour les credentials, `openstack` pour l'instance.

## Setup (préalable manuel)

1. **Créer un projet Public Cloud** dans le manager OVH.
2. **Créer un utilisateur OpenStack** dans le projet (Manager → Public Cloud → Project → Users & Roles → Create user). Note bien le `username` et le `password` (montré une seule fois).
3. **Créer des credentials API OVH** : https://eu.api.ovh.com/createToken/
   - Droits requis : `GET /cloud/*`, `POST /cloud/*`, `PUT /cloud/*`, `DELETE /cloud/*`.

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# édite tout : keys API OVH, user OpenStack, ssh key

terraform init
terraform plan
terraform apply
```

## Notes

- L'image officielle Debian 12 d'OVH crée un user `debian` (pas `root`). Le 1er run Ansible doit donc se faire en `debian` avec `become: true` :

  ```yaml
  ansible_user: debian
  ansible_become: true
  ```

- Après le 1er run Ansible : SSH passe sur `4242` en `deploy`.
- Le flavor par défaut `d2-2` est le moins cher (€~3/mois). Ajuste selon besoin.
