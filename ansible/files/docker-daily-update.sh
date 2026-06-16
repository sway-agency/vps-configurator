#!/usr/bin/env bash
# Managed by Ansible — vps-configurator
# Daily update: Docker engine packages + pull latest images for running containers,
# then re-up any compose projects whose images changed.
set -euo pipefail

LOG=/var/log/docker-daily-update.log
exec >>"$LOG" 2>&1
echo "=== $(date -Is) ==="

# 1) Engine update (security/feature releases from docker.com repo).
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin || true

# 2) Pull latest image for each running container.
mapfile -t IMAGES < <(docker ps --format '{{.Image}}' | sort -u)
for img in "${IMAGES[@]}"; do
  echo "-- pulling $img"
  docker pull "$img" || true
done

# 3) Re-up any compose project whose images changed.
mapfile -t PROJECTS < <(
  docker ps --format '{{.Label "com.docker.compose.project.working_dir"}}' \
  | awk 'NF' | sort -u
)
for dir in "${PROJECTS[@]}"; do
  if [ -d "$dir" ]; then
    echo "-- compose up -d in $dir"
    (cd "$dir" && docker compose up -d --remove-orphans) || true
  fi
done

# 4) Prune dangling images (keep tagged ones).
docker image prune -f || true

echo "=== done $(date -Is) ==="
