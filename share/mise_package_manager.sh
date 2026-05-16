#!/usr/bin/env bash
set -Eeuo pipefail

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

curl -fsSL https://mise.run -o "$TMPFILE"
# ให้ user ตรวจสอบก่อน run (optional)
bash "$TMPFILE"
