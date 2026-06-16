# Terraform — Scaleway (multi-env)

Provisionne par env : 1 VPS Scaleway + (optionnellement) 1 DB managée + bucket Cloudflare R2 + records DNS Cloudflare. Génère l'inventory Ansible automatiquement.

## Layout

```
scaleway/
├── modules/env/        # module réutilisable (VPS + DB + R2 + CF DNS + inventory Ansible)
└── envs/
    ├── prod/           # tfstate prod
    └── dev/            # tfstate dev (renomme librement : staging, preprod, qa, ...)
```

## Ajouter un env

Pour staging par exemple :

```bash
cp -r envs/dev envs/staging
cd envs/staging
# édite terraform.tfvars : env_name="staging", subdomain="staging"
terraform init
terraform apply
```

Chaque dir a son **propre tfstate** (isolé des autres envs).

## Workflow par env

```bash
cd envs/prod                 # ou envs/dev, etc.
cp terraform.tfvars.example terraform.tfvars
# édite tfvars : credentials Scaleway, Cloudflare, ssh key, R2 keys, ...

terraform init
terraform plan
terraform apply

# → écrit ../../../../ansible/inventories/<env_name>.yml automatiquement

cd ../../../../ansible
ansible-playbook -i inventories/<env_name>.yml playbook.yml
```

## Choix DB

`db_provider` :
- `scaleway` → Managed DB Scaleway. ACL n'autorise que l'IP du VPS. iptables ouvre l'egress vers cet endpoint.
- `vps` → la DB tournera dans docker-compose sur le VPS (à inclure dans ton repo `/var/www/<stack>`). Terraform génère juste le password (passé à Ansible → `/var/www/.env`).

`db_engine` : `postgresql` ou `mariadb`.

## Cloudflare R2 (S3)

Le bucket est créé par Terraform (`cloudflare_r2_bucket`). Les **access keys S3-style** (compatibles AWS SDK / Traefik / la plupart des libs S3) ne sont pas exposées par le provider Terraform — il faut les générer manuellement dans le dashboard CF :

1. Dashboard CF → R2 → **Manage R2 API Tokens** → Create API token
2. Permission : "Object Read & Write" sur le bucket cible
3. Copie l'`Access Key ID` + `Secret Access Key`
4. Colle-les dans `terraform.tfvars` (`r2_access_key_id`, `r2_secret_access_key`)
5. `terraform apply` → ces credentials sont écrites dans `/var/www/.env` via Ansible

## DNS

Pour chaque env, Terraform crée deux records A proxifiés :
- `<subdomain>.<domain>` → IP VPS (apex si `subdomain=""`)
- `*.<subdomain>.<domain>` → IP VPS (pour les routes Traefik : `api.prod`, `app.prod`, ...)

Ajoute MX/TXT/CAA via `extra_dns_records` dans le tfvars.

## Backend tfstate

Par défaut : tfstate local (dans le dir). Pour un usage sérieux, configure un backend distant (S3, Terraform Cloud, ...) — décommente le bloc `backend` dans `main.tf`.

## Destroy

```bash
cd envs/<env>
terraform destroy
```

⚠️ Détruit aussi le bucket R2 (les objets dedans sont perdus). Sauvegarde avant.
