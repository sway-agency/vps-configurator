<p align="center">
  <a href="https://github.com/sway-agency/vps-configurator">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset=".github/assets/sway-logo-white.svg">
      <img src=".github/assets/sway-logo-black.svg" alt="Sway" width="220">
    </picture>
  </a>
</p>

<h1 align="center">VPS Configurator: harden and provision a Docker VPS with Ansible and Terraform</h1>

<p align="center">
  Production-ready <strong>VPS hardening</strong> for <strong>Debian 12</strong> and <strong>Ubuntu 22.04 / 24.04</strong>, built for Docker and Traefik stacks.<br>
  Firewall, SSH lockdown, honeypot, automatic security updates and audits in one playbook, with multi-environment infrastructure as code.
</p>

<p align="center">
  <a href="https://github.com/sway-agency/vps-configurator/actions/workflows/ci.yml"><img src="https://github.com/sway-agency/vps-configurator/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/sway-agency/vps-configurator/actions/workflows/security.yml"><img src="https://github.com/sway-agency/vps-configurator/actions/workflows/security.yml/badge.svg" alt="Security"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-blue.svg" alt="MIT licence"></a>
  <img src="https://img.shields.io/badge/Ansible-production%20profile-ee0000.svg" alt="Ansible lint production profile">
  <img src="https://img.shields.io/badge/Terraform-%E2%89%A5%201.5-7b42bc.svg" alt="Terraform 1.5 and newer">
  <img src="https://img.shields.io/badge/Debian%2012%20%7C%20Ubuntu%2022.04%2B-supported-a81d33.svg" alt="Debian 12 and Ubuntu 22.04 and newer">
</p>

## Why VPS Configurator?

A fresh VPS is exposed to brute force bots within minutes. Securing it by hand is slow, easy to get wrong and impossible to repeat across environments. VPS Configurator turns a blank Debian or Ubuntu server into a locked down Docker host in a single command, the same way every time:

- **Secure by default.** Default deny firewall in and out, SSH keys only on a custom port, root login disabled, an SSH tarpit on port 22.
- **Lockout safe.** The SSH public key is validated before anything changes, the new SSH login is smoke tested before the old one is closed, and the firewall is applied last.
- **Self maintaining.** Daily security patches with automatic reboot, daily Docker engine and image updates, weekly CVE, rootkit and system audits.
- **Multi environment.** Terraform provisions one VPS, database, S3 bucket and DNS per environment (prod, staging, dev) and writes the matching Ansible inventory for you.
- **Ready for your stack.** `/var/www/.env` is generated with `DATABASE_URL`, S3 credentials and domain, so `docker compose up` just works.

## Stack

- **Terraform** provisions each environment: Scaleway VPS, optional managed database, Cloudflare R2 bucket and Cloudflare DNS. It writes the Ansible inventory automatically.
- **Ansible** hardens the VPS: firewall, SSH on 4242, honeypot, Docker, cron jobs, `/var/www/.env`.
- **Cloud bridge**: Terraform writes `ansible/inventories/<env>.yml` with the secrets, then Ansible writes `/var/www/.env` on the VPS for your Docker Compose stack.

```text
terraform apply ──► ansible/inventories/<env>.yml ──► ansible-playbook ──► /var/www/.env ──► docker compose up
```

## What it does

### On the VPS (Ansible)

- `deploy` user with passwordless sudo and SSH key only login, root SSH disabled
- SSH on port **4242**, [endlessh](https://github.com/skeeto/endlessh) honeypot on port 22
- **iptables** firewall for IPv4 and IPv6:
  - IN: 4242 (SSH), 22 (honeypot), 80 and 443 (Traefik), `lo`, `ESTABLISHED,RELATED`, ICMP
  - OUT: 80 and 443 (HTTP and HTTPS), 53 (DNS), 123 (NTP), plus database egress restricted to the managed database IP and port
  - everything else is dropped
- **Docker CE** with a hardened daemon: log rotation, `no-new-privileges`, `live-restore`, no userland proxy
- `/var/www` owned by `deploy`: clone your Docker Compose repository there
- `/var/www/.env` written with `DATABASE_URL`, `S3_ENDPOINT`, `AWS_ACCESS_KEY_ID` and more, mode `0600`
- Daily cron jobs: `unattended-upgrades` (APT security updates with automatic reboot), Docker engine upgrade, `docker pull` of running images and `docker compose up -d` of changed projects
- Scheduled **debsecan** (CVE), **rkhunter** (rootkits) and **lynis** (system audit) scans
- Optional zsh, oh-my-zsh, NVM and Go for root and `deploy`

### Infrastructure (Terraform)

- **Scaleway**: instance with routed IPv4 and IPv6, optional managed PostgreSQL or MySQL with an ACL that only allows the VPS
- **Cloudflare DNS**: A record for `<env>.<domain>` and wildcard `*.<env>.<domain>` (proxied), plus extra MX, TXT or CAA records
- **Cloudflare R2**: S3 compatible bucket per environment (S3 style access keys are created manually in the Cloudflare dashboard, see [`terraform/scaleway/README.md`](terraform/scaleway/README.md))
- **OVH** and **Hostinger**: provision with the `terraform/ovh/` module, or by hand following `terraform/hostinger/`
- Generated inventory `ansible/inventories/<env>.yml`, mode `0600`, never overwritten once you edit it

## Project structure

```text
.
├── ansible/
│   ├── playbook.yml                # assertions, then one tag per task file, firewall last
│   ├── ansible.cfg
│   ├── requirements.yml            # Ansible collections
│   ├── inventories/                # generated by Terraform, gitignored except the example
│   │   └── example.example.yml
│   ├── group_vars/
│   │   └── all.example.yml         # copy to all.yml (SSH key, ports, toggles)
│   ├── tasks/                      # base, user, ssh, honeypot, docker, www, app_env, auto_updates, security_scans, zsh, firewall
│   ├── templates/                  # iptables-rules.v4.j2, iptables-rules.v6.j2, app.env.j2
│   ├── files/                      # docker-daily-update.sh
│   └── handlers/main.yml
├── terraform/
│   ├── scaleway/
│   │   ├── modules/env/            # module: VPS, database, R2, DNS, inventory
│   │   └── envs/
│   │       ├── prod/               # prod state
│   │       └── dev/                # dev state (copy it for staging, preprod...)
│   ├── ovh/                        # OVH alternative (single environment)
│   └── hostinger/                  # no Terraform provider, manual guide
├── scripts/norminette.py           # repository rules: no secrets, whitespace, Sway logos
└── .github/workflows/              # CI, security scans, CodeQL
```

Detailed guides: [`ansible/README.md`](ansible/README.md), [`terraform/scaleway/README.md`](terraform/scaleway/README.md), [`terraform/ovh/README.md`](terraform/ovh/README.md), [`terraform/hostinger/README.md`](terraform/hostinger/README.md).

## Full workflow

Requirements: Ansible 2.14 or newer, Terraform 1.5 or newer, an Ed25519 SSH key, and a Debian 12 or Ubuntu 22.04+ VPS.

### 0. Prerequisites (once)

```sh
git clone https://github.com/sway-agency/vps-configurator.git && cd vps-configurator/ansible
ansible-galaxy collection install -r requirements.yml
cp group_vars/all.example.yml group_vars/all.yml
```

Edit `group_vars/all.yml`, above all `ssh_public_key` (your local public key).

### 1. Provision the infrastructure (per environment)

```sh
cd terraform/scaleway/envs/prod
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Fill in `terraform.tfvars` before applying: Scaleway and Cloudflare credentials, SSH key, R2 keys, domain. `terraform apply` writes `ansible/inventories/prod.yml`. Without Terraform, write the inventory by hand from `ansible/inventories/example.example.yml`.

### 2. Configure the VPS

```sh
cd ../../../../ansible
ansible-playbook -i inventories/prod.yml playbook.yml -e ansible_user=root -e ansible_port=22
```

The first run connects as `root` on port 22 with the provider key. Later runs use `deploy` on port 4242, the inventory default. Run a single part with tags, for example `--tags firewall` or `--tags docker`.

### 3. Deploy your Docker stack

On the VPS (`ssh -p 4242 deploy@<ip>`):

```sh
cd /var/www
git clone <your-traefik-db-apps-repo> stack
cd stack
docker compose up -d
```

Your `docker-compose.yml` reads `/var/www/.env` with `env_file: ../.env`.

### Add an environment (for example staging)

```sh
cd terraform/scaleway/envs
cp -r dev staging
cd staging
terraform init
terraform apply
cd ../../../../ansible
ansible-playbook -i inventories/staging.yml playbook.yml
```

Set `env_name = "staging"` and `subdomain = "staging"` in `terraform.tfvars` before `terraform apply`.

## Environment variables in `/var/www/.env`

| Variable | Source | Always set |
| --- | --- | --- |
| `ENV_NAME` | `env_name` | yes |
| `DOMAIN` | `<subdomain>.<domain>` | yes |
| `DATABASE_URL` | built from `db_engine` | yes |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_ENGINE` | managed or Docker database | yes |
| `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION` | R2 bucket | when `r2_enabled = true` |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | `terraform.tfvars` | when `r2_enabled = true` |

## Security notes

- Ports 80 and 443 are open to everyone. To hide the origin, use Cloudflare Tunnels and set `open_http_https: false`.
- DNS and NTP egress stay open, otherwise `apt`, `docker pull` and TLS break.
- `terraform.tfvars` and the Terraform state contain secrets. Keep them out of Git (already ignored) and prefer an encrypted remote backend.
- Database passwords are generated by Terraform: `terraform output -raw db_password`.

Found a vulnerability? Please report it privately, see [`SECURITY.md`](SECURITY.md).

## FAQ

**Can I get locked out of my server?** The playbook refuses to run with a malformed SSH key, validates the sshd configuration before restarting it, smoke tests the new `deploy` login on port 4242 before switching over, copies the provider root keys to `deploy` as a fallback, and applies the firewall last. Keep the provider console at hand for the first run anyway.

**Does it work without Terraform?** Yes. Write an inventory by hand and run the playbook on any Debian 12 or Ubuntu 22.04+ server, from any provider.

**Does it work with Traefik, Coolify or plain Docker Compose?** Yes. Ports 80 and 443 are open for any reverse proxy, and Docker is installed with a hardened daemon.

**Can I open more ports?** Yes. Use `extra_in_tcp_ports`, `extra_out_tcp_ports` and their UDP versions in `group_vars/all.yml`.

**Is it safe to run again?** Yes. Every task is idempotent: run it after changing a variable, or regularly to fix drift.

## Contributing

Contributions are welcome: new providers, new distributions, hardening improvements. Read [`CONTRIBUTING.md`](CONTRIBUTING.md). Every pull request runs the norminette, ansible-lint on the production profile, Terraform fmt, validate and TFLint, ShellCheck, actionlint, zizmor, Checkov, Gitleaks and CodeQL.

## Licence

Code under the [MIT licence](LICENSE). The Sway name and logos are trademarks of Sway: they may only be redistributed unmodified, where this project displays them.

<p align="center">Made with care by <strong>Sway</strong>.</p>
