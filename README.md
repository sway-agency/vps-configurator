# vps-configurator

Hardening + provisionnement multi-env d'un VPS Debian 12 / Ubuntu 22.04+ pour héberger des stacks Docker (Traefik + apps).

## Stack

- **Terraform** : provisionne par env (Scaleway VPS + DB managée + bucket Cloudflare R2 + DNS Cloudflare). Génère automatiquement l'inventory Ansible.
- **Ansible** : hardening du VPS (firewall, SSH 4242, honeypot, Docker, crons, `/var/www/.env`).
- **Cloud bridge** : Terraform écrit `ansible/inventories/<env>.yml` avec secrets ; Ansible écrit `/var/www/.env` sur le VPS pour ton docker-compose.

## Ce que ça fait

### Sur le VPS (Ansible)
- Utilisateur `deploy` avec sudo NOPASSWD, clé SSH only — root SSH désactivé
- SSH sur port **4242**, `endlessh` (honeypot) sur port 22
- Firewall **iptables** :
  - IN : 4242 (SSH), 22 (honeypot), 80/443 (Traefik), `lo`, `ESTABLISHED,RELATED`, ICMP
  - OUT : 80/443 (HTTP/S), 53 (DNS), 123 (NTP), + DB egress restreint à l'IP+port de la DB managée
  - Tout le reste DROP
- Docker CE + daemon hardened (log rotation, `no-new-privileges`)
- `/var/www` (owned by `deploy`) — c'est là que tu clones ton repo docker-compose
- `/var/www/.env` écrit avec `DATABASE_URL`, `S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, ... (mode 0600)
- Crons quotidiens : `unattended-upgrades` (sécurité APT + auto-reboot) + update Docker engine + `docker image pull` des images en cours

### Côté infra (Terraform)
- **Scaleway** : VPS Instance + (optionnel) Managed DB (PostgreSQL/MariaDB) avec ACL whitelist VPS
- **Cloudflare** : record A pour `<env>.<domain>` + wildcard `*.<env>.<domain>` (proxified) + records extras (MX/TXT/CAA)
- **Cloudflare R2** : bucket S3-compatible (les access keys S3-style se créent manuellement dans le dashboard CF — voir `terraform/scaleway/README.md`)
- Pour Hostinger/OVH : provisionnement manuel ou via les modules `terraform/ovh/`, `terraform/hostinger/`

## Structure

```
.
├── ansible/
│   ├── playbook.yml
│   ├── ansible.cfg
│   ├── inventories/                # généré par Terraform (gitignored sauf example)
│   │   └── example.example.yml
│   ├── group_vars/
│   │   └── all.example.yml         # copie en all.yml (clé SSH, ports, ...)
│   ├── tasks/                      # base, user, ssh, firewall, honeypot, docker, www, app_env, auto_updates
│   ├── templates/                  # iptables-rules.v4.j2, app.env.j2, ...
│   ├── files/                      # docker-daily-update.sh
│   └── handlers/main.yml
└── terraform/
    ├── scaleway/
    │   ├── modules/env/            # module : VPS + DB + R2 + DNS + inventory
    │   └── envs/
    │       ├── prod/               # tfstate prod
    │       └── dev/                # tfstate dev (renommable : staging, preprod, ...)
    ├── ovh/                        # alternative OVH (single-env, à adapter si multi-env)
    └── hostinger/                  # pas de provider TF → manuel
```

## Workflow complet

### 0. Prérequis (1 fois)

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
cp group_vars/all.example.yml group_vars/all.yml
# Édite group_vars/all.yml — surtout `ssh_public_key` (ta clé locale)
```

### 1. Provisionner l'infra (par env)

```bash
cd terraform/scaleway/envs/prod
cp terraform.tfvars.example terraform.tfvars
# Édite : credentials Scaleway, Cloudflare, ssh key, R2 keys, domaine, ...

terraform init
terraform apply
# → écrit ../../../../ansible/inventories/prod.yml automatiquement
```

### 2. Configurer le VPS

```bash
cd ../../../../ansible
ansible-playbook -i inventories/prod.yml playbook.yml
```

Le 1er run se fait en `root@22` (clé SSH du provider). Après succès, édite l'inventory généré : passe à `ansible_user: deploy` + `ansible_port: 4242` pour les runs suivants.

### 3. Déployer ta stack Docker

Sur le VPS (`ssh -p 4242 deploy@<IP>`) :

```bash
cd /var/www
git clone <ton-repo-traefik-db-apps> stack
cd stack
# ton docker-compose.yml référence /var/www/.env (env_file: ../.env)
docker compose up -d
```

### Ajouter un env (ex: staging)

```bash
cd terraform/scaleway/envs
cp -r dev staging
cd staging
# Édite terraform.tfvars : env_name="staging", subdomain="staging"
terraform init
terraform apply
cd ../../../../ansible
ansible-playbook -i inventories/staging.yml playbook.yml
```

## Variables d'environnement disponibles dans /var/www/.env

Selon ce qui est activé dans Terraform :

| Variable | Origine | Toujours présent |
|---|---|---|
| `ENV_NAME` | env_name TF | oui |
| `DOMAIN` | `<sub>.<domain>` | oui |
| `DATABASE_URL` | construit selon db_engine | oui |
| `DB_HOST` / `DB_PORT` / `DB_USER` / `DB_PASSWORD` / `DB_NAME` / `DB_ENGINE` | DB TF (managée ou docker) | oui |
| `S3_ENDPOINT` / `S3_BUCKET` / `S3_REGION` | bucket R2 | si `r2_enabled=true` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | tfvars (manuel) | si `r2_enabled=true` |

## Notes sécurité

- **80/443 ouverts IN à tous** (origine non cachée). Si tu veux durcir, considère Cloudflare Tunnels — il faudra `cloudflared` sur le VPS.
- **DNS (53)** et **NTP (123)** sont ouverts en egress — sinon `apt`/`docker pull`/TLS sont morts.
- **R2 access keys** sont en clair dans `terraform.tfvars` (gitignored) et le state. Considère un backend tfstate chiffré (S3+KMS, TFC).
- Les secrets DB sont générés par `random_password` (32 chars). Pour les voir : `terraform output -raw db_password`.

## OS supportés

- Debian 12 (Bookworm) — **recommandé**
- Ubuntu 22.04 / 24.04
