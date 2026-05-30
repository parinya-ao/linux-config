#!/usr/bin/env bash
set -Eeuo pipefail
trap 'gum log --level error "Unexpected failure" line="$LINENO" exit="$?"' ERR

# ── CONFIG ──────────────────────────────────────────────────────────────────
readonly C_PRIMARY="#00BFFF"
readonly C_SUCCESS="#04B575"
readonly C_WARNING="#FFA500"
readonly C_DANGER="#FF4500"
readonly C_MUTED="#666666"
readonly C_ACCENT="#C678DD"

export GUM_SPIN_SPINNER="line"
export GUM_LOG_LEVEL="info"
export GUM_LOG_TIME="rfc822"

# ── LAYER 1: UI PRIMITIVES ──────────────────────────────────────────────────

banner() {
  gum style --border double --border-foreground "$C_PRIMARY" --align center --padding "1 4" --bold "$*"
}

step() {
  gum style --foreground "$C_PRIMARY" --bold "▶  Step ${1}: ${2}"
}

ok()   { gum style --foreground "$C_SUCCESS" "  ✔  $*"; }
warn() { gum style --foreground "$C_WARNING" "  ⚠  $*"; }
info() { gum style --foreground "$C_MUTED"   "  ℹ  $*"; }

fail() {
  gum style --border thick --border-foreground "$C_DANGER" --foreground "$C_DANGER" --bold --padding "0 2" "✖  ERROR: $*"
  exit 1
}

kv() {
  local label="$1" value="$2"
  label=$(gum style --foreground "$C_MUTED"  --width 18 "$label")
  value=$(gum style --foreground "$C_ACCENT" "$value")
  gum join --horizontal "$label" "$value"
}

# ── LAYER 2: RUNNER ─────────────────────────────────────────────────────────

run_step() {
  local spinner="$1" title="$2"
  shift 2
  if gum spin --spinner "$spinner" --title "  ${title}..." -- "$@"; then
    ok "$title"
  else
    local code=$?
    fail "$title (exit $code)"
  fi
}

# ── LAYER 3: TASK FUNCTIONS ─────────────────────────────────────────────────

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command not found: $1"
  fi
}

install_global_tools() {
  local bin_dir="$HOME/.bun/bin"

  if [ -x "$bin_dir/codegraph" ] && [ -x "$bin_dir/mcp-server-sequential-thinking" ]; then
    info "Global MCP tools already installed, skipping"
    return 0
  fi

  step 1 "Installing MCP Servers globally via Bun"
  run_step line "Installing packages" \
    bun install -g \
      @modelcontextprotocol/server-sequential-thinking \
      @colbymchenry/codegraph \
      @agentmemory/agentmemory
}

connect_agentmemory() {
  need_cmd bun

  step 2 "Connecting Agent Memory to IDEs/Tools"

  local targets=("claude-code" "opencode" "antigravity" "cursor" "vscode" "codex")
  local skipped=0

  for target in "${targets[@]}"; do
    if bun x --yes @agentmemory/agentmemory@latest connect "$target" >/dev/null 2>&1; then
      ok "Agent Memory → $target"
      ((AM_CONNECTED++)) || true
    else
      info "Skipped $target (not found)"
      ((skipped++)) || true
    fi
  done

  gum log --level info "AgentMemory connect complete" connected="$AM_CONNECTED" skipped="$skipped"
}

inject_mcp_servers() {
  step 3 "Injecting Sequential Thinking & CodeGraph into AI CLIs"

  local clis=("claude" "opencode" "antigravity" "codex")
  local skipped=0

  for cli in "${clis[@]}"; do
    if ! command -v "$cli" >/dev/null 2>&1; then
      info "Skipped $cli (CLI not in PATH)"
      ((skipped++)) || true
      continue
    fi

    "$cli" mcp add sequential-thinking bunx @modelcontextprotocol/server-sequential-thinking >/dev/null 2>&1 || true
    "$cli" mcp add codegraph bunx @colbymchenry/codegraph >/dev/null 2>&1 || true
    ok "Configured MCP for $cli"
    ((CLI_CONFIGURED++)) || true
  done

  # Fallback: inject into opencode.json / opencode.jsonc
  local opencode_json
  if [ -f "$HOME/.config/opencode/opencode.json" ]; then
    opencode_json="$HOME/.config/opencode/opencode.json"
  elif [ -f "$HOME/.config/opencode/opencode.jsonc" ]; then
    opencode_json="$HOME/.config/opencode/opencode.jsonc"
  else
    opencode_json=""
  fi

  if [ -n "$opencode_json" ]; then
    local injected=0
    if ! jq -e '.mcp["sequential-thinking"]' "$opencode_json" >/dev/null 2>&1; then
      jq '.mcp["sequential-thinking"] = {"type": "local", "command": ["bunx", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true}' "$opencode_json" > /tmp/opencode_tmp.json && mv /tmp/opencode_tmp.json "$opencode_json"
      ((injected++)) || true
    fi
    if ! jq -e '.mcp["codegraph"]' "$opencode_json" >/dev/null 2>&1; then
      jq '.mcp["codegraph"] = {"type": "local", "command": ["bunx", "@colbymchenry/codegraph"], "enabled": true}' "$opencode_json" > /tmp/opencode_tmp.json && mv /tmp/opencode_tmp.json "$opencode_json"
      ((injected++)) || true
    fi
    if ! jq -e '.mcp["agentmemory"]' "$opencode_json" >/dev/null 2>&1; then
      jq '.mcp["agentmemory"] = {"type": "local", "command": ["bunx", "@agentmemory/mcp"], "enabled": true}' "$opencode_json" > /tmp/opencode_tmp.json && mv /tmp/opencode_tmp.json "$opencode_json"
      ((injected++)) || true
    fi
    [ "$injected" -gt 0 ] && ok "Injected MCP entries into $(basename "$opencode_json")" || info "$(basename "$opencode_json") already configured"
  fi

  gum log --level info "MCP injection complete" configured="$CLI_CONFIGURED" skipped="$skipped"
}

start_agentmemory_daemon() {
  step 4 "Starting AgentMemory as systemd daemon"

  local unit_dir="$HOME/.config/systemd/user"
  local unit_file="$unit_dir/agentmemory.service"

  mkdir -p "$unit_dir"

  if systemctl --user is-active agentmemory >/dev/null 2>&1; then
    info "agentmemory.service already running"
    return 0
  fi

  cat > "$unit_file" <<- SERVICE
[Unit]
Description=AgentMemory Persistent Memory Server
After=network.target

[Service]
Type=simple
ExecStart=$HOME/.bun/bin/agentmemory
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE

  run_step pulse "Registering systemd unit" systemctl --user daemon-reload
  run_step pulse "Enabling agentmemory" systemctl --user enable agentmemory
  run_step globe "Starting agentmemory daemon" systemctl --user start agentmemory

  # Wait for health check
  local retries=10
  while [ "$retries" -gt 0 ]; do
    if curl -sf http://localhost:3111/agentmemory/health >/dev/null 2>&1; then
      ok "AgentMemory healthy on :3111 (API) :3113 (Viewer)"
      return 0
    fi
    sleep 1
    ((retries--)) || true
  done

  warn "AgentMemory started but health check timed out — check 'journalctl --user -u agentmemory'"
}

install_agentmemory_skills() {
  step 5 "Installing AgentMemory skills for OpenCode"

  if [ -d "$HOME/.agents/skills/remember" ]; then
    info "AgentMemory skills already installed, skipping"
    return 0
  fi

  run_step points "Adding agentmemory skills" \
    bun x --yes skills@latest add rohitg00/agentmemory -y -a opencode

  ok "AgentMemory skills installed for OpenCode"
}

# ── LAYER 4: SUMMARY ────────────────────────────────────────────────────────

show_summary() {
  local connected="$1" configured="$2"
  local daemon_status="Stopped"

  if systemctl --user is-active agentmemory >/dev/null 2>&1; then
    daemon_status=$(gum style --foreground "$C_SUCCESS" "● Running")
  fi

  local title
  title=$(gum style --foreground "$C_SUCCESS" --bold "🎉  MCP SETUP COMPLETE")

  local r1 r2 r3 r4
  r1=$(kv "AgentMemory connects" "$connected")
  r2=$(kv "CLI MCP configs"      "$configured")
  r3=$(kv "Daemon"               "$daemon_status")
  r4=$(kv "Script"               "share/mcp.sh")

  local body
  body=$(gum join --vertical --align left "$title" "" "$r1" "$r2" "$r3" "$r4")

  gum style --border rounded --border-foreground "$C_SUCCESS" --padding "1 3" "$body"
}

# ── LAYER 5: MAIN ───────────────────────────────────────────────────────────

main() {
  banner "MCP Server Bootstrap"

  need_cmd gum
  need_cmd bun
  need_cmd jq
  need_cmd curl
  need_cmd systemctl

  # Global counters collected across pipeline tasks
  declare -g AM_CONNECTED=0 CLI_CONFIGURED=0

  local PIPELINE=(
    install_global_tools
    connect_agentmemory
    inject_mcp_servers
    start_agentmemory_daemon
    install_agentmemory_skills
  )

  for task in "${PIPELINE[@]}"; do
    "$task"
  done

  show_summary "$AM_CONNECTED" "$CLI_CONFIGURED"
}

main "$@"
