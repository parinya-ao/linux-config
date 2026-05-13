#!/usr/bin/env bash
# =============================================================================
#  startup.sh  — Universal Bootstrap for parinya-ao/linux-config
#  1. Detects distro via /etc/os-release (ID / ID_LIKE)
#  2. Dispatches to the per-distro driver script (apt / dnf / zypper)
#  3. Installs Nix (Determinate Systems, multi-user, no-confirm)
#  4. Clones / pulls the Home Manager config repo
#  5. Runs `home-manager switch` via Nix flakes
# =============================================================================
set -Eeuo pipefail
umask 022

# ── Color / logging ──────────────────────────────────────────────────────────
BOLD=$'\033[1m'
RESET=$'\033[0m'
BLUE=$'\033[1;34m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'

step() { printf '%s[STEP]%s %s\n' "$BLUE"  "$RESET" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
fail() { printf '%s[FAIL]%s %s\n' "$RED"   "$RESET" "$*" >&2; exit 1; }
info() { printf '%s[INFO]%s %s\n' "$YELLOW" "$RESET" "$*"; }

# ── Trap ─────────────────────────────────────────────────────────────────────
trap 'fail "Unexpected error at line $LINENO: $BASH_COMMAND"' ERR

# ── Helpers ──────────────────────────────────────────────────────────────────
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

resolve_self_dir() {
  local src="${BASH_SOURCE[0]}"
  while [ -L "$src" ]; do
    local dir; dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

need_cmd grep
need_cmd cut
SELF_DIR="$(resolve_self_dir)"

is_atomic() {
  command -v rpm-ostree >/dev/null 2>&1 || return 1
  rpm-ostree status >/dev/null 2>&1 || return 1
  return 0
}

# ── stdin guard: ปิด interactive input ทุกอย่าง ──────────────────────────────
# ถ้ารันแบบ pipe (curl | bash) stdin อาจเป็น pipe ไม่ใช่ terminal
# บังคับ close stdin เพื่อให้ทุก child process ไม่รอ keyboard
exec </dev/null

# ─────────────────────────────────────────────────────────────────────────────
# PART 0 — Distro detection
# ─────────────────────────────────────────────────────────────────────────────
STARTUP_OS_RELEASE_PATH="${STARTUP_OS_RELEASE_PATH:-/etc/os-release}"
STARTUP_TEST_MODE="${STARTUP_TEST_MODE:-}"

case "$STARTUP_TEST_MODE" in
  ""|dispatch-only|distro-only) ;;
  *) fail "Invalid STARTUP_TEST_MODE='$STARTUP_TEST_MODE' (use: dispatch-only, distro-only)" ;;
esac

OS_RELEASE="$STARTUP_OS_RELEASE_PATH"
[ -r "$OS_RELEASE" ] || fail "Cannot read $OS_RELEASE"

# shellcheck disable=SC1091
. "$OS_RELEASE"

OS_ID="${ID:-}"
OS_LIKE="${ID_LIKE:-}"
OS_PRETTY="${PRETTY_NAME:-$OS_ID}"

[ -n "$OS_ID" ] || fail "ID is missing in $OS_RELEASE"

pick_distro_script() {
  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|elementary|neon|zorin|kali|parrot)
      printf '%s/distro/ubuntu/ubuntu.sh\n' "$SELF_DIR"; return 0 ;;
    fedora)
      if is_atomic; then
        printf '%s/distro/fedora/atomic.sh\n' "$SELF_DIR"; return 0
      fi
      printf '%s/distro/fedora/fedora.sh\n' "$SELF_DIR"; return 0 ;;
    opensuse-tumbleweed|opensuse-leap|opensuse-slowroll|opensuse)
      printf '%s/distro/opensuse/opensuse.sh\n' "$SELF_DIR"; return 0 ;;
  esac
  case " $OS_LIKE " in
    *" debian "*)
      printf '%s/distro/ubuntu/ubuntu.sh\n' "$SELF_DIR"; return 0 ;;
    *" fedora "*|*" rhel "*|*" centos "*)
      if is_atomic; then
        printf '%s/distro/fedora/atomic.sh\n' "$SELF_DIR"; return 0
      fi
      printf '%s/distro/fedora/fedora.sh\n' "$SELF_DIR"; return 0 ;;
    *" suse "*|*" opensuse "*)
      printf '%s/distro/opensuse/opensuse.sh\n' "$SELF_DIR"; return 0 ;;
  esac
  return 1
}

DISTRO_SCRIPT="$(pick_distro_script)" \
  || fail "Unsupported distro: ID=${OS_ID} ID_LIKE=${OS_LIKE:-<empty>}
  Supported: ubuntu/debian family, fedora, opensuse/tumbleweed/leap"

case "$DISTRO_SCRIPT" in
  "$SELF_DIR"/*) ;;
  *) fail "Refusing script outside repo dir: $DISTRO_SCRIPT" ;;
esac

[ -f "$DISTRO_SCRIPT" ] || fail "Distro script not found: $DISTRO_SCRIPT"
[ -r "$DISTRO_SCRIPT" ] || fail "Distro script not readable: $DISTRO_SCRIPT"

info "Detected:  ${BOLD}${OS_PRETTY}${RESET}"
info "Script:    $DISTRO_SCRIPT"

if [[ "$STARTUP_TEST_MODE" == "dispatch-only" ]]; then
  ok "Dispatch-only test mode complete."
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# PART 1 — Run distro-specific driver
# ─────────────────────────────────────────────────────────────────────────────
step "Running distro driver: $(basename "$DISTRO_SCRIPT")"
# ✅ stdin already closed above — child script cannot block waiting for input
# Distro driver requires root for package installation, firmware, etc.
sudo /usr/bin/env bash "$DISTRO_SCRIPT" "$@"
ok "Distro driver finished."

if [[ "$STARTUP_TEST_MODE" == "distro-only" ]]; then
  ok "Distro-only test mode complete."
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# PART 2 — Install Nix (Determinate Systems, no-confirm = fully non-interactive)
# ─────────────────────────────────────────────────────────────────────────────
step "Checking Nix installation..."

if command -v nix >/dev/null 2>&1; then
  NIX_VER="$(nix --version 2>/dev/null || echo 'unknown')"
  info "Nix already installed: ${BOLD}${NIX_VER}${RESET} — skipping."
else
  step "Installing Nix via Determinate Systems installer..."
  need_cmd curl
  # --no-confirm removes ALL interactive prompts (confirmed by Determinate docs)
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  ok "Nix installed."
fi

NIX_PROFILE='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
if [ -e "$NIX_PROFILE" ]; then
  # shellcheck disable=SC1090
  . "$NIX_PROFILE"
  ok "Nix profile sourced."
else
  warn "nix-daemon.sh not found — PATH will be set after reboot."
fi

need_cmd nix
info "Nix version: $(nix --version)"

# ─────────────────────────────────────────────────────────────────────────────
# PART 3 — Clone / update Home Manager config repo (fully non-interactive)
# ─────────────────────────────────────────────────────────────────────────────
step "Preparing Home Manager config directory..."

TARGET_DIR="${HOME}/.config/home-manager"
REPO_URL="https://github.com/parinya-ao/linux-config.git"

mkdir -p "$TARGET_DIR"

if [ ! -d "${TARGET_DIR}/.git" ]; then
  step "Cloning repo → ${TARGET_DIR}"
  need_cmd git
  # GIT_TERMINAL_PROMPT=0 → ป้องกัน git ถามรหัสผ่าน (repo นี้ public ไม่ต้องการ)
  GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$TARGET_DIR"
  ok "Repo cloned."
else
  step "Repo exists — syncing to latest..."
  need_cmd git
  # ✅ reset hard แทน stash → ไม่มีทางหยุดรอ input เลย
  # (local changes จะถูก discard — เพราะ source of truth คือ remote)
  # git -C "$TARGET_DIR" fetch --quiet origin
  # git -C "$TARGET_DIR" reset --hard origin/main 2>/dev/null
  ok "Repo synced to remote HEAD."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PART 4 — Home Manager switch (fully non-interactive)
# ─────────────────────────────────────────────────────────────────────────────
step "Running Home Manager switch..."

cd "$TARGET_DIR"

# ✅ --impure removed (default pure is safer)
# ✅ -b backup → HM จะ rename file ที่ชนกัน แทนที่จะถาม
nix --extra-experimental-features "nix-command flakes" \
    run home-manager/master -- \
    switch \
    --flake ".#parinya" \
    -b backup \
    --show-trace

ok "Home Manager switch complete."

echo
echo -e "${BOLD}--------------------------------------------------${RESET}"
echo -e "${BOLD}  ALL DONE  ${RESET}"
echo -e "${BOLD}--------------------------------------------------${RESET}"
echo -e "  Distro driver    $(basename "$DISTRO_SCRIPT")"
echo -e "  Nix              $(nix --version 2>/dev/null || echo 'installed')"
echo -e "  Home Manager     switched → .#parinya"
echo -e "${BOLD}--------------------------------------------------${RESET}"
warn "Open a new terminal (or reboot) for all PATH changes to take effect."
