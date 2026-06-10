#!/usr/bin/env bash
# =============================================================================
# test_fedora_driver.sh - Integration Test for fedora.sh (Dry Run Mode)
# =============================================================================
set -euo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
export DRY_RUN=1
export DEBUG=0
export TERM=xterm-256color

# Mock paths
MOCK_BIN_DIR="/tmp/fedora_mock_bin"
mkdir -p "$MOCK_BIN_DIR"
export PATH="$MOCK_BIN_DIR:$PATH"

# ── MOCKS ────────────────────────────────────────────────────────────────────

# Mock gum
cat > "$MOCK_BIN_DIR/gum" << 'EOF'
#!/usr/bin/env bash
case "$1" in
  choose)
    # Simulate selecting "Alacritty" and "Docker Engine"
    echo "Alacritty"
    echo "Docker Engine"
    ;;
  spin)
    # Just run the command
    shift 4
    "$@"
    ;;
  style|join)
    # Do nothing for style, join, etc.
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$MOCK_BIN_DIR/gum"

# Mock rpm
cat > "$MOCK_BIN_DIR/rpm" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-E" && "$2" == "%fedora" ]]; then
  echo "40"
  exit 0
fi
if [[ "$1" == "-q" ]]; then
  # Simulate some packages installed, some not
  case "$2" in
    pciutils) exit 0 ;;
    rpmfusion-free-release) 
      [[ "${SIMULATE_ROUND:-1}" == "2" ]] && exit 0 || exit 1 
      ;;
    ffmpeg) exit 1 ;;
    *) exit 1 ;;
  esac
fi
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/rpm"

# Mock dnf
cat > "$MOCK_BIN_DIR/dnf" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "config-manager" ]]; then
  echo "MOCK DNF CONFIG-MANAGER: $*"
  exit 0
fi
echo "MOCK DNF: $*"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/dnf"

# Mock lspci
cat > "$MOCK_BIN_DIR/lspci" << 'EOF'
#!/usr/bin/env bash
echo "01:00.0 VGA compatible controller: NVIDIA Corporation GA104 [GeForce RTX 3070] (rev a1)"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/lspci"

# Mock systemctl
cat > "$MOCK_BIN_DIR/systemctl" << 'EOF'
#!/usr/bin/env bash
echo "MOCK SYSTEMCTL: $*"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/systemctl"

# Mock fwupdmgr
cat > "$MOCK_BIN_DIR/fwupdmgr" << 'EOF'
#!/usr/bin/env bash
echo "MOCK FWUPDMGR: $*"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/fwupdmgr"

# Mock sudo
cat > "$MOCK_BIN_DIR/sudo" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-v" ]]; then
  exit 0
fi
# Just execute the rest
shift
"$@"
EOF
chmod +x "$MOCK_BIN_DIR/sudo"

# Mock tee
cat > "$MOCK_BIN_DIR/tee" << 'EOF'
#!/usr/bin/env bash
echo "MOCK TEE: $*"
exit 0
EOF
chmod +x "$MOCK_BIN_DIR/tee"

# ── MAIN ────────────────────────────────────────────────────────────────────

echo "🚀 Starting Integration Test for fedora.sh..."

# Patch fedora.sh root check
if grep -q "\[\[ \$EUID -ne 0 \]\]" fedora.sh; then
  echo "Bypassing root check for testing..."
  sed -i 's/\[\[ $EUID -ne 0 \]/[[ 0 -ne 0 ]/' fedora.sh
fi

echo "--- RUNNING ROUND 1 ---"
export SIMULATE_ROUND=1
bash fedora.sh

echo -e "\n--- RUNNING ROUND 2 ---"
export SIMULATE_ROUND=2
if bash fedora.sh; then
  echo "✅ Integration Test Passed!"
else
  echo "❌ Integration Test Failed!"
  exit 1
fi

# Restore root check
sed -i 's/\[\[ 0 -ne 0 \]/[[ $EUID -ne 0 ]/' fedora.sh

# Cleanup
rm -rf "$MOCK_BIN_DIR"
