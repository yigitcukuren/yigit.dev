#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  echo 'Run as root on the Ubuntu server.' >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt-get update
apt-get install -y ca-certificates curl gnupg debian-keyring debian-archive-keyring

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
source /etc/os-release
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt -o /etc/apt/sources.list.d/caddy-stable.list
chmod a+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin caddy
systemctl enable --now docker caddy
install -m 0755 -d /srv/yigit.dev/site /srv/wallos
