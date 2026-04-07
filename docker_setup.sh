#!/bin/bash

set -e

### ====== VARIABLES (EDIT THIS) ======
PROXY="http://proxy.esl.cisco.com:80"
NO_PROXY="127.0.0.1,localhost"

### ====== 1. SET GLOBAL PROXY ======
echo "[+] Setting global proxy environment..."

sudo tee /etc/profile.d/proxy.sh > /dev/null <<EOF
export http_proxy=$PROXY
export https_proxy=$PROXY
export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY
export no_proxy=$NO_PROXY
EOF

# Load it immediately
source /etc/profile.d/proxy.sh

### ====== 2. CONFIGURE APT PROXY ======
echo "[+] Configuring APT proxy..."

sudo tee /etc/apt/apt.conf.d/95proxies > /dev/null <<EOF
Acquire::http::Proxy "$PROXY";
Acquire::https::Proxy "$PROXY";
EOF

### ====== 3. TEST CURL VIA PROXY ======
echo "[+] Testing curl with proxy..."
curl -I https://download.docker.com || {
    echo "❌ Curl failed via proxy. Check proxy settings."
    exit 1
}

### ====== 4. REMOVE OLD DOCKER PACKAGES ======
echo "[+] Removing old Docker packages..."

sudo apt remove -y $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1) || true

### ====== 5. INSTALL PREREQUISITES ======
echo "[+] Installing prerequisites..."

sudo apt update
sudo apt install -y ca-certificates curl

### ====== 6. ADD DOCKER GPG KEY ======
echo "[+] Adding Docker GPG key..."

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -x $PROXY -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

### ====== 7. ADD DOCKER REPO ======
echo "[+] Adding Docker repository..."

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "\${UBUNTU_CODENAME:-\$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

### ====== 8. UPDATE APT ======
echo "[+] Updating apt..."

sudo apt update

### ====== 9. INSTALL DOCKER ======
echo "[+] Installing Docker..."

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

### ====== 10. CONFIGURE DOCKER PROXY ======
echo "[+] Configuring Docker daemon proxy..."

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="NO_PROXY=$NO_PROXY"
EOF

### ====== 11. RELOAD & RESTART DOCKER ======
echo "[+] Restarting Docker..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart docker

### ====== 12. VERIFY ======
echo "[+] Verifying Docker..."

sudo docker run hello-world || {
    echo "❌ Docker test failed (likely proxy issue)"
    exit 1
}

echo "✅ Docker installed successfully behind proxy!"