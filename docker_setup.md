# 🐳 Docker Setup Behind Corporate Proxy (Ubuntu)

## 📌 Overview

This guide automates:

* Proxy configuration (system + APT)
* Docker installation
* Docker daemon proxy setup
* Validation

Designed for **corporate environments (e.g., Cisco labs)** where outbound internet access requires a proxy.

---

## ⚙️ Prerequisites

* Ubuntu (Jammy or compatible)
* `sudo` access
* Valid corporate proxy

---

## 🔧 Configuration Variables

Update these before running:

```bash
PROXY_HTTP="http://proxy.esl.cisco.com:8080/"
PROXY_HTTPS="http://proxy.esl.cisco.com:8080/"
NO_PROXY="localhost,127.0.0.1,.cisco.com"
```

---

## 🚀 Full Setup Script

```bash
#!/bin/bash

set -e

### ====== VARIABLES (EDIT THIS) ======
PROXY_HTTP="http://proxy.esl.cisco.com:8080/"
PROXY_HTTPS="http://proxy.esl.cisco.com:8080/"
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

### ====== 3. CURL TEST ======
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

sudo install -m 0755 -d /etc/apt/keyrings

curl -x $PROXY_HTTP -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo tee /etc/apt/keyrings/docker.asc > /dev/null

sudo chmod a+r /etc/apt/keyrings/docker.asc

### ====== 7. ADD DOCKER REPO ======
echo "[+] Adding Docker repo..."

ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")

sudo tee /etc/apt/sources.list.d/docker.list > /dev/null <<EOF
deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable
EOF

### ====== 8. APT UPDATE ======
echo "[+] Running apt update..."

sudo apt update

### ====== 9. INSTALL DOCKER ======
echo "[+] Installing Docker..."

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

### ====== 10. DOCKER PROXY CONFIG ======
echo "[+] Configuring Docker daemon proxy..."

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY_HTTP"
Environment="HTTPS_PROXY=$PROXY_HTTPS"
Environment="NO_PROXY=$NO_PROXY"
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

sudo usermod -aG docker $USER
```

---

## 🔐 Post-Installation Step

After script completes:

```bash
exec newgrp docker
```

Or:

```bash
logout
```

Then log back in.

---

## 🧪 Verification

### Check proxy variables

```bash
env | grep -i proxy
```

### Check Docker

```bash
docker run hello-world
```

---

## 🧠 Key Concepts

### Proxy Layers

| Layer              | Purpose             |
| ------------------ | ------------------- |
| `/etc/environment` | Global system proxy |
| APT config         | Package manager     |
| Docker daemon      | Image pulls         |

---

### Important Notes

* Use **HTTP proxy even for HTTPS traffic** in most corporate environments
* Avoid mixing multiple proxy config files unnecessarily
* Docker requires **daemon-level proxy config**, not just environment variables

---

## ❗ Troubleshooting

### APT Debug

```bash
sudo apt -o Debug::Acquire::https=true update
```

### Proxy Test

```bash
curl -x http://proxy.esl.cisco.com:8080 https://google.com -v
```

### Docker Logs

```bash
journalctl -u docker -f
```

---

## 🎯 Summary

✔ Proxy configured system-wide
✔ APT works behind proxy
✔ Docker installed and proxy-aware
✔ Ready for Minikube / Kubernetes

---

If you want, I can extend this into:

👉 **Kubernetes (kubeadm / minikube) full proxy-aware setup doc**
👉 **Cisco lab–grade automation playbook (Terraform + Ansible style)**
