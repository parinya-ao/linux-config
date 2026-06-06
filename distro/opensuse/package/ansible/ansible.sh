#!/usr/bin/env bash
set -Eeuo pipefail

# Ansible installer for openSUSE
echo "[INFO] Installing Ansible dev tools..."
sudo zypper --non-interactive install python3-pip
sudo pip3 install ansible-dev-tools ansible-creator
echo "[OK] Ansible installed."
