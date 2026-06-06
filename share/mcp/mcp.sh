#!/usr/bin/env bash
set -Eeuo pipefail
trap 'gum log --level error "Unexpected failure" line="$LINENO" exit="$?"' ERR

# ── MCP Server Bootstrap — Main Entry Point ───────────────────────────────────
# Orchestrates all MCP setup from a single config file (mcp.conf).
#
# Usage:
#   bash share/mcp/mcp.sh          # Run full pipeline
#   bash share/mcp/mcp.sh --check  # Check status only (no changes)
#
# Config: Edit share/mcp/mcp.conf to change all settings.
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Source config & modules ───────────────────────────────────────────────────
# shellcheck source=mcp.conf
source "$SCRIPT_DIR/mcp.conf"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/environment.sh
source "$SCRIPT_DIR/lib/environment.sh"
# shellcheck source=lib/binaries.sh
source "$SCRIPT_DIR/lib/binaries.sh"
# shellcheck source=lib/systemd.sh
source "$SCRIPT_DIR/lib/systemd.sh"
# shellcheck source=lib/claude.sh
source "$SCRIPT_DIR/lib/claude.sh"
# shellcheck source=lib/opencode.sh
source "$SCRIPT_DIR/lib/opencode.sh"

# ── Summary ───────────────────────────────────────────────────────────────────

show_summary() {
  local daemon_status="Stopped"
  if systemctl --user is-active agentmemory >/dev/null 2>&1; then
    daemon_status=$(gum style --foreground "$C_SUCCESS" "● Running")
  fi

  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  MCP SETUP COMPLETE")

  local r1 r2 r3 r4 r5
  r1=$(kv "Config file"    "$SCRIPT_DIR/mcp.conf")
  r2=$(kv "Binaries"       "$BUN_BIN_DIR")
  r3=$(kv "Daemon"         "$daemon_status")
  r4=$(kv "Claude Code"    "~/.claude.json")
  r5=$(kv "OpenCode"       "$OPENCODE_CONFIG_DIR")

  local body
  body=$(gum join --vertical --align left "$title" "" "$r1" "$r2" "$r3" "$r4" "$r5")

  gum style --border rounded --border-foreground "$C_SUCCESS" --padding "1 3" "$body"
}

# ── Main Pipeline ─────────────────────────────────────────────────────────────

main() {
  banner "MCP Server Bootstrap"

  need_cmd gum
  need_cmd bun
  need_cmd jq
  need_cmd curl
  need_cmd systemctl

  local PIPELINE=(
    "1:environment:setup_environment_d       # Propagate Nix PATH into systemd"
    "2:binaries:install_mcp_binaries         # Install direct binaries via bun"
    "3:systemd:generate_systemd_unit         # Generate hardened systemd unit"
    "4:claude:inject_claude_mcp              # Inject MCP into Claude Code"
    "5:opencode:inject_opencode_mcp          # Inject MCP into OpenCode"
  )

  for entry in "${PIPELINE[@]}"; do
    local num="${entry%%:*}"
    local rest="${entry#*:}"
    local name="${rest%%:*}"
    local func_and_comment="${rest#*:}"
    local func="${func_and_comment%% *}"
    local desc="${func_and_comment#*# }"
    step "$num" "$desc"
    "$func"
  done

  show_summary
}

main "$@"
