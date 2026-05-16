#!/usr/bin/env bash
# Firefox Developer Edition Installation for openSUSE
set -euo pipefail

REPO_NAME="home_ignis"
REPO_URL="https://download.opensuse.org/repositories/home:/ignis/openSUSE_Tumbleweed/"

echo "Adding Firefox Developer Edition repository..."
sudo zypper addrepo -f "$REPO_URL" "$REPO_NAME"

echo "Refreshing repositories..."
sudo zypper --non-interactive --gpg-auto-import-keys refresh

echo "Installing Firefox Developer Edition..."
sudo zypper --non-interactive install firefox-dev

echo "Firefox Developer Edition installation complete."
