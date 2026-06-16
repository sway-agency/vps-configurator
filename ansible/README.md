# Ansible — Configuration des VPS

Guide pratique pour lancer Ansible et configurer un VPS (Scaleway, OVH, Hostinger, ou n'importe quel Debian/Ubuntu) avec le hardening de ce repo.

---

## Sommaire

1. [Prérequis](#prérequis)
2. [Setup initial (1 fois par machine locale)](#setup-initial-1-fois-par-machine-locale)
3. [Workflow par env](#workflow-par-env)
4. [Inventory : avec ou sans Terraform](#inventory--avec-ou-sans-terraform)
5. [1er run : bootstrap → 2ème run : deploy](#1er-run--bootstrap--2ème-run--deploy)
6. [Lancer le playbook complet ou par tags](#lancer-le-playbook-complet-ou-par-tags)
7. [Vérifier que tout marche](#vérifier-que-tout-marche)
8. [Mettre à jour la conf d'un VPS](#mettre-à-jour-la-conf-dun-vps)
9. [Troubleshooting](#troubleshooting)

---

## Prérequis

### Sur ta machine locale

- **Ansible** ≥ 2.14 :
  ```bash
  # macOS
  brew install ansible

  # Linux (Debian/Ubuntu)
  sudo apt install ansible
  ```
- **Une paire de clés SSH** (Ed25519 recommandé) :
  ```bash
  ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "vps-admin"
  ```

### Sur le VPS

Le VPS doit être :
- **Debian 12 (Bookworm)** ou **Ubuntu 22.04+**
- Accessible en SSH sur le **port 22 en tant que `root`** (ou un user `sudoer` selon le provider — cf. tableau ci-dessous)
- Avec ta clé publique SSH déjà déployée (par le panel du provider ou par Terraform)

| Provider | User par défaut | Port | Comment provisionner |
|---|---|---|---|
| Scaleway (TF) | `root` | 22 | `cd terraform/scaleway/envs/<env> && terraform apply` |
| OVH (TF) | `debian` | 22 | `cd terraform/ovh && terraform apply` (ajouter `ansible_become: true`) |
| Hostinger | `root` | 22 | Manuel via hpanel — voir `terraform/hostinger/README.md` |

---

## Setup initial (1 fois par machine locale)

```bash
cd ansible

# Installe les collections Ansible requises
ansible-galaxy collection install -r requirements.yml

# Copie le fichier de vars globales et édite ta clé SSH publique
cp group_vars/all.example.yml group_vars/all.yml
$EDITOR group_vars/all.yml      # remplace ssh_public_key par TA clé publique
```

À éditer dans `group_vars/all.yml` :
- `ssh_public_key` — **obligatoire** (ta clé publique locale)
- `deploy_user`, `ssh_port`, `honeypot_port` — laisse les defaults sauf besoin spécifique
- `system_timezone` — défaut `Europe/Paris`

---

## Workflow par env

### Cas A : tu utilises Terraform (Scaleway)

```bash
cd ../terraform/scaleway/envs/prod
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars          # credentials Scaleway + Cloudflare + ssh key + ...
terraform init
terraform apply
# → écrit ../../../../ansible/inventories/prod.yml automatiquement
```

Puis tu reviens dans `ansible/` et tu sautes à [Lancer le playbook](#lancer-le-playbook-complet-ou-par-tags).

### Cas B : VPS déjà provisionné manuellement (Hostinger, OVH-Manager, autre)

Tu dois créer l'inventory à la main. Crée un fichier `inventories/<env>.yml` (le nom du fichier = nom de l'env) :

```yaml
prod:                            # nom du groupe = nom de l'env
  hosts:
    vps:
      ansible_host: 1.2.3.4      # IP publique du VPS
      ansible_user: root         # ou "debian" / "ubuntu" selon le provider
      ansible_port: 22
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      # ansible_become: true     # à activer si l'user de bootstrap n'est pas root (ex: OVH debian)
  vars:
    env_name: prod
    domain_full: prod.example.com
    # OPTIONNEL : si tu as une DB managée hors VPS
    # db_egress_host: 5.6.7.8
    # db_egress_port: 5432
    # OPTIONNEL : variables injectées dans /var/www/.env
    # app_env:
    #   ENV_NAME: prod
    #   DATABASE_URL: "postgres://app:xxx@5.6.7.8:5432/app?sslmode=require"
    #   AWS_ACCESS_KEY_ID: xxx
    #   AWS_SECRET_ACCESS_KEY: xxx
```

> Le fichier `inventories/example.example.yml` documente la structure complète.

---

## 1er run : bootstrap → runs suivants

L'inventory généré par Terraform pointe **toujours** sur l'état stationnaire (`deploy@4242`). Le 1er run (bootstrap) override en CLI ; les runs suivants n'ont rien à toucher.

Le playbook fait un **flip de la connexion SSH au milieu de son exécution** :
- Avant : SSH écoute sur `22` et accepte `root` (état initial du provider)
- Après : SSH écoute sur `4242`, accepte uniquement l'user `deploy` avec clé SSH

### Premier run (bootstrap — override CLI)

```bash
cd ansible
ansible-playbook -i inventories/prod.yml playbook.yml \
  -e ansible_user=root -e ansible_port=22 -e ansible_become=false
```

Le playbook :
1. **Pre-flight** : assert que `ssh_public_key` est bien formée (regex), sinon abort sans toucher au VPS
2. Crée l'user `deploy` + colle ta clé SSH (`exclusive: true` → la clé écrase tout authorized_keys existant)
3. Écrit `/etc/ssh/sshd_config.d/00-hardening.conf` avec `validate: sshd -t` (refuse si syntaxe KO)
4. **Restart sshd EXPLICITE** dans `tasks/ssh.yml` (plus dans un handler en fin de play)
5. **Smoke-test depuis localhost** : `wait_for port 4242` puis `ssh deploy@<IP> -p 4242 true`. Si KO → playbook fail AVANT iptables → port 22 root toujours accessible pour debug
6. **Bascule de connexion** : `set_fact` ansible_user/ansible_port → `meta: reset_connection` → le reste du play tourne sur deploy@4242
7. Installe Docker, endlessh, unattended-upgrades, etc.
8. **Backup iptables avant apply** (`iptables-save > /root/.iptables.rollback.v4`)
9. Applique iptables (`validate: iptables-restore --test` + DROP policy)
10. **Post-apply check** : `wait_for port 4242` depuis localhost. Si KO → rollback auto depuis le backup via la session SSH active (gardée vivante par `ESTABLISHED,RELATED`) + fail loud

### Filets de sécurité (anti-lockout)

| Étape | Si ça foire | Conséquence |
|---|---|---|
| pre-flight clé SSH | regex KO | Abort, VPS intact |
| sshd_config syntaxe | `sshd -t` rejette | Drop-in pas écrit, sshd inchangé |
| Smoke-test deploy@4242 | KO (clé pas posée, etc.) | Playbook abort. Port 22 root@22 encore OK pour reconnecter |
| iptables-restore --test | syntaxe KO | Rules pas appliquées, ancien firewall actif |
| Post-apply check | wait_for KO | **Rollback auto** depuis backup, fail loud |
| Session SSH ansible | doit survivre au restart sshd | `KillMode=process` Debian/Ubuntu + `ControlPersist=600s` |

### Runs suivants (idempotents)

```bash
ansible-playbook -i inventories/prod.yml playbook.yml
```

Ansible détecte ce qui est déjà OK et ne refait que ce qui change.

---

## Lancer le playbook complet ou par tags

### Tout le playbook

```bash
ansible-playbook -i inventories/prod.yml playbook.yml
```

### Une seule tâche (par tag)

```bash
# Met à jour uniquement la conf SSH
ansible-playbook -i inventories/prod.yml playbook.yml --tags ssh

# Refait juste le firewall
ansible-playbook -i inventories/prod.yml playbook.yml --tags firewall

# Re-pousse uniquement le /var/www/.env (après changement de tfvars + apply)
ansible-playbook -i inventories/prod.yml playbook.yml --tags app_env
```

Tags disponibles : `base`, `user`, `ssh`, `honeypot`, `docker`, `www`, `app_env`, `updates`, `firewall`.

### Mode dry-run (vérifier sans appliquer)

```bash
ansible-playbook -i inventories/prod.yml playbook.yml --check --diff
```

### Limiter à un host (si plusieurs)

```bash
ansible-playbook -i inventories/prod.yml playbook.yml --limit vps
```

### Verbosité (debug)

```bash
ansible-playbook -i inventories/prod.yml playbook.yml -vv
```

---

## Vérifier que tout marche

Après le 1er run réussi, vérifie depuis ta machine locale :

```bash
# 1. SSH sur le nouveau port en deploy (doit marcher)
ssh -p 4242 deploy@<IP>

# 2. Root SSH (doit être refusé)
ssh root@<IP>             # Connection refused (port 22 fermé sauf honeypot)
ssh -p 4242 root@<IP>     # Permission denied (root disabled)

# 3. Honeypot endlessh (doit tarpit — la commande va bloquer indéfiniment)
ssh -p 22 root@<IP>       # ssh dit "kex_protocol_error" après ~10s

# 4. iptables (sur le VPS)
ssh -p 4242 deploy@<IP> 'sudo iptables -L -n -v'

# 5. Docker
ssh -p 4242 deploy@<IP> 'docker version && docker compose version'

# 6. /var/www/.env (si tu as configuré app_env)
ssh -p 4242 deploy@<IP> 'sudo cat /var/www/.env'

# 7. Cron docker daily update
ssh -p 4242 deploy@<IP> 'sudo crontab -l && ls /usr/local/sbin/docker-daily-update'

# 8. unattended-upgrades
ssh -p 4242 deploy@<IP> 'sudo systemctl status apt-daily-upgrade.timer'
```

---

## Mettre à jour la conf d'un VPS

### Changer ssh_port, ports IN, etc.

1. Édite `group_vars/all.yml`
2. Re-applique : `ansible-playbook -i inventories/<env>.yml playbook.yml`
3. Si tu changes `ssh_port`, n'oublie pas de mettre à jour `inventories/<env>.yml` (`ansible_port`) pour les runs suivants.

### Ajouter un nouveau VPS dans un env existant

Édite l'inventory pour ajouter un host :

```yaml
prod:
  hosts:
    vps:    { ansible_host: 1.2.3.4, ... }
    vps-2:  { ansible_host: 5.6.7.8, ... }    # ← nouveau
  vars: { ... }
```

Puis `ansible-playbook -i inventories/prod.yml playbook.yml --limit vps-2`.

### Mettre à jour le `/var/www/.env` (après changement de creds DB / R2)

Si tu utilises Terraform :
```bash
cd terraform/scaleway/envs/prod
# édite tfvars
terraform apply                   # met à jour inventories/prod.yml
cd ../../../../ansible
ansible-playbook -i inventories/prod.yml playbook.yml --tags app_env
```

Sans Terraform : édite directement `inventories/<env>.yml` (vars → `app_env`), puis `--tags app_env`.

> Le fichier `.env` est rendu avec `mode 0600` (lecture par `deploy` uniquement). Ton `docker-compose.yml` doit le référencer via `env_file: ../.env` (depuis `/var/www/<stack>/`).

### Forcer un redémarrage Docker après mise à jour

```bash
ansible-playbook -i inventories/prod.yml playbook.yml --tags docker
```

---

## Troubleshooting

### `Permission denied (publickey)` au premier run

- Vérifie que la clé privée référencée dans l'inventory existe : `ls -l ~/.ssh/id_ed25519`
- Vérifie que la clé publique est bien sur le VPS (`ssh root@<IP> 'cat ~/.ssh/authorized_keys'`). Si ce n'est pas le cas, ajoute-la via le panel provider OU re-run `terraform apply`.
- Test direct : `ssh -i ~/.ssh/id_ed25519 -p 22 root@<IP>`. Si ça échoue ici, le pb est côté provider, pas Ansible.

### Le playbook abort sur "Smoke-test deploy@4242"

C'est le filet de sécurité : la nouvelle connexion ne marche pas, donc on n'a PAS touché iptables et **ton accès root@22 est toujours OK**.

Causes typiques :
1. **Clé SSH mal posée** : `ssh root@<IP> 'cat /home/deploy/.ssh/authorized_keys'` — doit contenir ta clé publique
2. **sshd écoute pas sur 4242** : `ssh root@<IP> 'sudo ss -tlnp | grep :4242'`
3. **Permission denied (publickey)** : compare l'empreinte de ta clé locale (`ssh-keygen -lf ~/.ssh/id_ed25519.pub`) à celle dans `authorized_keys`

Corrige puis relance le playbook avec les overrides bootstrap :
```bash
ansible-playbook -i inventories/prod.yml playbook.yml \
  -e ansible_user=root -e ansible_port=22 -e ansible_become=false
```

### "ROLLBACK iptables (SSH unreachable after apply)"

Le filet de sécurité de `firewall.yml` a détecté que SSH ne répond plus après application des règles, et a restauré les anciennes via la session active. Tu n'es pas locked out.

Diagnostique avant de relancer :
```bash
ssh -p 4242 deploy@<IP> 'sudo iptables -L -n -v | head -40'
```

Vérifie le template `ansible/templates/iptables-rules.v4.j2` et tes variables (`ssh_port`, `extra_in_tcp_ports`...).

### Lockout total (cas extrême — ne devrait pas arriver avec les filets ci-dessus)

Si malgré tout tu es bloqué (clé locale perdue après run, iptables corrompu manuellement, etc.), connecte-toi via la console **KVM/web** du provider (Scaleway, Hostinger, OVH), puis :

```bash
# Sur le VPS, en console KVM
sudo iptables -F                                       # flush IPv4
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo ip6tables -F                                      # flush IPv6
sudo ip6tables -P INPUT ACCEPT
sudo ip6tables -P OUTPUT ACCEPT
sudo systemctl restart ssh
# Vérifie l'authorized_keys de deploy ; ajoute une clé de secours si besoin
sudo -u deploy bash -c 'echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys'
```

Puis depuis local : `ansible-playbook ... --tags firewall` pour ré-appliquer.

### `iptables: command not found` sur le VPS

Image trop minimale. La task `firewall.yml` installe `iptables` mais si l'install échoue, vérifie l'accès internet du VPS (le 1er run a besoin d'`apt update`).

### `endlessh: failed to bind: Address already in use`

Un autre service (souvent `sshd` lui-même) écoute sur le port 22. Vérifie qu'`sshd` est bien sur 4242 :
```bash
sudo ss -tlnp | grep -E ':22|:4242'
```
Si sshd écoute encore sur 22, vérifie `/etc/ssh/sshd_config.d/00-hardening.conf` et `systemctl restart ssh`.

### Le cron `docker-daily-update` ne tourne pas

```bash
sudo cat /var/log/docker-daily-update.log
sudo grep docker-daily /var/log/syslog
```

S'il ne s'exécute pas, vérifie que le cron est bien là : `sudo crontab -l`.

### Comment voir les logs Ansible côté serveur ?

Ansible n'écrit pas de logs persistants par défaut. Pour activer côté local :
```bash
echo 'log_path = ./ansible.log' >> ansible.cfg
```

---

## Reset complet (réinstaller from scratch)

Si tu veux repartir d'un VPS vierge :

```bash
# Avec Terraform (le plus simple)
cd terraform/scaleway/envs/prod
terraform destroy
terraform apply

# Sans Terraform : reset l'image dans le panel provider, récupère la nouvelle IP,
# édite inventories/prod.yml, relance le playbook depuis le 1er run.
```
