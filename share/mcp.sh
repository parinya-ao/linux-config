#!/usr/bin/env bash
set -Eeuo pipefail
# ── MCP Bootstrap — Thin Wrapper ──────────────────────────────────────────────
# All logic has moved to share/mcp/ with modular config.
# Edit share/mcp/mcp.conf to change settings, then re-run this script.
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/mcp/mcp.sh" ]; then
  exec bash "$SCRIPT_DIR/mcp/mcp.sh" "$@"
else
  echo "ERROR: share/mcp/mcp.sh not found" >&2
  exit 1
fi
