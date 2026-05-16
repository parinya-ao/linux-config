#!/usr/bin/env bash
set -euo pipefail
source "${BASH_SOURCE[0]%/*}/../../../lib/ui.sh"
source "${BASH_SOURCE[0]%/*}/../../../lib/docker.sh"
source "${BASH_SOURCE[0]%/*}/../../../lib/privilege.sh"

step "Installing Docker Engine"

if ! rpm -q docker >/dev/null 2>&1; then
  as_root zypper --non-interactive in --no-recommends docker docker-compose docker-buildx
fi

docker_enable_service
docker_add_user_to_group

ok "Docker configured"

