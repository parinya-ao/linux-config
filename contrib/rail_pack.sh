#!/usr/bin/env bash
set -Eeuo pipefail

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

curl -fsSL https://railpack.com/install.sh -o "$TMPFILE"
bash "$TMPFILE"
