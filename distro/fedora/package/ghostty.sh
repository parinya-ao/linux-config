#!/usr/bin/env bash
function install_ghostty {
  sudo dnf copr enable scottames/ghostty
  sudo dnf install ghostty -y
}

export -f install_ghostty
