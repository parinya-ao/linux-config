#!/usr/bin/env bash
# =============================================================================
# clean.sh — Universal System Cleanup & Optimization
# =============================================================================
set -Eeuo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SELF_DIR/lib/ui.sh"
source "$SELF_DIR/lib/privilege.sh"

step "Starting full system cleanup..."

# ── 1. Nix Cleanup ────────────────────────────────────
status_line "Removing old Home Manager generations..."
nix-collect-garbage -d 2>/dev/null || true
as_root nix-collect-garbage -d 2>/dev/null || true

status_line "Optimizing Nix store (hardlink duplicates)..."
nix store optimise 2>/dev/null || true

status_line "Removing Nix build leftovers..."
rm -rf ~/.cache/nix/ 2>/dev/null || true
as_root rm -rf /tmp/nix-* /tmp/home-manager-* 2>/dev/null || true

# ── 2. Distribution Specific ──────────────────────────
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian)
      status_line "Cleaning apt cache..."
      as_root apt-get autoremove -y 2>/dev/null || true
      as_root apt-get clean 2>/dev/null || true
      ;;
    fedora)
      status_line "Cleaning dnf cache..."
      as_root dnf autoremove -y 2>/dev/null || true
      as_root dnf clean all 2>/dev/null || true
      ;;
    opensuse*|suse)
      status_line "Cleaning zypper cache..."
      as_root zypper clean --all 2>/dev/null || true
      as_root zypper purge-kernels 2>/dev/null || true
      ;;
  esac
fi

# ── 3. Logs & Snapshots ──────────────────────────────
status_line "Trimming journal logs (keep 1 day)..."
as_root journalctl --vacuum-time=1d 2>/dev/null || true

if command -v snapper >/dev/null 2>&1; then
  status_line "Cleaning Snapper snapshots..."
  as_root snapper -c root cleanup number 2>/dev/null || true
fi

# ── 4. Disk Usage Report ──────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "📊 Disk Usage Report"
echo "═══════════════════════════════════════"
echo "Nix store:    $(du -sh /nix/store 2>/dev/null | cut -f1 || echo "N/A")"
if [[ -d /var/cache/zypp ]]; then
  echo "zypper cache: $(du -sh /var/cache/zypp 2>/dev/null | cut -f1 || echo "0")"
fi
echo "Journal:      $(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+\s*\w+' | head -1 || echo "N/A")"
echo "Root free:    $(df -h / | awk 'NR==2{print $4}')"
echo "═══════════════════════════════════════"

ok "Cleanup complete!"
