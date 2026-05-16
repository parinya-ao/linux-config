#!/usr/bin/env bash
set -euo pipefail

function install_ghostty {
  sudo dnf copr enable scottames/ghostty -y
  sudo dnf install ghostty -y
}

export -f install_ghostty
