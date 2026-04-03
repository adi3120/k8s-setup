#!/bin/bash

set -e

echo "=============================="
echo "🔧 Setting Proxy Variables"
echo "=============================="

PROXY_HTTP="http://proxy-wsa.esl.cisco.com:80"
PROXY_HTTPS="http://proxy.esl.cisco.com:8080"

# Export for current session
export http_proxy=$PROXY_HTTP
export https_proxy=$PROXY_HTTPS
export HTTP_PROXY=$PROXY_HTTP
export HTTPS_PROXY=$PROXY_HTTPS

echo "=============================="
echo "🌐 Configuring APT Proxy"
echo "=============================="

sudo tee /etc/apt/apt.conf.d/proxy.conf <<EOF
Acquire::http::Proxy "$PROXY_HTTP";
Acquire::https::Proxy "$PROXY_HTTPS";
EOF

echo "=============================="
echo "📦 Updating APT"
echo "=============================="

sudo apt update

echo "=============================="
echo "📥 Installing Dependencies"
echo "=============================="

sudo apt install -y ca-certificates curl gnupg

echo "=============================="
echo "🧹 Cleaning Old Docker Config"
echo "=============================="

sudo rm -f /etc/apt/sources.list.d/docker.*
sudo rm -f /etc/apt/keyrings/docker.*

echo "=============================="
echo "🔐 Adding Docker GPG Key (Proxy-aware)"
echo "=============================="

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -x $PROXY_HTTP -fsSL \
https://download.docker.com/linux/ubuntu/gpg \
-o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "=============================="
echo "📦 Adding Docker Repository"
echo "=============================="

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "=============================="
echo "🔄 Updating APT Again"
echo "=============================="

sudo apt update

echo "=============================="
echo "🐳 Installing Docker"
echo "=============================="

sudo apt install -y docker-ce docker-ce-cli containerd.io

echo "=============================="
echo "👤 Adding User to Docker Group"
echo "=============================="

sudo usermod -aG docker $USER

echo "=============================="
echo "🌐 Configuring Docker Proxy"
echo "=============================="

sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json <<EOF
{
  "proxies": {
    "http-proxy": "$PROXY_HTTP",
    "https-proxy": "$PROXY_HTTPS"
  }
}
EOF

echo "=============================="
echo "🔁 Restarting Docker"
echo "=============================="

sudo systemctl daemon-reexec
sudo systemctl restart docker

echo "=============================="
echo "🧪 Testing Docker"
echo "=============================="

sudo docker run hello-world

echo "=============================="
echo "✅ DONE!"
echo "⚠️ Logout/Login OR run: newgrp docker"
echo "=============================="