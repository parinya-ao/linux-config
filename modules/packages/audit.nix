{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.packages.audit;
in
{
  options.my.packages.audit.enable = lib.mkEnableOption "Nix audit pipeline with Tetragon and Vector";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      vector
      logrotate
      (writeShellScriptBin "nix-audit-session" ''
        #!/usr/bin/env bash
        set -euo pipefail

        if [[ "''${1:-}" == "--" ]]; then
          shift
        fi

        if [[ "$#" -eq 0 ]]; then
          set -- home-manager switch --flake "$HOME/.config/home-manager"
        fi

        command -v tetra >/dev/null 2>&1 || { echo "tetra not found in PATH"; exit 1; }
        command -v vector >/dev/null 2>&1 || { echo "vector not found in PATH"; exit 1; }
        command -v sudo >/dev/null 2>&1 || { echo "sudo not found in PATH"; exit 1; }

        STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/nix-audit"
        CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-audit"
        VECTOR_CONFIG="$CONFIG_DIR/vector.toml"
        LOGROTATE_CONFIG="$CONFIG_DIR/logrotate.conf"
        LOGROTATE_STATE="$STATE_DIR/logrotate.state"

        [[ -f "$VECTOR_CONFIG" ]] || { echo "Missing vector config: $VECTOR_CONFIG"; exit 1; }

        mkdir -p "$STATE_DIR"

        SESSION_ID="provision-$(date +%s)"
        RAW_LOG="$STATE_DIR/tetragon_raw.json"
        CLEAN_LOG="$STATE_DIR/nix_audit_clean.json"
        VECTOR_LOG="$STATE_DIR/vector-''${SESSION_ID}.log"
        TETRA_LOG="$STATE_DIR/tetra-''${SESSION_ID}.log"

        : > "$RAW_LOG"
        : > "$CLEAN_LOG"

        sudo -v
        while true; do
          sudo -n true
          sleep 60
          kill -0 "$$" || exit
        done 2>/dev/null &
        SUDO_KEEPALIVE_PID=$!

        cleanup() {
          local code=$?
          trap - EXIT INT TERM
          if [[ -n "''${TETRA_PID:-}" ]]; then
            sudo kill "$TETRA_PID" >/dev/null 2>&1 || true
          fi
          if [[ -n "''${VECTOR_PID:-}" ]]; then
            kill "$VECTOR_PID" >/dev/null 2>&1 || true
          fi
          if [[ -n "''${SUDO_KEEPALIVE_PID:-}" ]]; then
            kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
          fi
          wait "''${VECTOR_PID:-}" >/dev/null 2>&1 || true

          if command -v logrotate >/dev/null 2>&1 && [[ -f "$LOGROTATE_CONFIG" ]]; then
            logrotate --state "$LOGROTATE_STATE" "$LOGROTATE_CONFIG" >/dev/null 2>&1 || true
          fi

          cp -f "$RAW_LOG" "$STATE_DIR/''${SESSION_ID}.raw.json" || true
          cp -f "$CLEAN_LOG" "$STATE_DIR/''${SESSION_ID}.clean.json" || true

          echo
          echo "AUDIT SUMMARY"
          if [[ -s "$CLEAN_LOG" ]]; then
            if command -v jq >/dev/null 2>&1; then
              tail -n 5 "$CLEAN_LOG" | jq -r '"[\(.t[11:16])] \(.p) \(.a)"' || tail -n 5 "$CLEAN_LOG"
            else
              tail -n 5 "$CLEAN_LOG"
            fi
          else
            echo "No logs captured in this session."
          fi
          echo "Audit logs saved in $STATE_DIR"
          exit "$code"
        }
        trap cleanup EXIT INT TERM

        vector --config "$VECTOR_CONFIG" >"$VECTOR_LOG" 2>&1 &
        VECTOR_PID=$!

        sudo tetra observe -o json >"$RAW_LOG" 2>"$TETRA_LOG" &
        TETRA_PID=$!

        "$@"
      '')
      (writeShellScriptBin "nix-audit-apply-policy" ''
        #!/usr/bin/env bash
        set -euo pipefail
        POLICY_PATH="''${XDG_CONFIG_HOME:-$HOME/.config}/nix-audit/monitor-etc-changes.yaml"
        [[ -f "$POLICY_PATH" ]] || { echo "Missing policy file: $POLICY_PATH"; exit 1; }

        if command -v kubectl >/dev/null 2>&1; then
          kubectl apply -f "$POLICY_PATH"
        else
          echo "kubectl not found. Apply policy manually:"
          echo "$POLICY_PATH"
          exit 1
        fi
      '')
    ];

    xdg.configFile = {
      "nix-audit/monitor-etc-changes.yaml".source = ../../audit/monitor-etc-changes.yaml;
      "nix-audit/vector.toml".source = ../../audit/vector.toml;
      "nix-audit/logrotate.conf".source = ../../audit/logrotate.conf;
    };
  };
}
