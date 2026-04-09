#!/bin/bash

set -e

### ====== VARIABLES (EDIT THIS) ======
PROXY_HTTP="http://proxy-wsa.esl.cisco.com:80/"
PROXY_HTTPS="http://proxy-wsa.esl.cisco.com:80/"
NO_PROXY="localhost,127.0.0.1,.cisco.com"

echo "========================================"
echo " Enterprise Proxy + Docker Setup"
echo "========================================"

### ====== 1. GLOBAL PROXY ENV ======

echo "[+] Setting /etc/environment proxy..."

sudo sed -i '/http_proxy/d;/https_proxy/d;/HTTP_PROXY/d;/HTTPS_PROXY/d;/no_proxy/d' /etc/environment

sudo tee -a /etc/environment > /dev/null <<EOF
http_proxy=$PROXY_HTTP
https_proxy=$PROXY_HTTPS
HTTP_PROXY=$PROXY_HTTP
HTTPS_PROXY=$PROXY_HTTPS
no_proxy=$NO_PROXY
EOF

### ====== 2. APT PROXY CONFIG ======
echo "[+] Configuring APT proxy..."

sudo tee /etc/apt/apt.conf.d/95proxies > /dev/null <<EOF
Acquire::http::Proxy "$PROXY_HTTP";
Acquire::https::Proxy "$PROXY_HTTPS";
EOF

### ====== 3. CURL ======

### ====== 3.1. CURL INSTALL ======
sudo apt update
sudo apt install -y curl

### ====== 3.1. CURL TEST ======
echo "[+] Testing proxy connectivity..."

curl -x $PROXY_HTTP -I https://download.docker.com || {
    echo "❌ Proxy not working. Fix before continuing."
    exit 1
}

### ====== 4. REMOVE OLD DOCKER ======
echo "[+] Removing old Docker packages..."

sudo rm -f /etc/apt/sources.list.d/docker.*
sudo rm -f /etc/apt/keyrings/docker.*
sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

### ====== 5. INSTALL DEPENDENCIES ======
echo "[+] Installing prerequisites..."

sudo apt update
sudo apt install -y ca-certificates curl gnupg

### ====== 6. ADD DOCKER GPG KEY ======
echo "[+] Adding Docker GPG key via proxy..."

# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl –x http://proxy-wsa.esl.cisco.com:80 -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

### ====== 7. ADD DOCKER REPO ======
echo "[+] Adding Docker repo..."

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

### ====== 8. APT UPDATE ======
echo "[+] Running apt update..."

sudo apt update

### ====== 9. INSTALL DOCKER ======
echo "[+] Installing Docker..."

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


sudo usermod -aG docker $USER && newgrp docker

### ====== 10. DOCKER PROXY CONFIG ======
echo "[+] Configuring Docker daemon proxy..."

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY_HTTP"
Environment="HTTPS_PROXY=$PROXY_HTTPS"
Environment="NO_PROXY=$NO_PROXY"
EOF

sudo tee /etc/docker/daemon.json <<EOF
{
  "proxies": {
    "http-proxy": "$PROXY_HTTP",
    "https-proxy": "$PROXY_HTTPS"
  }
}
EOF

### ====== 11. RESTART DOCKER ======
echo "[+] Restarting Docker..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart docker


### ====== 12. VERIFY ======
echo "[+] Testing Docker..."

sudo docker run hello-world || {
    echo "❌ Docker failed. Likely proxy issue in daemon."
    exit 1
}

echo "========================================"
echo "✅ SUCCESS: Docker running behind proxy"
echo "========================================"