#!/usr/bin/env bash
set -Eeuo pipefail

# Ansible installer for Fedora
echo "[INFO] Installing Ansible dev tools..."
sudo dnf install -y python3-pip
sudo pip3 install ansible-dev-tools ansible-creator
echo "[OK] Ansible installed."
