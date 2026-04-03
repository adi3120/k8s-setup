#!/bin/bash

set -e

PROXY_HTTP="http://proxy-wsa.esl.cisco.com:80"

sudo tee /etc/apt/apt.conf.d/proxy.conf <<EOF
Acquire::http::Proxy "$PROXY_HTTP";
EOF

sudo rm -f /etc/apt/sources.list.d/docker.*
sudo rm -f /etc/apt/keyrings/docker.*
 
sudo install -m 0755 -d /etc/apt/keyrings
 
export http_proxy=http://proxy-wsa.esl.cisco.com:80
export https_proxy=http://proxy-wsa.esl.cisco.com:80
 
sudo curl -x http://proxy-wsa.esl.cisco.com:80 -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: jammy
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
 
sudo apt update
 
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER && newgrp docker

sudo tee /etc/docker/daemon.json <<EOF
{
  "proxies": {
    "http-proxy": "$PROXY_HTTP",
    "https-proxy": "$PROXY_HTTPS"
  }
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker