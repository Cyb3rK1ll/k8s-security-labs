#!/usr/bin/env bash
# Automates HAProxy installation, certificate creation and config deployment.
# Usage:
#   sudo CERT_CN="*.example.com" CONFIG_SRC="haproxy.cfg" scripts/setup-haproxy.sh

set -euo pipefail

CERT_CN="${CERT_CN:-*.claumagagnotti.com}"
CONFIG_SRC="${CONFIG_SRC:-haproxy.cfg}"
CERT_DIR="${CERT_DIR:-/etc/ssl/purple}"
KEY_PATH="${CERT_DIR}/private.key"
CERT_PATH="${CERT_DIR}/fullchain.pem"
COMBINED_PATH="${CERT_DIR}/haproxy.pem"
HAPROXY_CFG="${HAPROXY_CFG:-/etc/haproxy/haproxy.cfg}"

log() {
  printf '[haproxy-bootstrap] %s\n' "$*"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must run as root (tip: sudo $0)" >&2
    exit 1
  fi
}

ensure_binary() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Installing missing dependency: $1"
    apt-get update
    apt-get install -y "$1"
  fi
}

install_haproxy() {
  if ! dpkg -s haproxy >/dev/null 2>&1; then
    log "Installing haproxy..."
    apt-get update
    apt-get install -y haproxy
  else
    log "haproxy already installed, skipping."
  fi
}

generate_certificate() {
  log "Generating self-signed certificate for CN=${CERT_CN}"
  mkdir -p "${CERT_DIR}"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "${KEY_PATH}" \
    -out "${CERT_PATH}" \
    -days 365 \
    -subj "/CN=${CERT_CN}"
  cat "${KEY_PATH}" "${CERT_PATH}" > "${COMBINED_PATH}"
  chmod 600 "${COMBINED_PATH}" "${KEY_PATH}"
}

deploy_config() {
  local source_cfg
  source_cfg="$(realpath "${CONFIG_SRC}")"
  if [[ ! -f "${source_cfg}" ]]; then
    echo "Config source ${source_cfg} not found" >&2
    exit 1
  fi
  log "Deploying HAProxy config from ${source_cfg}"
  mkdir -p "$(dirname "${HAPROXY_CFG}")"
  if [[ -f "${HAPROXY_CFG}" ]]; then
    cp -a "${HAPROXY_CFG}" "${HAPROXY_CFG}.$(date +%Y%m%d%H%M%S).bak"
  fi
  cp "${source_cfg}" "${HAPROXY_CFG}"
}

validate_and_restart() {
  log "Validating HAProxy configuration..."
  haproxy -c -f "${HAPROXY_CFG}"
  log "Restarting HAProxy service..."
  systemctl restart haproxy
  systemctl status haproxy --no-pager
}

main() {
  require_root
  ensure_binary openssl
  install_haproxy
  generate_certificate
  deploy_config
  validate_and_restart
  log "Done. Certificate stored under ${CERT_DIR}"
}

main "$@"
