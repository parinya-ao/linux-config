#!/bin/bash
# ============================================================
#  Fedora N-1 Enterprise Upgrade Policy
#
#  Rule: Upgrade to (CURRENT+1) ONLY AFTER (CURRENT+2) is
#        officially released via Bodhi. This ensures the target
#        version has ~6 months of field testing before touching
#        your system. No downgrades. Forward-only. One hop at a time.
#
#  Example:
#    On F43. F44 released? → BLOCKED (F44 is still "N").
#    F45 released? → ALLOWED (F44 is now "N-1"). Upgrade to F44.
# ============================================================

set -euo pipefail

# ---- 0. Sanity: Must run as root ----
[[ $EUID -ne 0 ]] && { echo "[!] Run with: sudo $0"; exit 1; }

for cmd in rpm dnf curl jq df awk; do
    command -v "$cmd" &>/dev/null || { echo "[!] Missing required command: $cmd"; exit 1; }
done

# ---- 1. Version Math ----
CURRENT_VER=$(rpm -E %fedora)
TARGET_VER=$((CURRENT_VER + 1))   # N-1: the version we WANT to upgrade TO
GATE_VER=$((CURRENT_VER + 2))     # N:   must be released BEFORE we move

# ---- 2. Detect DNF version ----
IS_DNF5=0
dnf --version 2>/dev/null | grep -qiE "dnf5|libdnf5" && IS_DNF5=1

echo "============================================================"
echo "  Fedora N-1 Upgrade (Enterprise Stability)"
echo "  Current  : Fedora $CURRENT_VER"
echo "  Target   : Fedora $TARGET_VER  (N-1, our destination)"
echo "  Gate     : Fedora $GATE_VER must be released  (N, the latest)"
echo "  Engine   : $([ $IS_DNF5 -eq 1 ] && echo DNF5 || echo DNF4)"
echo "============================================================"
echo ""

# ---- 3. N-1 Gate: Query Fedora releases.json ----
# The official releases metadata is the source of truth for stable
# Fedora versions. This avoids Rawhide / branched streams and focuses
# on GA releases only.
echo "--- [GATE] Checking N-1 Policy via Fedora releases.json ---"

RELEASES_URL="https://fedoraproject.org/releases.json"

LATEST_STABLE=$(
    curl -sf --max-time 15 "$RELEASES_URL" \
    | jq -r '[.[] | select(.version | test("^[0-9]+$")) | (.version | tonumber)] | max'
) || {
    echo "[!] Error: Could not retrieve Fedora release metadata."
    echo "    Ensure internet access and that jq is installed."
    exit 1
}

if [[ -z "${LATEST_STABLE:-}" || "$LATEST_STABLE" == "null" ]]; then
    echo "[!] Error: Could not determine the latest Fedora stable version from releases.json."
    echo "    The metadata format may have changed."
    exit 1
fi

echo "  Latest stable Fedora (N): $LATEST_STABLE"

if [[ "$LATEST_STABLE" -lt "$GATE_VER" ]]; then
    echo ""
    echo "  [BLOCKED] N-1 Policy Enforced."
    echo ""
    echo "  You are on   : Fedora $CURRENT_VER"
    echo "  Latest is    : Fedora $LATEST_STABLE  (still N, not yet N+1)"
    echo "  Upgrade to   : Fedora $TARGET_VER is locked until Fedora $GATE_VER is released."
    echo ""
    echo "  Fedora releases ~every 6 months (April & October)."
    echo "  Once Fedora $GATE_VER is out, re-run this script to upgrade to Fedora $TARGET_VER."
    exit 0
fi

echo "  [OK] Fedora $GATE_VER is released. Fedora $TARGET_VER is N-1. Gate PASSED."
echo ""

# ---- 4. Pre-flight: AC Power ----
if ls /sys/class/power_supply/BAT* &>/dev/null; then
    AC_ONLINE=0
    for f in /sys/class/power_supply/*/online; do
        [[ -f "$f" ]] && grep -q 1 "$f" && AC_ONLINE=1
    done
    [[ $AC_ONLINE -eq 0 ]] && { echo "[!] Error: Running on battery. Plug in AC adapter."; exit 1; }
    echo "  [OK] AC adapter connected."
else
    echo "  [OK] No battery detected (desktop/server)."
fi

# ---- 5. Pre-flight: Disk Space ----
check_disk() {
    local dir=$1 req_mb=$2
    local free_mb=$(( $(df -P "$dir" | awk 'NR==2{print $4}') / 1024 ))
    if [[ $free_mb -lt $req_mb ]]; then
        echo "[!] Error: $dir needs ${req_mb} MB, only ${free_mb} MB free."; exit 1
    fi
    echo "  [OK] $dir: ${free_mb} MB free (need ${req_mb} MB)."
}
check_disk "/"     15000
check_disk "/boot" 300
check_disk "/var"  5000

# ---- 6. Final Confirmation ----
echo ""
echo "[!] You are about to upgrade from Fedora $CURRENT_VER → Fedora $TARGET_VER."
echo "    Ensure you have a backup and no critical tasks are running."
echo ""
read -r -p "Proceed? (yes/no): " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { echo "Cancelled."; exit 0; }

# ---- 7. Update Current System ----
echo ""
echo "--- [1/3] Refreshing Fedora $CURRENT_VER ---"
dnf upgrade --refresh

# Check if a reboot is needed after the update
NEEDS_REBOOT=0
if command -v needs-rebooting &>/dev/null; then
    needs-rebooting -r &>/dev/null || NEEDS_REBOOT=1
elif [[ $IS_DNF5 -eq 1 ]]; then
    dnf needs-rebooting 2>/dev/null | grep -qi "reboot is required" && NEEDS_REBOOT=1
fi

if [[ $NEEDS_REBOOT -eq 1 ]]; then
    echo ""
    echo "[!] Kernel or core libraries were just updated. A reboot is required first."
    read -r -p "Reboot now? (yes/no): " REBOOT_NOW
    if [[ "$REBOOT_NOW" == "yes" ]]; then
        echo "Rebooting. Re-run this script after restarting."
        reboot
    fi
    echo "Aborted. Reboot manually, then re-run this script."; exit 1
fi
 echo "  [OK] No reboot required."

# ---- 8. Ensure upgrade plugin present (DNF4 only) ----
if [[ $IS_DNF5 -eq 0 ]]; then
    dnf list installed dnf-plugin-system-upgrade &>/dev/null \
        || dnf install -y dnf-plugin-system-upgrade
fi

# ---- 9. Download Fedora TARGET_VER Packages ----
echo ""
echo "--- [2/3] Downloading Fedora $TARGET_VER packages ---"
echo "[!] Review the transaction summary. If dependency errors appear, DO NOT force."
echo ""

if [[ $IS_DNF5 -eq 1 ]]; then
    dnf system-upgrade download --releasever="$TARGET_VER" --allowerasing
else
    dnf system-upgrade download --releasever="$TARGET_VER" --best --allowerasing
fi

# ---- 10. Reboot into Offline Upgrade ----
echo ""
echo "============================================================"
echo " Download complete. Ready to upgrade Fedora $CURRENT_VER → $TARGET_VER."
echo " DO NOT power off during the upgrade reboot."
echo ""
echo " Post-upgrade health checks (run after reboot):"
echo "   sudo dnf repoquery --unsatisfied   # broken deps"
echo "   sudo dnf clean packages            # clear old cache"
echo "   sudo rpmconf -a                    # merge config files"
echo "============================================================"
echo ""
read -r -p "Reboot and apply upgrade now? (yes/no): " DO_REBOOT

if [[ "$DO_REBOOT" == "yes" ]]; then
    echo "Initiating upgrade reboot..."
    [[ $IS_DNF5 -eq 1 ]] && dnf offline-upgrade reboot || dnf system-upgrade reboot
else
    echo ""
    echo "Paused. When ready, run:"
    [[ $IS_DNF5 -eq 1 ]] \
        && echo "  sudo dnf offline-upgrade reboot" \
        || echo "  sudo dnf system-upgrade reboot"
fi

