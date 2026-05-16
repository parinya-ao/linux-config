#!/usr/bin/env bash
set -euo pipefail

# Import GPG key
sudo rpm --import https://brave-browser-rpm-beta.s3.brave.com/brave-core-beta.asc

# Install Brave Browser Beta
sudo zypper addrepo https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo
sudo zypper install -y brave-browser-beta
