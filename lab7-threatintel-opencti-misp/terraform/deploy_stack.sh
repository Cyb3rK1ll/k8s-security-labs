#!/usr/bin/env bash
set -euo pipefail

HAPROXY_CN="$1"
PROJECT_NAME="$2"

mkdir -p /opt/misp
mv /tmp/misp-image /opt/misp/misp-image
mv /tmp/misp-compose.yml /opt/misp/docker-compose.yml
mv /tmp/misp-env /opt/misp/.env
mv /tmp/misp-scripts /opt/scripts
chmod +x /opt/scripts/setup-haproxy.sh
CERT_CN="$HAPROXY_CN" CONFIG_SRC="/opt/scripts/haproxy.cfg" /opt/scripts/setup-haproxy.sh
cd /opt/misp
sudo docker compose build misp
sudo COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose up -d
