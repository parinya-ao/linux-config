#!/usr/bin/env bash

set -euo pipefail

nix-store --optimize

nix-collect-garbage -d
