#!/usr/bin/env bash
set -Eeuo pipefail

nix flake update nixpkgs

nix run nixpkgs#nixfmt -- .

nix run home-manager/master -- switch --flake .#parinya -b backup
