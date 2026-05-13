#!/bin/bash
set -e

echo "[+] Oppdaterer systemet..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "[+] Installerer pakker for Docker repo..."
sudo apt-get install -y ca-certificates curl gnupg

echo "[+] Legger til Docker sitt offisielle apt-repo..."
sudo install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[+] Installerer Docker..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[+] Aktiverer Docker..."
sudo systemctl enable --now docker

echo "[+] Legger nåværende bruker i docker-gruppen..."
sudo usermod -aG docker "$USER"

echo "[+] Tester Docker med sudo..."
sudo docker run --rm hello-world >/dev/null

echo
echo "[+] Alt er klart."
echo
echo "Kjør nå:"
echo "  newgrp docker"
echo
echo "Deretter:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
echo "  docker ps"
echo
