#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Full system cleanup starting..."

# ── Nix cleanup ────────────────────────────────────────
echo "[1/7] Removing old Home Manager generations..."
nix-collect-garbage -d
sudo nix-collect-garbage -d

echo "[2/7] Optimizing Nix store (hardlink duplicates)..."
nix store optimise

echo "[3/7] Removing Nix build leftovers..."
rm -rf ~/.cache/nix/ 2>/dev/null || true
rm -rf /tmp/nix-* 2>/dev/null || true

# ── System cleanup ─────────────────────────────────────
echo "[4/7] Cleaning zypper package cache..."
sudo zypper clean --all 2>/dev/null || true

echo "[5/7] Purging old kernels..."
sudo zypper purge-kernels 2>/dev/null || true

echo "[6/7] Trimming journal logs (keep 1 day)..."
sudo journalctl --vacuum-time=1d 2>/dev/null || true

echo "[7/7] Cleaning Snapper snapshots..."
if command -v snapper >/dev/null 2>&1; then
    sudo snapper -c root cleanup number 2>/dev/null || true
fi

# ── Report ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "📊 Disk Usage Report"
echo "═══════════════════════════════════════"
echo "Nix store:  $(du -sh /nix/store 2>/dev/null | cut -f1)"
echo "zypper cache: $(du -sh /var/cache/zypp 2>/dev/null | cut -f1)"
echo "Journal:    $(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+\s*\w+')"
echo "Root free:  $(df -h / | awk 'NR==2{print $4}')"
echo "═══════════════════════════════════════"
echo "✅ Cleanup complete!"
