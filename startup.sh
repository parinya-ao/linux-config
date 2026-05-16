#!/usr/bin/env bash
# =============================================================================
# startup.sh — Universal Bootstrap for parinya-ao/linux-config
# =============================================================================
set -Eeuo pipefail
umask 022

# ------------------------------------------
# UI HELPERS
# ------------------------------------------
# Local minimal definitions before lib/ui.sh is available
step() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 39 --bold "[STEP] $*"
  else
    printf '\e[34;1m[STEP] %s\e[0m\n' "$*"
  fi
}

ok() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 82 "[OK] $*"
  else
    printf '\e[32m[OK] %s\e[0m\n' "$*"
  fi
}

warn() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 227 "[WARN] $*" >&2
  else
    printf '\e[33m[WARN] %s\e[0m\n' "$*" >&2
  fi
}

fail() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 196 --bold "[FAIL] $*" >&2
  else
    printf '\e[31;1m[FAIL] %s\e[0m\n' "$*" >&2
  fi
  exit 1
}

status_line() {
  if command -v gum >/dev/null 2>&1; then
    gum style "$*"
  else
    printf '%s\n' "$*"
  fi
}

spin_run() {
  local title="$1"
  shift
  if command -v gum >/dev/null 2>&1; then
    gum spin --show-output --spinner line --title "$title" -- "$@"
  else
    "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail
}

resolve_self_dir() {
  local src="${BASH_SOURCE[0]}"
  while [ -L "$src" ]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}

is_atomic() {
  command -v rpm-ostree >/dev/null 2>&1 || return 1
  rpm-ostree status >/dev/null 2>&1 || return 1
  return 0
}

run_privileged() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

start_sudo_keepalive() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  fi
  need_cmd sudo
  sudo -v || fail
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
}

install_gum() {
  case "$1" in
    ubuntu)
      run_privileged env DEBIAN_FRONTEND=noninteractive apt-get update -y
      run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y gum
      ;;
    fedora)
      run_privileged dnf install -y gum
      ;;
    opensuse)
      run_privileged zypper --non-interactive -y in --no-recommends gum
      ;;
    *)
      return 1
      ;;
  esac
}

pick_distro_script() {
  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|elementary|neon|zorin|kali|parrot)
      printf '%s/distro/ubuntu/ubuntu.sh\n' "$SELF_DIR"
      return 0
      ;;
    fedora)
      if is_atomic; then
        printf '%s/distro/fedora/atomic.sh\n' "$SELF_DIR"
      else
        printf '%s/distro/fedora/fedora.sh\n' "$SELF_DIR"
      fi
      return 0
      ;;
    opensuse-tumbleweed|opensuse-leap|opensuse-slowroll|opensuse)
      printf '%s/distro/opensuse/opensuse.sh\n' "$SELF_DIR"
      return 0
      ;;
  esac

  case " $OS_LIKE " in
    *" debian "*)
      printf '%s/distro/ubuntu/ubuntu.sh\n' "$SELF_DIR"
      return 0
      ;;
    *" fedora "*|*" rhel "*|*" centos "*)
      if is_atomic; then
        printf '%s/distro/fedora/atomic.sh\n' "$SELF_DIR"
      else
        printf '%s/distro/fedora/fedora.sh\n' "$SELF_DIR"
      fi
      return 0
      ;;
    *" suse "*|*" opensuse "*)
      printf '%s/distro/opensuse/opensuse.sh\n' "$SELF_DIR"
      return 0
      ;;
  esac
  return 1
}

trap 'fail' ERR
trap 'stop_sudo_keepalive' EXIT

need_cmd grep
need_cmd cut
SELF_DIR="$(resolve_self_dir)"

if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
  status_line "Run this script as a normal user"
  fail
fi

BOOTSTRAP_USER="${SUDO_USER:-$(id -un)}"
BOOTSTRAP_HOME="$(getent passwd "$BOOTSTRAP_USER" | cut -d: -f6)"
[ -n "$BOOTSTRAP_HOME" ] || fail

STARTUP_OS_RELEASE_PATH="${STARTUP_OS_RELEASE_PATH:-/etc/os-release}"
STARTUP_TEST_MODE="${STARTUP_TEST_MODE:-}"

case "$STARTUP_TEST_MODE" in
  ""|dispatch-only|distro-only) ;;
  *) fail ;;
esac

OS_RELEASE="$STARTUP_OS_RELEASE_PATH"
[ -r "$OS_RELEASE" ] || fail

# shellcheck disable=SC1090
. "$OS_RELEASE"

OS_ID="${ID:-}"
OS_LIKE="${ID_LIKE:-}"
[ -n "$OS_ID" ] || fail

DISTRO_SCRIPT="$(pick_distro_script)" || fail
[ -f "$DISTRO_SCRIPT" ] || fail
[ -r "$DISTRO_SCRIPT" ] || fail

case "$DISTRO_SCRIPT" in
  "$SELF_DIR"/distro/ubuntu/*) DISTRO_FAMILY="ubuntu" ;;
  "$SELF_DIR"/distro/fedora/*) DISTRO_FAMILY="fedora" ;;
  "$SELF_DIR"/distro/opensuse/*) DISTRO_FAMILY="opensuse" ;;
  *) fail ;;
esac

if [[ "$STARTUP_TEST_MODE" == "dispatch-only" ]]; then
  ok
  exit 0
fi

start_sudo_keepalive

# Close stdin after the single sudo password prompt.
exec </dev/null

has_gum() { command -v gum >/dev/null 2>&1; }

if ! command -v gum >/dev/null 2>&1; then
  step
  status_line "Preparing terminal interface"
  install_gum "$DISTRO_FAMILY" || fail
  if command -v gum >/dev/null 2>&1; then
    HAS_GUM=1
  fi
  ok
fi

step
status_line "Checking system compatibility"
ok

step
if [[ $EUID -eq 0 ]]; then
  spin_run "Running distribution setup" /usr/bin/env bash "$DISTRO_SCRIPT" "$@"
else
  spin_run "Running distribution setup" sudo /usr/bin/env bash "$DISTRO_SCRIPT" "$@"
fi
ok

if [[ "$STARTUP_TEST_MODE" == "distro-only" ]]; then
  ok
  exit 0
fi

if ! command -v nix >/dev/null 2>&1; then
  step
  spin_run "Installing nix package manager" \
    sh -c "curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm"
  ok
else
  status_line "Nix detected skipping installation"
fi

NIX_PROFILE='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
if [ -e "$NIX_PROFILE" ]; then
  # shellcheck disable=SC1090
  . "$NIX_PROFILE"
fi

need_cmd nix
need_cmd git

REPO_URL="https://github.com/parinya-ao/linux-config.git"

TARGET_DIR="${BOOTSTRAP_HOME}/.config/home-manager"

if [[ $EUID -eq 0 ]]; then
  USER_CMD=(sudo -u "$BOOTSTRAP_USER" env "HOME=$BOOTSTRAP_HOME")
else
  USER_CMD=(env "HOME=$BOOTSTRAP_HOME")
fi

"${USER_CMD[@]}" mkdir -p "$TARGET_DIR"

step
if [ ! -d "${TARGET_DIR}/.git" ]; then
  spin_run "Downloading configuration files" \
    "${USER_CMD[@]}" GIT_TERMINAL_PROMPT=0 git clone --quiet "$REPO_URL" "$TARGET_DIR"
else
  spin_run "Downloading configuration files" \
    "${USER_CMD[@]}" sh -c 'GIT_TERMINAL_PROMPT=0 git -C "$1" fetch --quiet origin && GIT_TERMINAL_PROMPT=0 git -C "$1" reset --hard origin/main >/dev/null' sh "$TARGET_DIR"
fi
ok

step
spin_run "Applying home manager flake" \
  "${USER_CMD[@]}" sh -c '
    cd "$1"
    nix --extra-experimental-features "nix-command flakes" \
      run home-manager/master -- \
      switch \
      --flake ".#parinya" \
      -b backup \
      --show-trace
  ' sh "$TARGET_DIR"
ok

STARTUP_CLEAR_FINAL="${STARTUP_CLEAR_FINAL:-0}"
if [[ "$STARTUP_CLEAR_FINAL" == "1" ]]; then
  clear
fi

if has_gum; then
  gum style \
    --foreground 212 --border-foreground 212 --border normal \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    "PROCESS COMPLETED" \
    "" \
    "ALL PACKAGES INSTALLED" \
    "ALL CONFIGURATIONS APPLIED" \
    "" \
    "CLOSE AND REOPEN TERMINAL NOW"
else
  printf '%s\n' "PROCESS COMPLETED"
  printf '%s\n' "ALL PACKAGES INSTALLED"
  printf '%s\n' "ALL CONFIGURATIONS APPLIED"
  printf '%s\n' "CLOSE AND REOPEN TERMINAL NOW"
fi
