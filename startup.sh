#!/usr/bin/env bash
# =============================================================================
#  startup.sh  — Universal Bootstrap for parinya-ao/linux-config
#  Architecture: Gum-powered, 100% Non-interactive, OOTB
#  1. Bootstraps gum (if missing) via universal binary download
#  2. Detects distro via /etc/os-release
#  3. Dispatches per-distro driver script (apt / dnf / zypper)
#  4. Installs Nix (Determinate Systems, multi-user, no-confirm)
#  5. Clones / pulls the Home Manager config repo
#  6. Runs `home-manager switch` via Nix flakes
# =============================================================================
set -Eeuo pipefail
umask 022

# ── Bootstrap gum (OOTB: works on any distro, no sudo, no package manager) ──
if ! command -v gum &>/dev/null; then
  GUM_VERSION="0.14.0"
  mkdir -p /tmp/gum-bin
  curl -fsSL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_linux_x86_64.tar.gz" \
    | tar -xz -C /tmp/gum-bin --strip-components=1 "gum_${GUM_VERSION}_linux_x86_64/gum"
  chmod +x /tmp/gum-bin/gum
  export PATH="/tmp/gum-bin:$PATH"
fi

# ── Gum-based UI (no raw ANSI codes) ────────────────────────────────────────
step() { gum style --foreground "#00BFFF" --bold "▶ $*"; }
ok()   { gum style --foreground "#04B575" "  ✔ $*"; }
warn() { gum style --foreground "#FFA500" "  ⚠ $*" >&2; }
info() { gum style --foreground "#FFA500" "  ℹ $*"; }
fail() { gum style --foreground "#FF4500" --bold "  ✖ $*" >&2; exit 1; }

# ── Trap ─────────────────────────────────────────────────────────────────────
trap 'fail "Unexpected error at line $LINENO"' ERR

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

# ── root check ──────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  fail "This script must be run as root: sudo bash $0"
fi

is_atomic() {
  command -v rpm-ostree >/dev/null 2>&1 || return 1
  rpm-ostree status >/dev/null 2>&1 || return 1
  return 0
}

# ── stdin guard: ปิด interactive input ทุกอย่าง ──────────────────────────────
exec </dev/null

# ─────────────────────────────────────────────────────────────────────────────
# PART 0 — Distro detection
# ─────────────────────────────────────────────────────────────────────────────
OS_RELEASE="/etc/os-release"
[ -r "$OS_RELEASE" ] || fail "Cannot read $OS_RELEASE"

# shellcheck disable=SC1091,SC1090
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

gum style --bold --foreground "#00BFFF" "  Detected:  $(gum style --italic "$OS_PRETTY")"
info "Script:    $DISTRO_SCRIPT"

# ─────────────────────────────────────────────────────────────────────────────
# PART 1 — Run distro-specific driver
# ─────────────────────────────────────────────────────────────────────────────
# DEBUG MODE: If DEBUG=1 is set, enable shell tracing
if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x
fi

step "[DEBUG ENABLED] Running distro driver: $(basename "$DISTRO_SCRIPT")"
if bash "$DISTRO_SCRIPT" "$@"; then
  ok "Distro driver finished."
else
  fail "Distro driver failed."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PART 2 — Install Nix (Determinate Systems, no-confirm)
# ─────────────────────────────────────────────────────────────────────────────
if command -v nix >/dev/null 2>&1; then
  NIX_VER="$(nix --version 2>/dev/null || echo 'unknown')"
  info "Nix already installed: $(gum style --bold "$NIX_VER") — skipping."
else
  need_cmd curl
  step "Installing Nix package manager..."
  if curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm; then
    ok "Nix installed."
  else
    fail "Nix installation failed."
  fi
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
TARGET_USER="parinya"
TARGET_HOME="/home/${TARGET_USER}"
TARGET_DIR="${TARGET_HOME}/.config/home-manager"
REPO_URL="https://github.com/parinya-ao/linux-config.git"

mkdir -p "$(dirname "$TARGET_DIR")"

if [ ! -d "${TARGET_DIR}/.git" ]; then
  need_cmd git
  step "Cloning repo → ${TARGET_DIR}"
  if GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$TARGET_DIR"; then
    chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_DIR"
    ok "Repo cloned and ownership set to ${TARGET_USER}."
  else
    fail "Git clone failed."
  fi
else
  need_cmd git
  chown -R "${TARGET_USER}:${TARGET_USER}" "$TARGET_DIR"
  ok "Repo exists and ownership verified."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PART 4 — Migration & Final Switch (Automated via migrate.sh)
# ─────────────────────────────────────────────────────────────────────────────
cd "$TARGET_DIR"

# Ensure dbus is available for the switch (needed for GNOME/dconf settings)
# We also ensure git is available (needed by migrate.sh)
dnf install -y dbus-x11 git 2>/dev/null || apt-get install -y dbus-x11 git 2>/dev/null || zypper --non-interactive install dbus-1-x11 git 2>/dev/null || true

# Run migrate.sh as the target user to perform the final setup
# We must preserve the bootstrapped gum PATH and target user's home
if sudo -u "${TARGET_USER}" -H \
  PATH="/tmp/gum-bin:$PATH" \
  DEBUG="${DEBUG:-0}" \
  bash ./migrate.sh; then
  ok "Migration and Home Manager switch complete."
else
  fail "Migration Assistant (migrate.sh) failed."
fi


# ── Summary ──────────────────────────────────────────────────────────────────
gum style --border rounded --margin "1 2" --padding "1 2" --border-foreground "#04B575" \
  "$(gum style --bold --foreground "#04B575" "🎉 ALL DONE")" \
  "" \
  "Distro driver    $(basename "$DISTRO_SCRIPT")" \
  "Nix              $(nix --version 2>/dev/null || echo 'installed')" \
  "Home Manager     switched → .#parinya" \
  "" \
  "$(gum style --italic --foreground "#FFA500" "Open a new terminal (or reboot) for all PATH changes to take effect.")"
