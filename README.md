# vps-configurator

Hardening minimal d'un VPS Debian 12 / Ubuntu 22.04+ pour héberger des stacks Docker (Traefik + apps).

## Ce que ça fait

- Utilisateur `deploy` avec sudo NOPASSWD, clé SSH only
- Root SSH désactivé, password auth désactivée
- SSH sur port **4242**
- `endlessh` (tarpit honeypot) sur port 22
- Firewall **iptables** :
  - IN : 4242 (SSH), 22 (honeypot), `lo`, `ESTABLISHED,RELATED`, ICMP
  - OUT : 80, 443 (HTTP/S), 53 (DNS), 123 (NTP), `lo`, `ESTABLISHED,RELATED`, ICMP
  - Tout le reste DROP
- Docker CE depuis le repo officiel
- `/var/www` créé (vide, pas de nginx)
- Crons quotidiens : `unattended-upgrades` (sécurité APT + auto-reboot) + update Docker engine + `docker image pull` des images en cours

> DNS (53) et NTP (123) sont ouverts en sortie car sans ça, `apt` et `docker pull` ne fonctionnent pas. Si tu veux les retirer, configure un DNS over HTTPS et désactive NTP côté systemd.

## Structure

```
.
├── ansible/                  # Configuration (cœur)
│   ├── playbook.yml
│   ├── inventory.example.yml
│   ├── group_vars/all.yml.example
│   └── tasks/                # Tasks atomiques (base, user, ssh, firewall, ...)
└── terraform/
    ├── scaleway/             # Provisionne un Instance Scaleway
    ├── ovh/                  # Provisionne un Public Cloud Instance OVH
    └── hostinger/            # Pas de provider TF → instructions manuelles
```

## Usage

### 1. Provisionner le VPS

**Scaleway** ou **OVH** : voir `terraform/<provider>/README.md`. Récupère l'IP en output.

**Hostinger** : créer le VPS manuellement depuis le panel (template Debian 12), récupérer l'IP.

### 2. Configurer le VPS avec Ansible

```bash
cd ansible
cp inventory.example.yml inventory.yml
cp group_vars/all.yml.example group_vars/all.yml
# Édite inventory.yml (IP) et group_vars/all.yml (ssh_public_key, deploy_user, ...)

ansible-playbook -i inventory.yml playbook.yml
```

Le premier run se fait en `root` (clé SSH du provider). Les runs suivants se font en `deploy` sur le port 4242 (mets à jour `inventory.yml` après le 1er run — commenté dedans).

### 3. Déployer ta stack

Sur le VPS :
```bash
ssh -p 4242 deploy@<IP>
cd /var/www
git clone <ton-repo-traefik-db-apps>
docker compose up -d
```

## Prérequis local

- `ansible` ≥ 2.14
- `terraform` ≥ 1.5 (si tu utilises les modules TF)
- Une paire de clés SSH (`ssh-keygen -t ed25519`)

## OS supportés

- Debian 12 (Bookworm) — **recommandé**
- Ubuntu 22.04 / 24.04
