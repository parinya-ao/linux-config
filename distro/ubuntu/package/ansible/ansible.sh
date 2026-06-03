#!/usr/bin/env bash
set -Eeuo pipefail

# Ansible installer for Ubuntu
echo "[INFO] Installing Ansible dev tools..."
sudo apt-get install -y python3-pip
sudo pip3 install ansible-dev-tools ansible-creator
echo "[OK] Ansible installed."
