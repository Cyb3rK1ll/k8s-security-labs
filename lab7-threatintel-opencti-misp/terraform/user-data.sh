#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/null) 2>&1

HOSTNAME="${HOSTNAME}"
DOCKER_PACKAGE_VERSION="${DOCKER_PACKAGE_VERSION}"
CONTAINERD_VERSION="${CONTAINERD_VERSION}"
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION}"
PORTAINER_VERSION="${PORTAINER_VERSION}"

hostnamectl set-hostname "${HOSTNAME}"

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  jq \
  software-properties-common

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get update
apt-get install -y \
  "docker-ce=${DOCKER_PACKAGE_VERSION}" \
  "docker-ce-cli=${DOCKER_PACKAGE_VERSION}" \
  "containerd.io=${CONTAINERD_VERSION}" \
  docker-buildx-plugin \
  "docker-compose-plugin=${DOCKER_COMPOSE_VERSION}"

apt-mark hold docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

cat >/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker

docker volume create portainer_data

docker run -d \
  --name portainer \
  --restart=always \
  -p 8000:8000 \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  "portainer/portainer-ce:${PORTAINER_VERSION}"

cat <<'BANNER' >/etc/motd
OpenCTI/MISP host provisioned via Terraform.
- Docker + Portainer están instalados.
- Clona el repo ti-iac-ec2 bajo /opt y usa docker compose para desplegar la pila.
- Accede a Portainer en https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9443
BANNER
