terraform {
  required_version = ">= 1.5"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  name_prefix = "${var.project_slug}-${var.env_name}"

  # Subdomain → domaine complet
  domain_full = var.subdomain == "" ? var.domain : "${var.subdomain}.${var.domain}"

  # Engine RDB Scaleway (format "PostgreSQL-15" / "MySQL-8")
  rdb_engine = var.db_engine == "postgresql" ? "PostgreSQL-${var.db_engine_version != "" ? var.db_engine_version : "16"}" : "MySQL-${var.db_engine_version != "" ? var.db_engine_version : "8"}"

  # Port DB
  db_port = var.db_engine == "postgresql" ? 5432 : 3306

  # URL DB scheme
  db_url_scheme = var.db_engine == "postgresql" ? "postgres" : "mysql"

  create_managed_db = var.db_provider == "scaleway"

  # === Endpoint DB exposé à l'app ===
  # Managed : IP du load-balancer Scaleway. VPS : hostname du service docker.
  # one() retourne null si count=0, l'IP sinon — pas d'eager-eval du [0].
  db_host = local.create_managed_db ? one(scaleway_rdb_instance.db[*].load_balancer[0].ip) : (var.db_engine == "postgresql" ? "postgres" : "mariadb")
  db_port_effective = local.db_port

  # === R2 endpoint ===
  r2_endpoint = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
  r2_bucket   = "${local.name_prefix}-assets"

  # === Mot de passe DB (unique source, branchée des deux côtés) ===
  db_password = random_password.db.result

  database_url = "${local.db_url_scheme}://${var.db_user}:${local.db_password}@${local.db_host}:${local.db_port_effective}/${var.db_name}${var.db_engine == "postgresql" ? "?sslmode=require" : ""}"

  app_env = merge(
    {
      ENV_NAME    = var.env_name
      DOMAIN      = local.domain_full

      DATABASE_URL = local.database_url
      DB_HOST      = local.db_host
      DB_PORT      = tostring(local.db_port_effective)
      DB_USER      = var.db_user
      DB_PASSWORD  = local.db_password
      DB_NAME      = var.db_name
      DB_ENGINE    = var.db_engine
    },
    var.r2_enabled ? {
      S3_ENDPOINT           = local.r2_endpoint
      S3_BUCKET             = local.r2_bucket
      S3_REGION             = "auto"
      AWS_ACCESS_KEY_ID     = var.r2_access_key_id
      AWS_SECRET_ACCESS_KEY = var.r2_secret_access_key
    } : {}
  )
}

# ============ Random password DB (managée ou docker-VPS) ============
resource "random_password" "db" {
  length  = 32
  special = false
}

# ============ VPS ============
resource "scaleway_iam_ssh_key" "bootstrap" {
  name       = "${local.name_prefix}-bootstrap"
  public_key = var.ssh_public_key
}

resource "scaleway_instance_server" "vps" {
  name              = "${local.name_prefix}-vps"
  type              = var.vps_type
  image             = var.vps_image
  enable_ipv6       = true
  routed_ip_enabled = true
  zone              = var.scaleway_zone

  root_volume {
    size_in_gb  = var.vps_root_volume_size_gb
    volume_type = "b_ssd"
  }

  tags = ["env:${var.env_name}", "project:${var.project_slug}", "managed-by-terraform"]

  depends_on = [scaleway_iam_ssh_key.bootstrap]
}

# ============ DB Managée (si db_provider=scaleway) ============
resource "scaleway_rdb_instance" "db" {
  count          = local.create_managed_db ? 1 : 0
  name           = "${local.name_prefix}-db"
  node_type      = var.db_node_type
  engine         = local.rdb_engine
  is_ha_cluster  = false
  disable_backup = false
  region         = var.scaleway_region
  user_name      = var.db_user
  password       = random_password.db.result
  volume_type    = "bssd"
  volume_size_in_gb = var.db_volume_size_gb

  tags = ["env:${var.env_name}", "project:${var.project_slug}"]
}

resource "scaleway_rdb_database" "db" {
  count       = local.create_managed_db ? 1 : 0
  instance_id = scaleway_rdb_instance.db[0].id
  name        = var.db_name
}

# ACL : autorise uniquement l'IP publique du VPS à se connecter à la DB.
resource "scaleway_rdb_acl" "db_acl" {
  count       = local.create_managed_db ? 1 : 0
  instance_id = scaleway_rdb_instance.db[0].id
  acl_rules {
    ip          = "${scaleway_instance_server.vps.public_ip}/32"
    description = "VPS ${local.name_prefix}"
  }
}

# ============ Cloudflare DNS ============
resource "cloudflare_record" "apex_or_sub" {
  zone_id = var.cloudflare_zone_id
  name    = var.subdomain == "" ? "@" : var.subdomain
  type    = "A"
  content = scaleway_instance_server.vps.public_ip
  ttl     = 1       # auto
  proxied = true
  comment = "vps-configurator: ${var.env_name}"
}

resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = var.subdomain == "" ? "*" : "*.${var.subdomain}"
  type    = "A"
  content = scaleway_instance_server.vps.public_ip
  ttl     = 1
  proxied = true
  comment = "vps-configurator: ${var.env_name} wildcard for Traefik"
}

resource "cloudflare_record" "extra" {
  # Index inclus dans la clé → autorise plusieurs records de même type+name
  # (ex: deux TXT pour rotation DKIM).
  for_each = { for idx, r in var.extra_dns_records : "${idx}-${r.type}-${r.name}" => r }
  zone_id  = var.cloudflare_zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.value
  ttl      = 1
  proxied  = each.value.proxied
}

# ============ Cloudflare R2 bucket ============
resource "cloudflare_r2_bucket" "assets" {
  count      = var.r2_enabled ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = local.r2_bucket
  location   = "WEUR"
}

# ============ Génération de l'inventory Ansible ============
# L'inventory reflète l'état STEADY (deploy@4242). Pour le 1er run (bootstrap
# root@22), on override en CLI :
#   ansible-playbook -i inventories/<env>.yml playbook.yml \
#     -e ansible_user=root -e ansible_port=22
# Idempotent : terraform apply n'écrase plus une édition manuelle.
resource "local_sensitive_file" "ansible_inventory" {
  filename        = "${var.ansible_dir}/inventories/${var.env_name}.yml"
  file_permission = "0600"
  content         = yamlencode({
    "${var.env_name}" = {
      hosts = {
        vps = {
          ansible_host                 = scaleway_instance_server.vps.public_ip
          ansible_user                 = "deploy"
          ansible_port                 = 4242
          ansible_ssh_private_key_file = "~/.ssh/id_ed25519"
          ansible_become               = true
        }
      }
      vars = merge(
        {
          env_name    = var.env_name
          domain_full = local.domain_full
          app_env     = local.app_env
        },
        local.create_managed_db ? {
          db_egress_host = local.db_host
          db_egress_port = local.db_port_effective
        } : {}
      )
    }
  })
}
